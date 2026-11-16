import 'dart:ui';

import 'package:flutter/material.dart';

import '../account/account_config.dart';
import '../account/account_setup_page.dart';
import '../account/accounts_page.dart';
import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../main.dart';
import '../notify/system_notifier.dart';
import '../settings/app_settings.dart';
import '../ui/theme.dart';
import 'core_launcher.dart';

/// Avvia il core con gli account salvati, chiede la configurazione se manca e, quando
/// tutto è pronto, mostra l'app vera e propria. Alla chiusura della finestra ferma il core.
class CoreGate extends StatefulWidget {
  const CoreGate({
    super.key,
    this.start = _defaultStart,
    this.apiFactory = _defaultApi,
    required this.accountStore,
    this.settings,
    this.notifier,
  });

  /// Avvio del core con variabili d'ambiente aggiuntive (dati degli account). Iniettabile nei test.
  final Future<CoreHandle> Function(Map<String, String> environment) start;
  final ApiClient Function(CoreConnection connection) apiFactory;
  final AccountStore accountStore;
  final AppSettings? settings;
  final MailNotifier? notifier;

  static Future<CoreHandle> _defaultStart(Map<String, String> environment) =>
      CoreLauncher.start(extraEnvironment: environment);

  static ApiClient _defaultApi(CoreConnection c) => ApiClient(baseUrl: c.baseUrl, token: c.token);

  @override
  State<CoreGate> createState() => _CoreGateState();
}

class _CoreGateState extends State<CoreGate> {
  CoreHandle? _handle;
  ApiClient? _api;
  CoreStartException? _error;
  List<AccountConfig> _accounts = const [];
  String _address = '';

  /// Il core è partito ma non ha i dati della casella: si mostra la configurazione.
  bool _needsSetup = false;

  /// Cambia a ogni riavvio del core: l'app viene ricreata da zero (nuova porta, nuovo token).
  int _generation = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Chiusura ordinata. Se l'app termina in modo brusco, il core si ferma comunque
    // perché il sistema chiude il suo stdin.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _handle?.stop();
        return AppExitResponse.exit;
      },
    );
    _start(loadAccount: true);
  }

  Future<void> _start({bool loadAccount = false}) async {
    setState(() {
      _error = null;
      _api = null;
    });
    try {
      if (loadAccount) {
        try {
          _accounts = await widget.accountStore.load();
        } on Object catch (e) {
          // Portachiavi assente o bloccato: si prosegue come se non ci fosse un account.
          debugPrint('[account] portachiavi non leggibile: $e');
        }
      }

      final handle = await widget.start(AccountConfig.coreEnvironment(_accounts));
      final api = widget.apiFactory(handle.connection);
      final status = await api.getAccountStatus();
      if (!mounted) {
        await handle.stop();
        return;
      }
      setState(() {
        _handle = handle;
        _api = api;
        _address = status.address;
        // Senza account salvati, in sviluppo gli user-secrets rendono il core già configurato: niente schermata.
        _needsSetup = !status.configured;
        _generation++;
      });
    } on CoreStartException catch (e) {
      if (mounted) setState(() => _error = e);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = CoreStartException(formatL10n.coreNotAnsweringCorrectly('$e')));
    }
  }

  /// Salva l'elenco nel portachiavi e riavvia il core con i nuovi dati (il core li legge solo all'avvio).
  Future<void> _saveAccounts(List<AccountConfig> accounts) async {
    await widget.accountStore.save(accounts);
    _accounts = accounts;
    final old = _handle;
    _handle = null;
    await old?.stop();
    await _start();
  }

  /// OAuth2 (4a): il core ha ricevuto dal fornitore un nuovo token di rinnovo. Si salva nel portachiavi; il core
  /// lo usa già, quindi niente riavvio.
  Future<void> _updateRefreshToken(String id, String refreshToken) async {
    final i = _accounts.indexWhere((a) => a.id == id);
    if (i < 0 || _accounts[i].refreshToken == refreshToken) return;
    final updated = [..._accounts]..[i] = _accounts[i].copyWith(refreshToken: refreshToken);
    try {
      await widget.accountStore.save(updated);
      // Ridisegno con lo stesso core (stessa chiave): la pagina Account vede il token nuovo e non risalva il vecchio.
      if (mounted) setState(() => _accounts = updated);
      debugPrint('[account] token di rinnovo di $id aggiornato nel portachiavi');
    } on Object catch (e) {
      debugPrint('[account] token di rinnovo di $id non salvato: $e');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _handle?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api != null && !_needsSetup) {
      return PostinoVipApp(
        key: ValueKey(_generation),
        api: api,
        settings: widget.settings,
        notifier: widget.notifier,
        accountsEditing: AccountsEditing(
          accounts: _accounts,
          coreAddress: _address,
          save: _saveAccounts,
          updateRefreshToken: _updateRefreshToken,
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Stessa lingua dell'app (tappa «Lingua», L1).
      locale: widget.settings?.language.locale,
      localeListResolutionCallback: (preferred, _) => resolveLocale(preferred),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      // Date e numeri (L5) nella lingua dell'app: la riceve chi formatta fuori dai widget.
      builder: (context, child) {
        setFormatLanguage(AppLocalizations.of(context));
        return child!;
      },
      // Schermata di primo avvio con lo stesso tema dell'app.
      theme: OfficeTheme.forApp(widget.settings?.theme ?? AppTheme.system).theme,
      darkTheme: OfficeTheme.forApp(widget.settings?.theme ?? AppTheme.system).darkTheme,
      themeMode: OfficeTheme.forApp(widget.settings?.theme ?? AppTheme.system).mode,
      home: api != null
          ? AccountSetupPage(
              api: api,
              initialEmail: _address,
              otherAccounts: _accounts,
              onSave: (account) => _saveAccounts([..._accounts, account]),
              firstRun: true,
            )
          : Scaffold(
              body: Center(
                child: _error == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          // Contesto sotto la MaterialApp: lì ci sono le traduzioni.
                          Builder(builder: (context) => Text(context.l10n.startingCore)),
                        ],
                      )
                    : _StartError(error: _error!, onRetry: _start),
              ),
            ),
    );
  }
}

class _StartError extends StatelessWidget {
  const _StartError({required this.error, required this.onRetry});

  final CoreStartException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(error.message, style: theme.textTheme.titleSmall!.copyWith(fontSize: 16)),
                ),
              ],
            ),
            if (error.log.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(context.l10n.coreLastLines, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.all(8),
                color: theme.colorScheme.surfaceContainerHighest,
                child: SingleChildScrollView(
                  child: SelectableText(
                    error.log.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
