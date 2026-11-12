import 'account_info.dart';
import 'mail_folder.dart';

/// Cartella nei Preferiti (in cima al riquadro cartelle, come Outlook): account + nome completo.
/// I Preferiti valgono solo su questo computer (scelta 3.4-1a): IMAP non ha un posto standard.
class FavoriteFolder {
  const FavoriteFolder(this.account, this.folder);

  final String account;
  final String folder;

  bool isFor(String account, String folder) => this.account == account && this.folder == folder;

  Map<String, dynamic> toJson() => {'account': account, 'folder': folder};

  static FavoriteFolder? fromJson(Object? json) {
    if (json case {'account': final String account, 'folder': final String folder}) {
      return FavoriteFolder(account, folder);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is FavoriteFolder && other.account == account && other.folder == folder;

  @override
  int get hashCode => Object.hash(account, folder);

  /// Ruoli dei Preferiti iniziali, nell'ordine di Outlook.
  static const defaultRoles = ['inbox', 'sent', 'trash'];

  /// Preferiti finché l'utente non li cambia: Posta in arrivo, Posta inviata e Posta eliminata del
  /// primo account (scelta 3.4-1a). Vuoto se le sue cartelle non sono ancora caricate.
  static List<FavoriteFolder> defaults(List<AccountInfo> accounts, Map<String, List<MailFolder>> foldersByAccount) {
    final account = accounts.firstOrNull;
    final folders = account == null ? null : foldersByAccount[account.id];
    if (account == null || folders == null) return const [];
    return [
      for (final role in defaultRoles)
        if (folders.where((f) => f.role == role).firstOrNull case final folder?)
          FavoriteFolder(account.id, folder.fullName),
    ];
  }
}
