using MimeKit;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Mime;

/// <summary>Elenco ed estrazione degli allegati di un MimeMessage, con indici coerenti tra le due operazioni.</summary>
public static class Attachments
{
    public static IReadOnlyList<AttachmentInfo> List(MimeMessage message) =>
        message.Attachments
            .Select((entity, i) =>
            {
                var fileName = FileName(entity);
                return new AttachmentInfo(i, fileName, EffectiveMimeType(entity, fileName));
            })
            .ToList();

    /// <returns>null se l'indice non esiste.</returns>
    public static AttachmentContent? Extract(MimeMessage message, int index)
    {
        var entity = message.Attachments.ElementAtOrDefault(index);
        if (entity is null)
            return null;

        using var ms = new MemoryStream();
        switch (entity)
        {
            case MimePart part when part.Content is not null:
                part.Content.DecodeTo(ms); // rimuove base64 / quoted-printable
                break;
            case MessagePart rfc822 when rfc822.Message is not null:
                rfc822.Message.WriteTo(ms); // mail allegata (.eml)
                break;
        }

        var fileName = FileName(entity);
        return new AttachmentContent(fileName, EffectiveMimeType(entity, fileName), ms.ToArray());
    }

    /// <summary>
    /// Tipo MIME dichiarato; se è generico (application/octet-stream, frequente in telecamere e
    /// dispositivi embedded) lo si ricava dall'estensione del nome file.
    /// </summary>
    public static string EffectiveMimeType(MimeEntity entity, string fileName)
    {
        var declared = entity.ContentType.MimeType;
        if (!declared.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase))
            return declared;

        // MimeTypes.GetMimeType restituisce application/octet-stream se l'estensione è sconosciuta.
        return MimeTypes.GetMimeType(fileName);
    }

    private static string FileName(MimeEntity entity) =>
        entity.ContentDisposition?.FileName
        ?? entity.ContentType.Name
        ?? (entity is MessagePart ? "messaggio.eml" : "(senza nome)");
}
