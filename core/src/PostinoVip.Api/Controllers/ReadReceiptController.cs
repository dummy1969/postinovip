using System.Reflection;
using Microsoft.AspNetCore.Mvc;
using MimeKit;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Mime;

namespace PostinoVip.Api.Controllers;

public sealed class ReceiptRequest
{
    /// <summary>true: invia la conferma; false: «Non inviare». In tutti e due i casi la mail diventa $MDNSent.</summary>
    public bool? Send { get; set; }

    /// <summary>Inviata da sola per l'opzione «Invia sempre» (Disposition: automatic-action).</summary>
    public bool Automatic { get; set; }
}

public sealed record ReceiptResponse(bool Sent);

/// <summary>Risposta a una richiesta di conferma di lettura (R1, RFC 8098 e RFC 3503).</summary>
[ApiController]
[Route("messages")]
[Route("accounts/{accountId}/messages")]
public sealed class ReadReceiptController(MailAccountRegistry accounts, ILogger<ReadReceiptController> logger)
    : MailControllerBase(accounts)
{
    private static readonly string Version =
        typeof(Program).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion?.Split('+')[0] ?? "?";

    /// <summary>
    /// POST /messages/{folder}/{uid}/receipt {"send": bool, "automatic"?: bool} — con send INVIA la conferma di lettura
    /// al mittente; in ogni caso MODIFICA la casella (STORE +$MDNSent), così la domanda non torna. 409 se la mail non
    /// chiede la conferma (o la chiede a un indirizzo diverso dal mittente), se sta in Posta indesiderata, Posta
    /// inviata o Bozze, o se è già stata trattata.
    /// </summary>
    [HttpPost("{folder}/{uid}/receipt")]
    public async Task<ActionResult<ReceiptResponse>> Answer(string folder, uint uid, [FromBody] ReceiptRequest request, CancellationToken ct)
    {
        var send = request.Send ?? throw new FieldValidationException("send", "Indicare send (true o false).");
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);

        var folders = PostinoVip.Core.Junk.JunkFolders.WithRole(await account.Reader.GetFoldersAsync(ct), account.Junk?.Load().Folder);
        var role = folders.FirstOrDefault(f => f.FullName == name)?.SpecialUse;
        if (role is "junk" or "sent" or "drafts")
            throw new InvalidOperationException("Nessuna conferma di lettura per le mail di Posta indesiderata, Posta inviata e Bozze.");
        var cache = account.Bodies?.Cache;
        var cached = cache?.FindFolder(name);
        if (cache is not null && cached is not null && cache.GetFlags(cached.Id, uid) is var (known, _) && (known & MailFlags.ReceiptHandled) != 0)
            throw new InvalidOperationException("Alla richiesta di conferma di lettura si è già risposto.");

        var original = await account.Reader.GetMimeMessageAsync(name, uid, ct);
        if (ReadReceipts.RequestedBy(original) is null)
            throw new InvalidOperationException("La mail non chiede una conferma di lettura al suo mittente.");

        if (send)
        {
            var receipt = ReadReceipts.Build(original, new MailboxAddress("", account.Address), request.Automatic, Version, DateTimeOffset.Now);
            await account.Sender.SendMimeAsync(receipt, ct);
            // Solo l'operazione, mai indirizzi o contenuti.
            logger.LogInformation("[{Account}] conferma di lettura inviata ({Kind}) per {Folder} uid {Uid}", account.Id,
                request.Automatic ? "automatica" : "scelta dall'utente", name, uid);
        }

        var flags = await account.Writer.UpdateFlagsAsync(name, uid, MailFlags.MdnSent, MailFlags.None, ct);
        logger.LogInformation("[{Account}] STORE +$MDNSent {Folder} uid {Uid}", account.Id, name, uid);
        if (cache is not null && cached is not null)
            cache.SetFlags(cached.Id, uid, flags, null, keepDue: true);
        return Ok(new ReceiptResponse(send));
    }
}
