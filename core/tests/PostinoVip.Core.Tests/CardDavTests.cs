using System.Net;
using PostinoVip.Core;
using PostinoVip.Core.Contacts;
using PostinoVip.Core.Contacts.CardDav;
using PostinoVip.Core.Dav;

namespace PostinoVip.Core.Tests;

// Contatti C4b: sincronizzazione CardDAV nei due sensi con un server finto (scoperta, prima volta con conferma,
// modifiche, eliminazioni, conflitti, errori).
public class CardDavTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-carddav-" + Guid.NewGuid().ToString("N"));
    private readonly FakeCardDavServer _server = new();
    private readonly ContactStore _store;
    private readonly DavStateStore _state;
    private readonly List<string> _log = [];

    public CardDavTests()
    {
        _store = new ContactStore(Path.Combine(_dir, "contacts"));
        _state = new DavStateStore(Path.Combine(_dir, "carddav.json"));
    }

    public void Dispose()
    {
        _server.Dispose();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static readonly DateTimeOffset Now = new(2026, 11, 6, 12, 0, 0, TimeSpan.Zero);

    private CardDavSync NewSync(string? password = null) => new(
        new DavClient(new NetworkCredential(_server.User, password ?? _server.Password)),
        _store, _state, DavClient.StartUrl(_server.Url, "ignorato"), _server.Url, _log.Add);

    private async Task<DavResult> SyncAsync(bool confirm = false, DateTimeOffset? now = null)
    {
        using var sync = NewSync();
        return await sync.RunAsync(now ?? Now, confirm, CancellationToken.None);
    }

    private static Contact Person(string given, string family, string email) =>
        new("", given, family, null, [new ContactEmail(email)], [], null, null);

    private Contact Only(string given) => Assert.Single(_store.List(), c => c.GivenName == given);

    // ---------------------------------------------------------------------------------------------
    // Scoperta
    // ---------------------------------------------------------------------------------------------

    [Theory]
    [InlineData(true)]  // well-known -> current-user-principal -> addressbook-home-set
    [InlineData(false)] // come IceWarp: nessun principal, rubrica trovata nelle cartelle
    public async Task ScopertaDellaRubrica(bool principal)
    {
        _server.Principal = principal;
        using var client = new DavClient(new NetworkCredential(_server.User, _server.Password));
        var book = await client.DiscoverAsync(DavClient.StartUrl(_server.Url, "x"), CancellationToken.None);
        Assert.Equal(FakeCardDavServer.BookPath, book.AbsolutePath);
        var info = await client.GetCollectionAsync(book, CancellationToken.None);
        Assert.Equal("Contatti", info.Name);
        Assert.True(info.SupportsSync);
        Assert.True(info.SupportsMultiget);
    }

    [Fact]
    public void IndirizzoDiPartenzaESoloHttps()
    {
        Assert.Equal("https://posta.example/.well-known/carddav", DavClient.StartUrl(null, "posta.example").AbsoluteUri);
        Assert.Equal("https://dav.example/.well-known/carddav", DavClient.StartUrl("https://dav.example", "x").AbsoluteUri);
        Assert.Equal("https://dav.example/rubrica/", DavClient.StartUrl("https://dav.example/rubrica/", "x").AbsoluteUri);
        Assert.Throws<DavException>(() => DavClient.EnsureAllowed(new Uri("http://dav.example/")));
        DavClient.EnsureAllowed(new Uri("http://127.0.0.1:1234/"));
    }

    // ---------------------------------------------------------------------------------------------
    // Prima volta (2a, 4a)
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task PrimaVoltaSoloDalServerPoiConfermaCarica()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261101T100000Z"));
        _server.Put("b.vcf", FakeCardDavServer.Card("uid-b", "Bruno", "Verdi", "bruno@example.com"));
        _store.Create(Person("Bruno", "Verdi", "bruno@example.com")); // uguale a uno del server: si collega
        _store.Create(Person("Carla", "Neri", "carla@example.com"));  // solo sul computer: aspetta la conferma

        var first = await SyncAsync();
        Assert.True(first.NeedsConfirmation);
        Assert.Equal(1, first.PendingUpload);
        Assert.Equal(3, _store.Count); // Anna scaricata, Bruno non duplicato
        Assert.Equal(2, _server.Cards.Count);
        Assert.DoesNotContain(_server.Requests, r => r.StartsWith("PUT") || r.StartsWith("DELETE"));
        Assert.Equal(new DateTimeOffset(2026, 11, 1, 10, 0, 0, TimeSpan.Zero), Only("Anna").Updated);

        var again = await SyncAsync();
        Assert.True(again.NeedsConfirmation); // senza conferma resta tutto come prima
        Assert.Equal(2, _server.Cards.Count);

        var confirmed = await SyncAsync(confirm: true);
        Assert.False(confirmed.NeedsConfirmation);
        Assert.Equal(3, _server.Cards.Count);
        Assert.Contains(_server.Cards.Values, v => v.Contains("carla@example.com"));
        Assert.Equal(3, _store.Count);

        var quiet = await SyncAsync();
        Assert.False(quiet.AnyChange);
    }

    [Fact]
    public async Task PrimaVoltaSenzaContattiSoloQuiNonChiedeConferma()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com"));
        var r = await SyncAsync();
        Assert.False(r.NeedsConfirmation);
        Assert.Equal(1, r.Downloaded);
        _store.Create(Person("Dario", "Gialli", "dario@example.com"));
        var r2 = await SyncAsync();
        Assert.Equal(1, r2.Uploaded); // dopo la prima volta i contatti nuovi vanno sul server da soli
        Assert.Equal(2, _server.Cards.Count);
    }

    // ---------------------------------------------------------------------------------------------
    // Modifiche ed eliminazioni nei due sensi
    // ---------------------------------------------------------------------------------------------

    [Theory]
    [InlineData(true, true)]
    [InlineData(false, true)]  // senza sync-collection: ctag + elenco degli ETag
    [InlineData(true, false)]  // senza multiget: GET uno alla volta
    public async Task ModificheEdEliminazioniNeiDueSensi(bool sync, bool multiget)
    {
        _server.SupportsSync = sync;
        _server.SupportsMultiget = multiget;
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261101T100000Z"));
        _server.Put("b.vcf", FakeCardDavServer.Card("uid-b", "Bruno", "Verdi", "bruno@example.com", "20261101T100000Z"));
        await SyncAsync();

        // dal server al computer: modifica ed eliminazione
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261102T100000Z", note: "dal server"));
        _server.Remove("b.vcf");
        var r = await SyncAsync();
        Assert.Equal(1, r.Downloaded);
        Assert.Equal(1, r.DeletedHere);
        Assert.Equal("dal server", Only("Anna").Notes);
        Assert.Equal(1, _store.Count);

        // dal computer al server: modifica, nuovo, eliminazione
        var anna = Only("Anna");
        _store.Update(anna.Id, anna with { Notes = "dal computer" });
        var nuovo = _store.Create(Person("Elena", "Blu", "elena@example.com"));
        var r2 = await SyncAsync();
        Assert.Equal(2, r2.Uploaded);
        Assert.Contains("NOTE:dal computer", _server.Cards["a.vcf"]);
        Assert.Contains(_server.Cards, c => c.Key == CardDavSync.FileName(_store.Find(nuovo.Id)!) && c.Value.Contains("UID:" + nuovo.VCardUid));
        Assert.Contains("UID:uid-a", _server.Cards["a.vcf"]); // UID e file restano quelli del server

        _store.Delete(anna.Id);
        var r3 = await SyncAsync();
        Assert.Equal(1, r3.DeletedThere);
        Assert.False(_server.Cards.ContainsKey("a.vcf"));
        Assert.False((await SyncAsync()).AnyChange);
    }

    // ---------------------------------------------------------------------------------------------
    // Conflitti (3b, 1a) ed eliminazioni contro modifiche (3a)
    // ---------------------------------------------------------------------------------------------

    private async Task<Contact> SyncedAnnaAsync()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261101T100000Z"));
        await SyncAsync();
        return Only("Anna");
    }

    [Fact]
    public async Task ConflittoVinceLaModificaPiuRecenteDelServer()
    {
        var anna = await SyncedAnnaAsync();
        _store.Update(anna.Id, anna with { Notes = "computer" }); // Updated = adesso (vero), prima del REV qui sotto
        var future = DateTimeOffset.UtcNow.AddMinutes(1);
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", future.ToString("yyyyMMdd'T'HHmmss'Z'"), note: "server"));
        var r = await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Equal(1, r.Conflicts);
        Assert.Equal("server", Only("Anna").Notes);
        Assert.Contains("NOTE:server", _server.Cards["a.vcf"]);
        Assert.Contains(_log, l => l.Contains("vince il server"));
    }

    [Fact]
    public async Task ConflittoVinceLaModificaPiuRecenteDelComputer()
    {
        var anna = await SyncedAnnaAsync();
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261103T100000Z", note: "server"));
        _store.Update(anna.Id, anna with { Notes = "computer" }); // adesso: dopo il 03/11
        var r = await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Equal(1, r.Conflicts);
        Assert.Equal("computer", Only("Anna").Notes);
        Assert.Contains("NOTE:computer", _server.Cards["a.vcf"]);
        Assert.False((await SyncAsync(now: DateTimeOffset.UtcNow)).AnyChange);
    }

    [Fact]
    public async Task ConflittoSenzaRevOConRevNelFuturoContaLOraInCuiSiVede()
    {
        var anna = await SyncedAnnaAsync();
        _store.Update(anna.Id, anna with { Notes = "computer" });
        // REV di un orologio avanti di un anno: non vale, conta "adesso" (dopo la modifica sul computer)
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20271101T100000Z", note: "server"));
        var seen = DateTimeOffset.UtcNow.AddSeconds(5);
        await SyncAsync(now: seen);
        var after = Only("Anna");
        Assert.Equal("server", after.Notes);
        Assert.Equal(seen.ToUnixTimeSeconds(), after.Updated!.Value.ToUnixTimeSeconds());

        // senza REV, visto prima della modifica sul computer: vince il computer
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", note: "server2"));
        _store.Update(after.Id, after with { Notes = "computer2" });
        await SyncAsync(now: DateTimeOffset.UtcNow.AddMinutes(-10));
        Assert.Equal("computer2", Only("Anna").Notes);
    }

    [Fact]
    public async Task EliminatoQuiMaCambiatoSulServerSiRicrea()
    {
        var anna = await SyncedAnnaAsync();
        _store.Delete(anna.Id);
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261104T100000Z", note: "server"));
        await SyncAsync();
        Assert.Equal("server", Only("Anna").Notes);
        Assert.True(_server.Cards.ContainsKey("a.vcf"));
    }

    [Fact]
    public async Task EliminatoSulServerMaCambiatoQuiSiRicarica()
    {
        var anna = await SyncedAnnaAsync();
        _store.Update(anna.Id, anna with { Notes = "computer" });
        _server.Remove("a.vcf");
        var r = await SyncAsync();
        Assert.Equal(0, r.DeletedHere);
        Assert.Equal("computer", Only("Anna").Notes);
        Assert.Contains(_server.Cards.Values, v => v.Contains("NOTE:computer"));
    }

    [Fact]
    public async Task EliminazioneRifiutataPerchéCambiatoSulServerSiRicreaQui()
    {
        var anna = await SyncedAnnaAsync();
        _store.Delete(anna.Id);
        // il server cambia tra l'elenco e l'eliminazione: DELETE con If-Match rifiutato (412)
        _server.BeforeNextWrite = () =>
            _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", "20261104T100000Z", note: "server"));
        var r = await SyncAsync();
        Assert.Equal(0, r.DeletedThere);
        Assert.True(_server.Cards.ContainsKey("a.vcf"));
        await SyncAsync(); // giro dopo: modificato sul server vince sull'eliminazione (3a)
        Assert.Equal("server", Only("Anna").Notes);
    }

    [Fact]
    public async Task ScritturaRifiutataPerchéCambiatoSulServerDiventaUnConflitto()
    {
        var anna = await SyncedAnnaAsync();
        _store.Update(anna.Id, anna with { Notes = "computer" });
        var later = DateTimeOffset.UtcNow.AddMinutes(2).ToString("yyyyMMdd'T'HHmmss'Z'");
        _server.BeforeNextWrite = () =>
            _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com", later, note: "server"));
        var r = await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Equal(0, r.Uploaded);
        Assert.Contains("NOTE:server", _server.Cards["a.vcf"]); // la versione del server non è stata sovrascritta
        var r2 = await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Equal(1, r2.Conflicts);
        Assert.Equal("server", Only("Anna").Notes); // più recente
    }

    // ---------------------------------------------------------------------------------------------
    // Errori, stato, lavoratore
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task PasswordSbagliataEServerSpento()
    {
        using (var sync = NewSync(password: "sbagliata"))
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => sync.RunAsync(Now, false, CancellationToken.None));
            Assert.Equal(401, ex.Status);
        }
        _server.Dispose();
        using var offline = NewSync();
        await Assert.ThrowsAsync<MailOfflineException>(() => offline.RunAsync(Now, false, CancellationToken.None));
    }

    [Fact]
    public async Task StatoPersoNonDuplicaIContatti()
    {
        await SyncedAnnaAsync();
        _store.Create(Person("Dario", "Gialli", "dario@example.com"));
        await SyncAsync();
        Assert.Equal(2, _server.Cards.Count);
        File.Delete(_state.Path);
        var r = await SyncAsync();
        Assert.False(r.NeedsConfirmation); // tutti ricollegati per nome e indirizzi
        Assert.Equal(2, _store.Count);
        Assert.Equal(2, _server.Cards.Count);
    }

    [Fact]
    public async Task AltraRubricaRicominciaDaCapo()
    {
        await SyncedAnnaAsync();
        _store.Create(Person("Dario", "Gialli", "dario@example.com"));
        using var other = new CardDavSync(new DavClient(new NetworkCredential(_server.User, _server.Password)),
            _store, _state, DavClient.StartUrl(_server.Url, "x"), "altra-sorgente", _log.Add);
        var r = await other.RunAsync(Now, false, CancellationToken.None);
        Assert.True(r.NeedsConfirmation); // conferma chiesta di nuovo: Dario non è mai stato su quel server
    }

    [Fact]
    public async Task LavoratoreParteDopoUnaModificaEConferma()
    {
        DavWorker.Debounce = TimeSpan.FromMilliseconds(10);
        _store.Create(Person("Dario", "Gialli", "dario@example.com"));
        var results = new List<DavResult>();
        var worker = new DavWorker("a1", _store, () => NewSync(), done: r => { lock (results) results.Add(r); });
        Assert.Equal("waiting", worker.Status.State);
        using var cts = new CancellationTokenSource();
        var run = worker.RunAsync(cts.Token);
        await WaitFor(() => worker.Status.State == "ok");
        Assert.True(worker.Status.NeedsConfirmation);
        Assert.Equal(1, worker.Status.PendingUpload);
        Assert.Equal("Contatti", worker.Status.AddressBook);

        worker.Confirm();
        await WaitFor(() => _server.Cards.Count == 1);
        _store.Create(Person("Elena", "Blu", "elena@example.com")); // modifica nell'app -> giro subito
        await WaitFor(() => _server.Cards.Count == 2);
        Assert.False(worker.Status.NeedsConfirmation);
        await cts.CancelAsync();
        await run;
    }

    [Fact]
    public async Task LavoratoreNonDisponibile()
    {
        var worker = new DavWorker("a1", _store, null, "Manca la password dell'account.");
        Assert.Equal("unavailable", worker.Status.State);
        Assert.Null(await worker.RunOnceAsync(CancellationToken.None));
    }

    private static async Task WaitFor(Func<bool> condition)
    {
        for (var i = 0; i < 200 && !condition(); i++)
            await Task.Delay(25);
        Assert.True(condition());
    }
}
