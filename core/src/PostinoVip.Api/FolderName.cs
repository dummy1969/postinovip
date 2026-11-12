namespace PostinoVip.Api;

public static class FolderName
{
    /// <summary>
    /// ASP.NET Core decodifica i parametri di route tranne %2F, che resta codificato per non
    /// confondersi con il separatore di percorso: lo decodifichiamo qui (es. "INBOX%2FSent" -> "INBOX/Sent").
    /// </summary>
    public static string FromRoute(string value) => Uri.UnescapeDataString(value);
}
