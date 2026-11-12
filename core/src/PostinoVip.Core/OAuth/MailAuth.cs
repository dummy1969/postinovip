using MailKit;
using MailKit.Security;

namespace PostinoVip.Core.OAuth;

/// <summary>
/// Login comune a IMAP, SMTP e POP3: con OAuth2 (token di accesso dell'account) SASL XOAUTH2, altrimenti la password.
/// </summary>
public static class MailAuth
{
    public static async Task AuthenticateAsync(IMailService client, string username, string password,
        Func<CancellationToken, Task<string>>? accessToken, CancellationToken ct)
    {
        if (accessToken is null)
        {
            await client.AuthenticateAsync(username, password, ct);
            return;
        }
        var token = await accessToken(ct);
        await client.AuthenticateAsync(new SaslMechanismOAuth2(username, token), ct);
    }
}
