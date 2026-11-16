using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Rules;

namespace PostinoVip.Api.Controllers;

/// <summary>
/// Regole dell'account (R1): le applica il core alle mail nuove della Posta in arrivo. Salvare non modifica la
/// casella: le regole valgono per le mail che arrivano da quel momento.
/// </summary>
[ApiController]
[Route("rules")]
[Route("accounts/{accountId}/rules")]
public sealed class RulesController(MailAccountRegistry accounts, RuleJobs jobs) : MailControllerBase(accounts)
{
    private RuleStore Store =>
        CurrentAccount.Rules ?? throw new NotSupportedException("Le regole richiedono la copia locale (Cache:Enabled=false).").WithCode("leRegoleRichiedonoLaCopia2");

    /// <summary>GET — le regole nell'ordine in cui si applicano.</summary>
    [HttpGet]
    public ActionResult<IReadOnlyList<MailRule>> Get() => Ok(Store.Load());

    /// <summary>PUT — sostituisce l'elenco completo (ordine compreso); dati non validi -> 400 sul campo "rules".</summary>
    [HttpPut]
    public ActionResult<IReadOnlyList<MailRule>> Put([FromBody] List<MailRule> rules) => Ok(Store.Save(rules));

    /// <summary>
    /// POST run — "Esegui regole ora" (R3): MODIFICA la casella. Le regole indicate (per id, anche disattivate)
    /// sulle mail già presenti nella cartella (con le sottocartelle se richiesto), tutte, lette o da leggere.
    /// 202 con l'id dell'esecuzione; l'avanzamento con GET run/{id}, l'interruzione con DELETE run/{id}.
    /// </summary>
    [HttpPost("run")]
    public async Task<ActionResult<RunRulesResponse>> Run([FromBody] RunRulesRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var all = Store.Load();
        var chosen = all.Where(r => request.RuleIds.Contains(r.Id)).ToList();
        if (chosen.Count == 0)
            throw new FieldValidationException("ruleIds", "Scegliere almeno una regola salvata.").WithCode("scegliereAlmenoUnaRegolaSalvata");
        var folder = string.IsNullOrWhiteSpace(request.Folder) ? RuleRunner.Inbox : request.Folder;
        var folders = new List<string> { folder };
        if (request.IncludeSubfolders)
        {
            // Sottocartelle: nome che continua con un separatore ("/" sul server di prova e nel POP3, "." su altri).
            var list = await account.Reader.GetFoldersAsync(ct);
            folders.AddRange(list.Select(f => f.FullName)
                .Where(n => n.Length > folder.Length + 1 && n.StartsWith(folder, StringComparison.Ordinal) && n[folder.Length] is '/' or '.'));
        }
        var id = jobs.Start(account, chosen, folders, request.Filter);
        return Accepted(new RunRulesResponse(id, folders));
    }

    [HttpGet("run/{id}")]
    public ActionResult<RuleJobStatus> RunStatus(string id) =>
        jobs.Status(CurrentAccount.Id, id) is { } status ? Ok(status) : NotFound();

    [HttpDelete("run/{id}")]
    public IActionResult CancelRun(string id) => jobs.Cancel(CurrentAccount.Id, id) ? Accepted() : NotFound();
}

/// <summary>Corpo di POST …/rules/run.</summary>
public sealed class RunRulesRequest
{
    public List<string> RuleIds { get; set; } = [];
    public string? Folder { get; set; }
    public bool IncludeSubfolders { get; set; }
    public RuleRunFilter Filter { get; set; } = RuleRunFilter.All;
}

public sealed record RunRulesResponse(string Id, IReadOnlyList<string> Folders);
