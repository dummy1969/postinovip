namespace PostinoVip.Api;

/// <summary>
/// Cartella della cache locale: "Cache:Directory" se indicata, altrimenti la cartella dei dati
/// dell'utente sul disco locale (Linux: $XDG_DATA_HOME o ~/.local/share; Windows: %LOCALAPPDATA%;
/// macOS: ~/Library/Application Support) + "postinovip". In sviluppo "postinovip-dev": le prove
/// non toccano la cache dell'app installata (che potrebbe avere uno schema diverso).
/// </summary>
public static class CacheLocation
{
    public static string Resolve(IConfiguration config, IHostEnvironment env)
    {
        if (config["Cache:Directory"] is { Length: > 0 } custom)
            return Path.GetFullPath(custom);

        var data = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData, Environment.SpecialFolderOption.DoNotVerify);
        if (string.IsNullOrEmpty(data))
            throw new InvalidOperationException("Cartella dei dati dell'utente non determinabile (HOME non impostata?): usare Cache:Directory.");
        return Path.Combine(data, env.IsDevelopment() ? "postinovip-dev" : "postinovip");
    }
}
