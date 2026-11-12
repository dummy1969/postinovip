// Diagnosi (12/11/2026): quali mail della Posta in arrivo fanno fallire MailKit sul BODYSTRUCTURE.
// SOLO LETTURA: INBOX aperta con EXAMINE, si chiede solo la struttura (UID FETCH n (UID BODYSTRUCTURE)), una mail alla
// volta; dopo un errore MailKit chiude la connessione e si riapre. Stampa solo gli UID: «BAD <uid> <messaggio>».
// Uso (da tools/diagnosi-inbox.sh): dotnet run tools/diagnosi-bodystructure.cs -- <file credenziali: host, porta, utente, password>
#:package MailKit@4.18.2
using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;

var lines = File.ReadAllText(args[0]).Split('\n');
var (host, port, user, pwd) = (lines[0], int.Parse(lines[1]), lines[2], lines[3]);

async Task<(ImapClient, IMailFolder)> Open()
{
    var c = new ImapClient { Timeout = 30_000 };
    await c.ConnectAsync(host, port, port == 993 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls);
    await c.AuthenticateAsync(user, pwd);
    await c.Inbox.OpenAsync(FolderAccess.ReadOnly);
    return (c, c.Inbox);
}

var (client, inbox) = await Open();
var uids = await inbox.SearchAsync(MailKit.Search.SearchQuery.All);
var bad = 0;
foreach (var uid in uids)
{
    try
    {
        await inbox.FetchAsync([uid], MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure);
    }
    catch (ImapProtocolException ex)
    {
        bad++;
        Console.WriteLine($"BAD {uid.Id} {ex.Message}");
        client.Dispose();
        (client, inbox) = await Open();
    }
}
Console.WriteLine($"TOTALE {uids.Count} mail, {bad} con errore");
await client.DisconnectAsync(true);
