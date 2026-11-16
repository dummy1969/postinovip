using System.Security.Cryptography;
using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Rules;

/// <summary>Fin dove le regole sono già state applicate nella Posta in arrivo (UIDVALIDITY e ultimo UID).</summary>
public sealed record RuleProgress(uint? UidValidity, uint LastUid);

/// <summary>
/// Le regole di un account in <c>accounts/{id}/rules.json</c> (scelta 6a: le applica il core) e l'avanzamento
/// in <c>rules-state.json</c>. Scrittura atomica (temporaneo, fsync, rinomina), file 0600. Le regole restano
/// anche ricostruendo la copia locale.
/// </summary>
public sealed class RuleStore(string directory)
{
    public const int MaxRules = 200;
    public const int MaxNameLength = 100;
    public const int MaxWords = 50;
    public const int MaxWordLength = 200;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private readonly Lock _lock = new();

    public string RulesPath { get; } = Path.Combine(directory, "rules.json");
    public string StatePath { get; } = Path.Combine(directory, "rules-state.json");

    public IReadOnlyList<MailRule> Load()
    {
        lock (_lock)
            return Read<List<MailRule>>(RulesPath) ?? [];
    }

    /// <summary>Controlla e salva l'elenco completo (nell'ordine in cui si applicano); restituisce quello salvato.</summary>
    public IReadOnlyList<MailRule> Save(IReadOnlyList<MailRule> rules)
    {
        var clean = Validate(rules);
        lock (_lock)
            Write(RulesPath, clean);
        return clean;
    }

    public RuleProgress? LoadProgress()
    {
        lock (_lock)
            return Read<RuleProgress>(StatePath);
    }

    public void SaveProgress(RuleProgress progress)
    {
        lock (_lock)
            Write(StatePath, progress);
    }

    /// <summary>
    /// Regole ripulite (nomi e parole senza spazi ai lati, parole vuote tolte, id dati a quelle nuove) oppure
    /// FieldValidationException sul campo "rules" con un messaggio per l'utente.
    /// </summary>
    public static List<MailRule> Validate(IReadOnlyList<MailRule> rules)
    {
        if (rules.Count > MaxRules)
            throw new FieldValidationException("rules", $"Al massimo {MaxRules} regole per account.").WithCode("alMassimoRegolePerAccount", ("maxRules", MaxRules));
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<MailRule>();
        foreach (var rule in rules)
        {
            var name = (rule.Name ?? "").Trim();
            if (name.Length == 0)
                throw new FieldValidationException("rules", "Ogni regola deve avere un nome.").WithCode("ogniRegolaDeveAvereUn");
            if (name.Length > MaxNameLength)
                throw new FieldValidationException("rules", $"«{name[..20]}…»: il nome può avere al massimo {MaxNameLength} caratteri.").WithCode("ilNomePuoAvereAl2", ("name", name[..20]), ("maxNameLength", MaxNameLength));
            var actions = rule.Actions ?? new RuleActions();
            if (actions.IsEmpty)
                throw new FieldValidationException("rules", $"«{name}»: scegliere almeno un'azione.");
            if (actions.Delete && actions.MoveTo is not null)
                throw new FieldValidationException("rules", $"«{name}»: «Elimina» e «Sposta» insieme non hanno senso, sceglierne uno.").WithCode("eliminaSpostaInsiemeNonHanno", ("name", name));
            if (actions.Category is < 1 or > 6)
                throw new FieldValidationException("rules", $"«{name}»: categoria non valida.").WithCode("categoriaNonValida", ("name", name));
            var id = IsValidId(rule.Id) && ids.Add(rule.Id) ? rule.Id : NewId(ids);
            result.Add(rule with
            {
                Id = id,
                Name = name,
                Conditions = Clean(rule.Conditions ?? new RuleConditions(), name),
                Exceptions = rule.Exceptions is null ? null : Clean(rule.Exceptions, name) is { IsEmpty: false } e ? e : null,
                Actions = actions with { MoveTo = Folder(actions.MoveTo), CopyTo = Folder(actions.CopyTo) },
            });
        }
        return result;
    }

    private static RuleConditions Clean(RuleConditions c, string rule)
    {
        if (c.SizeGreaterThanKb is < 1 or > 10_000_000)
            throw new FieldValidationException("rules", $"«{rule}»: dimensione non valida.").WithCode("dimensioneNonValida", ("rule", rule));
        return c with
        {
            From = Words(c.From, rule), ToOrCc = Words(c.ToOrCc, rule), SubjectContains = Words(c.SubjectContains, rule),
            SubjectOrBodyContains = Words(c.SubjectOrBodyContains, rule),
        };
    }

    private static List<string>? Words(IReadOnlyList<string>? words, string rule)
    {
        var clean = (words ?? []).Select(w => (w ?? "").Trim()).Where(w => w.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (clean.Count > MaxWords || clean.Any(w => w.Length > MaxWordLength))
            throw new FieldValidationException("rules", $"«{rule}»: troppe parole o parole troppo lunghe.").WithCode("troppeParoleParoleTroppoLunghe", ("rule", rule));
        return clean.Count == 0 ? null : clean;
    }

    private static string? Folder(string? folder) => string.IsNullOrWhiteSpace(folder) ? null : folder;

    private static bool IsValidId(string? id) => id is { Length: > 0 and <= 32 } && id.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');

    private static string NewId(HashSet<string> used)
    {
        while (true)
        {
            var id = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(4));
            if (used.Add(id))
                return id;
        }
    }

    private static T? Read<T>(string path) where T : class
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<T>(stream, Json);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            return null; // assente (nessuna regola) o rovinato
        }
    }

    private static void Write<T>(string path, T value)
    {
        CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(path)!);
        var temp = path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, value, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, path, overwrite: true);
    }
}
