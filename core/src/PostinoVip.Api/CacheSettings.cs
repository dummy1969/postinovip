namespace PostinoVip.Api;

/// <summary>Cartella della cache locale (null = cache disattivata con Cache:Enabled=false).</summary>
public sealed record CacheSettings(string? Root);
