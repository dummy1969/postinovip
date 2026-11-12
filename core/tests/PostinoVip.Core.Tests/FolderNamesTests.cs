namespace PostinoVip.Core.Tests;

public class FolderNamesTests
{
    [Theory]
    [InlineData("  Clienti  ", "Clienti")]
    [InlineData("Àèìòù 2026", "Àèìòù 2026")]
    [InlineData("Inbox vecchia", "Inbox vecchia")]
    public void NomeValidoRipulito(string name, string expected) =>
        Assert.Equal(expected, FolderNames.Validate(name, '/', topLevel: true));

    [Theory]
    [InlineData("", true)]
    [InlineData("   ", true)]
    [InlineData("Clienti/Rossi", true)] // creerebbe una sottocartella
    [InlineData("riga\nnuova", true)]
    [InlineData("INBOX", true)]
    [InlineData("inbox", true)]
    public void NomeNonValido(string name, bool topLevel)
    {
        var e = Assert.Throws<FieldValidationException>(() => FolderNames.Validate(name, '/', topLevel));
        Assert.Equal("name", e.Field);
    }

    [Fact]
    public void InboxPermessoComeSottocartellaETroppoLungoRifiutato()
    {
        Assert.Equal("INBOX", FolderNames.Validate("INBOX", '/', topLevel: false));
        Assert.Throws<FieldValidationException>(() => FolderNames.Validate(new string('a', FolderNames.MaxLength + 1), '/', false));
        Assert.Equal("a.b", FolderNames.Validate("a.b", '/', false)); // il punto è un separatore solo su altri server
        Assert.Throws<FieldValidationException>(() => FolderNames.Validate("a.b", '.', false));
    }

    [Fact]
    public void PrimoNomeLibero()
    {
        Assert.Equal("Clienti", FolderNames.FirstFree("Clienti", ["Altro"]));
        Assert.Equal("Clienti (2)", FolderNames.FirstFree("Clienti", ["clienti"]));
        Assert.Equal("Clienti (3)", FolderNames.FirstFree("Clienti", ["Clienti", "Clienti (2)"]));
    }
}
