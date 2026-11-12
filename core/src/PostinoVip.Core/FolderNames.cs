namespace PostinoVip.Core;

/// <summary>Regole per i nomi delle cartelle scritti dall'utente (Nuova cartella, Rinomina).</summary>
public static class FolderNames
{
    public const int MaxLength = 200;

    /// <summary>
    /// Nome ripulito (spazi in testa e in coda tolti) oppure FieldValidationException sul campo "name":
    /// vuoto, troppo lungo, con caratteri di controllo o con il separatore della gerarchia (creerebbe
    /// sottocartelle senza volerlo); "INBOX" è riservato in cima alla casella.
    /// </summary>
    public static string Validate(string? name, char separator, bool topLevel)
    {
        var clean = (name ?? "").Trim();
        if (clean.Length == 0)
            throw new FieldValidationException("name", "Scrivere il nome della cartella.");
        if (clean.Length > MaxLength)
            throw new FieldValidationException("name", $"Il nome può avere al massimo {MaxLength} caratteri.");
        if (clean.Any(char.IsControl))
            throw new FieldValidationException("name", "Il nome contiene caratteri non validi.");
        if (separator != '\0' && clean.Contains(separator))
            throw new FieldValidationException("name", $"Il nome non può contenere il carattere \"{separator}\".");
        if (topLevel && clean.Equals("INBOX", StringComparison.OrdinalIgnoreCase))
            throw new FieldValidationException("name", "\"INBOX\" è il nome riservato della Posta in arrivo.");
        return clean;
    }

    /// <summary>
    /// Primo nome libero tra <paramref name="name"/>, "name (2)", "name (3)"... (confronto senza
    /// maiuscole/minuscole, come fanno molti server): serve a spostare una cartella in Posta eliminata
    /// quando lì ce n'è già una con lo stesso nome.
    /// </summary>
    public static string FirstFree(string name, IEnumerable<string> taken)
    {
        var used = new HashSet<string>(taken, StringComparer.OrdinalIgnoreCase);
        if (!used.Contains(name))
            return name;
        for (var i = 2; ; i++)
            if (!used.Contains($"{name} ({i})"))
                return $"{name} ({i})";
    }
}
