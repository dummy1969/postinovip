using System.Collections.Concurrent;
using System.Security.Cryptography;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Rules;

namespace PostinoVip.Api;

/// <summary>Stato di un "Esegui regole ora" (R3), letto dall'app ogni mezzo secondo.</summary>
public sealed record RuleJobStatus(string Id, int Checked, int Total, int Applied, int Failed, bool Done, bool Cancelled, string? Error);

/// <summary>
/// Un RuleRunner per account (lo stesso per le mail nuove e per "Esegui regole ora": uno alla volta per account)
/// e le esecuzioni "Esegui regole ora" in corso, interrompibili. Le esecuzioni finite si dimenticano dopo
/// <see cref="Keep"/>.
/// </summary>
public sealed class RuleJobs(ILoggerFactory loggers)
{
    public static readonly TimeSpan Keep = TimeSpan.FromMinutes(10);

    private readonly ILogger _logger = loggers.CreateLogger("PostinoVip.Rules");
    private readonly ConcurrentDictionary<string, RuleRunner> _runners = new();
    private readonly ConcurrentDictionary<string, Job> _jobs = new();

    private readonly ConcurrentDictionary<string, PostinoVip.Core.AutoReply.AutoReplyRunner> _autoReplies = new();

    /// <summary>Risposte automatiche dell'account (stesso servizio delle regole: prima le risposte, poi le regole).</summary>
    public PostinoVip.Core.AutoReply.AutoReplyRunner? AutoReplyFor(MailAccount account) =>
        account.AutoReply is null
            ? null
            : _autoReplies.GetOrAdd(account.Id, _ => new PostinoVip.Core.AutoReply.AutoReplyRunner(account, account.AutoReply,
                m => _logger.LogInformation("{Message}", m)));

    private readonly ConcurrentDictionary<string, PostinoVip.Core.Junk.JunkFilter> _junk = new();

    /// <summary>Posta indesiderata dell'account (J1): lo stesso filtro per le mail nuove e per i comandi.</summary>
    public PostinoVip.Core.Junk.JunkFilter? JunkFor(MailAccount account) =>
        account.Junk is null
            ? null
            : _junk.GetOrAdd(account.Id, _ => new PostinoVip.Core.Junk.JunkFilter(account, account.Junk,
                m => _logger.LogInformation("{Message}", m)));

    private readonly ConcurrentDictionary<string, PostinoVip.Core.Conversations.ConversationTools> _conversations = new();

    /// <summary>Ignora e Pulisci conversazione dell'account (C1): lo stesso oggetto per le mail nuove e per i comandi.</summary>
    public PostinoVip.Core.Conversations.ConversationTools? ConversationsFor(MailAccount account) =>
        account.Ignore is null
            ? null
            : _conversations.GetOrAdd(account.Id, _ => new PostinoVip.Core.Conversations.ConversationTools(account, account.Ignore,
                m => _logger.LogInformation("{Message}", m)));

    public RuleRunner RunnerFor(MailAccount account) =>
        _runners.GetOrAdd(account.Id, _ => new RuleRunner(account,
            account.Rules ?? throw new NotSupportedException("Le regole richiedono la copia locale.").WithCode("leRegoleRichiedonoLaCopia"),
            m => _logger.LogInformation("{Message}", m)));

    /// <summary>Avvia l'esecuzione in background; restituisce il suo id.</summary>
    public string Start(MailAccount account, IReadOnlyList<MailRule> rules, IReadOnlyList<string> folders, RuleRunFilter filter)
    {
        Cleanup();
        var job = new Job(Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8)), account.Id);
        _jobs[job.Id] = job;
        var runner = RunnerFor(account);
        _ = Task.Run(async () =>
        {
            try
            {
                var result = await runner.RunOnFoldersAsync(rules, folders, filter, (done, total) =>
                {
                    job.Checked = done;
                    job.Total = total;
                }, job.Cancel.Token);
                job.Applied = result.Applied;
                job.Failed = result.Failed;
            }
            catch (OperationCanceledException) when (job.Cancel.IsCancellationRequested)
            {
                job.Cancelled = true;
            }
            catch (Exception ex)
            {
                job.Error = ex is MailOfflineException ? "Non connesso: il server non è raggiungibile." : $"{ex.GetType().Name}: {ex.Message}";
                _logger.LogWarning("[{Account}] esegui regole ora non riuscito: {Error}", account.Id, job.Error);
            }
            finally
            {
                job.Finished = DateTimeOffset.UtcNow;
            }
        });
        return job.Id;
    }

    public RuleJobStatus? Status(string account, string id) =>
        _jobs.TryGetValue(id, out var j) && j.Account == account
            ? new RuleJobStatus(j.Id, j.Checked, j.Total, j.Applied, j.Failed, j.Finished is not null, j.Cancelled, j.Error)
            : null;

    public bool Cancel(string account, string id)
    {
        if (!_jobs.TryGetValue(id, out var j) || j.Account != account)
            return false;
        j.Cancel.Cancel();
        return true;
    }

    private void Cleanup()
    {
        foreach (var (id, j) in _jobs)
            if (j.Finished is { } f && DateTimeOffset.UtcNow - f > Keep)
                _jobs.TryRemove(id, out _);
    }

    private sealed class Job(string id, string account)
    {
        public string Id { get; } = id;
        public string Account { get; } = account;
        public CancellationTokenSource Cancel { get; } = new();
        public volatile int Checked;
        public volatile int Total;
        public int Applied;
        public int Failed;
        public volatile bool Cancelled;
        public string? Error;
        public DateTimeOffset? Finished;
    }
}
