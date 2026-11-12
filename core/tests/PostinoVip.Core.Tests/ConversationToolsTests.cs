using System.Text;
using MimeKit;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Conversations;
using PostinoVip.Core.Local;
using PostinoVip.Core.Pop3;

namespace PostinoVip.Core.Tests;

/// <summary>Ignora conversazione e Pulisci conversazione (C1), su un account POP3 locale (niente server).</summary>
public sealed class ConversationToolsTests : IDisposable
{
    private const string Me = "io@example.com";
    private const string Trash = "Posta eliminata";
    private const string Sent = "Posta inviata";
    private readonly string _dir = Directory.CreateTempSubdirectory("postinovip-conv-").FullName;

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        Directory.Delete(_dir, recursive: true);
    }

    private (MailAccount Account, LocalMailStore Store, MailAccountRegistry Registry) Pop3Account()
    {
        var settings = new MailAccountSettings
        {
            Id = "pop", Type = MailAccountType.Pop3,
            Pop3 = new Pop3Settings { Host = "pop.example.invalid", Username = Me, Password = "x" },
            Smtp = new Smtp.SmtpSettings { Host = "smtp.example.invalid", Username = Me, Password = "x" },
        };
        var registry = MailAccountRegistry.CreateImap([settings], _dir);
        var store = new LocalMailStore(Path.Combine(MailAccountRegistry.CacheDirectory(_dir, "pop"), "mail"));
        store.EnsureDefaults();
        return (registry.Get("pop"), store, registry);
    }

    /// <summary>Aggiunge una mail con Message-ID &lt;<paramref name="id"/>@x&gt;, in risposta a <paramref name="parent"/>.</summary>
    private static async Task<uint> AddAsync(MailAccount account, LocalMailStore store, string id, string body, string? parent = null,
        string folder = "INBOX", bool seen = true, string? refs = null)
    {
        var headers = new StringBuilder($"From: anna@fornitore.it\r\nTo: {Me}\r\nSubject: {id}\r\nMessage-ID: <{id}@x>\r\n");
        if (parent is not null)
            headers.Append($"In-Reply-To: <{parent}@x>\r\nReferences: {refs ?? $"<{parent}@x>"}\r\n");
        var uid = await store.AddAsync(folder, new MemoryStream(Encoding.UTF8.GetBytes(
            $"{headers}Date: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\n{body.Replace("\n", "\r\n")}\r\n")));
        await account.Reader.GetHeadersAsync(folder, 0, 1);
        if (seen)
            await account.Writer.SetSeenAsync(folder, uid, true);
        await account.Reader.GetHeadersAsync(folder, 0, 1);
        return uid;
    }

    private static async Task<List<string>> Subjects(MailAccount account, string folder) =>
        (await account.Reader.GetHeadersAsync(folder, 0, 50)).Items.Select(m => m.Subject).Order().ToList();

    [Fact]
    public async Task IgnoraSpostaLaConversazioneDellaCartellaELeMailNuove()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var log = new List<string>();
        var tools = new ConversationTools(account, account.Ignore!, log.Add);
        await tools.RunNewAsync(); // punto di partenza
        var a = await AddAsync(account, store, "a", "Domanda");
        await AddAsync(account, store, "b", "Risposta", parent: "a");
        await AddAsync(account, store, "c", "Mia risposta", parent: "a", folder: Sent);
        await AddAsync(account, store, "d", "Altro");
        await tools.RunNewAsync(); // nulla di ignorato: avanza

        var result = await tools.IgnoreAsync("INBOX", [a]);

        Assert.Equal((Trash, 2), (result.Destination, result.Moved.Count));
        Assert.Equal(["d"], await Subjects(account, "INBOX"));
        Assert.Equal(["c"], await Subjects(account, Sent)); // 1b: solo la cartella aperta
        Assert.Equal(["a", "b"], await Subjects(account, Trash));
        Assert.True(await tools.IsIgnoredAsync(Sent, [(await account.Reader.GetHeadersAsync(Sent, 0, 1)).Items[0].Uid]));

        // Le mail nuove della conversazione (anche risposta a una risposta) vanno in Posta eliminata.
        await AddAsync(account, store, "e", "Ancora", parent: "b", seen: false);
        await AddAsync(account, store, "f", "Nuova", seen: false);
        var run = await tools.RunNewAsync();
        Assert.Equal((2, 1, 0), (run.Checked, run.Moved, run.Failed));
        await AddAsync(account, store, "g", "E ancora", parent: "e", refs: "<e@x>", seen: false);
        Assert.Equal(1, (await tools.RunNewAsync()).Moved);
        Assert.Equal(["d", "f"], await Subjects(account, "INBOX"));
        Assert.Equal(["a", "b", "e", "g"], await Subjects(account, Trash));
        Assert.DoesNotContain(log, l => l.Contains("@x") || l.Contains("Ancora")); // mai Message-ID od oggetti

        // Interrompi Ignora da Posta eliminata: tutto torna in Posta in arrivo, le nuove restano lì.
        var inTrash = (await account.Reader.GetHeadersAsync(Trash, 0, 50)).Items.Single(m => m.Subject == "a").Uid;
        var back = await tools.StopIgnoringAsync(Trash, [inTrash]);
        Assert.Equal(("INBOX", 4), (back.Destination, back.Moved.Count));
        Assert.Empty(await Subjects(account, Trash));
        await AddAsync(account, store, "h", "Dopo", parent: "a", seen: false);
        Assert.Equal(0, (await tools.RunNewAsync()).Moved);
        Assert.Contains("h", await Subjects(account, "INBOX"));
        var d = (await account.Reader.GetHeadersAsync("INBOX", 0, 50)).Items.Single(m => m.Subject == "d").Uid;
        await Assert.ThrowsAsync<InvalidOperationException>(() => tools.StopIgnoringAsync("INBOX", [d]));
    }

    [Fact]
    public async Task IgnoraSalvaInModoPrivatoEDaPostaEliminataNonSposta()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var tools = new ConversationTools(account, account.Ignore!);
        var a = await AddAsync(account, store, "a", "Già eliminata", folder: Trash);

        var result = await tools.IgnoreAsync(Trash, [a]);

        Assert.Empty(result.Moved);
        Assert.Contains("a@x", account.Ignore!.Load());
        if (!OperatingSystem.IsWindows())
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(account.Ignore.SettingsPath));
        File.WriteAllText(account.Ignore.SettingsPath, "{rovinato");
        Assert.Empty(account.Ignore.Load());
    }

    [Fact]
    public async Task PulisciSpostaSoloLeMailCitatePerInteroDaUnaRisposta()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var tools = new ConversationTools(account, account.Ignore!);
        await AddAsync(account, store, "a", "Ciao, ci vediamo domani\nalle 10?");
        await AddAsync(account, store, "b", "Va bene, a domani.\n\nIl 2/11 Anna ha scritto:\n> Ciao, ci vediamo domani alle\n> 10?", parent: "a");
        // c risponde a b ma ne cita solo un pezzo: b resta.
        await AddAsync(account, store, "c", "Perfetto.\n> Va bene", parent: "b", refs: "<a@x> <b@x>");
        // Da leggere, contrassegnata: restano anche se citate.
        await AddAsync(account, store, "u", "Non letta", seen: false);
        await AddAsync(account, store, "u2", "Ok\n> Non letta", parent: "u");
        var f = await AddAsync(account, store, "f", "Importante");
        await account.Writer.UpdateFlagsAsync("INBOX", [f], MailFlags.Flagged, MailFlags.None);
        await AddAsync(account, store, "f2", "Sì\n> Importante", parent: "f");
        // La risposta in Posta inviata vale: s è citata da una mia risposta.
        await AddAsync(account, store, "s", "Mi mandi il listino?");
        await AddAsync(account, store, "s2", "Eccolo.\n> Mi mandi il listino?", parent: "s", folder: Sent);
        // Stesso inizio ma non per intero, e parola dentro un'altra: restano.
        await AddAsync(account, store, "p", "Ciao");
        await AddAsync(account, store, "p2", "Ciaone a tutti", parent: "p");

        var result = await tools.CleanUpAsync("INBOX", null);

        Assert.Equal(Trash, result.Destination);
        Assert.Equal(["a", "s"], await Subjects(account, Trash));
        Assert.Equal(11 - 1, result.Checked); // le mail della cartella (s2 è in Posta inviata)
        Assert.Equal(["s2"], await Subjects(account, Sent));
        Assert.Empty((await tools.CleanUpAsync("INBOX", null)).Moved); // già pulita
        await Assert.ThrowsAsync<InvalidOperationException>(() => tools.CleanUpAsync(Trash, null));
    }

    [Fact]
    public async Task PulisciConversazioneGuardaSoloQuella()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var tools = new ConversationTools(account, account.Ignore!);
        await AddAsync(account, store, "a", "Prima domanda");
        var b = await AddAsync(account, store, "b", "Risposta\n> Prima domanda", parent: "a");
        await AddAsync(account, store, "x", "Altra domanda");
        await AddAsync(account, store, "y", "Altra risposta\n> Altra domanda", parent: "x");

        var result = await tools.CleanUpAsync("INBOX", [b]);

        Assert.Single(result.Moved);
        Assert.Equal(["a"], await Subjects(account, Trash));
        Assert.Equal(["b", "x", "y"], await Subjects(account, "INBOX"));
    }

    [Fact]
    public void TestoCitatoAncheInHtmlEMaiLeMailFirmate()
    {
        static MimeMessage Text(string body) => new() { Body = new TextPart("plain") { Text = body } };
        var original = Text("Ciao Marco,\nil preventivo è pronto: 1.200 €.\n\n-- \nAnna");
        var html = new MimeMessage
        {
            Body = new TextPart("html") { Text = "<p>Grazie!</p><blockquote>Ciao Marco,<br>il preventivo è pronto: 1.200&nbsp;€.<br><br>-- <br>Anna</blockquote>" },
        };
        Assert.True(CleanUpText.IsQuotedIn(original, html));
        Assert.False(CleanUpText.IsQuotedIn(original, Text("> Ciao Marco,\n> il preventivo è pronto: 1.300 €.\n> -- \n> Anna")));
        Assert.False(CleanUpText.IsQuotedIn(Text("> solo citazioni"), Text("> solo citazioni"))); // nessun testo proprio
        Assert.Equal("ciao a tutti", CleanUpText.Normalize("> Ciao,\n>  a TUTTI!", skipQuoted: false));

        var signed = new MimeMessage { Body = new MimeKit.Cryptography.MultipartSigned() };
        Assert.True(CleanUpText.IsSigned(signed));
        Assert.False(CleanUpText.IsSigned(original));
    }
}
