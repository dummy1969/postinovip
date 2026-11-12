using PostinoVip.Core.Account;
using PostinoVip.Core.Calendars;
using PostinoVip.Core.Dav;
using PostinoVip.Core.OAuth;

namespace PostinoVip.Core.Tests;

/// <summary>
/// G1: CalDAV con OAuth2 (Google): permesso del calendario chiesto solo quando serve, principal di Google come partenza,
/// token Bearer, permesso mancante e 403 spiegati per il calendario. Fornitore e server CalDAV finti.
/// </summary>
public sealed class GoogleCalDavTests : IDisposable
{
    private const string Granted = "openid email https://mail.google.com/ https://www.googleapis.com/auth/calendar";
    private readonly FakeOAuthServer _oauth = new() { Rotate = false, Scope = Granted };
    private readonly FakeCardDavServer _server = new(caldav: true) { SecondCalendar = true };
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-gcaldav-" + Guid.NewGuid().ToString("N"));

    public GoogleCalDavTests() => _server.AcceptBearer = t => t.StartsWith("AT", StringComparison.Ordinal);

    public void Dispose()
    {
        _server.Dispose();
        _oauth.Dispose();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private OAuthProvider Google() => OAuthProviders.GoogleFrom(new OAuthProviderSettings
    {
        ClientId = "client-di-prova", ClientSecret = "s", TokenEndpoint = _oauth.TokenEndpoint,
        CalDavUrl = _server.Url + ".well-known/caldav",
    });

    private (DavClient Client, Uri Start) Client()
    {
        var tokens = new OAuthTokenSource(Google(), "RT0");
        var start = MailAccountRegistry.OAuthStart(tokens.Provider, DavKind.CalDav, _server.User)!;
        return (MailAccountRegistry.BearerClient(_server.User, tokens, start, kind: DavKind.CalDav), start);
    }

    [Fact]
    public void PermessoDelCalendarioSoloSeChiesto()
    {
        var google = OAuthProviders.GoogleFrom(new OAuthProviderSettings { ClientId = "c" });
        string Scope(bool contacts, bool calendar) => System.Web.HttpUtility.ParseQueryString(new Uri(
            OAuthClient.AuthorizationUrl(google, "http://localhost:1/oauth/callback", "s", "c", null, contacts, calendar)).Query)["scope"]!;

        Assert.Equal("openid email https://mail.google.com/", Scope(false, false));
        Assert.Equal("openid email https://mail.google.com/ https://www.googleapis.com/auth/calendar", Scope(false, true));
        Assert.Equal("openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav https://www.googleapis.com/auth/calendar",
            Scope(true, true));
        Assert.Equal("https://apidata.googleusercontent.com/caldav/v2/io@gmail.com/user", google.CalDavUrlFor(" io@gmail.com "));
        Assert.True(google.SupportsCalDav);
        Assert.False(OAuthProviders.MicrosoftFrom(new OAuthProviderSettings { ClientId = "c" }).SupportsCalDav);
        Assert.True(google.GrantsCalendar(Granted));
        Assert.False(google.GrantsCalendar("openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav"));
        Assert.Equal(["https://www.googleapis.com/auth/calendar.events"],
            OAuthProviders.GoogleFrom(new OAuthProviderSettings { ClientId = "c", CalendarScope = "https://www.googleapis.com/auth/calendar.events" })
                .CalendarScopesOrEmpty);
    }

    [Fact]
    public async Task ScopertaDeiCalendariConIlToken()
    {
        var (client, start) = Client();
        using (client)
        {
            var found = await client.DiscoverAllAsync(start, CancellationToken.None);
            Assert.Equal([FakeCardDavServer.CalendarPath, FakeCardDavServer.SecondCalendarPath], found.Select(f => f.Url.AbsolutePath).Order());
        }
        Assert.All(_server.Authorizations, a => Assert.Equal("Bearer AT1", a));
    }

    [Fact]
    public async Task SenzaIlPermessoDelCalendarioIlTokenNonParte()
    {
        _oauth.Scope = "openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav"; // solo i contatti
        var (client, start) = Client();
        using (client)
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => client.DiscoverAllAsync(start, CancellationToken.None));
            Assert.Contains("non comprende il calendario", ex.Message);
        }
        Assert.Empty(_server.Requests);

        _oauth.Scope = Granted;
        _server.ForbiddenBody = """{"error":{"code":403,"message":"CalDAV API has not been used in project 9 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/caldav.googleapis.com/overview?project=9 then retry.","details":[{"reason":"SERVICE_DISABLED"}]}}""";
        var (other, otherStart) = Client();
        using (other)
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => other.DiscoverAllAsync(otherStart, CancellationToken.None));
            Assert.Contains("L'API CalDAV non è attiva", ex.Message);
            Assert.Contains("caldav.googleapis.com", ex.Message);
        }
    }

    [Fact]
    public async Task CalendariSincronizzatiConIlToken()
    {
        _server.Put("s1.ics", FakeCardDavServer.Event("s1", "Dal server"));
        var set = new CalendarSet(Path.Combine(_dir, "calendars"));
        var (client, start) = Client();
        using (var job = new CalDavSyncJob(client, set, start))
        {
            await job.RunAsync(DateTimeOffset.UtcNow, confirm: false, CancellationToken.None);
            set.Store(set.Default.Id).SaveLocal(null, FakeCardDavServer.Event("n1", "Dal computer"));
            await job.RunAsync(DateTimeOffset.UtcNow.AddSeconds(1), confirm: false, CancellationToken.None);
        }
        Assert.Equal(2, set.List().Count); // «Calendario» e «Lavoro» del server
        Assert.Contains(_server.Cards.Values, v => v.Contains("Dal computer"));
        Assert.DoesNotContain(_server.Authorizations, a => a.StartsWith("Basic", StringComparison.Ordinal));
    }

    [Fact]
    public async Task CalendariDiSolaLetturaComeLeFestivitaDiGoogle()
    {
        _server.Holidays = true;
        _server.Put("natale.ics", FakeCardDavServer.Event("natale", "Natale"), FakeCardDavServer.HolidaysPath);
        var set = new CalendarSet(Path.Combine(_dir, "calendars"));
        var (client, start) = Client();
        using (client)
        {
            var found = await client.DiscoverAllAsync(start, CancellationToken.None);
            Assert.True(found.Single(f => f.Url.AbsolutePath == FakeCardDavServer.HolidaysPath).ReadOnly);
            Assert.False(found.Single(f => f.Url.AbsolutePath == FakeCardDavServer.CalendarPath).ReadOnly);
        }
        var (client2, start2) = Client();
        using (var job = new CalDavSyncJob(client2, set, start2))
        {
            await job.RunAsync(DateTimeOffset.UtcNow, confirm: false, CancellationToken.None);
            // il predefinito va al primo scrivibile, anche se le festività sono elencate per prime
            Assert.Equal("Calendario", set.Default.Name);
            Assert.False(set.Default.ReadOnly);
            var holidays = set.List().Single(c => c.Name == "Festività");
            Assert.True(holidays.ReadOnly);
            Assert.Equal(1, set.Store(holidays.Id).Count);

            // una modifica sul computer (che l'API non permette) non va mai sul server
            set.Store(holidays.Id).SaveLocal(null, FakeCardDavServer.Event("mio", "Mio"));
            await job.RunAsync(DateTimeOffset.UtcNow.AddSeconds(1), confirm: true, CancellationToken.None);
        }
        Assert.DoesNotContain(_server.Requests, r => r.StartsWith("PUT " + FakeCardDavServer.HolidaysPath) || r.StartsWith("POST") || r.StartsWith("DELETE"));
    }
}
