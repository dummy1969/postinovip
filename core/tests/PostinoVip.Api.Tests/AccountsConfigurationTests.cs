using Microsoft.Extensions.Configuration;

namespace PostinoVip.Api.Tests;

public class AccountsConfigurationTests
{
    private static IConfiguration Config(Dictionary<string, string?> values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    [Fact]
    public void LimiteDellaCachePerAccountDalleVariabili()
    {
        // Come le passa l'app: Accounts__N__Cache__BodyMonths (qui con ":" come separatore).
        var accounts = AccountsConfiguration.Read(Config(new()
        {
            ["Accounts:0:Id"] = "uno",
            ["Accounts:0:Cache:BodyMonths"] = "3",
            ["Accounts:1:Id"] = "due",
            ["Accounts:1:Cache:BodyMonths"] = "0",
            ["Accounts:2:Id"] = "tre",
        }));

        Assert.Equal([3, 0, null], accounts.Select(a => a.Cache.BodyMonths));
    }

    [Fact]
    public void LimiteNegativoRifiutato()
    {
        Assert.Throws<ArgumentException>(() => AccountsConfiguration.Read(Config(new()
        {
            ["Accounts:0:Id"] = "uno",
            ["Accounts:0:Cache:BodyMonths"] = "-1",
        })));
    }

    [Fact]
    public void CrittografiaAutenticazioneECertificatoDalleVariabili()
    {
        // Come le passa l'app (4.1): Accounts__N__Imap__Security, …__Smtp__RequireAuth, …__CertificateSha256.
        var accounts = AccountsConfiguration.Read(Config(new()
        {
            ["Accounts:0:Id"] = "uno",
            ["Accounts:0:Imap:Port"] = "143",
            ["Accounts:0:Imap:Security"] = "None",
            ["Accounts:0:Imap:CertificateSha256"] = "AB",
            ["Accounts:0:Smtp:Port"] = "25",
            ["Accounts:0:Smtp:RequireAuth"] = "false",
            ["Accounts:1:Id"] = "due",
            ["Accounts:1:Imap:Port"] = "143",
            ["Accounts:1:Smtp:Port"] = "465",
        }));

        Assert.Equal(PostinoVip.Core.Security.ConnectionSecurity.None, accounts[0].Imap.EffectiveSecurity);
        Assert.Equal("AB", accounts[0].Imap.CertificateSha256);
        Assert.False(accounts[0].Smtp.RequireAuth);
        Assert.Equal(PostinoVip.Core.Security.ConnectionSecurity.StartTls, accounts[1].Imap.EffectiveSecurity);
        Assert.Equal(PostinoVip.Core.Security.ConnectionSecurity.SslOnConnect, accounts[1].Smtp.EffectiveSecurity);
        Assert.True(accounts[1].Smtp.RequireAuth);
    }

    [Fact]
    public void AccountPop3DalleVariabili()
    {
        // Come le passerà l'app (4.2c): Accounts__N__Type=Pop3, Accounts__N__Pop3__*.
        var accounts = AccountsConfiguration.Read(Config(new()
        {
            ["Accounts:0:Id"] = "pop",
            ["Accounts:0:Type"] = "Pop3",
            ["Accounts:0:Pop3:Host"] = "pop.example.com",
            ["Accounts:0:Pop3:Port"] = "110",
            ["Accounts:0:Pop3:Username"] = "me@example.com",
            ["Accounts:0:Pop3:Password"] = "x",
            ["Accounts:0:Pop3:RemoveAfterDays"] = "30",
            ["Accounts:0:Pop3:RemoveWhenDeleted"] = "true",
            ["Accounts:0:Pop3:CheckMinutes"] = "5",
            ["Accounts:0:Smtp:Host"] = "smtp.example.com",
        }));

        var a = accounts.Single();
        Assert.True(a.IsPop3);
        Assert.True(a.IsConfigured);
        Assert.Equal(PostinoVip.Core.Security.ConnectionSecurity.StartTls, a.Pop3.EffectiveSecurity);
        Assert.Equal((true, 30, true, 5), (a.Pop3.LeaveOnServer, a.Pop3.RemoveAfterDays, a.Pop3.RemoveWhenDeleted, a.Pop3.CheckMinutes));
        Assert.Equal(("me@example.com", "x"), (a.Smtp.Username, a.Smtp.Password)); // dal POP3
        Assert.Equal("me@example.com", a.Address);
    }
}
