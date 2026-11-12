using PostinoVip.Core.Dav;

namespace PostinoVip.Core.Contacts.CardDav;

/// <summary>
/// Sincronizzazione della rubrica di un account con una rubrica CardDAV (C4b): l'algoritmo comune <see cref="DavSync"/>
/// sulla rubrica vista da <see cref="ContactDavStore"/>.
/// </summary>
public sealed class CardDavSync(DavClient client, ContactStore store, DavStateStore stateStore, Uri start, string source,
    Action<string>? log = null) : DavSync(client, new ContactDavStore(store), stateStore, start, source, log)
{
    /// <summary>Nome del file sul server, dall'UID (stesso contatto = stesso indirizzo anche ripetendo il caricamento).</summary>
    public static string FileName(Contact c) => FileNameFromUid(c.VCardUid, c.Id, ".vcf");
}

/// <summary>
/// La rubrica come la vede la sincronizzazione: impronta e chiave dei doppioni di <see cref="ContactStore"/>, vCard letti e
/// scritti con <see cref="VCard"/>, ora della modifica nel REV.
/// </summary>
public sealed class ContactDavStore(ContactStore store) : IDavItemStore
{
    public string ItemsLabel => "contatti";
    public int MaxItems => ContactStore.MaxContacts;

    public IReadOnlyList<DavLocalItem> List() => store.List().Select(ToItem).ToList();

    public DavLocalItem? Find(string id) => store.Find(id) is { } c ? ToItem(c) : null;

    public DavIncoming? Parse(string data) =>
        VCard.Parse(data).FirstOrDefault() is { } c ? new DavIncoming(c, c.Updated, ContactStore.DuplicateKey(c)) : null;

    public DavApplyResult Apply(string? id, DavIncoming incoming, DateTimeOffset updated, string? expectedFingerprint)
    {
        var r = store.ApplyFromSync(id, (Contact)incoming.Value with { Updated = updated }, expectedFingerprint);
        var outcome = r.Outcome switch
        {
            SyncApplyOutcome.Saved => DavApplyOutcome.Saved,
            SyncApplyOutcome.Invalid => DavApplyOutcome.Invalid,
            SyncApplyOutcome.ChangedMeanwhile => DavApplyOutcome.ChangedMeanwhile,
            _ => DavApplyOutcome.Full,
        };
        return new DavApplyResult(r.Contact is null ? null : ToItem(r.Contact), outcome);
    }

    public bool Remove(string id, string expectedFingerprint) => store.RemoveFromSync(id, expectedFingerprint);

    /// <summary>Ogni contatto sul server ha un UID (RFC 6352): aggiunto se manca.</summary>
    public DavExport? Export(string id, string expectedFingerprint)
    {
        if (store.Find(id) is not { } c || ContactStore.Fingerprint(c) != expectedFingerprint)
            return null;
        if (string.IsNullOrWhiteSpace(c.VCardUid))
        {
            var r = store.ApplyFromSync(c.Id, c with { VCardUid = "urn:uuid:" + Guid.NewGuid() }, expectedFingerprint);
            if (r.Outcome != SyncApplyOutcome.Saved)
                return null;
            c = r.Contact!;
        }
        return new DavExport(VCard.Write(c), ToItem(c), CardDavSync.FileName(c));
    }

    private static DavLocalItem ToItem(Contact c) =>
        new(c.Id, ContactStore.Fingerprint(c), c.Updated, ContactStore.DuplicateKey(c));
}
