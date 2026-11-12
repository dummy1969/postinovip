using MailKit;
using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Tests;

public class SpecialUseTests
{
    [Theory]
    [InlineData(FolderAttributes.Sent | FolderAttributes.HasNoChildren, "Posta inviata", "sent")]
    [InlineData(FolderAttributes.Trash, "Cestino", "trash")]
    [InlineData(FolderAttributes.Drafts, "Bozze", "drafts")]
    [InlineData(FolderAttributes.Junk, "Spam", "junk")]
    [InlineData(FolderAttributes.None, "INBOX", "inbox")]
    [InlineData(FolderAttributes.HasNoChildren, "Sent", null)] // il nome da solo non basta
    public void RuoloDagliAttributi(FolderAttributes attributes, string fullName, string? expected)
    {
        Assert.Equal(expected, SpecialUse.FromAttributes(attributes, fullName));
    }
}
