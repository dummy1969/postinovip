using MimeKit;
using PostinoVip.Core.Html;
using PostinoVip.Core.Mime;

namespace PostinoVip.Core.Cache;

/// <summary>
/// Testo di un messaggio per l'indice di ricerca: corpo in testo semplice (dall'HTML se manca la
/// parte di testo) e nomi degli allegati. Limitato a <see cref="MaxBodyLength"/> caratteri: oltre,
/// l'indice crescerebbe molto per testi (log, elenchi) in cui raramente si cerca.
/// </summary>
public sealed record SearchText(string Body, IReadOnlyList<string> AttachmentNames)
{
    public const int MaxBodyLength = 64 * 1024;

    public bool HasAttachments => AttachmentNames.Count > 0;

    public static SearchText From(MimeMessage message)
    {
        var body = message.TextBody;
        if (string.IsNullOrWhiteSpace(body) && message.HtmlBody is { } html)
            body = HtmlText.ToPlainText(html);
        body ??= "";
        if (body.Length > MaxBodyLength)
            body = body[..MaxBodyLength];
        return new SearchText(body, Attachments.List(message).Select(a => a.FileName).ToList());
    }
}
