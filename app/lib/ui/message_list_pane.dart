import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../account/accounts_page.dart' show AccountsEditing, AccountsPage;
import '../api/api_client.dart';
import '../models/mail_folder.dart';
import '../models/message_header.dart';
import '../models/message_tags.dart';
import '../models/search_result.dart';
import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'importance_icon.dart';
import 'home_page.dart' show MainFocus, MessageOpener;
import 'auto_reply_dialog.dart';
import 'categories.dart';
import 'conversation_view.dart';
import 'drag_drop.dart';
import 'error_view.dart';
import 'follow_up.dart';
import 'message_context_menu.dart';
import 'outbox_view.dart';
import 'tag_menus.dart';
import 'theme.dart';
import 'format.dart';

/// Pannello centrale: casella di ricerca e, sotto, le intestazioni della cartella selezionata
/// (dalla più recente) oppure i risultati della ricerca.
class MessageListPane extends StatelessWidget {
  const MessageListPane({super.key});

  /// Chiavi delle due liste (per i test).
  static const messageListKey = ValueKey('message-list');
  static const searchResultsKey = ValueKey('search-results');

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);

    if (model.selectedFolder == null) {
      return const Center(child: Text('Nessuna cartella selezionata'));
    }
    if (model.showingOutbox) return const OutboxView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!model.isOnline(model.selectedAccount)) const _OfflineStrip(),
        if (model.needsLogin(model.selectedAccount)) const _LoginExpiredStrip(),
        if (model.autoReplyAccounts.any((a) => a.id == model.selectedAccount)) const _AutoReplyStrip(),
        if (model.searchActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _searchTitle(model),
              style: theme.textTheme.titleSmall!.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const _ViewBar(),
        const Divider(height: 1),
        // Lista larga (riquadro di lettura in basso o disattivato, scelta 3.9-2a): colonne come Outlook.
        if (!model.searchActive && context.watch<AppSettings>().readingPane != ReadingPanePosition.right)
          _ColumnHeader(extraLeft: model.conversationView ? _toggleWidth - 6 : 0),
        Expanded(
          child: _KeyboardScroll(
            model: model,
            child: model.searchActive
                ? _searchBody(model)
                : (model.conversationView ? _conversationBody(model) : _folderBody(model)),
          ),
        ),
      ],
    );
  }

  static String _searchTitle(MailboxModel model) {
    final where = switch (model.searchScope) {
      SearchScope.folder => 'in ${model.selectedFolder}',
      SearchScope.account =>
        model.multipleAccounts && model.currentAccount != null
            ? 'in tutte le cartelle di ${model.currentAccount!.name}'
            : 'in tutte le cartelle',
      SearchScope.allAccounts => model.multipleAccounts ? 'in tutti gli account' : 'in tutte le cartelle',
    };
    if (model.searching && model.searchResults.isEmpty) return 'Ricerca $where…';
    return '${model.searchTotal} ${model.searchTotal == 1 ? 'risultato' : 'risultati'} $where';
  }

  /// Lista vuota: caricamento, errore o cartella senza mail (anche in vista conversazioni).
  static Widget? _emptyBody(MailboxModel model) {
    if (model.messages.isNotEmpty) return null;
    if (model.loadingMessages) return const Center(child: CircularProgressIndicator());
    if (model.messagesError != null) return ErrorView(message: model.messagesError!, onRetry: model.loadMore);
    return Center(
      child: Text(model.listFilter == ListFilter.unread ? 'Nessun messaggio da leggere' : 'Cartella vuota'),
    );
  }

  Widget _folderBody(MailboxModel model) {
    if (_emptyBody(model) case final empty?) return empty;

    // Righe: intestazione di gruppo (Oggi, Ieri, …) e messaggi, come in Outlook classico.
    final now = DateTime.now();
    final rows = <_Row>[];
    String? group;
    for (final (i, m) in model.messages.indexed) {
      final label = _groupLabel(model.sort, m, now);
      if (label != group) {
        group = label;
        rows.add(_Row.group(label, i));
      }
      if (!model.collapsedGroups.contains(label)) rows.add(_Row.message(i));
    }
    final footer = model.hasMore || model.messagesError != null;
    final account = model.selectedAccount;
    final folder = model.selectedFolder;
    final online = model.isOnline(account);
    return MessageContextMenu(
      builder: (context, openMenu) => ListView.builder(
        key: messageListKey,
        primary: true, // lo scorrimento di _KeyboardScroll (Home, Fine, Pag)
        itemCount: rows.length + (footer ? 1 : 0),
        itemBuilder: (context, i) {
          // Scorrimento continuo sull'indice del messaggio (un'intestazione conta come il primo del suo gruppo).
          final index = i < rows.length ? rows[i].message : model.messages.length;
          _loadAhead(
            index,
            model.messages.length,
            hasMore: model.hasMore,
            busy: model.loadingMessages,
            error: model.messagesError,
            load: model.loadMore,
          );
          if (i == rows.length) return _footer(error: model.messagesError, onRetry: model.loadMore);
          final row = rows[i];
          if (row.group case final label?) {
            return _GroupHeader(
              label: label,
              collapsed: model.collapsedGroups.contains(label),
              onTap: () => model.toggleGroup(label),
            );
          }
          final m = model.messages[row.message];
          return _mailRow(context, model, openMenu, MessageRef(account!, folder!, m.uid), m, online: online);
        },
      ),
    );
  }

  /// Gruppo della riga secondo l'ordinamento, come Outlook: per data (Oggi, Ieri…), per mittente, per oggetto
  /// o per fascia di dimensione.
  static String _groupLabel(ListSort sort, MessageHeader m, DateTime now) => switch (sort) {
    ListSort.date => listGroupLabel(m.listDate, now: now),
    ListSort.from => m.from.trim().isEmpty ? '(mittente sconosciuto)' : m.from,
    ListSort.subject => m.subject.trim().isEmpty ? '(nessun oggetto)' : m.subject,
    ListSort.size => sizeGroupLabel(m.size),
  };

  /// Riga di una mail (anche di una mail dentro una conversazione aperta: [indent] e, se sta in
  /// un'altra cartella, [folderLabel]).
  static Widget _mailRow(
    BuildContext context,
    MailboxModel model,
    void Function(Offset) openMenu,
    MessageRef ref,
    MessageHeader m, {
    required bool online,
    bool selected = true,
    double indent = 0,
    Widget? leading,
    String? folderLabel,
  }) {
    final tile = _MessageTile(
      m,
      selected: selected && model.selection.contains(ref),
      isCursor: model.cursorConversation == null && model.cursor == ref,
      indent: indent,
      leading: leading,
      folderLabel: folderLabel,
      onTap: () => _click(context, model, ref),
      onSecondaryTap: (position) {
        model.selectForContextMenu(ref);
        openMenu(position);
      },
      // Senza connessione la bandierina si vede ma non si cambia (come gli altri comandi).
      onFlag: online
          ? () => TagMenus.toggleFlag(
              context,
              TagTarget(account: ref.account, folder: ref.folder, uid: m.uid, tags: m.tags),
            )
          : null,
    );
    // Trascinamento (3.5c): senza connessione nessuna cartella accetterebbe le mail.
    return online ? _draggable(model, ref, m.subject, tile) : tile;
  }

  /// Larghezza del triangolo delle conversazioni (le righe senza triangolo restano allineate).
  static const _toggleWidth = 18.0;

  /// Vista per conversazioni (3.6, come Outlook classico): una riga per conversazione con la mail più
  /// recente della cartella, il numero di mail, grassetto se ce n'è una da leggere; il triangolo
  /// mostra sotto, rientrate, tutte le sue mail (anche di altre cartelle, con il nome della cartella).
  Widget _conversationBody(MailboxModel model) {
    if (_emptyBody(model) case final empty?) return empty;
    final account = model.selectedAccount!;
    final folder = model.selectedFolder!;
    final names = {for (final f in model.foldersByAccount[account] ?? const <MailFolder>[]) f.fullName: f.displayName};
    final now = DateTime.now();
    final rows = <_Row>[];
    String? group;
    for (final (i, c) in model.conversations.indexed) {
      final head = c.headIn(folder);
      if (head == null) continue;
      final label = listGroupLabel(head.listDate, now: now);
      if (label != group) {
        group = label;
        rows.add(_Row.group(label, i));
      }
      if (model.collapsedGroups.contains(label)) continue;
      rows.add(_Row.message(i));
      if (c.count > 1 && model.expandedConversations.contains(c.id)) {
        for (var j = 0; j < c.count; j++) {
          rows.add(_Row.member(i, j));
        }
      }
    }
    final footer = model.hasMore || model.messagesError != null;
    final online = model.isOnline(account);
    return MessageContextMenu(
      builder: (context, openMenu) => ListView.builder(
        key: messageListKey,
        primary: true, // lo scorrimento di _KeyboardScroll (Home, Fine, Pag)
        itemCount: rows.length + (footer ? 1 : 0),
        itemBuilder: (context, i) {
          final index = i < rows.length ? rows[i].message : model.conversations.length;
          _loadAhead(
            index,
            model.conversations.length,
            hasMore: model.hasMore,
            busy: model.loadingMessages,
            error: model.messagesError,
            load: model.loadMore,
          );
          if (i == rows.length) return _footer(error: model.messagesError, onRetry: model.loadMore);
          final row = rows[i];
          if (row.group case final label?) {
            return _GroupHeader(
              label: label,
              collapsed: model.collapsedGroups.contains(label),
              onTap: () => model.toggleGroup(label),
            );
          }
          final c = model.conversations[row.message];
          final openHere = model.selectedConversation == c.id;
          if (row.member case final j?) {
            final m = c.messages[j];
            return _mailRow(
              context,
              model,
              openMenu,
              MessageRef(account, m.folder, m.message.uid),
              m.message,
              online: online,
              selected: !openHere, // con la conversazione selezionata è evidenziata solo la sua riga
              indent: _toggleWidth + 14,
              folderLabel: m.folder == folder ? null : names[m.folder] ?? m.folder,
            );
          }
          final head = c.headIn(folder)!;
          final headRef = MessageRef(account, folder, head.uid);
          if (c.count == 1) {
            return _mailRow(
              context,
              model,
              openMenu,
              headRef,
              head,
              online: online,
              leading: const SizedBox(width: _toggleWidth),
            );
          }
          final refs = model.conversationRefs(c);
          final expanded = model.expandedConversations.contains(c.id);
          final tile = _MessageTile(
            head,
            key: ValueKey('conversation:${c.id}'),
            selected:
                openHere || (model.selectedConversation == null && refs.every(model.selection.contains) && !expanded),
            isCursor: model.cursorConversation == c.id,
            unread: c.hasUnread,
            hasAttachments: c.hasAttachments,
            count: c.count,
            leading: _ConversationToggle(expanded: expanded, onTap: () => model.toggleConversation(c.id)),
            onTap: () {
              _focusMail(context);
              if (_isDoubleClick(model, c.id)) WidgetsBinding.instance.addPostFrameCallback((_) => _open(context));
              final keys = HardwareKeyboard.instance;
              model.clickConversation(
                c,
                toggle: keys.isControlPressed || keys.isMetaPressed,
                range: keys.isShiftPressed,
              );
            },
            onSecondaryTap: (position) {
              model.selectConversationForContextMenu(c);
              openMenu(position);
            },
            onFlag: online
                ? () => TagMenus.toggleFlag(
                    context,
                    TagTarget(account: account, folder: folder, uid: head.uid, tags: head.tags),
                  )
                : null,
          );
          if (!online) return tile;
          return MessageDragSource(
            row: headRef,
            refs: refs.every(model.selection.contains) ? model.selection : refs,
            label: head.subject,
            onSelect: () => model.clickConversation(c),
            child: tile,
          );
        },
      ),
    );
  }

  Widget _searchBody(MailboxModel model) {
    final results = model.searchResults;
    if (results.isEmpty && model.searching) return const Center(child: CircularProgressIndicator());
    if (results.isEmpty && model.searchError != null) {
      return ErrorView(message: model.searchError!, onRetry: model.search);
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nessun risultato nella cache locale'),
            const SizedBox(height: 8),
            _ServerSearchFooter(model),
          ],
        ),
      );
    }

    // Cartella (e account) di ogni risultato solo se la ricerca non è limitata alla cartella aperta.
    final showWhere = model.searchScope != SearchScope.folder;
    final showAccount = model.searchScope == SearchScope.allAccounts && model.multipleAccounts;
    final names = {for (final a in model.accounts) a.id: a.name};
    final more = model.searchHasMore || model.searchError != null;
    return ListView.separated(
      key: searchResultsKey,
      primary: true, // lo scorrimento di _KeyboardScroll (Home, Fine, Pag)
      // In fondo: il caricamento dei risultati locali successivi (se ce ne sono) e la ricerca sul server.
      itemCount: results.length + (more ? 2 : 1),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        _loadAhead(
          i,
          results.length,
          hasMore: model.searchHasMore,
          busy: model.searching,
          error: model.searchError,
          load: model.loadMoreResults,
        );
        if (i == results.length && more) return _footer(error: model.searchError, onRetry: model.loadMoreResults);
        if (i >= results.length) return _ServerSearchFooter(model);
        final r = results[i];
        final ref = MessageRef(r.account, r.hit.folder, r.hit.uid);
        final tile = _SearchTile(
          r.hit,
          where: showWhere ? [if (showAccount) names[r.account] ?? r.account, r.hit.folder].join(' · ') : null,
          selected: model.isSelected(r.account, r.hit.folder, r.hit.uid),
          onTap: () => _click(context, model, ref),
        );
        return model.isOnline(r.account) ? _draggable(model, ref, r.hit.subject, tile) : tile;
      },
    );
  }

  /// Riga trascinabile: parte la selezione se la riga ne fa parte, altrimenti solo questa (come Outlook).
  static Widget _draggable(MailboxModel model, MessageRef ref, String subject, Widget tile) => MessageDragSource(
    row: ref,
    refs: model.selection.contains(ref) ? model.selection : {ref},
    label: subject,
    child: tile,
  );

  /// Clic su una riga con i tasti premuti in quel momento: Ctrl aggiunge/toglie, Maiusc seleziona
  /// l'intervallo (scelta 3.5-1a, come Outlook).
  static void _click(BuildContext context, MailboxModel model, MessageRef ref) {
    _focusMail(context);
    if (_isDoubleClick(model, ref)) WidgetsBinding.instance.addPostFrameCallback((_) => _open(context));
    final keys = HardwareKeyboard.instance;
    model.clickMessage(ref, toggle: keys.isControlPressed || keys.isMetaPressed, range: keys.isShiftPressed);
  }

  // Doppio clic misurato a mano (come nella finestra "Sposta elementi"): onDoubleTap ritarderebbe ogni clic semplice.
  // Si ricorda anche il modello: nei test ogni app ha il suo, e un clic del test precedente sulla stessa riga (stesso
  // MessageRef) non deve valere come primo clic. Su un Mac M1 tra due test passano meno di 300 ms reali (macOS M1).
  static Object? _lastClicked;
  static MailboxModel? _lastModel;
  static DateTime _lastClickAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Secondo clic sulla stessa riga entro [kDoubleTapTimeout]: la mail si apre nella sua finestra (MessageWindow),
  /// come Outlook.
  static bool _isDoubleClick(MailboxModel model, Object row) {
    final now = DateTime.now();
    final double =
        identical(model, _lastModel) && row == _lastClicked && now.difference(_lastClickAt) <= kDoubleTapTimeout;
    _lastClicked = double ? null : row;
    _lastModel = model;
    _lastClickAt = now;
    return double;
  }

  static void _open(BuildContext context) {
    if (!context.mounted) return;
    try {
      context.read<MessageOpener?>()?.open();
    } on ProviderNotFoundException {
      // lista mostrata da sola (test)
    }
  }

  /// La tastiera torna alla posta (anche se il fuoco era nella casella di ricerca): Canc, frecce...
  static void _focusMail(BuildContext context) {
    try {
      context.read<MainFocus>().node.requestFocus();
    } on ProviderNotFoundException {
      // lista mostrata da sola (test)
    }
  }

  /// Righe dalla fine a cui si comincia a caricare la pagina successiva: di solito arriva prima che
  /// l'utente tocchi il fondo.
  static const loadAheadRows = 15;

  /// Scorrimento continuo: quando viene costruita una delle ultime [loadAheadRows] righe (cioè sta per
  /// comparire) si chiede la pagina successiva. Dopo un errore niente nuovi tentativi da soli: "Riprova".
  /// Il caricamento parte dopo il frame (non si può notificare il modello durante la costruzione); il
  /// modello ignora le richieste mentre una pagina è già in arrivo.
  static void _loadAhead(
    int index,
    int length, {
    required bool hasMore,
    required bool busy,
    required String? error,
    required VoidCallback load,
  }) {
    if (index < length - loadAheadRows || !hasMore || busy || error != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Widget _footer({required String? error, required VoidCallback onRetry}) {
    if (error != null) {
      return ListTile(
        title: Text(error),
        trailing: TextButton(onPressed: onRetry, child: const Text('Riprova')),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Striscia sottile sopra la lista quando il server dell'account aperto non risponde (scelta
/// 3.1-3a); "Disconnesso" compare anche nella barra di stato.
class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onErrorContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(FluentIcons.cloud_off_16_regular, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Non connesso: mostro la copia sul computer. Spostare, eliminare, segnare come letto e '
              'inviare tornano disponibili da soli quando il server risponde.',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// OAuth2 (2a, 05/11/2026): il fornitore ha rifiutato il token di rinnovo dell'account aperto (con Gmail in prova
/// succede ogni 7 giorni). «Accedi di nuovo» apre la modifica dell'account con l'accesso già avviato; salvando, il core
/// riparte con il token nuovo.
class _LoginExpiredStrip extends StatelessWidget {
  const _LoginExpiredStrip();

  static String providerName(String? id) => switch (id) {
    'google' => 'Google',
    'microsoft' => 'Microsoft',
    null || '' => 'il fornitore',
    _ => id,
  };

  @override
  Widget build(BuildContext context) {
    final model = context.read<MailboxModel>();
    final editing = context.read<AccountsEditing?>();
    final theme = Theme.of(context);
    final color = theme.colorScheme.onErrorContainer;
    final config = editing?.accounts.where((a) => a.id == model.selectedAccount).firstOrNull;
    final name = providerName(config?.oauthProvider);
    return Container(
      key: const Key('login-expired-strip'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(FluentIcons.person_warning_16_regular, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Accesso a $name scaduto: questo account non riceve né invia posta finché non accedi di nuovo.',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (editing != null && config != null)
            TextButton(
              key: const Key('login-expired-signin'),
              onPressed: () => AccountsPage.editAccount(
                context,
                api: context.read<ApiClient>(),
                editing: editing,
                account: config,
                signInAgain: true,
              ),
              style: TextButton.styleFrom(foregroundColor: color),
              child: const Text('Accedi di nuovo'),
            ),
        ],
      ),
    );
  }
}

/// Barra gialla come Outlook (scelta 5a): le risposte automatiche dell'account aperto sono attive.
class _AutoReplyStrip extends StatelessWidget {
  const _AutoReplyStrip();

  @override
  Widget build(BuildContext context) {
    final model = context.read<MailboxModel>();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF4D3F00) : const Color(0xFFFFF4CE);
    final foreground = dark ? const Color(0xFFFFE8A3) : const Color(0xFF4D3F00);
    final account = model.selectedAccount;
    return Container(
      key: const Key('autoreply-strip'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(FluentIcons.mail_arrow_up_16_regular, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Le risposte automatiche sono attive per questo account.',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          TextButton(
            onPressed: account == null ? null : () => AutoReplyDialog.show(context, account: account),
            style: TextButton.styleFrom(foregroundColor: foreground),
            child: const Text('Modifica…'),
          ),
          TextButton(
            key: const Key('autoreply-strip-off'),
            onPressed: account == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await model.saveAutoReply(account, model.autoReplies[account]!.copyWith(enabled: false));
                      messenger.showSnackBar(const SnackBar(content: Text('Risposte automatiche disattivate.')));
                    } on ApiException catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Non disattivate: $e')));
                    }
                  },
            style: TextButton.styleFrom(foregroundColor: foreground),
            child: const Text('Disattiva'),
          ),
        ],
      ),
    );
  }
}

/// In fondo ai risultati: "Cerca anche sul server" e poi il suo esito.
class _ServerSearchFooter extends StatelessWidget {
  const _ServerSearchFooter(this.model);

  final MailboxModel model;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    if (!model.canSearchServer) return const SizedBox.shrink(); // solo account POP3: niente da cercare sul server
    if (model.serverSearching) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Ricerca sul server…'),
          ],
        ),
      );
    }
    if (model.serverSearchError != null) {
      return ListTile(
        title: Text('Ricerca sul server non riuscita: ${model.serverSearchError}'),
        trailing: TextButton(onPressed: model.searchServer, child: const Text('Riprova')),
      );
    }
    if (model.serverSearchDone) {
      final added = model.serverAdded;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          (added == 0
                  ? 'Il server non ha trovato altre mail.'
                  : 'Il server ha trovato $added mail in più (con l\'icona della nuvola).') +
              (model.serverTruncated ? ' Mostrate le ${MailboxModel.serverSearchLimit} più recenti.' : ''),
          textAlign: TextAlign.center,
          style: small,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: model.searchServer,
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Cerca anche sul server'),
          ),
          const SizedBox(height: 4),
          Text(
            'Per le mail più vecchie del limite della cache e per Posta eliminata e Indesiderata,\n'
            'di cui qui sono state cercate solo le intestazioni.',
            textAlign: TextAlign.center,
            style: small,
          ),
        ],
      ),
    );
  }
}

/// Una riga della lista: intestazione di gruppo oppure messaggio. [message] è l'indice in
/// [MailboxModel.messages] (per un'intestazione, quello del primo messaggio del gruppo); in vista
/// conversazioni è l'indice in [MailboxModel.conversations] e [member] quello della mail aperta sotto.
/// Scorrimento della lista mostrata per i salti della tastiera (Home, Fine, Pag↑, Pag↓): le liste lo prendono come
/// PrimaryScrollController. La ListView costruisce solo le righe vicine a quelle visibili: per una riga lontana la
/// lista prima scorre, poi la riga costruita si mostra da sola ([MailboxModel.revealCursor]).
class _KeyboardScroll extends StatefulWidget {
  const _KeyboardScroll({required this.model, required this.child});

  final MailboxModel model;
  final Widget child;

  @override
  State<_KeyboardScroll> createState() => _KeyboardScrollState();
}

class _KeyboardScrollState extends State<_KeyboardScroll> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _attach(widget.model);
  }

  @override
  void didUpdateWidget(_KeyboardScroll old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      _detach(old.model);
      _attach(widget.model);
    }
  }

  @override
  void dispose() {
    _detach(widget.model);
    _scroll.dispose();
    super.dispose();
  }

  void _attach(MailboxModel model) {
    model.onListJump = _jump;
    model.pageRows = _pageRows;
  }

  void _detach(MailboxModel model) {
    if (model.onListJump == _jump) model.onListJump = null;
    if (model.pageRows == _pageRows) model.pageRows = null;
  }

  void _jump(ListJump jump) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    switch (jump) {
      case ListJump.start:
        _scroll.jumpTo(0);
      case ListJump.end:
        _toEnd(6);
      case ListJump.pageDown:
        _scroll.jumpTo((p.pixels + p.viewportDimension).clamp(0.0, p.maxScrollExtent));
      case ListJump.pageUp:
        _scroll.jumpTo((p.pixels - p.viewportDimension).clamp(0.0, p.maxScrollExtent));
    }
  }

  /// In fondo: l'altezza della lista è stimata sulle righe costruite, quindi si ripete finché non è davvero in fondo.
  void _toEnd(int tries) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels < p.maxScrollExtent) {
        _scroll.jumpTo(p.maxScrollExtent);
        if (tries > 1) _toEnd(tries - 1);
      }
    });
  }

  /// Righe in una pagina: altezza visibile diviso altezza media stimata di una riga, meno una (la riga in fondo
  /// resta visibile dopo il salto).
  int _pageRows() {
    if (!_scroll.hasClients) return 10;
    final p = _scroll.position;
    final rows = widget.model.navRowCount;
    if (rows == 0) return 10;
    final average = (p.maxScrollExtent + p.viewportDimension) / rows;
    if (average <= 0) return 10;
    return ((p.viewportDimension / average).floor() - 1).clamp(1, 1000);
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(controller: _scroll, child: widget.child);
}

class _Row {
  const _Row.group(String this.group, this.message) : member = null;
  const _Row.message(this.message) : group = null, member = null;
  const _Row.member(this.message, int this.member) : group = null;

  final String? group;
  final int message;
  final int? member;
}

/// Triangolo che apre o chiude una conversazione.
class _ConversationToggle extends StatelessWidget {
  const _ConversationToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: expanded ? 'Chiudi la conversazione' : 'Mostra tutte le mail della conversazione',
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: MessageListPane._toggleWidth,
        height: 20,
        child: Icon(
          expanded ? FluentIcons.chevron_down_12_regular : FluentIcons.chevron_right_12_regular,
          size: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Sopra la lista, come in Outlook classico: "Tutti | Da leggere" e l'ordine per data.
class _ViewBar extends StatelessWidget {
  const _ViewBar();

  static const _sortChoices = [
    ((ListSort.date, false), 'Per data: più recenti in cima'),
    ((ListSort.date, true), 'Per data: più vecchi in cima'),
    ((ListSort.from, true), 'Per mittente: A → Z'),
    ((ListSort.from, false), 'Per mittente: Z → A'),
    ((ListSort.subject, true), 'Per oggetto: A → Z'),
    ((ListSort.subject, false), 'Per oggetto: Z → A'),
    ((ListSort.size, false), 'Per dimensione: più grandi in cima'),
    ((ListSort.size, true), 'Per dimensione: più piccole in cima'),
  ];

  static String _sortLabel(ListSort sort) => switch (sort) {
    ListSort.date => 'Per data',
    ListSort.from => 'Per mittente',
    ListSort.subject => 'Per oggetto',
    ListSort.size => 'Per dimensione',
  };

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    // Una sola riga di separazione sotto (il Divider che segue): prima qui c'era anche un bordo, due righe (V4).
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // Lista stretta (sotto i 320 pixel): niente etichetta «Conversazioni», ordine con la sola freccia e filtri che si
      // accorciano con «…», invece di uscire dalla riga (trovato con le finestre piccole, 09/11/2026).
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 320;
          final tabs = [
            for (final (filter, label) in [(ListFilter.all, 'Tutti'), (ListFilter.unread, 'Da leggere')])
              _FilterTab(label: label, selected: model.listFilter == filter, onTap: () => model.setListFilter(filter)),
          ];
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Le due schede vicine (con spaceBetween e l'ordine che non prende tutto il suo spazio si allontanavano);
              // con la lista stretta si accorciano con «…».
              if (narrow)
                for (final t in tabs) Flexible(child: t)
              else
                Row(mainAxisSize: MainAxisSize.min, children: tabs),
              // L'etichetta prende lo spazio libero e, con la lista stretta, si accorcia invece di uscire.
              if (!narrow)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: model.conversationView ? const _ConversationBadge() : null,
                  ),
                ),
              Flexible(
                flex: narrow ? 1 : 2,
                child: PopupMenuButton<(ListSort, bool)>(
                  tooltip: 'Ordina per',
                  initialValue: (model.conversationView ? ListSort.date : model.sort, model.oldestFirst),
                  onSelected: (choice) => model.setSort(choice.$1, ascending: choice.$2),
                  itemBuilder: (context) => [
                    for (final (value, label) in _sortChoices)
                      // In vista conversazioni solo per data, come Outlook.
                      if (!model.conversationView || value.$1 == ListSort.date)
                        PopupMenuItem(value: value, child: Text(label)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!narrow) ...[
                          Flexible(
                            child: Text(
                              _sortLabel(model.conversationView ? ListSort.date : model.sort),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Icon(
                          model.oldestFirst ? FluentIcons.arrow_up_16_regular : FluentIcons.arrow_down_16_regular,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sopra la lista, accanto all'ordine: la vista per conversazioni è attiva (clic: si può spegnere).
class _ConversationBadge extends StatelessWidget {
  const _ConversationBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Vista per conversazioni attiva in questa cartella: clic per cambiarla',
      child: InkWell(
        onTap: () => ConversationViewCommand.toggle(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.chat_multiple_16_filled, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Conversazioni',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Tutti» o «Da leggere» sopra la lista, come le schede della barra multifunzione (tappa «Aspetto», V4): quella
/// scelta in blu e grassetto con una barretta blu arrotondata sotto, larga quanto il nome.
class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(OfficeTheme.radius)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // La barretta è larga quanto il testo: lo Stack prende la misura del testo (anche accorciato con «…»).
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontSize: 13,
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Intestazione di un gruppo per data, con il triangolino per chiuderlo.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.collapsed, required this.onTap});

  final String label;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? FluentIcons.chevron_right_12_regular : FluentIcons.chevron_down_12_regular,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un messaggio come in Outlook classico: barra blu a sinistra se da leggere, mittente (graffetta,
/// categorie e bandierina), oggetto e data (in blu se da leggere), una riga di anteprima.
class _MessageTile extends StatefulWidget {
  const _MessageTile(
    this.message, {
    super.key,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onFlag,
    this.isCursor = false,
    this.unread,
    this.hasAttachments,
    this.count,
    this.leading,
    this.indent = 0,
    this.folderLabel,
  });

  final MessageHeader message;
  final bool selected;

  /// Riga di una conversazione: da leggere e graffetta valgono per tutta la conversazione
  /// (predefiniti: quelli della mail), [count] = numero di mail.
  final bool? unread;
  final bool? hasAttachments;
  final int? count;

  /// A sinistra del testo (il triangolo delle conversazioni) e rientro delle mail di una conversazione.
  final Widget? leading;
  final double indent;

  /// Cartella della mail, se non è quella aperta (mail di una conversazione).
  final String? folderLabel;

  /// La tastiera è su questa riga (frecce): quando lo diventa, la lista scorre per mostrarla.
  final bool isCursor;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onSecondaryTap;

  /// Clic sulla bandierina; null senza connessione.
  final VoidCallback? onFlag;

  @override
  State<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<_MessageTile> {
  bool _hover = false;
  double _listWidth = double.infinity;

  @override
  void initState() {
    super.initState();
    // Riga costruita solo dopo un salto della tastiera (Home, Fine, Pag): va mostrata anche lei.
    final model = context.read<MailboxModel>();
    if (widget.isCursor && model.revealCursor) {
      model.revealCursor = false;
      _reveal();
    }
  }

  void _reveal() {
    // Dopo il frame: la riga è al suo posto. Le due regole insieme scorrono il minimo indispensabile
    // (in giù se la riga è sotto, in su se è sopra, niente se è già visibile).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  @override
  void didUpdateWidget(_MessageTile old) {
    super.didUpdateWidget(old);
    if (widget.isCursor && !old.isCursor) {
      context.read<MailboxModel>().revealCursor = false;
      _reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = widget.unread ?? !message.seen;
    final muted = scheme.onSurfaceVariant;
    final preview = message.preview?.trim() ?? '';
    final tags = message.tags;
    final settings = context.watch<AppSettings>();
    // Righe di anteprima (3.9-4a) e vista a colonne con la lista larga (3.9-2a).
    final lines = settings.previewLines;
    final wide = settings.readingPane != ReadingPanePosition.right;
    final attachments = widget.hasAttachments ?? message.hasAttachments == true;
    final fromStyle = TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.bold : FontWeight.normal);
    final subjectStyle = TextStyle(
      fontSize: 13,
      color: unread ? scheme.primary : scheme.onSurface,
      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
    );
    final previewText = lines == 0 || preview.isEmpty
        ? null
        : Text(
            preview,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          );
    final extras = [
      if (widget.folderLabel case final where?)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            where,
            style: TextStyle(fontSize: 12, color: muted, fontStyle: FontStyle.italic),
          ),
        ),
      if (widget.count case final n?)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Tooltip(
            message: '$n mail nella conversazione',
            child: Text(
              '$n',
              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
            ),
          ),
        ),
    ];
    final categories = [
      for (final c in tags.categories)
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Tooltip(message: settings.categoryName(c), child: CategorySwatch(c, size: 10)),
        ),
    ];
    final flag = _FlagButton(tags: tags, hover: _hover || widget.selected, onPressed: widget.onFlag);

    // Larghezza della lista: con poco spazio la colonna Categorie non c'è (vedi MailColumns.showCategories).
    return LayoutBuilder(
      builder: (context, box) {
        _listWidth = box.maxWidth;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: widget.selected ? scheme.secondaryContainer : Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTapUp: (details) => widget.onSecondaryTap(details.globalPosition),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: unread ? scheme.primary : Colors.transparent, width: 3),
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(10 + widget.indent - (widget.leading == null ? 0 : 6), 6, 4, 6),
                child: wide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ?widget.leading,
                              SizedBox(
                                width: MailColumns.icons,
                                child: Row(
                                  children: [
                                    Icon(
                                      unread ? FluentIcons.mail_unread_16_regular : FluentIcons.mail_read_16_regular,
                                      size: 14,
                                      color: unread ? scheme.primary : muted,
                                    ),
                                    if (attachments) Icon(FluentIcons.attach_16_regular, size: 14, color: muted),
                                    ?ImportanceIcon.of(message.importance),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: MailColumns.fromFlex,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(message.from, overflow: TextOverflow.ellipsis, style: fromStyle),
                                    ),
                                    ...extras,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: MailColumns.subjectFlex,
                                child: Text(
                                  message.subject,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: subjectStyle,
                                ),
                              ),
                              SizedBox(
                                width: MailColumns.received,
                                child: Text(
                                  formatListDate(message.listDate),
                                  style: TextStyle(fontSize: 12, color: unread ? scheme.primary : muted),
                                ),
                              ),
                              SizedBox(
                                width: MailColumns.size,
                                child: Text(
                                  formatMailSize(message.size),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ),
                              if (MailColumns.showCategories(_listWidth))
                                SizedBox(
                                  width: MailColumns.categories,
                                  child: Row(children: [const SizedBox(width: 8), ...categories]),
                                ),
                              flag,
                            ],
                          ),
                          if (previewText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: MailColumns.icons, right: 30),
                              child: previewText,
                            ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ?widget.leading,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(message.from, overflow: TextOverflow.ellipsis, style: fromStyle),
                                    ),
                                    ...extras,
                                    ?ImportanceIcon.of(message.importance),
                                    if (attachments)
                                      Tooltip(
                                        message: 'Contiene allegati',
                                        child: Icon(FluentIcons.attach_16_regular, size: 14, color: muted),
                                      ),
                                    ...categories,
                                  ],
                                ),
                                // La data al massimo larga quanto la riga: con la lista strettissima si accorcia invece di
                                // uscire (finestre piccole, 09/11/2026); di solito sta tutta e l'oggetto prende il resto.
                                LayoutBuilder(
                                  builder: (context, box) => Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          message.subject,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: subjectStyle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: box.maxWidth > 8 ? box.maxWidth - 8 : 0),
                                        child: Text(
                                          formatListDate(message.listDate),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: unread ? scheme.primary : muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ?previewText,
                              ],
                            ),
                          ),
                          flag,
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bandierina a destra della riga, come in Outlook: rossa se contrassegnata, segno di spunta se
/// completata, altrimenti visibile solo passando sopra la riga.
class _FlagButton extends StatelessWidget {
  const _FlagButton({required this.tags, required this.hover, required this.onPressed});

  final MessageTags tags;
  final bool hover;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, tooltip) = tags.flagged
        ? (
            FluentIcons.flag_16_filled,
            scheme.error,
            tags.due == null
                ? 'Contrassegnato: clic per completare'
                : 'Completare entro ${formatDueDate(tags.due!)}: clic per completare',
          )
        : tags.completed
        ? (FluentIcons.checkmark_16_regular, scheme.onSurfaceVariant, 'Completato: clic per contrassegnare di nuovo')
        : (FluentIcons.flag_16_regular, hover ? scheme.onSurfaceVariant : Colors.transparent, 'Contrassegna per oggi');
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        tooltip: onPressed == null ? null : tooltip,
        onPressed: onPressed,
        // Senza connessione: stesso aspetto, nessun clic.
        icon: Icon(icon, color: color),
        disabledColor: color,
      ),
    );
  }
}

/// Un risultato: mittente e data, oggetto, estratto con le parole trovate in grassetto e, se la
/// ricerca non è limitata alla cartella aperta, dove si trova la mail.
class _SearchTile extends StatelessWidget {
  const _SearchTile(this.hit, {required this.where, required this.selected, required this.onTap});

  final SearchHit hit;
  final String? where;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = hit.seen ? FontWeight.normal : FontWeight.bold;
    final small = theme.textTheme.bodySmall;

    return ListTile(
      dense: true,
      selected: selected,
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              hit.from,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: weight),
            ),
          ),
          if (hit.fromServer) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Trovata sul server',
              child: Icon(Icons.cloud_outlined, size: 16, color: small?.color),
            ),
          ],
          const SizedBox(width: 8),
          Text(formatListDate(hit.date), style: TextStyle(fontWeight: weight)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hit.subject, overflow: TextOverflow.ellipsis, maxLines: 1),
          if (hit.snippet case final snippet? when snippet.trim().isNotEmpty)
            Text.rich(highlightedSnippet(snippet, small), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (where != null)
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 14, color: small?.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(where!, style: small, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// L'estratto del core con le parole trovate (tra U+0002 e U+0003) in grassetto; spazi e
/// a capo ridotti a uno spazio.
TextSpan highlightedSnippet(String snippet, TextStyle? style) {
  final text = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
  final spans = <TextSpan>[];
  var bold = false;
  for (final part in text.split(RegExp('[${SearchHit.highlightStart}${SearchHit.highlightEnd}]'))) {
    if (part.isNotEmpty) {
      spans.add(
        TextSpan(
          text: part,
          style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      );
    }
    bold = !bold;
  }
  return TextSpan(style: style, children: spans);
}

/// Larghezze delle colonne della lista larga (3.9-2a), condivise da intestazione e righe.
class MailColumns {
  MailColumns._();

  static const icons = 40.0;
  static const fromFlex = 3;
  static const subjectFlex = 5;
  static const received = 110.0;
  static const size = 70.0;
  static const categories = 70.0;
  static const flag = 26.0;

  /// La colonna Categorie solo se la lista è larga almeno così (con la barra dei moduli, a 640×480 non entra).
  static const categoriesMinWidth = 480.0;
  static bool showCategories(double listWidth) => listWidth >= categoriesMinWidth;
}

/// Intestazioni delle colonne: un clic ordina per quella colonna, un altro inverte (scelta 3.9-3a). In vista
/// conversazioni si ordina solo per data.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({this.extraLeft = 0});

  /// Spazio del triangolo delle conversazioni, per restare allineati alle righe.
  final double extraLeft;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, ListSort? column, {TextAlign align = TextAlign.left}) {
      final active = column != null && (model.conversationView ? ListSort.date : model.sort) == column;
      final enabled = column != null && (!model.conversationView || column == ListSort.date);
      final text = Row(
        mainAxisAlignment: align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (active)
            Icon(
              model.oldestFirst ? FluentIcons.chevron_up_12_regular : FluentIcons.chevron_down_12_regular,
              size: 12,
              color: scheme.onSurfaceVariant,
            ),
        ],
      );
      if (!enabled) return text;
      return Tooltip(
        message: 'Ordina per ${label.toLowerCase()}',
        child: InkWell(onTap: () => model.sortBy(column), child: text),
      );
    }

    return LayoutBuilder(builder: (context, box) => _header(context, cell, scheme, box.maxWidth));
  }

  Widget _header(
    BuildContext context,
    Widget Function(String, ListSort?, {TextAlign align}) cell,
    ColorScheme scheme,
    double width,
  ) {
    return Container(
      key: const ValueKey('column-header'),
      height: 26,
      padding: EdgeInsets.only(left: 13 + extraLeft, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          const SizedBox(width: MailColumns.icons),
          Expanded(flex: MailColumns.fromFlex, child: cell('Da', ListSort.from)),
          const SizedBox(width: 8),
          Expanded(flex: MailColumns.subjectFlex, child: cell('Oggetto', ListSort.subject)),
          SizedBox(width: MailColumns.received, child: cell('Ricevuto', ListSort.date)),
          SizedBox(
            width: MailColumns.size,
            child: cell('Dimensione', ListSort.size, align: TextAlign.right),
          ),
          if (MailColumns.showCategories(width))
            SizedBox(
              width: MailColumns.categories,
              child: Padding(padding: const EdgeInsets.only(left: 8), child: cell('Categorie', null)),
            ),
          const SizedBox(width: MailColumns.flag, child: Icon(FluentIcons.flag_16_regular, size: 14)),
        ],
      ),
    );
  }
}
