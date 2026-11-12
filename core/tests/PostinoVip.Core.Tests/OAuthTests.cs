using PostinoVip.Core.Account;
using PostinoVip.Core.Imap;
using PostinoVip.Core.OAuth;
using PostinoVip.Core.Pop3;
using PostinoVip.Core.Security;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

/// <summary>OAuth2 (O1): PKCE, indirizzo di accesso, token con rinnovo, XOAUTH2 su IMAP/SMTP/POP3, con fornitore finto.</summary>
public sealed class OAuthTests : IDisposable
{
    private readonly FakeOAuthServer _oauth = new();

    public void Dispose() => _oauth.Dispose();

    private OAuthProvider Provider() => OAuthProviders.MicrosoftFrom(new OAuthProviderSettings
    {
        ClientId = "client-di-prova", TokenEndpoint = _oauth.TokenEndpoint, AuthorizationEndpoint = "https://login.example/authorize",
    });

    [Fact]
    public void PkceComeNellaRfc7636()
    {
        // Esempio dell'appendice B della RFC 7636.
        Assert.Equal("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", Pkce.Challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"));
        var v = Pkce.NewVerifier();
        Assert.Equal(43, v.Length);
        Assert.DoesNotContain('=', v);
        Assert.NotEqual(v, Pkce.NewVerifier());
    }

    [Fact]
    public void IndirizzoDellaPaginaDiAccesso()
    {
        var url = new Uri(OAuthClient.AuthorizationUrl(Provider(), "http://localhost:5100/oauth/callback", "stato", "sfida", "io@outlook.it"));
        var q = System.Web.HttpUtility.ParseQueryString(url.Query);

        Assert.Equal("login.example", url.Host);
        Assert.Equal(("client-di-prova", "code", "S256", "sfida", "stato"), (q["client_id"], q["response_type"], q["code_challenge_method"], q["code_challenge"], q["state"]));
        Assert.Equal("http://localhost:5100/oauth/callback", q["redirect_uri"]);
        Assert.Contains("offline_access", q["scope"]);
        Assert.Contains("https://outlook.office.com/IMAP.AccessAsUser.All", q["scope"]);
        Assert.Contains("https://outlook.office.com/SMTP.Send", q["scope"]);
        Assert.Equal("io@outlook.it", q["login_hint"]);
    }

    [Fact]
    public void IndirizzoDallIdToken()
    {
        Assert.Equal("io@outlook.it", OAuthClient.EmailFromIdToken(FakeOAuthServer.IdToken("io@outlook.it")));
        Assert.Null(OAuthClient.EmailFromIdToken("non-un-jwt"));
        Assert.Null(OAuthClient.EmailFromIdToken(null));
    }

    [Fact]
    public async Task CodiceScambiatoConPkce()
    {
        var tokens = await OAuthClient.ExchangeCodeAsync(Provider(), "good-code", "verificatore", "http://localhost:1/oauth/callback");

        Assert.Equal(("RT1", "io@outlook.it"), (tokens.RefreshToken, tokens.Email));
        var sent = _oauth.Requests.Single();
        Assert.Equal(("authorization_code", "verificatore", "client-di-prova"), (sent["grant_type"], sent["code_verifier"], sent["client_id"]));
        Assert.False(sent.ContainsKey("client_secret")); // Microsoft, app pubblica: niente segreto
    }

    [Fact]
    public async Task TokenTenutoFinoAllaScadenzaERinnovoComunicato()
    {
        var rotated = new List<string>();
        var source = new OAuthTokenSource(Provider(), "RT0", rotated.Add);

        var first = await source.GetAccessTokenAsync();
        var again = await source.GetAccessTokenAsync();

        Assert.Equal(first, again); // in memoria: una sola richiesta
        Assert.Single(_oauth.Requests);
        Assert.Equal("RT0", _oauth.Requests.Single()["refresh_token"]);
        Assert.Single(rotated); // Microsoft cambia il token di rinnovo: all'app, per il portachiavi
        source.Invalidate();
        await source.GetAccessTokenAsync();
        Assert.Equal(rotated[0], _oauth.Requests.Last()["refresh_token"]); // il nuovo, non quello vecchio
    }

    [Fact]
    public async Task TokenRevocatoChiedeUnNuovoAccessoESenzaReteNonConnesso()
    {
        var revoked = await Assert.ThrowsAsync<OAuthException>(() => new OAuthTokenSource(Provider(), "revoked").GetAccessTokenAsync());
        Assert.True(revoked.NeedsLogin);
        Assert.Contains("Accedi con Microsoft", revoked.Message);

        var offline = OAuthProviders.MicrosoftFrom(new OAuthProviderSettings { ClientId = "x", TokenEndpoint = "http://127.0.0.1:1/token" });
        await Assert.ThrowsAsync<MailOfflineException>(() => new OAuthTokenSource(offline, "RT").GetAccessTokenAsync());
    }

    [Fact]
    public async Task ImapSmtpPop3AccedonoConXoauth2()
    {
        var source = new OAuthTokenSource(Provider(), "RT0");
        var trust = (FakeMailServer s) => TrustedCertificate.Fingerprint(s.Certificate);

        await using var imap = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: true, offerStartTls: false);
        await using (var session = new ImapMailService(new ImapSettings
        {
            Host = "127.0.0.1", Port = imap.Port, Username = "io@outlook.it", Security = ConnectionSecurity.SslOnConnect,
            CertificateSha256 = trust(imap), AccessToken = source.GetAccessTokenAsync,
        }))
            await session.ConnectAsync();
        var token = await source.GetAccessTokenAsync();
        Assert.Equal($"io@outlook.it {token}", Assert.Single(imap.OAuthLogins));
        Assert.DoesNotContain(imap.Commands, c => c.Contains("LOGIN"));

        await using var smtp = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: true, offerStartTls: false);
        await new SmtpMailService(new SmtpSettings
        {
            Host = "127.0.0.1", Port = smtp.Port, Username = "io@outlook.it", Security = ConnectionSecurity.SslOnConnect,
            CertificateSha256 = trust(smtp), AccessToken = source.GetAccessTokenAsync,
        }).TestAsync();
        Assert.Equal($"io@outlook.it {token}", Assert.Single(smtp.OAuthLogins));

        await using var pop3 = new FakeMailServer(FakeMailServer.Protocol.Pop3, implicitTls: true, offerStartTls: false);
        var check = await AccountTester.TestPop3Async(new Pop3Settings
        {
            Host = "127.0.0.1", Port = pop3.Port, Username = "io@outlook.it", Security = ConnectionSecurity.SslOnConnect,
            CertificateSha256 = trust(pop3), AccessToken = source.GetAccessTokenAsync,
        });
        Assert.True(check.Ok, check.Error);
        Assert.Equal($"io@outlook.it {token}", Assert.Single(pop3.OAuthLogins));
        Assert.DoesNotContain(pop3.Commands, c => c.StartsWith("PASS"));
    }

    [Fact]
    public async Task GoogleConSegretoServerGmailESenzaScopeNelRinnovo()
    {
        var google = OAuthProviders.GoogleFrom(new OAuthProviderSettings
        {
            ClientId = "id-google", ClientSecret = "segreto-desktop", TokenEndpoint = _oauth.TokenEndpoint,
        });
        Assert.Contains("https://mail.google.com/", google.Scopes);
        Assert.Equal(("imap.gmail.com", 993, "smtp.gmail.com", 587, "pop.gmail.com", 995),
            (google.Servers.ImapHost, google.Servers.ImapPort, google.Servers.SmtpHost, google.Servers.SmtpPort, google.Servers.Pop3Host, google.Servers.Pop3Port));
        Assert.Equal(ConnectionSecurity.StartTls, google.Servers.SmtpSecurity);
        Assert.StartsWith("https://accounts.google.com/o/oauth2/v2/auth?", OAuthClient.AuthorizationUrl(google, "http://localhost:1/oauth/callback", "s", "c", null));

        await new OAuthTokenSource(google, "RT0").GetAccessTokenAsync();
        var sent = _oauth.Requests.Single();
        Assert.Equal("segreto-desktop", sent["client_secret"]);
        Assert.False(sent.ContainsKey("scope")); // Google: il rinnovo non elenca gli scope

        await new OAuthTokenSource(Provider(), "RT0").GetAccessTokenAsync();
        Assert.Contains("IMAP.AccessAsUser.All", _oauth.Requests.Last()["scope"]); // Microsoft sì

        var all = OAuthProviders.From(new Dictionary<string, OAuthProviderSettings> { ["Google"] = new() { ClientId = "x" } });
        Assert.True(all["google"].IsConfigured);
        Assert.False(all["microsoft"].IsConfigured);
    }

    [Fact]
    public async Task AccessoScadutoSegnalatoEPoiDiNuovoValido()
    {
        var changes = new List<bool>();
        var source = new OAuthTokenSource(Provider(), "RT0", needsLoginChanged: changes.Add);
        _oauth.Rotate = false;
        _oauth.Revoked = "RT0";

        await Assert.ThrowsAsync<OAuthException>(() => source.GetAccessTokenAsync());
        await Assert.ThrowsAsync<OAuthException>(() => source.GetAccessTokenAsync());
        Assert.True(source.NeedsLogin);
        Assert.Equal([true], changes); // segnalato una volta sola

        _oauth.Revoked = null;
        await source.GetAccessTokenAsync();
        Assert.False(source.NeedsLogin);
        Assert.Equal([true, false], changes);

        // Senza rete non è "accesso scaduto".
        var offline = new OAuthTokenSource(OAuthProviders.MicrosoftFrom(new OAuthProviderSettings { ClientId = "x", TokenEndpoint = "http://127.0.0.1:1/token" }),
            "RT", needsLoginChanged: changes.Add);
        await Assert.ThrowsAsync<MailOfflineException>(() => offline.GetAccessTokenAsync());
        Assert.False(offline.NeedsLogin);
    }

    [Fact]
    public async Task RegistroUsaIlTokenEFornitoreSconosciutoBloccaLAvvio()
    {
        MailAccountSettings Account(string provider) => new()
        {
            Id = "ms",
            Imap = new ImapSettings { Host = "imap.example", Username = "io@outlook.it" },
            Smtp = new SmtpSettings { Host = "smtp.example", Username = "io@outlook.it" },
            OAuth = new AccountOAuthSettings { Provider = provider, RefreshToken = "RT0" },
        };
        var providers = new Dictionary<string, OAuthProvider> { ["microsoft"] = Provider() };
        var changed = new List<(string, string)>();

        var settings = Account("microsoft");
        Assert.True(settings.IsConfigured); // senza password
        var needsLogin = new List<(string, bool)>();
        await using (var registry = MailAccountRegistry.CreateImap([settings], oauthProviders: providers,
            refreshTokenChanged: (a, t) => changed.Add((a, t)), needsLoginChanged: (a, v) => needsLogin.Add((a, v))))
        {
            Assert.NotNull(settings.Imap.AccessToken);
            Assert.Same(settings.Imap.AccessToken!.Target, settings.Smtp.AccessToken!.Target); // un solo token per l'account
            await settings.Smtp.AccessToken(default);
            Assert.Equal("ms", Assert.Single(changed).Item1);

            // Token di rinnovo rifiutato: l'account chiede un nuovo accesso (2a).
            _oauth.Revoked = changed[0].Item2;
            settings.OAuth.Tokens!.Invalidate();
            await Assert.ThrowsAsync<OAuthException>(() => settings.Imap.AccessToken(default));
            Assert.True(registry.Get("ms").NeedsLogin);
            Assert.Equal(("ms", true), Assert.Single(needsLogin));
        }

        Assert.Throws<ArgumentException>(() => MailAccountRegistry.CreateImap([Account("boh")], oauthProviders: providers));
        var noClient = new Dictionary<string, OAuthProvider> { ["microsoft"] = OAuthProviders.MicrosoftFrom(null) };
        Assert.Contains("client ID", Assert.Throws<ArgumentException>(() => MailAccountRegistry.CreateImap([Account("microsoft")], oauthProviders: noClient)).Message);
    }
}
