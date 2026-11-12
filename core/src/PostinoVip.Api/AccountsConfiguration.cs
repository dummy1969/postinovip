using PostinoVip.Core.Account;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Api;

/// <summary>
/// Legge le caselle dalla configurazione:
/// - "Accounts": elenco (variabili d'ambiente Accounts__0__Id, Accounts__0__Imap__Host, ...);
/// - se l'elenco manca, le sezioni "Imap" e "Smtp" del formato a un account, come account "main".
/// </summary>
public static class AccountsConfiguration
{
    public const string LegacyId = "main";

    /// <exception cref="ArgumentException">Elenco non valido (id mancanti, non validi o ripetuti).</exception>
    public static IReadOnlyList<MailAccountSettings> Read(IConfiguration config)
    {
        var accounts = config.GetSection("Accounts").Get<List<MailAccountSettings>>() ?? [];
        if (accounts.Count == 0)
        {
            accounts.Add(new MailAccountSettings
            {
                Id = LegacyId,
                Imap = config.GetSection("Imap").Get<ImapSettings>() ?? new ImapSettings(),
                Smtp = config.GetSection("Smtp").Get<SmtpSettings>() ?? new SmtpSettings(),
                CardDav = config.GetSection("CardDav").Get<AccountDavSettings>() ?? new AccountDavSettings(),
                CalDav = config.GetSection("CalDav").Get<AccountDavSettings>() ?? new AccountDavSettings(),
            });
        }
        foreach (var a in accounts)
        {
            if (a.IsPop3)
                a.Smtp.InheritCredentialsFrom(a.Pop3.Username, a.Pop3.Password);
            else
                a.Smtp.InheritCredentialsFrom(a.Imap);
        }

        MailAccountRegistry.Validate(accounts);
        return accounts;
    }
}
