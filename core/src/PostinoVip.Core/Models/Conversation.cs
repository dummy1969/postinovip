namespace PostinoVip.Core.Models;

/// <summary>Una mail di una conversazione con la cartella in cui si trova (può essere diversa da quella aperta).</summary>
public sealed record ConversationMessage(string Folder, MessageHeader Message);

/// <summary>
/// Conversazione (3.6): Id stabile finché le mail non cambiano (id interno della prima mail), mail dalla più
/// recente. Unread = mail da leggere tra quelle mostrate; HasAttachments = almeno una con allegati.
/// </summary>
public sealed record Conversation(long Id, int Count, int Unread, bool HasAttachments, IReadOnlyList<ConversationMessage> Messages);

/// <summary>Una pagina di conversazioni; Total è il numero di conversazioni della cartella.</summary>
public sealed record ConversationPage(int Total, int Offset, int Limit, IReadOnlyList<Conversation> Items);
