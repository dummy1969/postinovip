using System.Text;

namespace PostinoVip.Core.Contacts;

/// <summary>
/// Minuscolo e senza accenti con una tabella esplicita delle lettere latine ("Nicolò" -> "nicolo", "Società" ->
/// "societa"). Non si usa string.Normalize: il core gira con InvariantGlobalization (6b) e lì la scomposizione
/// degli accenti non è garantita (trovato con tools/verifica-contatti.sh: nei test passava, nel core no).
/// </summary>
public static class TextFold
{
    private const string From = "àáâãäåāăąçćčďèéêëēĕėęěìíîïīĭįıñńňòóôõöøōŏőùúûüūŭůűųýÿžźżšśşţťŕřľĺłđ";
    private const string To   = "aaaaaaaaacccdeeeeeeeeeiiiiiiiinnnooooooooouuuuuuuuuyyzzzsssttrrllld";

    public static string Fold(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (var c in s)
        {
            var lower = char.ToLowerInvariant(c);
            var i = From.IndexOf(lower);
            if (i >= 0)
                sb.Append(To[i]);
            else if (lower == 'ß')
                sb.Append("ss");
            else if (lower == 'æ')
                sb.Append("ae");
            else if (lower == 'œ')
                sb.Append("oe");
            else
                sb.Append(lower);
        }
        return sb.ToString();
    }
}
