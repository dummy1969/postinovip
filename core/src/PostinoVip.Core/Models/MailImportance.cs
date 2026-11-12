using System.Text.Json;
using System.Text.Json.Serialization;
using MimeKit;

namespace PostinoVip.Core.Models;

/// <summary>Importanza di una mail (P1), come in Outlook: «Priorità alta» o «Priorità bassa».</summary>
[JsonConverter(typeof(MailImportanceJsonConverter))]
public enum MailImportance { Normal = 0, High = 1, Low = 2 }

/// <summary>In JSON "normal", "high", "low", come gli altri valori dell'API.</summary>
public sealed class MailImportanceJsonConverter() : JsonStringEnumConverter<MailImportance>(JsonNamingPolicy.CamelCase);

/// <summary>
/// Lettura e scrittura delle intestazioni dell'importanza. Le mail ne usano tre, scritte da programmi diversi:
/// <c>Importance</c> (RFC 2156, Outlook: high / normal / low), <c>X-Priority</c> (1–5, 1 la più alta, il numero
/// può essere seguito da un commento come «(Highest)») e <c>Priority</c> (RFC 2156: urgent / normal / non-urgent).
/// Vale la prima presente in quest'ordine, come fa Outlook.
/// </summary>
public static class MailImportanceHeaders
{
    /// <summary>Le intestazioni da chiedere al server (FETCH BODY.PEEK[HEADER.FIELDS (…)]).</summary>
    public static readonly HeaderId[] Ids = [HeaderId.Importance, HeaderId.XPriority, HeaderId.Priority];

    public static MailImportance From(HeaderList? headers)
    {
        if (headers is null)
            return MailImportance.Normal;
        if (Value(headers, HeaderId.Importance) is { } importance)
        {
            return importance.ToLowerInvariant() switch
            {
                "high" => MailImportance.High,
                "low" => MailImportance.Low,
                _ => MailImportance.Normal,
            };
        }
        if (Value(headers, HeaderId.XPriority) is { Length: > 0 } x)
        {
            return x[0] switch
            {
                '1' or '2' => MailImportance.High,
                '4' or '5' => MailImportance.Low,
                _ => MailImportance.Normal,
            };
        }
        return Value(headers, HeaderId.Priority)?.ToLowerInvariant() switch
        {
            "urgent" => MailImportance.High,
            "non-urgent" => MailImportance.Low,
            _ => MailImportance.Normal,
        };
    }

    /// <summary>
    /// Scrive l'importanza come Outlook: <c>Importance</c> e <c>X-Priority</c> (letta dai programmi che non conoscono
    /// la prima). Normale: nessuna intestazione.
    /// </summary>
    public static void Apply(MimeMessage message, MailImportance importance)
    {
        message.Headers.RemoveAll(HeaderId.Importance);
        message.Headers.RemoveAll(HeaderId.XPriority);
        switch (importance)
        {
            case MailImportance.High:
                message.Importance = MessageImportance.High;
                message.XPriority = XMessagePriority.Highest;
                break;
            case MailImportance.Low:
                message.Importance = MessageImportance.Low;
                message.XPriority = XMessagePriority.Lowest;
                break;
        }
    }

    private static string? Value(HeaderList headers, HeaderId id)
    {
        var value = headers[id]?.Trim();
        return string.IsNullOrEmpty(value) ? null : value;
    }
}
