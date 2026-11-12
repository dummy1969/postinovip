using MailKit.Security;
using Microsoft.Extensions.Configuration;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

// Uso:
//   PostinoVip.Cli                                              -> cartelle + ultime 20 mail di INBOX (sola lettura)
//   PostinoVip.Cli send --to <a,b> [--cc <c>] --subject <s> --body <b> -> invio SMTP, con conferma
//   PostinoVip.Cli flags [cartella]                             -> flag e parole chiave accettati dal server (sola lettura)

// Ordine di precedenza: appsettings.json < user-secrets < variabili d'ambiente.
var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)
    .AddUserSecrets<Program>(optional: true)
    .AddEnvironmentVariables()
    .Build();

var imapSettings = config.GetSection("Imap").Get<ImapSettings>() ?? new ImapSettings();
var smtpSettings = config.GetSection("Smtp").Get<SmtpSettings>() ?? new SmtpSettings();

smtpSettings.InheritCredentialsFrom(imapSettings);

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

try
{
    if (args.Length > 0 && args[0] == "send")
        return await SendAsync(args[1..], smtpSettings, cts.Token);
    if (args.Length > 0 && args[0] == "flags")
        return await FlagsAsync(imapSettings, args.Length > 1 ? args[1] : "INBOX", cts.Token);

    return await ListAsync(imapSettings, cts.Token);
}
catch (ArgumentException ex)
{
    Console.Error.WriteLine($"Configurazione: {ex.Message}");
    return 2;
}
catch (FormatException ex)
{
    Console.Error.WriteLine($"Indirizzo non valido: {ex.Message}");
    return 2;
}
catch (AuthenticationException)
{
    // Messaggio generico: non si riportano dettagli che possano contenere credenziali.
    Console.Error.WriteLine("Autenticazione fallita: controllare username e password.");
    return 3;
}
catch (OperationCanceledException)
{
    Console.Error.WriteLine("Annullato.");
    return 130;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Errore: {ex.GetType().Name}: {ex.Message}");
    return 1;
}

static async Task<int> ListAsync(ImapSettings settings, CancellationToken ct)
{
    await using var mail = new ImapMailService(settings);

    Console.WriteLine($"Connessione a {settings.Host}:{settings.Port} come {settings.Username} ...");
    await mail.ConnectAsync(ct);

    Console.WriteLine();
    Console.WriteLine("== Cartelle ==");
    foreach (var folder in await mail.GetFoldersAsync(ct))
        Console.WriteLine($"  {folder.FullName,-40} {folder.Count,6}");

    Console.WriteLine();
    Console.WriteLine("== INBOX: ultime 20 mail ==");
    var page = await mail.GetHeadersAsync("INBOX", offset: 0, limit: 20, ct: ct);
    if (page.Items.Count == 0)
        Console.WriteLine("  (INBOX vuota)");

    foreach (var h in page.Items)
    {
        var date = h.Date?.ToLocalTime().ToString("yyyy-MM-dd HH:mm") ?? "----------------";
        var mark = h.Seen ? " " : "*"; // * = non letta
        Console.WriteLine($"{mark} {date}  {Truncate(h.From, 28),-28}  {Truncate(h.Subject, 70)}");
    }

    return 0;
}

static async Task<int> SendAsync(string[] args, SmtpSettings settings, CancellationToken ct)
{
    string? to = null, cc = null, subject = null, body = null;
    for (var i = 0; i < args.Length - 1; i += 2)
    {
        switch (args[i])
        {
            case "--to": to = args[i + 1]; break;
            case "--cc": cc = args[i + 1]; break;
            case "--subject": subject = args[i + 1]; break;
            case "--body": body = args[i + 1]; break;
            default:
                Console.Error.WriteLine($"Opzione sconosciuta: {args[i]}");
                return 2;
        }
    }

    if (string.IsNullOrWhiteSpace(to) || subject is null || body is null)
    {
        Console.Error.WriteLine("Uso: send --to <indirizzi separati da virgola> [--cc <indirizzi>] --subject <oggetto> --body <testo>");
        return 2;
    }

    var msg = new OutgoingMessage(settings.Username, SplitAddresses(to), SplitAddresses(cc), subject, body);
    var smtp = new SmtpMailService(settings);
    _ = MimeMessageBuilder.Build(msg); // valida gli indirizzi prima di chiedere conferma

    // L'invio ha effetti esterni: riepilogo e conferma esplicita.
    Console.WriteLine($"Server:  {settings.Host}:{settings.Port} (STARTTLS)");
    Console.WriteLine($"Da:      {msg.From}");
    Console.WriteLine($"A:       {string.Join(", ", msg.To)}");
    if (msg.Cc.Count > 0)
        Console.WriteLine($"Cc:      {string.Join(", ", msg.Cc)}");
    Console.WriteLine($"Oggetto: {msg.Subject}");
    Console.WriteLine($"Testo:   {Truncate(msg.Body, 70)}");
    Console.Write("Inviare? [s/N] ");
    var answer = Console.ReadLine()?.Trim().ToLowerInvariant();
    if (answer is not ("s" or "si" or "sì"))
    {
        Console.WriteLine("Invio annullato.");
        return 0;
    }

    var result = await smtp.SendAsync(msg, ct);
    Console.WriteLine($"Inviato. Risposta del server: {result.ServerResponse}");
    return 0;
}

static List<string> SplitAddresses(string? list) =>
    (list ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).ToList();

static string Truncate(string s, int max) => s.Length <= max ? s : s[..(max - 1)] + "…";

// Diagnostica per le categorie (parole chiave IMAP): FLAGS e PERMANENTFLAGS della cartella, aperta con EXAMINE.
static async Task<int> FlagsAsync(ImapSettings settings, string folderName, CancellationToken ct)
{
    using var client = new MailKit.Net.Imap.ImapClient();
    await client.ConnectAsync(settings.Host, settings.Port, PostinoVip.Core.Security.ConnectionSecurityExtensions.ToMailKit(settings.EffectiveSecurity), ct);
    await client.AuthenticateAsync(settings.Username, settings.Password, ct);
    var folder = await client.GetFolderAsync(folderName, ct);
    await folder.OpenAsync(MailKit.FolderAccess.ReadOnly, ct);
    Console.WriteLine($"Cartella: {folder.FullName} (sola lettura)");
    Console.WriteLine($"FLAGS:          {folder.AcceptedFlags}; parole chiave: [{string.Join(", ", folder.AcceptedKeywords)}]");
    Console.WriteLine($"PERMANENTFLAGS: {folder.PermanentFlags}; parole chiave: [{string.Join(", ", folder.PermanentKeywords)}]");
    Console.WriteLine($"Parole chiave nuove permesse (\\*): {(folder.PermanentFlags.HasFlag(MailKit.MessageFlags.UserDefined) ? "sì" : "no")}");
    await client.DisconnectAsync(true, ct);
    return 0;
}
