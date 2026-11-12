using PostinoVip.Core.Account;
using PostinoVip.Core.Contacts;
using PostinoVip.Core.Contacts.CardDav;
using PostinoVip.Core.Dav;
using PostinoVip.Core.OAuth;

namespace PostinoVip.Core.Tests;

/// <summary>
/// C4d: CardDAV con OAuth2 (Google): permesso dei contatti chiesto solo quando serve, token Bearer al server dei
/// contatti, permesso mancante, 401 e 403 di Google spiegati. Fornitore e server CardDAV finti.
/// </summary>
public sealed class GoogleCardDavTests : IDisposable
{
    private const string Granted = "openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav";
    private readonly FakeOAuthServer _oauth = new() { Rotate = false, Scope = Granted };
    private readonly FakeCardDavServer _server = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-gcarddav-" + Guid.NewGuid().ToString("N"));

    public GoogleCardDavTests() => _server.AcceptBearer = t => t.StartsWith("AT", StringComparison.Ordinal);

    public void Dispose()
    {
        _server.Dispose();
        _oauth.Dispose();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private OAuthProvider Google(string? contactsScope = null) => OAuthProviders.GoogleFrom(new OAuthProviderSettings
    {
        ClientId = "client-di-prova", ClientSecret = "s", TokenEndpoint = _oauth.TokenEndpoint, ContactsScope = contactsScope,
        CardDavUrl = _server.Url + ".well-known/carddav",
    });

    private (DavClient Client, OAuthTokenSource Tokens, Uri Start) Client()
    {
        var tokens = new OAuthTokenSource(Google(), "RT0");
        var start = new Uri(tokens.Provider.CardDavUrl!);
        return (MailAccountRegistry.BearerClient(_server.User, tokens, start), tokens, start);
    }

    [Fact]
    public void PermessoDeiContattiSoloSeChiesto()
    {
        var google = OAuthProviders.GoogleFrom(new OAuthProviderSettings { ClientId = "c" });
        string Scope(bool contacts) => System.Web.HttpUtility.ParseQueryString(
            new Uri(OAuthClient.AuthorizationUrl(google, "http://localhost:1/oauth/callback", "s", "c", null, contacts)).Query)["scope"]!;

        Assert.Equal("openid email https://mail.google.com/", Scope(false));
        Assert.Equal("openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav", Scope(true));
        Assert.Equal("https://www.googleapis.com/.well-known/carddav", google.CardDavUrl);
        Assert.True(google.SupportsCardDav);
        Assert.False(OAuthProviders.MicrosoftFrom(new OAuthProviderSettings { ClientId = "c" }).SupportsCardDav);
        // permesso diverso dalla configurazione, senza ricompilare
        Assert.Equal(["https://www.googleapis.com/auth/contacts"], Google("https://www.googleapis.com/auth/contacts").ContactsScopesOrEmpty);
        Assert.True(google.GrantsContacts(Granted));
        Assert.False(google.GrantsContacts("openid email https://mail.google.com/"));
        Assert.Null(google.GrantsContacts(null));
    }

    [Fact]
    public async Task ScopertaConIlTokenDiAccesso()
    {
        var (client, tokens, start) = Client();
        using (client)
        {
            var found = await client.DiscoverAllAsync(start, CancellationToken.None);
            Assert.Equal(FakeCardDavServer.BookPath, found.Single().Url.AbsolutePath);
        }
        Assert.All(_server.Authorizations, a => Assert.Equal("Bearer AT1", a)); // mai la password, un solo token
        Assert.Equal(Granted, tokens.GrantedScopes);
    }

    [Fact]
    public async Task SenzaIlPermessoDeiContattiIlTokenNonParte()
    {
        _oauth.Scope = "openid email https://mail.google.com/"; // accesso fatto prima del C4d
        var (client, _, start) = Client();
        using (client)
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => client.DiscoverAllAsync(start, CancellationToken.None));
            Assert.Contains("non comprende i contatti", ex.Message);
        }
        Assert.Empty(_server.Requests);
    }

    [Fact]
    public async Task RifiutiDiGoogleSpiegati()
    {
        _server.AcceptBearer = _ => false;
        var (client, _, start) = Client();
        using (client)
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => client.DiscoverAllAsync(start, CancellationToken.None));
            Assert.Contains("rifai «Accedi con Google»", ex.Message);
            Assert.Equal(401, ex.Status);

            // dopo il 401 il token si chiede di nuovo
            _server.AcceptBearer = _ => true;
            _server.ForbiddenBody = """{"error":{"code":403,"message":"CardDAV API has not been used in project 123456 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/carddav.googleapis.com/overview?project=123456 then retry.","status":"PERMISSION_DENIED","details":[{"reason":"SERVICE_DISABLED"}]}}""";
            ex = await Assert.ThrowsAsync<DavException>(() => client.DiscoverAllAsync(start, CancellationToken.None));
            Assert.Contains("API CardDAV non è attiva", ex.Message);
            Assert.Contains("(https://console.developers.google.com/apis/api/carddav.googleapis.com/overview?project=123456)", ex.Message);
            Assert.Equal(2, _oauth.Requests.Count);

            _server.ForbiddenBody = """{"error":{"code":403,"status":"PERMISSION_DENIED","details":[{"reason":"ACCESS_TOKEN_SCOPE_INSUFFICIENT"}]}}""";
            ex = await Assert.ThrowsAsync<DavException>(() => client.DiscoverAllAsync(start, CancellationToken.None));
            Assert.Contains("non comprende il permesso dei contatti", ex.Message);
        }
    }

    [Fact]
    public async Task SincronizzazioneNeiDueSensiConIlToken()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com"));
        var store = new ContactStore(Path.Combine(_dir, "contacts"));
        var state = new DavStateStore(Path.Combine(_dir, "carddav.json"));
        store.Create(new Contact("", "Carla", "Neri", null, [new ContactEmail("carla@example.com")], [], null, null));
        var (client, _, start) = Client();
        using (var sync = new CardDavSync(client, store, state, start, start.AbsoluteUri))
        {
            await sync.RunAsync(DateTimeOffset.UtcNow, confirm: false, CancellationToken.None);
            Assert.Equal(2, store.List().Count);
            await sync.RunAsync(DateTimeOffset.UtcNow, confirm: true, CancellationToken.None);
        }
        Assert.Equal(2, _server.Cards.Count);
        Assert.Contains(_server.Cards.Values, v => v.Contains("carla@example.com"));
        Assert.DoesNotContain(_server.Authorizations, a => a.StartsWith("Basic", StringComparison.Ordinal));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ContattiNuoviConPostComeGoogle(bool withoutEtag)
    {
        _server.CreateWithPost = true;
        _server.PostWithoutEtag = withoutEtag;
        var store = new ContactStore(Path.Combine(_dir, "contacts"));
        var state = new DavStateStore(Path.Combine(_dir, "carddav.json"));
        var carla = store.Create(new Contact("", "Carla", "Neri", null, [new ContactEmail("carla@example.com")], [], null, null));
        store.Create(new Contact("", "Dario", "Blu", null, [new ContactEmail("dario@example.com")], [], null, null));
        var (client, _, start) = Client();
        using (var sync = new CardDavSync(client, store, state, start, start.AbsoluteUri))
        {
            await sync.RunAsync(DateTimeOffset.UtcNow, confirm: true, CancellationToken.None);
            // un solo PUT rifiutato, poi solo POST; indirizzi scelti dal server
            Assert.Single(_server.Requests, r => r.StartsWith("PUT"));
            Assert.Equal(2, _server.Requests.Count(r => r == "POST " + FakeCardDavServer.BookPath));
            Assert.Equal(["g1", "g2"], _server.Cards.Keys.Order().ToList());
            var entries = state.Load().Entries;
            Assert.All(entries, e => Assert.NotNull(e.Etag));

            // modifica dall'app: PUT con If-Match sull'indirizzo dato dal server; nessun doppione al giro dopo
            store.Update(carla.Id, carla with { Notes = "nuovo numero" });
            await sync.RunAsync(DateTimeOffset.UtcNow.AddSeconds(1), confirm: false, CancellationToken.None);
        }
        Assert.Equal(2, _server.Cards.Count);
        Assert.Contains("nuovo numero", _server.Cards.Single(c => c.Value.Contains("carla@example.com")).Value);
        Assert.Equal(2, store.List().Count);
    }

    [Fact]
    public async Task PutConLocationComeGoogle()
    {
        _server.PutCreatesWithOwnId = true;
        var store = new ContactStore(Path.Combine(_dir, "contacts"));
        var state = new DavStateStore(Path.Combine(_dir, "carddav.json"));
        var carla = store.Create(new Contact("", "Carla", "Neri", null, [new ContactEmail("carla@example.com")], [], null, null));
        var (client, _, start) = Client();
        using (var sync = new CardDavSync(client, store, state, start, start.AbsoluteUri))
        {
            await sync.RunAsync(DateTimeOffset.UtcNow, confirm: true, CancellationToken.None);
            Assert.Equal(FakeCardDavServer.BookPath + "id1", Assert.Single(state.Load().Entries).Href);

            // giro dopo: stesso contatto, stesso id (prima: «1 dal server, 1 eliminati qui» e id cambiato)
            var r = await sync.RunAsync(DateTimeOffset.UtcNow.AddSeconds(1), confirm: false, CancellationToken.None);
            Assert.Equal((0, 0), (r.Downloaded, r.DeletedHere));
            Assert.Equal(carla.Id, Assert.Single(store.List()).Id);

            store.Update(carla.Id, carla with { Notes = "nuovo numero" });
            await sync.RunAsync(DateTimeOffset.UtcNow.AddSeconds(2), confirm: false, CancellationToken.None);
            store.Delete(carla.Id);
            await sync.RunAsync(DateTimeOffset.UtcNow.AddSeconds(3), confirm: false, CancellationToken.None);
        }
        Assert.Empty(_server.Cards);
        Assert.Single(_server.Requests, r => r.StartsWith("DELETE " + FakeCardDavServer.BookPath + "id1"));
    }
}
