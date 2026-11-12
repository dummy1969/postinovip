namespace PostinoVip.Api.Tests;

public class ApiTokenTests
{
    [Theory]
    [InlineData("")]
    [InlineData("troppo-corto")]
    public void TokenMancanteOCortoRifiutato(string value)
    {
        Assert.Throws<ArgumentException>(() => new ApiToken(value));
    }

    [Fact]
    public void ConfrontoEsatto()
    {
        var token = new ApiToken(ApiTests.Token);

        Assert.True(token.Matches(ApiTests.Token));
        Assert.False(token.Matches(ApiTests.Token + "x"));
        Assert.False(token.Matches(ApiTests.Token[..^1]));
        Assert.False(token.Matches(null));
    }
}
