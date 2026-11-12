using PostinoVip.Core.Account;

namespace PostinoVip.Core.Tests;

public class MailAccountRegistryTests
{
    private static MailAccountSettings Settings(string id) => new() { Id = id };

    [Theory]
    [InlineData("")]
    [InlineData("con spazio")]
    [InlineData("a/b")]
    [InlineData("àccento")]
    public void IdNonValidoRifiutato(string id)
    {
        var ex = Assert.Throws<ArgumentException>(() => MailAccountRegistry.Validate([Settings(id)]));
        Assert.Contains("Id account non valido", ex.Message);
    }

    [Fact]
    public void IdRipetutoONessunAccountRifiutati()
    {
        Assert.Contains("ripetuto", Assert.Throws<ArgumentException>(() => MailAccountRegistry.Validate([Settings("a"), Settings("a")])).Message);
        Assert.Throws<ArgumentException>(() => MailAccountRegistry.Validate([]));
    }

    [Fact]
    public async Task GetPerIdOppureIlPrimo()
    {
        await using var registry = MailAccountRegistry.CreateImap([Settings("uno"), Settings("due_2")]);

        Assert.Equal("uno", registry.Get(null).Id);
        Assert.Equal("due_2", registry.Get("due_2").Id);
        Assert.Throws<MailNotFoundException>(() => registry.Get("tre"));
    }

    [Fact]
    public void ConfiguratoSoloConTuttiIDati()
    {
        var s = new MailAccountSettings { Id = "a" };
        s.Imap.Host = "imap.example.com";
        s.Imap.Username = "me@example.com";
        s.Smtp.Host = "smtp.example.com";
        Assert.False(s.IsConfigured); // manca la password

        s.Imap.Password = "x";
        Assert.True(s.IsConfigured);
    }

    [Fact]
    public void NomeMostratoPredefinitoEIndirizzo()
    {
        var s = new MailAccountSettings { Id = "a" };
        s.Smtp.Username = "me@example.com";
        Assert.Equal("me@example.com", s.DisplayName);

        s.Name = "Lavoro";
        Assert.Equal("Lavoro", s.DisplayName);
    }
}
