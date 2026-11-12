using System.Security.Cryptography;
using System.Text;

namespace PostinoVip.Api;

/// <summary>
/// Token condiviso tra app e core, letto da POSTINOVIP_TOKEN (variabile d'ambiente, non argomento:
/// gli argomenti sono visibili a tutti gli utenti con "ps"). Mai scritto nei log.
/// </summary>
public sealed class ApiToken
{
    public const string ConfigKey = "POSTINOVIP_TOKEN";
    public const int MinLength = 32;

    private readonly byte[] _expected;

    public ApiToken(string token)
    {
        if (string.IsNullOrEmpty(token) || token.Length < MinLength)
            throw new ArgumentException($"{ConfigKey} mancante o più corto di {MinLength} caratteri.");
        _expected = Encoding.UTF8.GetBytes(token);
    }

    /// <summary>Confronto a tempo costante: non rivela quanti caratteri iniziali sono corretti.</summary>
    public bool Matches(string? candidate) =>
        candidate is not null && CryptographicOperations.FixedTimeEquals(_expected, Encoding.UTF8.GetBytes(candidate));
}
