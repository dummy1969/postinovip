using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using PostinoVip.Core;

namespace PostinoVip.Api.Tests;

/// <summary>La lingua dell'app è una sola per tutto il core: questi test la cambiano, quindi non girano insieme agli altri
/// (che leggono i testi delle mail in italiano).</summary>
[CollectionDefinition("UiLanguage", DisableParallelization = true)]
public sealed class UiLanguageCollection;

[Collection("UiLanguage")]
public sealed class UiLanguageTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeMailReader _reader = new();
    private readonly FakeMailSender _sender = new();
    private readonly FakeMailWriter _writer = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public UiLanguageTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Smtp:Username", "me@example.com");
            b.UseSetting("Watch:Enabled", "false");
            b.ConfigureServices(s => s.UseFakeAccounts(_ => (_reader, _writer, _sender)));
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        UiLanguage.Set("it");
    }

    [Fact]
    public async Task LinguaDellAppDallaRichiesta()
    {
        // Scelta 2a: la lingua dell'ultima richiesta vale per i testi che il core scrive da solo; le lingue sconosciute no.
        using var english = new HttpRequestMessage(HttpMethod.Get, "/folders");
        english.Headers.AcceptLanguage.ParseAdd("en");
        await _client.SendAsync(english);
        Assert.Equal("en", UiLanguage.Current);
        using var german = new HttpRequestMessage(HttpMethod.Get, "/folders");
        german.Headers.AcceptLanguage.ParseAdd("de-DE");
        await _client.SendAsync(german);
        Assert.Equal("en", UiLanguage.Current);
    }

    [Fact]
    public async Task IlBrowserDellAccessoNonCambiaLaLingua()
    {
        // Senza token (il browser che torna dall'accesso OAuth) la lingua resta quella dell'app; la pagina è in quella lingua.
        UiLanguage.Set("en");
        using var anonymous = _factory.CreateClient();
        using var browser = new HttpRequestMessage(HttpMethod.Get, "/oauth/callback?state=x&code=y");
        browser.Headers.AcceptLanguage.ParseAdd("it-IT");
        var page = await (await anonymous.SendAsync(browser)).Content.ReadAsStringAsync();
        Assert.Equal("en", UiLanguage.Current);
        Assert.Contains("Sign-in failed", page);
        Assert.Contains("lang=\"en\"", page);
    }
}
