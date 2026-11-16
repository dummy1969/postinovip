import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'about/licenses.dart';
import 'account/account_config.dart';
import 'account/accounts_page.dart';
import 'api/api_client.dart';
import 'attachments/file_picker.dart';
import 'attachments/file_saver.dart';
import 'compose/system_clipboard.dart';
import 'core/core_gate.dart';
import 'l10n/app_localizations.dart';
import 'l10n/formats.dart';
import 'l10n/language.dart';
import 'notify/new_mail_notifications.dart';
import 'notify/system_notifier.dart';
import 'notify/window_presenter.dart';
import 'state/reminder_model.dart';
import 'ui/reminder_dialog.dart';
import 'settings/app_settings.dart';
import 'state/calendar_model.dart';
import 'state/contacts_model.dart';
import 'state/mailbox_model.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  installSystemClipboard(); // Linux: appunti dell'editor con GTK, senza lo xclip del pacchetto
  await initializeDateFormatting(); // nomi di giorni e mesi per le date (L5), prima di ogni formato

  // Impostazioni salvate (SharedPreferences) e notifiche di sistema; se le notifiche non sono
  // disponibili (notifier null) l'app funziona lo stesso, senza popup.
  final settings = AppSettings(SharedPreferencesStore());
  await settings.load();
  final notifier = await SystemNotifier.create(openAction: settings.l10n.openMailAction);

  // CoreGate avvia il core (porta casuale + token + account dal portachiavi) e poi mostra PostinoVipApp.
  runApp(CoreGate(accountStore: SecureAccountStore(), settings: settings, notifier: notifier));
}

class PostinoVipApp extends StatefulWidget {
  const PostinoVipApp({
    super.key,
    required this.api,
    this.settings,
    this.notifier,
    this.windowPresenter,
    this.fileSaver,
    this.filePicker,
    this.accountsEditing,
  });

  final ApiClient api;

  /// Null nei test: impostazioni in memoria con i valori predefiniti.
  final AppSettings? settings;

  /// Null nei test o se le notifiche di sistema non sono disponibili.
  final MailNotifier? notifier;

  /// Sostituibile nei test; predefinito: canale nativo del runner.
  final WindowPresenter? windowPresenter;

  /// Sostituibile nei test; predefinito: finestra di salvataggio di sistema.
  final FileSaver? fileSaver;
  final FilePickerService? filePicker;

  /// Gestione degli account dalle Impostazioni (null nei test: voce nascosta).
  final AccountsEditing? accountsEditing;

  @override
  State<PostinoVipApp> createState() => _PostinoVipAppState();
}

class _PostinoVipAppState extends State<PostinoVipApp> {
  late final AppSettings _settings = widget.settings ?? AppSettings(MemorySettingsStore());
  late final WindowPresenter _presenter = widget.windowPresenter ?? NativeWindowPresenter();
  MailboxModel? _model;
  ContactsModel? _contacts;
  CalendarModel? _calendar;
  late final ReminderModel _reminders = ReminderModel(widget.api, _settings, notifier: widget.notifier)..start();
  StreamSubscription<String?>? _clicks;

  @override
  void initState() {
    super.initState();
    _clicks = widget.notifier?.clicks.listen(_onNotificationClick);
  }

  @override
  void dispose() {
    _clicks?.cancel();
    _reminders.dispose();
    super.dispose();
  }

  /// Clic sulla notifica: finestra in primo piano e, se indicata, apertura della cartella/mail.
  Future<void> _onNotificationClick(String? payload) async {
    await _presenter.present();
    if (payload == ReminderModel.payload) return _reminders.requestShow();
    final target = NotificationTarget.decode(payload);
    if (target != null) await _model?.openFromNotification(target.account, target.folder, target.uid);
  }

  MailboxModel _createModel() {
    final model = MailboxModel(widget.api, settings: _settings);
    final updateToken = widget.accountsEditing?.updateRefreshToken;
    if (updateToken != null) model.onCredentialsChanged = (account, token) => updateToken(account, token);
    model.onContactsChanged = (account) => _contacts?.contactsChanged(account);
    model.onCalendarsChanged = (account) {
      _calendar?.calendarsChanged(account);
      unawaited(_reminders.refresh());
    };
    model.addListener(() => _reminders.setAccounts(model.accounts));
    final notifier = widget.notifier;
    if (notifier != null) {
      final notifications = NewMailNotifications(settings: _settings, notifier: notifier);
      model.onNewMail = notifications.handle;
    }
    _model = model;
    return model
      ..loadFolders()
      ..startWatching();
  }

  @override
  Widget build(BuildContext context) {
    // ApiClient, impostazioni e modello sono disponibili a tutti i widget sotto
    // (context.read<ApiClient>() / context.watch<MailboxModel>() / context.watch<AppSettings>()).
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: _settings),
        Provider<MailNotifier?>.value(value: widget.notifier),
        Provider<FileSaver>.value(value: widget.fileSaver ?? SystemFileSaver()),
        Provider<FilePickerService>.value(value: widget.filePicker ?? SystemFilePicker()),
        Provider<AccountsEditing?>.value(value: widget.accountsEditing),
        ChangeNotifierProvider(create: (_) => _createModel()),
        ChangeNotifierProvider(create: (_) => _contacts = ContactsModel(widget.api)),
        ChangeNotifierProvider(create: (_) => _calendar = CalendarModel(widget.api, _settings)..onEventsChanged = () => unawaited(_reminders.refresh())),
        ChangeNotifierProvider.value(value: _reminders),
      ],
      // Ridisegna l'app solo quando cambiano il tema o la lingua, non a ogni altra impostazione.
      child: Selector<AppSettings, (AppTheme, AppLanguage)>(
        selector: (_, settings) => (settings.theme, settings.language),
        builder: (context, choice, home) {
          final looks = OfficeTheme.forApp(choice.$1);
          return MaterialApp(
            title: 'PostinoVip',
            debugShowCheckedModeBanner: false,
            // Lingua (tappa «Lingua», L1): i testi dell'app e quelli standard di Flutter e dell'editor.
            locale: choice.$2.locale,
            localeListResolutionCallback: (preferred, _) => resolveLocale(preferred),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            // Date e numeri (L5) nella lingua dell'app: la riceve chi formatta fuori dai widget.
            builder: (context, child) {
              setFormatLanguage(AppLocalizations.of(context));
              return child!;
            },
            // Stile Outlook classico, con il tema di Office scelto (predefinito: quello del sistema).
            theme: looks.theme,
            darkTheme: looks.darkTheme,
            themeMode: looks.mode,
            home: home,
          );
        },
        child: const ReminderHost(child: HomePage()),
      ),
    );
  }
}

/// Traduzioni dell'app (lib/l10n), testi standard di Flutter e dell'editor delle mail.
const appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
  FlutterQuillLocalizations.delegate,
];
