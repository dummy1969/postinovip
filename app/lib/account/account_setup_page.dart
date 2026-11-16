import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../models/calendar.dart';
import '../models/carddav.dart';
import '../models/oauth.dart';
import 'account_config.dart';

/// Configurazione di una casella: al primo avvio (core non configurato), per aggiungere un account
/// o per modificarne uno. "Salva" è possibile solo dopo una verifica riuscita con i dati di
/// connessione attuali; nome e mail scaricate si possono cambiare senza rifarla.
class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({
    super.key,
    required this.api,
    required this.onSave,
    this.initial,
    this.initialEmail,
    this.otherAccounts = const [],
    this.firstRun = false,
    this.openUrl,
    this.signInAgain = false,
    this.dialog = false,
  });

  /// Finestra sopra l'app (scelta 2a del 10/11/2026, come Firme): «Verifica connessione» a sinistra, «Annulla» e
  /// «Salva» in basso a destra; dopo il salvataggio si chiude. false: pagina intera (primo avvio, niente dietro).
  final bool dialog;

  /// Aperta da «Accedi di nuovo» (2a): l'accesso con il fornitore dell'account parte da solo.
  final bool signInAgain;

  /// Apre la pagina di accesso OAuth2 nel browser di sistema (nei test si sostituisce).
  final Future<bool> Function(Uri url)? openUrl;

  /// Ogni quanto chiedere al core se l'accesso nel browser è finito.
  static const oauthPollInterval = Duration(seconds: 1);

  /// Serve solo per "Verifica connessione" (il core prova i dati senza salvarli).
  final ApiClient api;

  /// Salva l'account e riavvia il core con i nuovi dati.
  final Future<void> Function(AccountConfig account) onSave;

  /// Account da modificare (id mantenuto); null = nuovo account.
  final AccountConfig? initial;
  final String? initialEmail;

  /// Gli altri account: lo stesso indirizzo con lo stesso tipo non si può aggiungere due volte; con l'altro
  /// tipo (IMAP e POP3 sulla stessa casella, scelta 6a) sì, con un avviso.
  final List<AccountConfig> otherAccounts;
  final bool firstRun;

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _email = TextEditingController(text: widget.initial?.email ?? widget.initialEmail ?? '');
  late final _password = TextEditingController(text: widget.initial?.password ?? '');
  late final _imapHost = TextEditingController(text: widget.initial?.imapHost ?? '');
  late final _imapPort = TextEditingController(text: '${widget.initial?.imapPort ?? 993}');
  late final _smtpHost = TextEditingController(text: widget.initial?.smtpHost ?? '');
  late final _smtpPort = TextEditingController(text: '${widget.initial?.smtpPort ?? 587}');

  late int _bodyMonths = widget.initial?.bodyMonths ?? AccountConfig.defaultBodyMonths;

  /// IMAP o POP3: si sceglie solo creando l'account (scelta 1a).
  late AccountType _type = widget.initial?.type ?? AccountType.imap;
  late bool _leaveOnServer = widget.initial?.leaveOnServer ?? true;
  late bool _removeAfter = widget.initial?.removeAfter ?? true;
  late final _removeDays = TextEditingController(
    text: '${widget.initial?.removeAfterDays ?? AccountConfig.defaultRemoveAfterDays}',
  );
  late bool _removeWhenDeleted = widget.initial?.removeWhenDeleted ?? false;
  late int _checkMinutes = widget.initial?.checkMinutes ?? AccountConfig.defaultCheckMinutes;
  late MailSecurity _imapSecurity = widget.initial?.imapSecurity ?? MailSecurity.ssl;
  late MailSecurity _smtpSecurity = widget.initial?.smtpSecurity ?? MailSecurity.startTls;
  late bool _smtpAuth = widget.initial?.smtpRequireAuth ?? true;

  /// Certificati di cui l'utente si fida, legati al server e alla porta per cui li ha accettati:
  /// cambiando server o porta non valgono più (si chiederà di nuovo, se serve).
  late _Pin? _imapPin = _Pin.of(
    widget.initial?.imapHost,
    widget.initial?.imapPort,
    widget.initial?.imapCertificateSha256,
  );
  late _Pin? _smtpPin = _Pin.of(
    widget.initial?.smtpHost,
    widget.initial?.smtpPort,
    widget.initial?.smtpCertificateSha256,
  );
  bool _showPassword = false;

  /// OAuth2 (O2): fornitori con client ID, accesso fatto (fornitore e token di rinnovo), accesso in corso.
  List<OAuthProviderInfo> _providers = const [];
  late String? _oauthProvider = widget.initial?.usesOAuth == true ? widget.initial!.oauthProvider : null;
  late String? _refreshToken = widget.initial?.usesOAuth == true ? widget.initial!.refreshToken : null;
  String? _oauthFlow;
  Timer? _oauthTimer;
  String? _oauthError;

  bool get _oauth => _oauthProvider != null && _refreshToken != null;

  /// Scelta 1a (05/11/2026): "Tipo di account" IMAP / POP3 / Gmail / Outlook.com come i riquadri di Outlook classico.
  /// Con un servizio (id del fornitore OAuth2) niente password né server: accesso nel browser, poi IMAP con XOAUTH2.
  late String? _service = widget.initial?.usesOAuth == true ? widget.initial!.oauthProvider : null;

  /// Nome del servizio come lo conosce l'utente.
  static String serviceLabel(String id, [String? name]) => switch (id) {
    'google' => 'Gmail',
    'microsoft' => 'Outlook.com / Microsoft 365',
    _ => name ?? id,
  };

  /// Valore della lista "Tipo di account": "Imap", "Pop3" o `oauth:<fornitore>`.
  String get _kind => _service != null ? 'oauth:$_service' : _type.coreName;

  void _setKind(String kind) {
    if (kind.startsWith('oauth:')) {
      final id = kind.substring(6);
      setState(() {
        if (_oauthProvider != id) {
          _oauthProvider = null;
          _refreshToken = null;
        }
        _service = id;
        _type = AccountType.imap;
        _oauthError = null;
      });
    } else {
      setState(() {
        _service = null;
        _oauthProvider = null;
        _refreshToken = null;
        _oauthError = null;
      });
      _setType(AccountType.fromCore(kind));
    }
  }

  @override
  void initState() {
    super.initState();
    widget.api.getOAuthProviders().then((p) {
      if (!mounted) return;
      setState(
        () => _providers = [
          for (final x in p)
            if (x.configured) x,
        ],
      );
      if (widget.signInAgain) {
        final provider = _providers.where((x) => x.id == _service).firstOrNull;
        if (provider != null) unawaited(_signIn(provider)); // con i permessi delle sincronizzazioni accese
      }
    }, onError: (Object _) {}); // core senza OAuth: niente pulsanti
  }

  bool _testing = false;
  bool _saving = false;
  String? _imapError;
  String? _smtpError;
  String? _generalError;

  /// Valori per cui la verifica è riuscita: se cambiano, va rifatta. Un account già salvato
  /// era stato verificato: modificandolo si può cambiare solo il nome senza rifare la verifica.
  late AccountConfig? _verified = widget.initial;

  late final String _id = widget.initial?.id ?? AccountConfig.newId();

  List<TextEditingController> get _all => [
    _name,
    _email,
    _password,
    _imapHost,
    _imapPort,
    _smtpHost,
    _smtpPort,
    _removeDays,
    _cardDavUrl,
    _calDavUrl,
  ];

  /// Calendario con CalDAV (K3): come i contatti.
  late bool _calDav = widget.initial?.calDavEnabled ?? false;
  late final _calDavUrl = TextEditingController(text: widget.initial?.calDavUrl ?? '');
  bool _calDavTesting = false;
  CalDavTestResult? _calDavResult;

  /// Contatti con CardDAV (C4c, 1b): non sono dati di connessione della posta, «Verifica rubrica» è facoltativa.
  late bool _cardDav = widget.initial?.cardDavEnabled ?? false;
  late final _cardDavUrl = TextEditingController(text: widget.initial?.cardDavUrl ?? '');
  bool _cardDavTesting = false;
  CardDavTestResult? _cardDavResult;

  bool get _pop3 => _type == AccountType.pop3;

  int get _removeDaysValue => int.tryParse(_removeDays.text.trim()) ?? AccountConfig.defaultRemoveAfterDays;

  /// L'accesso in corso chiede anche il permesso dei contatti (C4d, 1a) o del calendario (G3, 1a).
  bool _contactsRequested = false;
  bool _calendarRequested = false;

  /// "Accedi con …": pagina del fornitore nel browser di sistema, poi si aspetta il core (3a). [contacts] (C4d, 1a) e
  /// [calendar] (G3, 1a): anche il permesso dei contatti o del calendario; con la sincronizzazione già accesa si chiede
  /// sempre, così con contatti e calendario accesi l'accesso è uno solo con tutti e due.
  Future<void> _signIn(OAuthProviderInfo provider, {bool contacts = false, bool calendar = false}) async {
    final l = context.l10n;
    final google = provider.id == 'google';
    final withContacts = contacts || (_cardDav && google);
    final withCalendar = calendar || (_calDav && google);
    setState(() {
      _oauthError = null;
      _contactsRequested = withContacts;
      _calendarRequested = withCalendar;
    });
    try {
      final email = _email.text.trim();
      final start = await widget.api.startOAuth(provider.id,
          loginHint: email.contains('@') ? email : null, contacts: withContacts, calendar: withCalendar);
      final opened = await (widget.openUrl ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(
        Uri.parse(start.url),
      );
      if (!opened) {
        await widget.api.cancelOAuth(start.id);
        if (mounted) setState(() => _oauthError = l.browserNotOpened);
        return;
      }
      if (!mounted) return;
      setState(() => _oauthFlow = start.id);
      _oauthTimer = Timer.periodic(AccountSetupPage.oauthPollInterval, (_) => _pollOAuth(provider));
    } on ApiException catch (e) {
      if (mounted) setState(() => _oauthError = l.signInNotStarted('$e'));
    }
  }

  Future<void> _pollOAuth(OAuthProviderInfo provider) async {
    final id = _oauthFlow;
    if (id == null) return;
    final l = context.l10n;
    OAuthFlowStatus status;
    try {
      status = await widget.api.getOAuthFlow(id);
    } on ApiException catch (e) {
      _stopOAuth();
      if (mounted) {
        setState(() => _oauthError = e.statusCode == 404 ? l.signInExpired : l.signInFailedError('$e'));
      }
      return;
    }
    if (!mounted || status.status == 'pending') return;
    _stopOAuth();
    if (status.failed) {
      setState(() => _oauthError = status.error ?? l.signInFailed);
      return;
    }
    // Riuscito: indirizzo e server compilati da soli (5a), token al posto della password, poi la verifica.
    setState(() {
      _oauthProvider = provider.id;
      _refreshToken = status.refreshToken;
      // C4d e G3: ogni casella resta accesa solo se Google ha davvero concesso quel permesso.
      var noContacts = false;
      var noCalendar = false;
      if (_contactsRequested) {
        _cardDav = status.contacts == true;
        _cardDavResult = null;
        noContacts = status.contacts != true;
      }
      if (_calendarRequested) {
        _calDav = status.calendar == true;
        _calDavResult = null;
        noCalendar = status.calendar != true;
      }
      if (noContacts || noCalendar) {
        _oauthError = noContacts && noCalendar
            ? l.signInWithoutContactsCalendar
            : noContacts
            ? l.signInWithoutContacts
            : l.signInWithoutCalendar;
      }
      _contactsRequested = false;
      _calendarRequested = false;
      if (status.email case final email? when email.isNotEmpty) _email.text = email;
      if (status.servers case final servers?) {
        if (_pop3) {
          _imapHost.text = servers.pop3Host;
          _imapPort.text = '${servers.pop3Port}';
          _imapSecurity = MailSecurity.ssl;
        } else {
          _imapHost.text = servers.imapHost;
          _imapPort.text = '${servers.imapPort}';
          _imapSecurity = MailSecurity.forKnownImapPort(servers.imapPort) ?? MailSecurity.ssl;
        }
        _smtpHost.text = servers.smtpHost;
        _smtpPort.text = '${servers.smtpPort}';
        _smtpSecurity = MailSecurity.forKnownSmtpPort(servers.smtpPort) ?? MailSecurity.startTls;
        _smtpAuth = true;
      }
    });
    // Dopo il ridisegno: il campo password (non più mostrato) non deve più contare per i controlli del modulo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _test();
    });
  }

  void _stopOAuth() {
    _oauthTimer?.cancel();
    _oauthTimer = null;
    _oauthFlow = null;
  }

  Future<void> _cancelOAuth() async {
    final id = _oauthFlow;
    _stopOAuth();
    setState(() {});
    if (id != null) {
      try {
        await widget.api.cancelOAuth(id);
      } on ApiException {
        // già finito o scaduto
      }
    }
  }

  /// Le righe dell'accesso con un servizio (Gmail…): spiegazione e pulsante, attesa, account collegato.
  List<Widget> _oauthSection(ThemeData theme, bool busy) {
    final id = _service;
    if (id == null) return const [];
    final provider = _providers.where((p) => p.id == id).firstOrNull;
    final label = serviceLabel(id, provider?.name);
    final company = provider?.name ?? label;
    final l = context.l10n;
    return [
      const SizedBox(height: 12),
      if (_oauthFlow != null)
        Row(
          key: const Key('oauth-waiting'),
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(child: Text(l.waitingSignIn(company))),
            TextButton(onPressed: _cancelOAuth, child: Text(l.cancel)),
          ],
        )
      else if (_oauth)
        Row(
          key: const Key('oauth-linked'),
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l.signedInWith(company))),
            if (provider != null)
              TextButton(onPressed: busy ? null : () => _signIn(provider), child: Text(l.signInAgain)),
          ],
        )
      else ...[
        Text(l.noPasswordSignIn(company), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: provider == null
              ? Text(
                  l.serviceUnavailable(label),
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : FilledButton.icon(
                  key: Key('oauth-${provider.id}'),
                  onPressed: busy ? null : () => _signIn(provider),
                  icon: const Icon(Icons.login),
                  label: Text(l.signInWith(company)),
                ),
        ),
      ],
      if (_oauthError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_oauthError!, style: TextStyle(color: theme.colorScheme.error)),
        ),
      const SizedBox(height: 8),
    ];
  }

  @override
  void dispose() {
    _oauthTimer?.cancel();
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  AccountConfig _current() {
    final imapHost = _imapHost.text.trim();
    final imapPort = int.tryParse(_imapPort.text.trim()) ?? 0;
    final smtpHost = _smtpHost.text.trim();
    final smtpPort = int.tryParse(_smtpPort.text.trim()) ?? 0;
    return AccountConfig(
      id: _id,
      type: _type,
      leaveOnServer: _leaveOnServer,
      removeAfter: _removeAfter,
      removeAfterDays: _removeDaysValue,
      removeWhenDeleted: _removeWhenDeleted,
      checkMinutes: _checkMinutes,
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _oauth ? '' : _password.text,
      oauthProvider: _oauth ? _oauthProvider : null,
      refreshToken: _oauth ? _refreshToken : null,
      imapHost: imapHost,
      imapPort: imapPort,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      bodyMonths: _bodyMonths,
      imapSecurity: _imapSecurity,
      smtpSecurity: _smtpSecurity,
      smtpRequireAuth: _smtpAuth,
      // Con "Nessuna" non c'è certificato.
      imapCertificateSha256: _imapSecurity == MailSecurity.none ? null : _imapPin?.forServer(imapHost, imapPort),
      smtpCertificateSha256: _smtpSecurity == MailSecurity.none ? null : _smtpPin?.forServer(smtpHost, smtpPort),
    );
  }

  bool get _canSave {
    final v = _verified;
    return v != null && _current().sameConnection(v) && !_duplicate(_email.text);
  }

  bool _sameAddress(AccountConfig a, String email) => a.email.toLowerCase() == email.trim().toLowerCase();

  bool _duplicate(String email) => widget.otherAccounts.any((a) => _sameAddress(a, email) && a.type == _type);

  /// Stessa casella già configurata con l'altro tipo (IMAP e POP3): permesso, con un avviso (6a).
  AccountConfig? _otherType(String email) =>
      widget.otherAccounts.where((a) => _sameAddress(a, email) && a.type != _type).firstOrNull;

  /// Cambiando tipo, la porta di ricezione standard passa a quella dell'altro protocollo.
  void _setType(AccountType type) {
    final current = int.tryParse(_imapPort.text.trim());
    final standard = {...MailSecurity.standardImapPorts, ...MailSecurity.standardPop3Ports};
    setState(() {
      _type = type;
      if (current == null || standard.contains(current)) {
        _imapPort.text = '${type == AccountType.pop3 ? _imapSecurity.pop3Port : _imapSecurity.imapPort}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _testing || _saving;
    final l = context.l10n;

    final title = widget.firstRun
        ? l.welcomeTitle
        : widget.initial == null
        ? l.newAccount
        : l.editAccount;
    final content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}), // aggiorna lo stato di "Salva"
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.firstRun)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(l.firstRunIntro, style: theme.textTheme.bodyMedium),
                  ),
                if (widget.initial == null)
                  DropdownButtonFormField<String>(
                    key: const Key('account-type'),
                    initialValue: _kind,
                    decoration: InputDecoration(
                      labelText: l.accountType,
                      helperText:
                          l.accountTypeHelp +
                          (_providers.isEmpty
                              ? ''
                              : '\n${l.accountTypeServices([for (final p in _providers) serviceLabel(p.id, p.name)].join(', '))}'),
                      helperMaxLines: 4,
                    ),
                    items: [
                      for (final t in AccountType.values) DropdownMenuItem(value: t.coreName, child: Text(t.label)),
                      for (final p in _providers)
                        DropdownMenuItem(value: 'oauth:${p.id}', child: Text(serviceLabel(p.id, p.name))),
                    ],
                    onChanged: busy ? null : (k) => _setKind(k!),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l.accountTypeValue(_service != null ? serviceLabel(_service!) : _type.label),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ..._oauthSection(theme, busy),
                TextFormField(
                  controller: _name,
                  enabled: !busy,
                  decoration: InputDecoration(labelText: l.nameOptional, hintText: l.nameOptionalHint),
                ),
                if (_service == null || _oauth)
                  TextFormField(
                    controller: _email,
                    enabled: !busy,
                    // Con un servizio l'indirizzo è quello dell'accesso: non si cambia a mano.
                    readOnly: _service != null,
                    decoration: InputDecoration(labelText: l.emailAddressUser),
                    validator: (v) => !(v ?? '').contains('@')
                        ? l.invalidAddressShort
                        : _duplicate(v!)
                        ? l.accountAlreadyPresent
                        : null,
                  ),
                if (_service == null)
                  TextFormField(
                    controller: _password,
                    enabled: !busy,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: l.password,
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? l.hidePassword : l.showPassword,
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? l.passwordRequired : null,
                  ),
                if (_otherType(_email.text) case final other?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.sameMailboxOtherType(other.type.label, other.displayName),
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
                if (_service == null) ...[
                  const SizedBox(height: 16),
                  _serverRow(
                    l.incomingServer(_type.label),
                    _imapHost,
                    _imapPort,
                    _imapError,
                    busy,
                    security: _imapSecurity,
                    onSecurity: (s) => setState(() => _imapSecurity = s),
                    knownPort: _pop3 ? MailSecurity.forKnownPop3Port : MailSecurity.forKnownImapPort,
                    standardPort: (s) => _pop3 ? s.pop3Port : s.imapPort,
                    standardPorts: _pop3 ? MailSecurity.standardPop3Ports : MailSecurity.standardImapPorts,
                    trusted: _current().imapCertificateSha256 != null,
                    onForget: () => setState(() => _imapPin = null),
                    key: const ValueKey('imap'),
                  ),
                  _serverRow(
                    l.outgoingServer,
                    _smtpHost,
                    _smtpPort,
                    _smtpError,
                    busy,
                    security: _smtpSecurity,
                    onSecurity: (s) => setState(() => _smtpSecurity = s),
                    knownPort: MailSecurity.forKnownSmtpPort,
                    standardPort: (s) => s.smtpPort,
                    standardPorts: MailSecurity.standardSmtpPorts,
                    trusted: _current().smtpCertificateSha256 != null,
                    onForget: () => setState(() => _smtpPin = null),
                    key: const ValueKey('smtp'),
                    extra: CheckboxListTile(
                      key: const Key('smtp-auth'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _smtpAuth,
                      onChanged: busy ? null : (v) => setState(() => _smtpAuth = v ?? true),
                      title: Text(l.smtpAuthTitle),
                      subtitle: Text(l.smtpAuthSubtitle),
                    ),
                  ),
                ],
                if (_pop3) ..._pop3Options(busy, theme),
                if (!_pop3)
                  DropdownButtonFormField<int>(
                    initialValue: _bodyMonths,
                    decoration: InputDecoration(
                      labelText: l.downloadedMail,
                      helperText: l.downloadedMailHelp,
                      helperMaxLines: 3,
                    ),
                    items: [
                      for (final m in AccountConfig.bodyMonthsChoices)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            AccountConfig.bodyMonthsLabel(l, m) +
                                (m == AccountConfig.defaultBodyMonths ? l.recommendedSuffix : ''),
                          ),
                        ),
                    ],
                    onChanged: busy ? null : (m) => setState(() => _bodyMonths = m!),
                  ),
                ..._cardDavSection(busy, theme),
                ..._calDavSection(busy, theme),
                if (_generalError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_generalError!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (!widget.dialog) ...[const SizedBox(height: 24), ..._actions(theme, busy)],
              ],
            ),
          ),
        ),
      );
    if (!widget.dialog) return Scaffold(appBar: AppBar(title: Text(title)), body: content);

    // Finestra (2a): titolo, modulo che scorre, pulsanti sempre visibili in basso.
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      key: const Key('account-setup-dialog'),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: (screen.width - 48).clamp(280.0, 640.0),
        height: (screen.height - 48).clamp(300.0, 760.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            Expanded(child: content),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: _actions(theme, busy)),
            ),
          ],
        ),
      ),
    );
  }

  /// Contatti (C4d) e calendario (G3) con OAuth2: solo Gmail; Microsoft non ancora.
  bool get _contactsWithOAuth => _service == 'google';
  bool get _cardDavUnavailable => _service != null && !_contactsWithOAuth;
  bool get _calDavUnavailable => _service != null ? !_contactsWithOAuth : _oauth;

  /// Gmail senza accesso fatto: la casella aspetta «Accedi con Google».
  bool get _cardDavNeedsSignIn => _contactsWithOAuth && !_oauth;
  bool get _calDavNeedsSignIn => _contactsWithOAuth && !_oauth;

  /// Casella del calendario: con Gmail accenderla apre il browser per il permesso del calendario (G3, scelta 1a); se
  /// l'accesso non riesce o non lo concede resta spenta.
  void _setCalDav(bool on) {
    if (!on || !_contactsWithOAuth) {
      setState(() {
        _calDav = on;
        _calDavResult = null;
      });
      return;
    }
    final provider = _providers.where((p) => p.id == _service).firstOrNull;
    if (provider == null) return;
    unawaited(_signIn(provider, calendar: true));
  }

  /// Casella dei contatti: con Gmail accenderla apre il browser per il permesso dei contatti (C4d, scelta 1a); se
  /// l'accesso non riesce o non lo concede resta spenta.
  void _setCardDav(bool on) {
    if (!on || !_contactsWithOAuth) {
      setState(() {
        _cardDav = on;
        _cardDavResult = null;
      });
      return;
    }
    final provider = _providers.where((p) => p.id == _service).firstOrNull;
    if (provider == null) return;
    unawaited(_signIn(provider, contacts: true));
  }

  /// Sezione «Contatti» (C4c, 1b): casella, indirizzo facoltativo e «Verifica rubrica».
  List<Widget> _cardDavSection(bool busy, ThemeData theme) {
    final unavailable = _cardDavUnavailable || _cardDavNeedsSignIn;
    final host = _imapHost.text.trim();
    final result = _cardDavResult;
    final waiting = _oauthFlow != null && _contactsRequested;
    final l = context.l10n;
    return [
      const SizedBox(height: 16),
      Text(l.contacts, style: theme.textTheme.titleSmall),
      CheckboxListTile(
        key: const Key('carddav-enabled'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _cardDav && !unavailable,
        onChanged: busy || unavailable || _oauthFlow != null ? null : (v) => _setCardDav(v ?? false),
        title: Text(_contactsWithOAuth ? l.syncContactsGoogle : l.syncContactsServer),
        subtitle: Text(
          _cardDavUnavailable
              ? l.notYetForMicrosoft
              : _cardDavNeedsSignIn
              ? l.signInWithGoogleFirst
              : _contactsWithOAuth
              ? l.syncContactsGoogleHelp
              : l.syncContactsServerHelp,
        ),
      ),
      if (waiting)
        Padding(
          key: const Key('carddav-oauth-waiting'),
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(l.contactsSignInWaiting),
        ),
      if (_cardDav && !unavailable) ...[
        if (!_contactsWithOAuth) TextFormField(
          key: const Key('carddav-url'),
          controller: _cardDavUrl,
          enabled: !busy,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l.contactsServerUrl,
            hintText: 'https://…',
            helperText: host.isEmpty ? l.emptyFoundOnIncoming : l.emptyFoundOn(host),
          ),
          onChanged: (_) => setState(() => _cardDavResult = null),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final u = Uri.tryParse(t);
            return u == null || u.scheme != 'https' || u.host.isEmpty ? l.httpsRequired : null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('carddav-test'),
              onPressed: busy || _cardDavTesting ? null : _testCardDav,
              icon: _cardDavTesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.contacts_outlined),
              label: Text(l.testAddressBook),
            ),
            const SizedBox(width: 12),
            if (result != null)
              Expanded(
                child: Text(
                  result.ok ? l.addressBookFound(result.addressBook ?? '') : result.error ?? l.addressBookNotFound,
                  key: const Key('carddav-result'),
                  style: TextStyle(color: result.ok ? Colors.green.shade700 : theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  /// Sezione «Calendario» (K3): come «Contatti», con «Verifica calendario».
  List<Widget> _calDavSection(bool busy, ThemeData theme) {
    final unavailable = _calDavUnavailable || _calDavNeedsSignIn;
    final host = _imapHost.text.trim();
    final result = _calDavResult;
    final waiting = _oauthFlow != null && _calendarRequested;
    final l = context.l10n;
    return [
      const SizedBox(height: 16),
      Text(l.calendarSection, style: theme.textTheme.titleSmall),
      CheckboxListTile(
        key: const Key('caldav-enabled'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _calDav && !unavailable,
        onChanged: busy || unavailable || _oauthFlow != null ? null : (v) => _setCalDav(v ?? false),
        title: Text(_contactsWithOAuth ? l.syncCalendarGoogle : l.syncCalendarServer),
        subtitle: Text(
          _calDavUnavailable
              ? l.notYetForMicrosoft
              : _calDavNeedsSignIn
              ? l.signInWithGoogleFirst
              : _contactsWithOAuth
              ? l.syncCalendarGoogleHelp
              : l.syncCalendarServerHelp,
        ),
      ),
      if (waiting)
        Padding(
          key: const Key('caldav-oauth-waiting'),
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(l.calendarSignInWaiting),
        ),
      if (_calDav && !unavailable) ...[
        if (!_contactsWithOAuth) TextFormField(
          key: const Key('caldav-url'),
          controller: _calDavUrl,
          enabled: !busy,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l.calendarServerUrl,
            hintText: 'https://…',
            helperText: host.isEmpty ? l.emptyFoundOnIncoming : l.emptyFoundOn(host),
          ),
          onChanged: (_) => setState(() => _calDavResult = null),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final u = Uri.tryParse(t);
            return u == null || u.scheme != 'https' || u.host.isEmpty ? l.httpsRequired : null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('caldav-test'),
              onPressed: busy || _calDavTesting ? null : _testCalDav,
              icon: _calDavTesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calendar_month_outlined),
              label: Text(l.testCalendar),
            ),
            const SizedBox(width: 12),
            if (result != null)
              Expanded(
                child: Text(
                  result.ok
                      ? l.calendarsFound(result.calendars.length, result.calendars.map((c) => l.quoted(c)).join(', '))
                      : result.error ?? l.calendarNotFound,
                  key: const Key('caldav-result'),
                  style: TextStyle(color: result.ok ? Colors.green.shade700 : theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  /// Cerca i calendari con i dati scritti, in sola lettura (nessun appuntamento letto né scritto).
  Future<void> _testCalDav() async {
    final host = _imapHost.text.trim();
    final url = _calDavUrl.text.trim();
    final l = context.l10n;
    String? problem;
    if (_oauth) {
      // G3: con il token dell'account, calendari di Google
    } else if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      problem = l.enterAddressPasswordFirst;
    } else if (host.isEmpty && url.isEmpty) {
      problem = l.enterServerOrCalendarUrl;
    } else if (url.isNotEmpty && Uri.tryParse(url)?.scheme != 'https') {
      problem = l.httpsRequired;
    }
    if (problem != null) {
      setState(() => _calDavResult = CalDavTestResult(ok: false, error: problem));
      return;
    }
    setState(() {
      _calDavTesting = true;
      _calDavResult = null;
    });
    CalDavTestResult result;
    try {
      result = _oauth
          ? await widget.api.testCalDav(
              email: _email.text.trim(),
              host: host,
              oauthProvider: _oauthProvider,
              refreshToken: _refreshToken,
            )
          : await widget.api.testCalDav(
              email: _email.text.trim(),
              password: _password.text,
              host: host,
              url: url,
              certificateSha256: _imapPin?.forServer(host, int.tryParse(_imapPort.text.trim()) ?? 0),
            );
    } on ApiException catch (e) {
      result = CalDavTestResult(ok: false, error: e.fieldErrors.values.firstOrNull?.firstOrNull ?? e.message);
    }
    if (!mounted) return;
    setState(() {
      _calDavTesting = false;
      _calDavResult = result;
    });
  }

  /// Cerca la rubrica con i dati scritti, in sola lettura (nessun contatto letto né scritto).
  Future<void> _testCardDav() async {
    final host = _imapHost.text.trim();
    final url = _cardDavUrl.text.trim();
    final l = context.l10n;
    String? problem;
    if (_oauth) {
      // C4d: con il token dell'account, rubrica di Google
    } else if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      problem = l.enterAddressPasswordFirst;
    } else if (host.isEmpty && url.isEmpty) {
      problem = l.enterServerOrContactsUrl;
    } else if (url.isNotEmpty && Uri.tryParse(url)?.scheme != 'https') {
      problem = l.httpsRequired;
    }
    if (problem != null) {
      setState(() => _cardDavResult = CardDavTestResult(ok: false, error: problem));
      return;
    }
    setState(() {
      _cardDavTesting = true;
      _cardDavResult = null;
    });
    CardDavTestResult result;
    try {
      result = _oauth
          ? await widget.api.testCardDav(
              email: _email.text.trim(),
              host: host,
              oauthProvider: _oauthProvider,
              refreshToken: _refreshToken,
            )
          : await widget.api.testCardDav(
              email: _email.text.trim(),
              password: _password.text,
              host: host,
              url: url,
              certificateSha256: _imapPin?.forServer(host, int.tryParse(_imapPort.text.trim()) ?? 0),
            );
    } on ApiException catch (e) {
      result = CardDavTestResult(ok: false, error: e.fieldErrors.values.firstOrNull?.firstOrNull ?? e.message);
    }
    if (!mounted) return;
    setState(() {
      _cardDavTesting = false;
      _cardDavResult = result;
    });
  }

  /// Opzioni POP3 come Outlook (scelte 2a e 3a): non sono dati di connessione, non richiedono una verifica.
  List<Widget> _pop3Options(bool busy, ThemeData theme) {
    Widget check(Key key, bool value, ValueChanged<bool> onChanged, Widget title, {bool enabled = true}) =>
        CheckboxListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: value,
          onChanged: busy || !enabled ? null : (v) => setState(() => onChanged(v ?? false)),
          title: title,
        );
    final l = context.l10n;
    return [
      Text(l.deliverySection, style: theme.textTheme.titleSmall),
      check(
        const Key('pop3-leave'),
        _leaveOnServer,
        (v) => _leaveOnServer = v,
        Text(l.leaveCopyOnServer),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: check(
                    const Key('pop3-remove-after'),
                    _removeAfter,
                    (v) => _removeAfter = v,
                    Text(l.removeFromServerAfter),
                    enabled: _leaveOnServer,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    key: const Key('pop3-remove-days'),
                    controller: _removeDays,
                    enabled: !busy && _leaveOnServer && _removeAfter,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    validator: (v) {
                      if (!_pop3 || !_leaveOnServer || !_removeAfter) return null;
                      final d = int.tryParse((v ?? '').trim());
                      return d != null && d >= 1 && d <= 999 ? null : '1–999';
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(l.days),
              ],
            ),
            check(
              const Key('pop3-remove-deleted'),
              _removeWhenDeleted,
              (v) => _removeWhenDeleted = v,
              Text(l.removeWhenDeleted),
              enabled: _leaveOnServer,
            ),
          ],
        ),
      ),
      if (!_leaveOnServer)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l.pop3NoCopyWarning,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      DropdownButtonFormField<int>(
        key: const Key('pop3-check'),
        initialValue: _checkMinutes,
        decoration: InputDecoration(labelText: l.checkMailEvery, helperText: l.checkMailEveryHelp, helperMaxLines: 2),
        items: [
          for (final m in AccountConfig.checkMinutesChoices)
            DropdownMenuItem(
              value: m,
              child: Text(l.minutesCount(m) + (m == AccountConfig.defaultCheckMinutes ? l.recommendedSuffix : '')),
            ),
        ],
        onChanged: busy ? null : (m) => setState(() => _checkMinutes = m!),
      ),
    ];
  }

  Widget _serverRow(
    String title,
    TextEditingController host,
    TextEditingController port,
    String? error,
    bool busy, {
    required Key key,
    required MailSecurity security,
    required ValueChanged<MailSecurity> onSecurity,
    required MailSecurity? Function(int? port) knownPort,
    required int Function(MailSecurity security) standardPort,
    required Set<int> standardPorts,
    required bool trusted,
    required VoidCallback onForget,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final verifiedOk = _verified != null && error == null && _canSave;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              if (verifiedOk) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
              ],
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: host,
                  enabled: !busy,
                  decoration: InputDecoration(labelText: l.server, hintText: l.serverHint),
                  validator: (v) => (v ?? '').trim().isEmpty ? l.serverRequired : null,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: port,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.port),
                  // Porta nota -> crittografia proposta (modificabile dal menu).
                  onChanged: (v) {
                    final proposed = knownPort(int.tryParse(v.trim()));
                    if (proposed != null && proposed != security) onSecurity(proposed);
                  },
                  validator: (v) {
                    final p = int.tryParse((v ?? '').trim());
                    return p != null && p > 0 && p < 65536 ? null : '1–65535';
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<MailSecurity>(
                  key: ValueKey('$key-security-$security'),
                  initialValue: security,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.encryption),
                  items: [for (final s in MailSecurity.values) DropdownMenuItem(value: s, child: Text(s.label(l)))],
                  onChanged: busy
                      ? null
                      : (s) {
                          // Crittografia cambiata -> porta standard, ma solo se quella attuale è vuota o
                          // standard: una porta personalizzata resta com'è.
                          final current = int.tryParse(port.text.trim());
                          if (current == null || standardPorts.contains(current)) {
                            port.text = '${standardPort(s!)}';
                          }
                          onSecurity(s!);
                        },
                ),
              ),
            ],
          ),
          if (security == MailSecurity.none)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.unencryptedWarning,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          if (trusted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.certificateTrustedByYou,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: busy ? null : onForget, child: Text(l.stopTrusting)),
                ],
              ),
            ),
          ?extra,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    setState(() {
      _testing = true;
      _verified = null;
      _imapError = _smtpError = _generalError = null;
    });
    try {
      // Certificato non valido: si chiede se fidarsi e, se sì, si ripete la prova con l'impronta.
      for (var attempt = 0; attempt < 3; attempt++) {
        final candidate = _current();
        final r = await widget.api.testAccount(
          email: candidate.email,
          password: candidate.password,
          imapHost: candidate.imapHost,
          imapPort: candidate.imapPort,
          smtpHost: candidate.smtpHost,
          smtpPort: candidate.smtpPort,
          imapSecurity: candidate.imapSecurity,
          smtpSecurity: candidate.smtpSecurity,
          smtpRequireAuth: candidate.smtpRequireAuth,
          imapCertificateSha256: candidate.imapCertificateSha256,
          smtpCertificateSha256: candidate.smtpCertificateSha256,
          type: candidate.type,
          oauthProvider: candidate.oauthProvider,
          refreshToken: candidate.refreshToken,
        );
        if (!mounted) return;
        setState(() {
          _imapError = r.imapError;
          _smtpError = r.smtpError;
          if (r.ok) _verified = candidate;
        });
        if (r.ok) return;
        // Durante la domanda niente indicatore di attesa: si aspetta l'utente, non il server.
        setState(() => _testing = false);
        if (!await _askTrust(r) || !mounted) return;
        setState(() => _testing = true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _generalError = l.testFailed('$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Per ogni certificato rifiutato, "Fidarsi di questo certificato?". True se ne è stato accettato almeno uno
  /// (la prova va ripetuta). Stesso certificato per IMAP e SMTP (stesso server): si chiede una volta.
  Future<bool> _askTrust(AccountTestResult r) async {
    var accepted = false;
    final l = context.l10n;
    final imap = r.imapCertificate;
    final smtp = r.smtpCertificate;
    if (imap != null) {
      if (!await _confirmCertificate(l.incomingServer('IMAP'), imap)) return accepted;
      if (!mounted) return accepted;
      setState(() => _imapPin = _Pin(imap.host, imap.port, imap.sha256));
      accepted = true;
      if (smtp != null && smtp.sha256 == imap.sha256) {
        setState(() => _smtpPin = _Pin(smtp.host, smtp.port, smtp.sha256));
        return true;
      }
    }
    if (smtp != null) {
      if (!await _confirmCertificate(l.outgoingServer, smtp)) return accepted;
      if (!mounted) return accepted;
      setState(() => _smtpPin = _Pin(smtp.host, smtp.port, smtp.sha256));
      accepted = true;
    }
    return accepted;
  }

  Future<bool> _confirmCertificate(String server, CertificateInfo c) async {
    String date(DateTime? d) => d == null ? '?' : formatDate(d);
    final theme = Theme.of(context);
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.trustCertificateQuestion),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.invalidCertificatePresented(server, '${c.host}:${c.port}')),
                const SizedBox(height: 4),
                for (final p in c.problems) Text('• $p', style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                _certLine(l.certificateIssuedTo, c.subject),
                _certLine(l.certificateIssuedBy, c.issuer),
                _certLine(l.certificateValid, l.certificateValidRange(date(c.notBefore), date(c.notAfter))),
                _certLine(l.certificateFingerprint, c.formattedSha256, mono: true),
                const SizedBox(height: 12),
                Text(l.certificateAdvice),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.trustCertificate)),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _certLine(String label, String value, {bool mono = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        SelectableText(value, style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 12) : null),
      ],
    ),
  );

  /// «Verifica connessione» e «Salva» con la nota sotto; nella finestra anche «Annulla» (stile comune: pulsante
  /// principale pieno a destra, «Annulla» di testo alla sua sinistra).
  List<Widget> _actions(ThemeData theme, bool busy) {
    final l = context.l10n;
    final test = OutlinedButton.icon(
      // Con un servizio si verifica da sola dopo l'accesso; prima non c'è niente da provare.
      onPressed: busy || (_service != null && !_oauth) ? null : _test,
      icon: _testing
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.wifi_tethering),
      label: Text(l.testConnection),
    );
    final save = FilledButton.icon(
      onPressed: busy || !_canSave ? null : _save,
      icon: _saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.save),
      label: Text(l.save),
    );
    return [
      if (widget.dialog)
        // Se lo spazio non basta i pulsanti vanno a capo invece di uscire dalla finestra.
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          overflowSpacing: 8,
          children: [
            test,
            const SizedBox(width: 16),
            TextButton(
              key: const Key('account-setup-cancel'),
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            save,
          ],
        )
      else
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [test, const SizedBox(width: 12), save]),
      if (!_canSave && !busy)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l.saveAfterTest,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
    ];
  }

  Future<void> _save() async {
    // "Nessuna" crittografia (scelta 2a): conferma esplicita.
    final verified = _verified!;
    if (verified.hasUnencrypted && !await _confirmUnencrypted(verified)) return;
    if (!mounted) return;
    final l = context.l10n;
    setState(() {
      _saving = true;
      _generalError = null;
    });
    try {
      // Dati di connessione verificati + nome e limite attuali.
      // Dati di connessione verificati + nome, limite e opzioni POP3 attuali (non richiedono una verifica).
      await widget.onSave(
        verified.copyWith(
          name: _name.text.trim(),
          bodyMonths: _bodyMonths,
          leaveOnServer: _leaveOnServer,
          removeAfter: _removeAfter,
          removeAfterDays: _removeDaysValue,
          removeWhenDeleted: _removeWhenDeleted,
          checkMinutes: _checkMinutes,
          cardDavEnabled: _cardDav && !_cardDavUnavailable && !_cardDavNeedsSignIn,
          cardDavUrl: _cardDavUrl.text,
          calDavEnabled: _calDav && !_calDavUnavailable && !_calDavNeedsSignIn,
          calDavUrl: _calDavUrl.text,
        ),
      );
      if (widget.dialog && mounted) Navigator.pop(context); // nella finestra Account: l'account è in sospeso
    } on Object catch (e) {
      // Es. portachiavi bloccato o assente.
      if (mounted) {
        setState(() {
          _saving = false;
          _generalError = l.accountNotSaved('$e');
        });
      }
    }
  }

  Future<bool> _confirmUnencrypted(AccountConfig a) async {
    final l = context.l10n;
    final servers = [
      if (a.imapSecurity == MailSecurity.none) l.unencryptedIncoming('${a.imapHost}:${a.imapPort}'),
      if (a.smtpSecurity == MailSecurity.none) l.unencryptedOutgoing('${a.smtpHost}:${a.smtpPort}'),
    ];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
        title: Text(l.unencryptedTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(l.unencryptedContent(servers.join(l.andSeparator))),
        ),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.saveUnencrypted),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Certificato accettato per un server e una porta precisi.
class _Pin {
  const _Pin(this.host, this.port, this.sha256);

  final String host;
  final int port;
  final String sha256;

  static _Pin? of(String? host, int? port, String? sha256) =>
      host == null || port == null || sha256 == null ? null : _Pin(host, port, sha256);

  String? forServer(String host, int port) =>
      host.toLowerCase() == this.host.toLowerCase() && port == this.port ? sha256 : null;
}
