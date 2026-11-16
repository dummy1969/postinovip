import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import '../models/orphan_cache.dart';
import 'account_config.dart';
import 'account_setup_page.dart';

/// Elenco degli account e operazioni sugli account, così come li conosce l'app.
class AccountsEditing {
  const AccountsEditing({
    required this.accounts,
    required this.coreAddress,
    required this.save,
    this.updateRefreshToken,
  });

  /// Account salvati nel portachiavi, in ordine (il primo è quello predefinito).
  final List<AccountConfig> accounts;

  /// Indirizzo del primo account secondo il core: con l'elenco vuoto, in sviluppo, viene dagli user-secrets.
  final String coreAddress;

  /// Salva l'elenco e riavvia il core (che legge gli account solo all'avvio): l'app viene ricreata.
  final Future<void> Function(List<AccountConfig> accounts) save;

  /// OAuth2: nuovo token di rinnovo dal core, salvato nel portachiavi senza riavviare il core.
  final Future<void> Function(String account, String refreshToken)? updateRefreshToken;
}

/// Gestione degli account: aggiungi, modifica, rimuovi, ricostruisci la copia locale; dati locali
/// degli account rimossi. Finestra sopra l'app come Firme (scelta 1a del 10/11/2026): aggiungi, modifica e rimuovi
/// restano in sospeso e valgono tutti insieme con «OK» (un solo riavvio del core), «Annulla» li scarta;
/// «Ricostruisci cache» ed «Elimina dati locali» sono comandi immediati, con la loro conferma.
/// "Rimuovi" toglie l'account solo dall'app: sul server non viene mai modificato nulla, e i dati
/// scaricati restano sul computer finché l'utente non li elimina in "Dati di account rimossi".
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.api, required this.editing});

  /// Verifica della connessione, ricostruzione della cache, dati degli account rimossi.
  final ApiClient api;
  final AccountsEditing editing;

  @override
  State<AccountsPage> createState() => _AccountsPageState();

  /// Apre la finestra Account sopra l'app (o sopra le Opzioni).
  static Future<void> show(BuildContext context, {required ApiClient api, required AccountsEditing editing}) =>
      showDialog<void>(context: context, builder: (_) => AccountsPage(api: api, editing: editing));

  /// Modifica di un account fuori dalla finestra Account, salvata subito; [signInAgain]: «Accedi di nuovo» dalla
  /// striscia «Accesso scaduto» (2a), l'accesso parte da solo. Il salvataggio riavvia il core con il token nuovo.
  static Future<void> editAccount(
    BuildContext context, {
    required ApiClient api,
    required AccountsEditing editing,
    required AccountConfig account,
    bool signInAgain = false,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AccountSetupPage(
      api: api,
      dialog: true,
      initial: account,
      signInAgain: signInAgain,
      otherAccounts: [
        for (final a in editing.accounts)
          if (a.id != account.id) a,
      ],
      onSave: (updated) => editing.save([for (final a in editing.accounts) a.id == account.id ? updated : a]),
    ),
  );
}

class _AccountsPageState extends State<AccountsPage> {
  /// Elenco con le modifiche in sospeso: diventa quello vero solo con «OK».
  late List<AccountConfig> _accounts = [...widget.editing.accounts];

  /// Account già salvati (nel core): solo questi si possono ricostruire.
  late final Set<String> _saved = {for (final a in widget.editing.accounts) a.id};

  bool _saving = false;
  String? _saveError;

  bool get _changed {
    final before = widget.editing.accounts;
    if (before.length != _accounts.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (!identical(before[i], _accounts[i])) return true;
    }
    return false;
  }

  /// Dati locali degli account rimossi; null mentre si caricano.
  List<OrphanCache>? _orphans;
  String? _orphansError;

  @override
  void initState() {
    super.initState();
    _loadOrphans();
  }

  Future<void> _loadOrphans() async {
    List<OrphanCache> orphans = const [];
    String? error;
    try {
      orphans = await widget.api.getCacheOrphans();
    } on ApiException catch (e) {
      error = e.statusCode == 501 ? null : e.toString(); // 501: cache disattivata, niente da mostrare
    }
    if (!mounted) return;
    setState(() {
      _orphans = orphans;
      _orphansError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final screen = MediaQuery.sizeOf(context);
    final list = ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              if (_accounts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.noAccountsSaved(widget.editing.coreAddress.isEmpty ? '' : ' (${widget.editing.coreAddress})'),
                    ),
                  ),
                ),
              for (final a in _accounts)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(a.displayName.characters.first.toUpperCase())),
                    title: Text(a.displayName),
                    subtitle: Text(
                      '${a.name.trim().isEmpty ? '' : '${a.email} · '}${a.type.label} ${a.imapHost}'
                      '${a.usesOAuth ? ' · ${l.accountSignedInWith(a.oauthProvider == 'microsoft' ? 'Microsoft' : a.oauthProvider!)}' : ''}\n'
                      '${a.isPop3 ? _pop3Summary(l, a) : l.accountDownloadedMail(AccountConfig.bodyMonthsLabel(l, a.bodyMonths).toLowerCase())}'
                      '${a.cardDavEnabled ? ' · ${l.accountContactsSynced}' : ''}'
                      '${a.calDavEnabled ? ' · ${l.accountCalendarSynced}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.edit,
                          icon: const Icon(Icons.edit),
                          onPressed: () => _edit(context, a),
                        ),
                        // POP3 (5a): non c'è un server da cui ricostruire, le mail sono solo sul computer.
                        if (!a.isPop3 && _saved.contains(a.id))
                          IconButton(
                            tooltip: l.rebuildCache,
                            icon: const Icon(Icons.cached),
                            onPressed: () => _rebuild(context, a),
                          ),
                        IconButton(
                          tooltip: l.removeFromApp,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(context, a),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.addAccount),
                  onPressed: () => _add(context),
                ),
              ),
              ..._orphansSection(theme, l),
            ],
          );
    return Dialog(
      key: const Key('accounts-dialog'),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: (screen.width - 48).clamp(280.0, 720.0),
        height: (screen.height - 48).clamp(300.0, 640.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(l.accountsTitle, style: theme.textTheme.titleLarge),
            ),
            Expanded(child: list),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _saveError ?? (_changed ? l.pendingChangesOk : ''),
                      key: const Key('accounts-pending'),
                      style: theme.textTheme.bodySmall?.copyWith(color: _saveError == null ? null : theme.colorScheme.error),
                    ),
                  ),
                  TextButton(
                    key: const Key('accounts-cancel'),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('accounts-ok'),
                    onPressed: _saving ? null : _ok,
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «OK»: con modifiche le salva tutte insieme e riavvia il core (l'app viene ricreata, finestre comprese).
  Future<void> _ok() async {
    if (!_changed) {
      Navigator.pop(context);
      return;
    }
    final l = context.l10n;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.editing.save(_accounts);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      // Es. portachiavi bloccato: l'elenco salvato resta com'era, le modifiche restano qui.
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = l.accountsNotSaved('$e');
        });
      }
    }
  }

  static String _pop3Summary(AppLocalizations l, AccountConfig a) {
    final copy = !a.leaveOnServer
        ? l.pop3RemovedAfterDownload
        : a.removeAfter
        ? l.pop3CopyForDays(a.removeAfterDays)
        : l.pop3CopyLeft;
    return l.pop3Summary(copy, a.checkMinutes);
  }

  /// "Dati di account rimossi": visibile solo se ce ne sono (o se non si è riusciti a leggerli).
  List<Widget> _orphansSection(ThemeData theme, AppLocalizations l) {
    final orphans = _orphans ?? const <OrphanCache>[];
    if (orphans.isEmpty && _orphansError == null) return const [];
    return [
      const SizedBox(height: 32),
      Text(l.removedAccountsData, style: theme.textTheme.titleSmall!.copyWith(fontSize: 16)),
      const SizedBox(height: 4),
      Text(
        l.removedAccountsDataInfo,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (_orphansError != null) Text(_orphansError!, style: TextStyle(color: theme.colorScheme.error)),
      for (final o in orphans)
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(o.label),
            subtitle: Text(
              [
                formatSize(o.sizeBytes),
                if (o.localOnly) l.orphanPop3Only,
                // C2: i contatti sono solo su questo computer, come le mail POP3.
                if (o.contacts > 0) l.orphanContacts(o.contacts),
              ].join(' · '),
            ),
            trailing: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.delete_forever),
              label: Text(l.deleteLocalData),
              onPressed: () => _deleteOrphan(o),
            ),
          ),
        ),
    ];
  }

  /// «Aggiungi account»: l'account nuovo resta in sospeso fino a «OK».
  Future<void> _add(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AccountSetupPage(
      api: widget.api,
      dialog: true,
      otherAccounts: _accounts,
      onSave: (added) async => setState(() => _accounts = [..._accounts, added]),
    ),
  );

  /// «Modifica»: la modifica resta in sospeso fino a «OK».
  Future<void> _edit(BuildContext context, AccountConfig account) => showDialog<void>(
    context: context,
    builder: (_) => AccountSetupPage(
      api: widget.api,
      dialog: true,
      initial: account,
      otherAccounts: [
        for (final a in _accounts)
          if (a.id != account.id) a,
      ],
      onSave: (updated) async =>
          setState(() => _accounts = [for (final a in _accounts) a.id == account.id ? updated : a]),
    ),
  );

  Future<void> _rebuild(BuildContext context, AccountConfig account) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.rebuildQuestion),
        content: Text(l.rebuildContent(account.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.rebuild)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.forAccount(account.id).rebuildCache();
      messenger.showSnackBar(
        SnackBar(content: Text(l.rebuildStarted(account.displayName))),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.rebuildFailed('$e'))));
    }
  }

  Future<void> _deleteOrphan(OrphanCache orphan) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final confirmed = orphan.localOnly
        ? await _confirmLocalOnly(orphan)
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.deleteLocalDataQuestion),
              content: Text(
                l.deleteLocalDataContent(
                  orphan.label,
                  formatSize(orphan.sizeBytes),
                  orphan.contacts > 0 ? '${l.deleteLocalDataContacts(orphan.contacts)}\n\n' : '',
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.delete),
                ),
              ],
            ),
          );
    if (confirmed != true) return;
    try {
      await widget.api.deleteCacheOrphan(orphan.id);
      messenger.showSnackBar(SnackBar(content: Text(l.localDataDeleted(orphan.label))));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.localDataNotDeleted('$e'))));
    }
    await _loadOrphans();
  }

  /// Dati di un account POP3 (5a): le mail esistono solo qui. Per eliminarle si scrive l'indirizzo (o l'id).
  Future<bool?> _confirmLocalOnly(OrphanCache orphan) => showDialog<bool>(
    context: context,
    builder: (_) => _TypeToConfirmDialog(orphan: orphan),
  );

  /// «Rimuovi dall'app»: dopo la conferma l'account esce dall'elenco; diventa vero con «OK».
  Future<void> _remove(BuildContext context, AccountConfig account) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeAccountQuestion),
        content: Text(
          l.removeAccountContent(
            account.displayName,
            account.email,
            account.isPop3 ? l.removeAccountPop3Note : l.removeAccountImapNote,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _accounts = [
      for (final a in _accounts)
        if (a.id != account.id) a,
    ]);
  }
}

/// "Eliminare per sempre le mail?": "Elimina per sempre" si attiva solo dopo aver scritto l'indirizzo.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({required this.orphan});

  final OrphanCache orphan;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _typed = TextEditingController();

  String get _expected => widget.orphan.address ?? widget.orphan.id;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orphan = widget.orphan;
    final l = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: error),
      title: Text(l.deleteForeverQuestion),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.deleteForeverContent(orphan.label, formatSize(orphan.sizeBytes), _expected)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('confirm-address'),
              controller: _typed,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: _typed.text.trim().toLowerCase() == _expected.toLowerCase()
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(l.deleteForever),
        ),
      ],
    );
  }
}
