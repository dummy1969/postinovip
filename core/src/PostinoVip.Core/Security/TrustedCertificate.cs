using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace PostinoVip.Core.Security;

/// <summary>Dati di un certificato mostrati all'utente per decidere se fidarsi (mai dati privati).</summary>
public sealed record CertificateInfo(
    string Host,
    int Port,
    string Subject,
    string Issuer,
    DateTimeOffset? NotBefore,
    DateTimeOffset? NotAfter,
    string Sha256,
    IReadOnlyList<string> Problems)
{
    /// <summary>Gli stessi problemi come codici per l'app (L6): nameMismatch, untrustedRoot, notTimeValid, revoked,
    /// chainInvalid, noCertificate.</summary>
    public IReadOnlyList<string> ProblemCodes { get; init; } = [];
}

/// <summary>
/// Il server ha presentato un certificato non valido (autofirmato, nome diverso, scaduto…) e diverso da
/// quello di cui l'utente ha scelto di fidarsi. La connessione è stata rifiutata prima di inviare la password.
/// </summary>
public sealed class UntrustedCertificateException(CertificateInfo certificate, Exception? inner = null)
    : Exception($"Certificato non valido per {certificate.Host}:{certificate.Port} ({string.Join(", ", certificate.Problems)}).", inner)
{
    public CertificateInfo Certificate { get; } = certificate;
}

/// <summary>
/// Controllo del certificato del server (4.1, scelta 6a). Un certificato valido (firmato da un'autorità
/// riconosciuta, con il nome del server, non scaduto) è sempre accettato. Uno non valido è accettato
/// **solo** se la sua impronta SHA-256 è quella salvata con l'account ("Fidarsi di questo certificato?"):
/// se il server ne presenta un altro, la connessione è rifiutata e si chiede di nuovo. Mai "qualsiasi
/// certificato". Un oggetto per connessione: <see cref="Rejected"/> è il certificato dell'ultimo rifiuto.
/// </summary>
public sealed class TrustedCertificate(string host, int port, string? pinnedSha256)
{
    public CertificateInfo? Rejected { get; private set; }

    public bool Validate(object sender, X509Certificate? certificate, X509Chain? chain, SslPolicyErrors errors)
    {
        if (errors == SslPolicyErrors.None)
            return true;
        if (certificate is null)
        {
            Rejected = null;
            return false;
        }
        var sha256 = Fingerprint(certificate);
        if (NormalizeFingerprint(pinnedSha256) is { } pinned && pinned == sha256)
            return true;
        Rejected = Describe(certificate, sha256, chain, errors);
        return false;
    }

    /// <summary>Impronta SHA-256 dei byte del certificato, esadecimale maiuscolo senza separatori.</summary>
    public static string Fingerprint(X509Certificate certificate) =>
        Convert.ToHexString(certificate.GetCertHash(HashAlgorithmName.SHA256));

    /// <summary>Impronta salvata, accettata anche con ":" o spazi e in minuscolo; null se vuota o non valida.</summary>
    public static string? NormalizeFingerprint(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;
        var hex = new string(value.Where(c => c is not (':' or ' ')).ToArray()).ToUpperInvariant();
        return hex.Length == 64 && hex.All(Uri.IsHexDigit) ? hex : null;
    }

    private CertificateInfo Describe(X509Certificate certificate, string sha256, X509Chain? chain, SslPolicyErrors errors)
    {
        var problems = new List<string>();
        var codes = new List<string>();
        void Add(string code, string text)
        {
            if (codes.Contains(code))
                return;
            codes.Add(code);
            problems.Add(text);
        }
        if (errors.HasFlag(SslPolicyErrors.RemoteCertificateNameMismatch))
            Add("nameMismatch", $"intestato a un nome diverso da {host}");
        if (errors.HasFlag(SslPolicyErrors.RemoteCertificateChainErrors))
        {
            var before = problems.Count;
            var status = chain?.ChainStatus.Select(s => s.Status).ToHashSet() ?? [];
            if (status.Contains(X509ChainStatusFlags.UntrustedRoot) || status.Contains(X509ChainStatusFlags.PartialChain))
                Add("untrustedRoot", "non firmato da un'autorità riconosciuta (es. autofirmato)");
            if (status.Contains(X509ChainStatusFlags.NotTimeValid))
                Add("notTimeValid", "scaduto o non ancora valido");
            if (status.Contains(X509ChainStatusFlags.Revoked))
                Add("revoked", "revocato");
            if (problems.Count == before)
                Add("chainInvalid", "catena di certificazione non valida");
        }
        if (errors.HasFlag(SslPolicyErrors.RemoteCertificateNotAvailable))
            Add("noCertificate", "nessun certificato");

        var c2 = certificate as X509Certificate2;
        return new CertificateInfo(host, port, certificate.Subject, certificate.Issuer,
            c2 is null ? null : new DateTimeOffset(c2.NotBefore.ToUniversalTime(), TimeSpan.Zero),
            c2 is null ? null : new DateTimeOffset(c2.NotAfter.ToUniversalTime(), TimeSpan.Zero),
            sha256, problems) { ProblemCodes = codes };
    }
}
