using System.Text;
using Microsoft.Data.Sqlite;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class SearchTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly AccountCache _cache;

    public SearchTests() => _cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static readonly DateTimeOffset Base = new(2026, 10, 1, 9, 0, 0, TimeSpan.FromHours(2));

    private long Add(string folder, uint uid, string subject, string fromName = "Anna Bianchi", string to = "io@example.com",
        int day = 0, string? cc = null)
    {
        var f = _cache.GetOrAddFolder(folder);
        _cache.UpsertHeaders(f.Id, [new HeaderRecord(uid, MailFlags.None, subject, fromName, "anna@example.com", to, cc,
            Base.AddDays(day), Base.AddDays(day), 100, null, null)]);
        return f.Id;
    }

    private IReadOnlyList<(string Folder, uint Uid)> Find(string query, string? folder = null, int offset = 0, int limit = 50) =>
        _cache.Search(MailSearchQuery.Parse(query), folder, offset, limit).Items.Select(r => (r.Folder, r.Uid)).ToList();

    // ---------------------------------------------------------------------------------------------
    // Sintassi
    // ---------------------------------------------------------------------------------------------

    [Theory]
    [InlineData("fattura", "\"fattura\"*")]
    [InlineData("fatt ottobre", "\"fatt\"* AND \"ottobre\"*")]
    [InlineData("\"fattura di ottobre\"", "\"fattura di ottobre\"")]
    [InlineData("da:anna", "sender : \"anna\"*")]
    [InlineData("A:mario Oggetto:\"ordine 12\"", "recipients : \"mario\"* AND subject : \"ordine 12\"")]
    [InlineData("allegato:pdf", "attachments : \"pdf\"*")]
    [InlineData("from:anna", "sender : \"anna\"*")]                // L6d: parole chiave inglesi, sempre valide
    [InlineData("To:mario Subject:\"ordine 12\"", "recipients : \"mario\"* AND subject : \"ordine 12\"")]
    [InlineData("attachment:pdf", "attachments : \"pdf\"*")]
    [InlineData("ore 10:30", "\"ore\"* AND \"10:30\"*")]           // "10" non è un filtro
    [InlineData("Re:offerta", "\"Re:offerta\"*")]                  // filtro sconosciuto: testo
    [InlineData("AND OR NOT ( * -", "\"AND\"* AND \"OR\"* AND \"NOT\"*")] // nessuna sintassi FTS5 dall'utente
    [InlineData("dice \"ciao", "\"dice\"* AND \"ciao\"")]           // virgolette non chiuse
    public void TraduzionePerFts5(string text, string match)
    {
        Assert.Equal(match, MailSearchQuery.Parse(text).Match);
    }

    [Fact]
    public void FiltroAllegatiEVuoti()
    {
        var only = MailSearchQuery.Parse("allegati:sì");
        Assert.Equal((null, true), (only.Match, only.HasAttachments));
        var both = MailSearchQuery.Parse("fattura allegati:no");
        Assert.Equal(("\"fattura\"*", false), (both.Match, both.HasAttachments));
        Assert.Equal([new SearchTerm(SearchField.Sender, "anna", false), new SearchTerm(null, "ordine 12", true)],
            MailSearchQuery.Parse("da:anna \"ordine 12\"").Terms);
        Assert.Equal("\"allegati:forse\"*", MailSearchQuery.Parse("allegati:forse").Match);
        Assert.True(MailSearchQuery.Parse("hasattachments:yes").HasAttachments);
        Assert.False(MailSearchQuery.Parse("HasAttachments:no").HasAttachments);
        // Spagnolo, francese e tedesco (17/11/2026, scelta 3a): valgono sempre, in qualunque lingua dell'app.
        Assert.True(MailSearchQuery.Parse("adjuntos:sí").HasAttachments);
        Assert.False(MailSearchQuery.Parse("piècesjointes:non").HasAttachments);
        Assert.True(MailSearchQuery.Parse("anlagen:ja").HasAttachments);
        Assert.False(MailSearchQuery.Parse("Anlagen:nein").HasAttachments);
        Assert.Equal([new SearchTerm(SearchField.Sender, "anna", false), new SearchTerm(SearchField.Recipients, "mario", false),
                new SearchTerm(SearchField.Subject, "reunión", false), new SearchTerm(SearchField.Attachments, "pdf", false)],
            MailSearchQuery.Parse("de:anna para:mario asunto:reunión adjunto:pdf").Terms);
        Assert.Equal([new SearchTerm(SearchField.Recipients, "mario", false), new SearchTerm(SearchField.Subject, "réunion", false),
                new SearchTerm(SearchField.Attachments, "pdf", false)],
            MailSearchQuery.Parse("à:mario objet:réunion piècejointe:pdf").Terms);
        Assert.Equal([new SearchTerm(SearchField.Sender, "anna", false), new SearchTerm(SearchField.Recipients, "mario", false),
                new SearchTerm(SearchField.Subject, "besprechung", false), new SearchTerm(SearchField.Attachments, "pdf", false)],
            MailSearchQuery.Parse("von:anna an:mario betreff:besprechung anlage:pdf").Terms);
        Assert.True(MailSearchQuery.Parse("  ").IsEmpty);
        Assert.True(MailSearchQuery.Parse("- , ;").IsEmpty);
    }

    // ---------------------------------------------------------------------------------------------
    // Ricerca nelle intestazioni
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public void ParoleAncheComePrefissoESenzaAccenti()
    {
        Add("INBOX", 1, "Fattura di ottobre");
        Add("INBOX", 2, "Perché la riunione è spostata");
        Add("INBOX", 3, "Altro");

        Assert.Equal([("INBOX", 1u)], Find("fatt"));
        Assert.Equal([("INBOX", 1u)], Find("FATTURA ottobre"));
        Assert.Equal([("INBOX", 2u)], Find("perche e spostata"));
        Assert.Empty(Find("fattura riunione")); // tutte le parole
    }

    [Fact]
    public void FiltriPerCampo()
    {
        Add("INBOX", 1, "Mario chiede", fromName: "Luca Verdi", to: "mario@example.com");
        Add("INBOX", 2, "Ciao", fromName: "Mario Rossi", to: "io@example.com");
        Add("INBOX", 3, "Copia", fromName: "Luca Verdi", to: "io@example.com", cc: "mario@example.com");

        Assert.Equal([3u, 2u, 1u], Find("mario").Select(r => r.Uid));
        Assert.Equal([2u], Find("da:mario").Select(r => r.Uid));
        Assert.Equal([3u, 1u], Find("a:mario").Select(r => r.Uid)); // A e Cc
        Assert.Equal([1u], Find("oggetto:mario").Select(r => r.Uid));
    }

    [Fact]
    public void DalPiuRecentePerDataDiArrivoConPagine()
    {
        // UID e data in ordini diversi: conta la data (anche con fusi orari diversi).
        Add("INBOX", 1, "report", day: 5);
        Add("INBOX", 2, "report", day: 1);
        Add("Archivio", 9, "report", day: 3);

        var all = _cache.Search(MailSearchQuery.Parse("report"), null, 0, 2);

        Assert.Equal(3, all.Total);
        Assert.Equal([("INBOX", 1u), ("Archivio", 9u)], all.Items.Select(r => (r.Folder, r.Uid)));
        Assert.Equal([("INBOX", 2u)], Find("report", offset: 2));
        Assert.Equal([("Archivio", 9u)], Find("report", folder: "Archivio"));
    }

    [Fact]
    public void MessaggiToltiSparisconoDallIndice()
    {
        var inbox = Add("INBOX", 1, "uno");
        Add("INBOX", 2, "uno");
        Add("Vecchia", 3, "uno");

        _cache.DeleteMessages(inbox, [1]);
        _cache.RemoveFoldersNotIn(["INBOX"]); // eliminazione a cascata

        Assert.Equal([("INBOX", 2u)], Find("uno"));
        _cache.ResetFolder(inbox, 99); // UIDVALIDITY cambiato
        Assert.Empty(Find("uno"));
        Assert.Equal(0L, Scalar("SELECT count(*) FROM messages_fts"));
    }

    [Fact]
    public void IntestazioniAggiornateNonDuplicano()
    {
        var f = Add("INBOX", 1, "prima versione");
        _cache.UpsertHeaders(f, [new HeaderRecord(1, MailFlags.Seen, "seconda versione", null, "x@example.com", null, null,
            Base, Base, 1, null, null)]);

        Assert.Empty(Find("prima"));
        Assert.Single(Find("seconda"));
        Assert.Equal(1L, Scalar("SELECT count(*) FROM messages_fts"));
    }

    // ---------------------------------------------------------------------------------------------
    // Corpi
    // ---------------------------------------------------------------------------------------------

    private static SearchText Text(string body, params string[] attachments) => new(body, attachments);

    [Fact]
    public void CorpoCercabileConEstrattoEvidenziato()
    {
        var f = Add("INBOX", 1, "Ordine");
        Add("INBOX", 2, "Altro");
        _cache.SetBody(f, 1, new string('a', 64), Text("Buongiorno, in allegato la fattura numero 42 di ottobre. Saluti"));

        var hit = _cache.Search(MailSearchQuery.Parse("fattura 42"), null, 0, 10).Items.Single();

        Assert.Equal(1u, hit.Uid);
        Assert.True(hit.BodyIndexed);
        Assert.Contains("\u0002fattura\u0003", hit.Snippet);
        Assert.Contains("\u000242\u0003", hit.Snippet);
        Assert.False(_cache.Search(MailSearchQuery.Parse("altro"), null, 0, 10).Items.Single().BodyIndexed);
    }

    [Fact]
    public void AllegatiPerNomeEPerPresenza()
    {
        var f = Add("INBOX", 1, "Con allegato");
        Add("INBOX", 2, "Senza allegato letto");
        Add("INBOX", 3, "Corpo mai letto");
        _cache.SetBody(f, 1, new string('a', 64), Text("vedi file", "Preventivo_2026.pdf"));
        _cache.SetBody(f, 2, new string('b', 64), Text("niente"));

        Assert.Equal([1u], Find("allegato:preventivo").Select(r => r.Uid));
        Assert.Equal([1u], Find("allegati:sì").Select(r => r.Uid));
        Assert.Equal([2u], Find("allegati:no").Select(r => r.Uid)); // il 3 è sconosciuto: escluso
        Assert.Equal([1u], Find("allegato allegati:si").Select(r => r.Uid));
    }

    [Fact]
    public void CorpoUscitoDalLimiteSiCercaSoloNelleIntestazioni()
    {
        var f = Add("INBOX", 1, "Oggetto", day: -400);
        _cache.SetBody(f, 1, new string('a', 64), Text("parolarara"));
        Assert.Single(Find("parolarara"));

        _cache.DropBodies((_, _) => false);

        Assert.Empty(Find("parolarara"));
        Assert.Single(Find("oggetto"));
        Assert.Null(_cache.GetBodyRow(f, 1)!.Sha256);
    }

    [Fact]
    public void CorpoSalvatoSenzaTestoVaIndicizzatoDopo()
    {
        var f = Add("INBOX", 1, "x");
        _cache.SetBody(f, 1, new string('c', 64)); // come il download in background: prima solo il file

        Assert.Equal([(1u, new string('c', 64))], _cache.GetBodiesToIndex(f));
        _cache.SetBody(f, 1, new string('c', 64), Text("indicizzato"));
        Assert.Empty(_cache.GetBodiesToIndex(f));
    }

    [Fact]
    public void TestoDalMessaggio()
    {
        var html = MimeMessage.Load(new MemoryStream(Encoding.UTF8.GetBytes(
            "Subject: x\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Ciao <b>Marcello</b></p>\r\n")));
        Assert.Contains("Ciao Marcello", SearchText.From(html).Body);

        var builder = new BodyBuilder { TextBody = new string('x', SearchText.MaxBodyLength + 10) };
        builder.Attachments.Add("listino.xlsx", [1, 2, 3]);
        var big = new MimeMessage { Body = builder.ToMessageBody() };
        var text = SearchText.From(big);
        Assert.Equal(SearchText.MaxBodyLength, text.Body.Length);
        Assert.Equal(["listino.xlsx"], text.AttachmentNames);
    }

    [Fact]
    public void RicercheStraneNonDannoErrori()
    {
        Add("INBOX", 1, "normale");
        foreach (var q in new[] { "\"", "NEAR(a b)", "*", "col:", "a: b:", "\"\"", "^start", "x OR", "subject:normale" })
            _ = _cache.Search(MailSearchQuery.Parse(q), null, 0, 10);
    }

    private object? Scalar(string sql)
    {
        using var db = new SqliteConnection($"Data Source={_cache.Path}");
        db.Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = sql;
        return cmd.ExecuteScalar();
    }
}
