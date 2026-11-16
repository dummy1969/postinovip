using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using PostinoVip.Api;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;

var builder = WebApplication.CreateBuilder(args);

// Token obbligatorio: senza, il core non parte (errore chiaro invece di un'Api aperta).
ApiToken token;
try
{
    token = new ApiToken(builder.Configuration[ApiToken.ConfigKey] ?? "");
}
catch (ArgumentException ex)
{
    Console.Error.WriteLine($"Avvio non possibile: {ex.Message}");
    Console.Error.WriteLine("Per l'avvio manuale: export POSTINOVIP_TOKEN=$(openssl rand -hex 32)");
    return 2;
}
builder.Services.AddSingleton(token);

// Solo loopback, impostato nel codice: ha la precedenza su ASPNETCORE_URLS e launchSettings.
// Porta 0 = scelta dal sistema operativo (avvio dall'app); 5080 per l'avvio manuale.
var port = builder.Configuration.GetValue("Api:Port", 5080);
builder.WebHost.ConfigureKestrel(o => o.Listen(IPAddress.Loopback, port));

// Avviato dall'app (POSTINOVIP_MANAGED=1): termina quando l'app chiude lo stdin.
// Confronto testuale: GetValue<bool> non accetta "1".
if (builder.Configuration["POSTINOVIP_MANAGED"] is "1" or "true")
    builder.Services.AddHostedService<StdinWatcher>();

// Caselle: elenco "Accounts" oppure le sezioni "Imap"/"Smtp" del formato a un account.
// Lette all'avvio: con dati non validi il core non parte (errore chiaro invece di 500 a ogni richiesta).
IReadOnlyList<MailAccountSettings> accountSettings;
try
{
    accountSettings = AccountsConfiguration.Read(builder.Configuration);
}
catch (ArgumentException ex)
{
    Console.Error.WriteLine($"Avvio non possibile: {ex.Message}");
    return 2;
}
builder.Services.AddSingleton(accountSettings);

// OAuth2 (O1): client ID dei fornitori da oauth-clients.json accanto al core o nella cartella del progetto (escluso
// da git: identifica chi distribuisce PostinoVip), oppure da variabili OAuth__Microsoft__ClientId.
// Nei test (ambiente Testing) no: le prove non devono dipendere dalla registrazione vera.
if (!builder.Environment.IsEnvironment("Testing"))
{
    builder.Configuration.AddJsonFile(Path.Combine(AppContext.BaseDirectory, "oauth-clients.json"), optional: true, reloadOnChange: false);
    builder.Configuration.AddJsonFile("oauth-clients.json", optional: true, reloadOnChange: false);
    builder.Configuration.AddEnvironmentVariables();
}
var oauthProviders = PostinoVip.Core.OAuth.OAuthProviders.From(
    builder.Configuration.GetSection("OAuth").Get<Dictionary<string, PostinoVip.Core.OAuth.OAuthProviderSettings>>() ?? []);
builder.Services.AddSingleton(oauthProviders);
builder.Services.AddSingleton<OAuthLogins>();

// Cache locale (SQLite + file .eml), una cartella per account. Cache:Enabled=false la disattiva (tutto letto dal server).
var cacheRoot = builder.Configuration["Cache:Enabled"] is "false" ? null : CacheLocation.Resolve(builder.Configuration, builder.Environment);
builder.Services.AddSingleton(new CacheSettings(cacheRoot));

// Una connessione IMAP persistente per account (chiuse dal container all'arresto).
builder.Services.AddSingleton(sp =>
{
    var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("PostinoVip.Cache");
    var hub = sp.GetRequiredService<MailboxEventHub>();
    return MailAccountRegistry.CreateImap(sp.GetRequiredService<IReadOnlyList<MailAccountSettings>>(), cacheRoot,
        message => logger.LogInformation("{Message}", message),
        (account, online) => hub.Publish(MailboxEvent.Connection(account, online)),
        // POP3 (4.2): mail nuove nella Posta in arrivo locale, come la notifica IDLE di INBOX.
        (account, count) => hub.Publish(MailboxEvent.Changed(account, PostinoVip.Core.Local.LocalMailStore.Inbox, count)),
        oauthProviders,
        // Nuovo token di rinnovo (Microsoft lo cambia a ogni rinnovo): all'app, che lo salva nel portachiavi (4a).
        (account, refreshToken) => hub.Publish(MailboxEvent.CredentialsChanged(account, refreshToken)),
        // Token di rinnovo rifiutato (scaduto o revocato) o di nuovo valido: «Accedi di nuovo» nell'app (2a).
        (account, needsLogin) => hub.Publish(MailboxEvent.LoginStatus(account, needsLogin)),
        // CardDAV (C4b): rubrica cambiata sul computer, o conferma della prima volta da chiedere: l'app la rilegge.
        (account, result) =>
        {
            if (result.LocalChanged || result.NeedsConfirmation)
                hub.Publish(MailboxEvent.ContactsChanged(account, result.Downloaded + result.DeletedHere));
        },
        // CalDAV (K2a): calendari cambiati sul computer, o conferma della prima volta da chiedere.
        (account, result) =>
        {
            if (result.LocalChanged || result.NeedsConfirmation)
                hub.Publish(MailboxEvent.CalendarsChanged(account, result.Downloaded + result.DeletedHere));
        },
        // Lista aperta su una cartella con molte mail nuove (11/11/2026, 1a): il download in background la completa.
        // Senza download in background la lista sincronizza tutta la cartella, come prima.
        builder.Configuration["Cache:Download:Enabled"] is "false" ? null
            : (account, folder) => hub.Publish(MailboxEvent.HeadersPending(account, folder)));
});
// Pulizia periodica della cache (corpi fuori dal limite, file orfani) e download in background dei corpi
// su una connessione IMAP dedicata per account (Cache:Download:Enabled=false lo disattiva).
if (cacheRoot is not null)
{
    builder.Services.AddHostedService<CacheMaintenanceService>();
    if (builder.Configuration["Cache:Download:Enabled"] is not "false")
        builder.Services.AddHostedService<CacheDownloadService>();
}
// Controllo di INBOX in tempo reale (IDLE) su una connessione dedicata per account; eventi verso l'app via /events.
builder.Services.AddSingleton<MailboxEventHub>();
// File .eml aperti nell'app (E1): solo in memoria, in sola lettura.
builder.Services.AddSingleton(new PostinoVip.Core.Eml.EmlStore());
// Account non raggiungibili: nuovo tentativo periodico, per tornare "connessi" anche senza clic.
builder.Services.AddHostedService<ConnectivityService>();
// Posta in uscita e bozze scritte senza connessione (3.8): servono la cache locale (la coda sta lì).
builder.Services.AddSingleton<OutboxSignal>();
if (cacheRoot is not null && builder.Configuration["Outbox:Enabled"] is not "false")
    builder.Services.AddHostedService<OutboxService>();
if (builder.Configuration["Watch:Enabled"] is not "false")
    builder.Services.AddHostedService<InboxWatcherService>();
// Regole sulle mail nuove della Posta in arrivo (R1); Rules:Enabled=false le disattiva (test).
builder.Services.AddSingleton<RuleJobs>();
if (cacheRoot is not null && builder.Configuration["Rules:Enabled"] is not "false")
    builder.Services.AddHostedService<RulesService>();
// Controllo periodico della posta degli account POP3 (4.2); Pop3:Enabled=false lo disattiva (test).
if (builder.Configuration["Pop3:Enabled"] is not "false")
    builder.Services.AddHostedService<Pop3Service>();
// Sincronizzazione dei contatti con CardDAV (C4b) e dei calendari con CalDAV (K2a) per gli account che la attivano;
// CardDavSync:Enabled=false le ferma entrambe (test). (CardDav:Enabled e CalDav:Enabled, senza "Sync", sono invece le
// impostazioni dell'account "main" degli user-secrets.)
if (builder.Configuration["CardDavSync:Enabled"] is not "false")
    builder.Services.AddHostedService<CardDavService>();

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<MailExceptionHandler>();
builder.Services.AddOpenApi();

var app = builder.Build();

app.UseExceptionHandler();
app.UseMiddleware<TokenAuthMiddleware>(); // prima di tutto il resto, OpenAPI compreso
// Lingua dell'app (tappa «Lingua», L6, scelta 2a): ogni richiesta la porta; il core la usa per i testi che scrive da solo.
// Solo le richieste dell'app (con il token): il browser che torna dall'accesso OAuth ha la sua lingua, non quella dell'app.
app.Use((context, next) =>
{
    if (context.Request.Headers.Authorization.Count > 0)
        PostinoVip.Core.UiLanguage.Set(context.Request.Headers.AcceptLanguage);
    return next(context);
});

// Documento OpenAPI su /openapi/v1.json in sviluppo e nei test; non nella build di rilascio.
if (!app.Environment.IsProduction())
    app.MapOpenApi();

app.MapControllers();

// Annuncia la porta effettiva (utile con porta 0): l'app legge questa riga dallo stdout.
app.Lifetime.ApplicationStarted.Register(() =>
{
    var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()?.Addresses.FirstOrDefault();
    if (address is null)
        return; // TestServer nei test: nessun indirizzo reale
    var actualPort = new Uri(address.Replace("://[::]", "://localhost")).Port;
    Console.Out.WriteLine($"POSTINOVIP_READY {JsonSerializer.Serialize(new { port = actualPort })}");
    Console.Out.Flush();
});

app.Run();
return 0;

// Rende Program visibile a WebApplicationFactory nei test.
public partial class Program;
