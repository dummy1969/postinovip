using System.Collections.Concurrent;
using System.Security.Cryptography;
using PostinoVip.Core;
using PostinoVip.Core.OAuth;

namespace PostinoVip.Api;

/// <summary>Stato di un accesso OAuth2 per l'app: in attesa, riuscito (con token di rinnovo e indirizzo) o non riuscito.</summary>
/// <summary>
/// <see cref="Contacts"/> e <see cref="Calendar"/>: il fornitore ha concesso il permesso dei contatti / del calendario
/// (null = non chiesto o non si sa).
/// </summary>
public sealed record OAuthFlowStatus(string Id, string Provider, string Status, string? Email, string? RefreshToken, string? Error,
    OAuthServers? Servers, bool? Contacts = null, bool? Calendar = null)
{
    /// <summary>Codice e valori di <see cref="Error"/> per l'app (L6).</summary>
    public string? ErrorCode { get; init; }
    public IReadOnlyDictionary<string, string>? ErrorArgs { get; init; }
}

/// <summary>
/// Accessi OAuth2 in corso (3a: browser di sistema + ritorno su http://localhost:{porta del core}/oauth/callback, PKCE).
/// Ogni accesso ha uno "state" casuale, usabile una volta sola e per <see cref="Lifetime"/>; il verificatore PKCE non
/// esce dal core. Il token di rinnovo si consegna all'app una volta sola (poi l'accesso si dimentica).
/// </summary>
public sealed class OAuthLogins(IReadOnlyDictionary<string, OAuthProvider> providers, ILogger<OAuthLogins> logger)
{
    public const string CallbackPath = "/oauth/callback";
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);

    private readonly ConcurrentDictionary<string, Flow> _flows = new();

    public IReadOnlyDictionary<string, OAuthProvider> Providers => providers;

    public (string Id, string Url) Start(string providerId, string redirectUri, string? loginHint, bool contacts = false,
        bool calendar = false)
    {
        Cleanup();
        if (!providers.TryGetValue(providerId, out var provider))
            throw new PostinoVip.Core.FieldValidationException("provider", $"Fornitore sconosciuto: {providerId}.");
        if (!provider.IsConfigured)
            throw new InvalidOperationException(
                $"Manca il client ID di {provider.DisplayName}: va registrata l'app e scritto in oauth-clients.json (sezione OAuth:{provider.Id}).").WithCode("mancaIlClientIdDi", ("displayName", provider.DisplayName), ("id", provider.Id));
        if (contacts && !provider.SupportsCardDav)
            throw new PostinoVip.Core.FieldValidationException("contacts", $"La sincronizzazione dei contatti non è disponibile con {provider.DisplayName}.").WithCode("laSincronizzazioneDeiContattiNon", ("displayName", provider.DisplayName));
        if (calendar && !provider.SupportsCalDav)
            throw new PostinoVip.Core.FieldValidationException("calendar", $"La sincronizzazione del calendario non è disponibile con {provider.DisplayName}.").WithCode("laSincronizzazioneDelCalendarioNon", ("displayName", provider.DisplayName));
        var flow = new Flow(Random(), provider, Random(), Pkce.NewVerifier(), redirectUri) { Contacts = contacts, Calendar = calendar };
        _flows[flow.Id] = flow;
        return (flow.Id, OAuthClient.AuthorizationUrl(provider, redirectUri, flow.State, Pkce.Challenge(flow.Verifier), loginHint, contacts, calendar));
    }

    /// <summary>Il browser è tornato: scambia il codice con i token. Restituisce il testo della pagina mostrata nel browser.</summary>
    public async Task<(bool Ok, string Message)> CompleteAsync(string? state, string? code, string? error, string? errorDescription,
        CancellationToken ct)
    {
        var flow = state is null ? null : _flows.Values.FirstOrDefault(f => CryptographicOperations.FixedTimeEquals(
            System.Text.Encoding.ASCII.GetBytes(f.State), System.Text.Encoding.ASCII.GetBytes(state)));
        if (flow is null || flow.Done || DateTimeOffset.UtcNow - flow.Created > Lifetime)
            return (false, PostinoVip.Core.Texts.CoreTexts.Get("oauthUnknownFlow"));
        flow.Done = true;
        if (error is not null || string.IsNullOrEmpty(code))
        {
            flow.Error = error == "access_denied" ? "Accesso annullato." : $"Accesso non riuscito ({error ?? "nessun codice"}).";
            flow.ErrorCode = error == "access_denied" ? "oauthCancelled" : error is null ? "oauthNoCode" : "oauthFlowFailed";
            flow.ErrorArgs = new Dictionary<string, string> { ["error"] = error ?? "" };
            logger.LogInformation("Accesso OAuth {Provider} non riuscito: {Error}", flow.Provider.Id, error ?? "senza codice");
            // Pagina del browser nella lingua dell'app (L6b).
            return (false, flow.ErrorCode switch
            {
                "oauthCancelled" => PostinoVip.Core.Texts.CoreTexts.Get("oauthCancelled"),
                "oauthNoCode" => PostinoVip.Core.Texts.CoreTexts.Get("oauthNoCode"),
                _ => PostinoVip.Core.Texts.CoreTexts.Get("oauthFlowFailed", ("error", error ?? "")),
            });
        }
        try
        {
            var tokens = await OAuthClient.ExchangeCodeAsync(flow.Provider, code, flow.Verifier, flow.RedirectUri, ct);
            if (string.IsNullOrEmpty(tokens.RefreshToken))
                throw new OAuthException("no_refresh_token", "Il fornitore non ha dato un token di rinnovo (manca offline_access?).")
                    .WithCode("oauthNoRefreshToken");
            flow.RefreshToken = tokens.RefreshToken;
            flow.Email = tokens.Email;
            flow.Granted = flow.Contacts ? flow.Provider.GrantsContacts(tokens.Scope) : null;
            flow.GrantedCalendar = flow.Calendar ? flow.Provider.GrantsCalendar(tokens.Scope) : null;
            logger.LogInformation("Accesso OAuth {Provider} riuscito{Contacts}{Calendar}", flow.Provider.Id,
                flow.Granted switch { true => " (con i contatti)", false => " (senza il permesso dei contatti)", _ => "" },
                flow.GrantedCalendar switch { true => " (con il calendario)", false => " (senza il permesso del calendario)", _ => "" });
            return (true, PostinoVip.Core.Texts.CoreTexts.Get("oauthDone"));
        }
        catch (Exception ex) when (ex is OAuthException or PostinoVip.Core.MailOfflineException)
        {
            flow.Error = ex.Message;
            flow.ErrorCode = CoreError.CodeOf(ex);
            flow.ErrorArgs = CoreError.ArgsOf(ex);
            logger.LogInformation("Accesso OAuth {Provider} non riuscito: {Type}", flow.Provider.Id, ex.GetType().Name);
            return (false, ex.Message);
        }
    }

    /// <summary>Stato per l'app; a accesso riuscito il token di rinnovo si consegna una sola volta.</summary>
    public OAuthFlowStatus? Status(string id)
    {
        if (!_flows.TryGetValue(id, out var f))
            return null;
        var status = f.RefreshToken is not null ? "done" : f.Error is not null ? "error" : "pending";
        var result = new OAuthFlowStatus(f.Id, f.Provider.Id, status, f.Email, f.RefreshToken, f.Error, f.Provider.Servers, f.Granted,
            f.GrantedCalendar) { ErrorCode = f.Error is null ? null : f.ErrorCode, ErrorArgs = f.Error is null ? null : f.ErrorArgs };
        if (status != "pending")
            _flows.TryRemove(id, out _);
        return result;
    }

    public bool Cancel(string id) => _flows.TryRemove(id, out _);

    private void Cleanup()
    {
        foreach (var (id, f) in _flows)
            if (DateTimeOffset.UtcNow - f.Created > Lifetime)
                _flows.TryRemove(id, out _);
    }

    private static string Random() => Pkce.Base64Url(RandomNumberGenerator.GetBytes(24));

    private sealed class Flow(string id, OAuthProvider provider, string state, string verifier, string redirectUri)
    {
        public string Id { get; } = id;
        public OAuthProvider Provider { get; } = provider;
        public string State { get; } = state;
        public string Verifier { get; } = verifier;
        public string RedirectUri { get; } = redirectUri;
        public DateTimeOffset Created { get; } = DateTimeOffset.UtcNow;
        public volatile bool Done;
        public string? ErrorCode;
        public IReadOnlyDictionary<string, string>? ErrorArgs;
        public string? RefreshToken;
        public string? Email;
        public string? Error;
        public bool Contacts { get; init; }
        public bool? Granted;
        public bool Calendar { get; init; }
        public bool? GrantedCalendar;
    }
}
