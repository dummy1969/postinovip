namespace PostinoVip.Api.Contracts;

/// <summary>Versione del core (Directory.Build.props), del runtime .NET e del sistema operativo.</summary>
public sealed record VersionResponse(string Version, string Runtime, string Os);
