namespace PostinoVip.Core.OAuth;

/// <summary>
/// Token di accesso di un account con OAuth2: tenuto in memoria fino a poco prima della scadenza, poi rinnovato
/// con il token di rinnovo. Se il fornitore ne dà uno nuovo (Microsoft lo cambia a ogni rinnovo),
/// <paramref name="refreshTokenChanged"/> lo passa all'app, che lo salva nel portachiavi (4a).
/// Senza rete: MailOfflineException; token revocato o scaduto: OAuthException (serve un nuovo accesso).
/// <paramref name="needsLoginChanged"/> (2a, 05/11/2026): il fornitore ha rifiutato il token di rinnovo (true) o di
/// nuovo accettato (false); l'app mostra «Accesso scaduto» con «Accedi di nuovo».
/// </summary>
public sealed class OAuthTokenSource(OAuthProvider provider, string refreshToken, Action<string>? refreshTokenChanged = null,
    TimeProvider? time = null, Action<bool>? needsLoginChanged = null)
{
    private static readonly TimeSpan Margin = TimeSpan.FromMinutes(2);

    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly TimeProvider _time = time ?? TimeProvider.System;
    private string _refreshToken = refreshToken;
    private string? _accessToken;
    private DateTimeOffset _expiresAt;

    public OAuthProvider Provider => provider;

    /// <summary>Permessi concessi secondo l'ultima risposta del fornitore (null prima del primo token).</summary>
    public string? GrantedScopes { get; private set; }

    /// <summary>true dopo che il fornitore ha rifiutato il token di rinnovo (scaduto o revocato): serve un nuovo accesso.</summary>
    public bool NeedsLogin { get; private set; }

    public async Task<string> GetAccessTokenAsync(CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try
        {
            if (_accessToken is { } cached && _time.GetUtcNow() < _expiresAt - Margin)
                return cached;
            OAuthTokens tokens;
            try
            {
                tokens = await OAuthClient.RefreshAsync(provider, _refreshToken, ct);
            }
            catch (OAuthException e) when (e.NeedsLogin)
            {
                SetNeedsLogin(true);
                throw;
            }
            SetNeedsLogin(false);
            _accessToken = tokens.AccessToken;
            _expiresAt = tokens.ExpiresAt;
            if (tokens.Scope is not null)
                GrantedScopes = tokens.Scope;
            if (tokens.RefreshToken is { Length: > 0 } rotated && rotated != _refreshToken)
            {
                _refreshToken = rotated;
                refreshTokenChanged?.Invoke(rotated);
            }
            return _accessToken;
        }
        finally
        {
            _lock.Release();
        }
    }

    private void SetNeedsLogin(bool value)
    {
        if (NeedsLogin == value)
            return;
        NeedsLogin = value;
        needsLoginChanged?.Invoke(value);
    }

    /// <summary>Il server ha rifiutato il token (es. appena revocato): il prossimo collegamento ne chiede uno nuovo.</summary>
    public void Invalidate() => _accessToken = null;
}
