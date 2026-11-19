import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// Barra di stato: numero di elementi della cartella o del calendario
  ///
  /// In it, this message translates to:
  /// **'Elementi: {count}'**
  String statusItems(int count);

  /// Barra di stato: mail non lette della cartella
  ///
  /// In it, this message translates to:
  /// **'Da leggere: {count}'**
  String statusUnread(int count);

  /// Barra di stato: risultati della ricerca
  ///
  /// In it, this message translates to:
  /// **'Risultati: {count}'**
  String statusResults(int count);

  /// Barra di stato in Persone: contatti della rubrica
  ///
  /// In it, this message translates to:
  /// **'Contatti: {count}'**
  String statusContacts(int count);

  /// Barra di stato in Persone: contatti trovati dalla ricerca
  ///
  /// In it, this message translates to:
  /// **'Trovati: {count}'**
  String statusFound(int count);

  /// Barra di stato: tutti gli account raggiungibili
  ///
  /// In it, this message translates to:
  /// **'Connesso'**
  String get statusConnected;

  /// Barra di stato: un account non raggiungibile (con un solo account)
  ///
  /// In it, this message translates to:
  /// **'Disconnesso'**
  String get statusDisconnected;

  /// Barra di stato: nomi degli account non raggiungibili, separati da virgola
  ///
  /// In it, this message translates to:
  /// **'Disconnesso: {accounts}'**
  String statusDisconnectedAccounts(String accounts);

  /// Titolo della finestra File → Opzioni
  ///
  /// In it, this message translates to:
  /// **'Opzioni'**
  String get optionsTitle;

  /// Pulsante che chiude la finestra Opzioni
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get optionsClose;

  /// Categoria delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Generale'**
  String get optionsPageGeneral;

  /// Categoria delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Posta'**
  String get optionsPageMail;

  /// Categoria delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get optionsPageNotifications;

  /// Categoria delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Calendario'**
  String get optionsPageCalendar;

  /// Titolo della sezione account in Opzioni → Generale
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get optionsAccountSection;

  /// Nessun account e nessun core configurato
  ///
  /// In it, this message translates to:
  /// **'(non configurato)'**
  String get optionsAccountNotConfigured;

  /// Solo nello sviluppo: account letto dagli user-secrets di .NET
  ///
  /// In it, this message translates to:
  /// **'Dati da user-secrets (sviluppo)'**
  String get optionsAccountFromUserSecrets;

  /// Numero degli account configurati
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} account}}'**
  String optionsAccountCount(int count);

  /// Pulsante che apre la finestra Account
  ///
  /// In it, this message translates to:
  /// **'Gestisci…'**
  String get optionsAccountManage;

  /// Titolo della sezione tema e barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get optionsLookSection;

  /// Etichetta della scelta del tema (anche il pulsante in Visualizza)
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get optionsTheme;

  /// Spiegazione sotto la scelta del tema
  ///
  /// In it, this message translates to:
  /// **'Il testo delle mail resta su fondo bianco anche con i temi scuri'**
  String get optionsThemeHelper;

  /// Tema: chiaro o scuro come il sistema
  ///
  /// In it, this message translates to:
  /// **'Usa impostazione di sistema'**
  String get themeSystem;

  /// Nome di un tema
  ///
  /// In it, this message translates to:
  /// **'Colorato'**
  String get themeColorful;

  /// Nome di un tema
  ///
  /// In it, this message translates to:
  /// **'Bianco'**
  String get themeWhite;

  /// Nome di un tema
  ///
  /// In it, this message translates to:
  /// **'Grigio scuro'**
  String get themeDarkGray;

  /// Nome di un tema
  ///
  /// In it, this message translates to:
  /// **'Nero'**
  String get themeBlack;

  /// Etichetta della scelta della posizione della barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'Barra dei moduli (Posta, Calendario, Persone)'**
  String get optionsModuleBar;

  /// Posizione della barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'A sinistra'**
  String get moduleBarLeft;

  /// Posizione della barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'In basso nel riquadro di sinistra'**
  String get moduleBarBottom;

  /// Titolo della sezione lingua in Opzioni → Generale
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get optionsLanguageSection;

  /// Etichetta della scelta della lingua
  ///
  /// In it, this message translates to:
  /// **'Lingua dell\'interfaccia'**
  String get optionsLanguage;

  /// Nota sotto la scelta della lingua: la lingua vale anche per i testi che il core scrive nelle mail
  ///
  /// In it, this message translates to:
  /// **'Vale anche per i testi che l\'app scrive nelle mail (intestazioni delle risposte, conferme di lettura)'**
  String get optionsLanguageHelper;

  /// Lingua: quella del sistema operativo (italiano o inglese; le altre lingue diventano inglese)
  ///
  /// In it, this message translates to:
  /// **'Come il sistema'**
  String get languageSystem;

  /// Scheda della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Scheda della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Invia/Ricevi'**
  String get tabSendReceive;

  /// Scheda della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Cartella'**
  String get tabFolder;

  /// Scheda della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Visualizza'**
  String get tabView;

  /// Gruppo della barra multifunzione (Visualizza)
  ///
  /// In it, this message translates to:
  /// **'Layout'**
  String get groupLayout;

  /// Comando in Visualizza
  ///
  /// In it, this message translates to:
  /// **'Comprimi barra multifunzione'**
  String get ribbonCollapse;

  /// Suggerimento di Comprimi barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Mostra solo i nomi delle schede (Ctrl+F1)'**
  String get ribbonCollapseTooltip;

  /// Gruppo della scheda Invia/Ricevi
  ///
  /// In it, this message translates to:
  /// **'Invia e ricevi'**
  String get groupSendReceive;

  /// Comando della scheda Invia/Ricevi
  ///
  /// In it, this message translates to:
  /// **'Invia/ricevi tutte le cartelle'**
  String get sendReceiveAll;

  /// Suggerimento di Invia/ricevi tutte le cartelle
  ///
  /// In it, this message translates to:
  /// **'Aggiorna cartelle e messaggi di tutti gli account (F9)'**
  String get sendReceiveAllTooltip;

  /// Comando di Visualizza: posizione del riquadro di lettura
  ///
  /// In it, this message translates to:
  /// **'Riquadro di lettura'**
  String get readingPane;

  /// Comando di Visualizza: righe di anteprima nella lista
  ///
  /// In it, this message translates to:
  /// **'Anteprima messaggio'**
  String get messagePreview;

  /// Anteprima messaggio: nessuna riga
  ///
  /// In it, this message translates to:
  /// **'Disattivata'**
  String get messagePreviewOff;

  /// Anteprima messaggio: numero di righe
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 riga} other{{count} righe}}'**
  String messagePreviewLines(int count);

  /// Gruppo di Visualizza
  ///
  /// In it, this message translates to:
  /// **'Messaggi'**
  String get groupMessages;

  /// Comando di Visualizza
  ///
  /// In it, this message translates to:
  /// **'Mostra come conversazioni'**
  String get showAsConversations;

  /// Suggerimento di Mostra come conversazioni, attivo
  ///
  /// In it, this message translates to:
  /// **'Attivo in questa cartella: clic per tornare alla lista semplice'**
  String get showAsConversationsOnTooltip;

  /// Suggerimento di Mostra come conversazioni, spento
  ///
  /// In it, this message translates to:
  /// **'Raccoglie in una riga le mail della stessa conversazione'**
  String get showAsConversationsOffTooltip;

  /// Suggerimento dei comandi disattivati sulle cartelle speciali
  ///
  /// In it, this message translates to:
  /// **'Posta in arrivo, Posta inviata, Posta eliminata e le altre cartelle speciali non si possono rinominare né eliminare'**
  String get specialFolderHint;

  /// Gruppo della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Nuovo'**
  String get groupNew;

  /// Comando della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Nuova cartella'**
  String get newFolder;

  /// Suggerimento di Nuova cartella
  ///
  /// In it, this message translates to:
  /// **'Crea una sottocartella della cartella selezionata'**
  String get newFolderTooltip;

  /// Gruppo della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Azioni'**
  String get groupActions;

  /// Comando della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Rinomina cartella'**
  String get renameFolder;

  /// Suggerimento di Rinomina cartella
  ///
  /// In it, this message translates to:
  /// **'Cambia il nome della cartella selezionata (F2)'**
  String get renameFolderTooltip;

  /// Comando della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Elimina cartella'**
  String get deleteFolder;

  /// Suggerimento di Elimina quando l'eliminazione è definitiva
  ///
  /// In it, this message translates to:
  /// **'Elimina dal server, senza possibilità di recupero'**
  String get deletePermanentlyTooltip;

  /// Suggerimento di Elimina cartella
  ///
  /// In it, this message translates to:
  /// **'Sposta la cartella, con il suo contenuto, in Posta eliminata'**
  String get deleteFolderTooltip;

  /// Comando della scheda Cartella (in Outlook «Elimina tutto»)
  ///
  /// In it, this message translates to:
  /// **'Svuota cartella'**
  String get emptyFolder;

  /// Suggerimento di Svuota cartella
  ///
  /// In it, this message translates to:
  /// **'Elimina dal server tutte le mail della cartella, senza possibilità di recupero'**
  String get emptyFolderTooltip;

  /// Suggerimento di Svuota cartella disattivato
  ///
  /// In it, this message translates to:
  /// **'Solo per Posta eliminata e Posta indesiderata'**
  String get emptyFolderOnlyTooltip;

  /// Gruppo della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get groupArchive;

  /// Comando della scheda Cartella
  ///
  /// In it, this message translates to:
  /// **'Imposta cartella di archiviazione'**
  String get setArchiveFolder;

  /// Suggerimento di Imposta cartella di archiviazione
  ///
  /// In it, this message translates to:
  /// **'Scegli o crea la cartella in cui Archivia sposta le mail di questo account'**
  String get setArchiveFolderTooltip;

  /// Comando della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Nuovo messaggio'**
  String get newMessage;

  /// Suggerimento di Nuovo messaggio
  ///
  /// In it, this message translates to:
  /// **'Scrivi un nuovo messaggio'**
  String get newMessageTooltip;

  /// Comando e gruppo della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// Elimina nella Posta eliminata
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get deletePermanently;

  /// Suggerimento di Elimina
  ///
  /// In it, this message translates to:
  /// **'Sposta in Posta eliminata'**
  String get moveToDeletedTooltip;

  /// Comando della scheda Home: sposta nella cartella di archiviazione
  ///
  /// In it, this message translates to:
  /// **'Archivia'**
  String get archive;

  /// Menu della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Pulisci'**
  String get cleanUp;

  /// Suggerimento di Pulisci
  ///
  /// In it, this message translates to:
  /// **'Sposta in Posta eliminata le mail superflue: quelle citate per intero da una risposta'**
  String get cleanUpTooltip;

  /// Menu della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Posta indesiderata'**
  String get junk;

  /// Suggerimento del menu Posta indesiderata
  ///
  /// In it, this message translates to:
  /// **'Blocca mittente, Non bloccare mai, Opzioni posta indesiderata'**
  String get junkTooltip;

  /// Gruppo della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Rispondi'**
  String get groupRespond;

  /// Comando e gruppo della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get move;

  /// Suggerimento di Sposta
  ///
  /// In it, this message translates to:
  /// **'Sposta in un\'altra cartella'**
  String get moveTooltip;

  /// Voce del menu Sposta
  ///
  /// In it, this message translates to:
  /// **'Altra cartella… (Ctrl+Maiusc+V)'**
  String get moveOtherFolder;

  /// Menu della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Regole'**
  String get rules;

  /// Suggerimento del menu Regole
  ///
  /// In it, this message translates to:
  /// **'Smista da sola la posta in arrivo'**
  String get rulesTooltip;

  /// Voce del menu Regole
  ///
  /// In it, this message translates to:
  /// **'Crea regola…'**
  String get createRule;

  /// Voce del menu Regole
  ///
  /// In it, this message translates to:
  /// **'Gestisci regole e avvisi…'**
  String get manageRulesEllipsis;

  /// Gruppo della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Tag'**
  String get groupTags;

  /// Comando della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Segna come non letto'**
  String get markUnread;

  /// Comando della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Segna come letto'**
  String get markRead;

  /// Menu della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Categorizza'**
  String get categorize;

  /// Suggerimento di Categorizza
  ///
  /// In it, this message translates to:
  /// **'Assegna una categoria colorata'**
  String get categorizeTooltip;

  /// Menu della scheda Home: contrassegno per completamento
  ///
  /// In it, this message translates to:
  /// **'Completa'**
  String get followUp;

  /// Suggerimento di Completa
  ///
  /// In it, this message translates to:
  /// **'Contrassegna per completamento, con una scadenza'**
  String get followUpTooltip;

  /// Gruppo della scheda Home
  ///
  /// In it, this message translates to:
  /// **'Trova'**
  String get groupFind;

  /// Comando della scheda Home e testo della casella di ricerca
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get search;

  /// Suggerimento di Cerca
  ///
  /// In it, this message translates to:
  /// **'Cerca nella posta'**
  String get searchTooltip;

  /// Scheda File (menu)
  ///
  /// In it, this message translates to:
  /// **'File'**
  String get fileTab;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Apri file .eml…'**
  String get openEml;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Salva con nome… (F12)'**
  String get saveAs;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Stampa… (Ctrl+P)'**
  String get printMessage;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Salva come PDF…'**
  String get saveAsPdf;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Risposte automatiche'**
  String get automaticReplies;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Gestisci regole e avvisi'**
  String get manageRules;

  /// Voce del menu File
  ///
  /// In it, this message translates to:
  /// **'Informazioni su PostinoVip'**
  String get aboutApp;

  /// Opzioni di visualizzazione della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Mostra sempre la barra multifunzione'**
  String get ribbonShowAlways;

  /// Opzioni di visualizzazione della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Mostra solo le schede (Ctrl+F1)'**
  String get ribbonTabsOnly;

  /// Suggerimento della freccia in alto a destra
  ///
  /// In it, this message translates to:
  /// **'Opzioni di visualizzazione della barra multifunzione'**
  String get ribbonDisplayOptions;

  /// Posizione del riquadro di lettura
  ///
  /// In it, this message translates to:
  /// **'A destra'**
  String get readingPaneRight;

  /// Posizione del riquadro di lettura
  ///
  /// In it, this message translates to:
  /// **'In basso'**
  String get readingPaneBottom;

  /// Riquadro di lettura nascosto
  ///
  /// In it, this message translates to:
  /// **'Disattivato'**
  String get readingPaneOff;

  /// Opzioni di visualizzazione della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Barra multifunzione classica'**
  String get ribbonClassic;

  /// Opzioni di visualizzazione della barra multifunzione
  ///
  /// In it, this message translates to:
  /// **'Barra multifunzione semplificata'**
  String get ribbonSimplified;

  /// Rispondi al mittente (anche titolo della finestra di composizione)
  ///
  /// In it, this message translates to:
  /// **'Rispondi'**
  String get reply;

  /// Rispondi a tutti i destinatari
  ///
  /// In it, this message translates to:
  /// **'Rispondi a tutti'**
  String get replyAll;

  /// Inoltra la mail
  ///
  /// In it, this message translates to:
  /// **'Inoltra'**
  String get forward;

  /// Suggerimento del pulsante nella barra in alto
  ///
  /// In it, this message translates to:
  /// **'Invia/ricevi tutte le cartelle (F9)'**
  String get sendReceiveAllF9;

  /// Suggerimento della ricerca. Le parole chiave (da:, a:, oggetto:, allegato:, allegati:sì/no) le interpreta il core: per ora solo quelle italiane
  ///
  /// In it, this message translates to:
  /// **'Parole (anche iniziali: \"fatt\" trova \"fattura\"), \"frase esatta\"\nda:anna   a:mario   oggetto:riunione\nallegato:pdf   allegati:sì   allegati:no'**
  String get searchHelp;

  /// Pulsante della casella di ricerca
  ///
  /// In it, this message translates to:
  /// **'Chiudi la ricerca'**
  String get searchClose;

  /// Dove cercare
  ///
  /// In it, this message translates to:
  /// **'Cartella attuale'**
  String get searchScopeFolder;

  /// Dove cercare: tutte le cartelle dell'account
  ///
  /// In it, this message translates to:
  /// **'Tutte le cartelle'**
  String get searchScopeAccount;

  /// Dove cercare: tutti gli account
  ///
  /// In it, this message translates to:
  /// **'Tutti gli account'**
  String get searchScopeAllAccounts;

  /// Barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'Posta (Ctrl+1)'**
  String get moduleMail;

  /// Barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'Calendario (Ctrl+2)'**
  String get moduleCalendar;

  /// Barra dei moduli
  ///
  /// In it, this message translates to:
  /// **'Persone (Ctrl+3)'**
  String get modulePeople;

  /// Zoom del riquadro di lettura
  ///
  /// In it, this message translates to:
  /// **'Riduci (Ctrl+-)'**
  String get zoomOut;

  /// Zoom del riquadro di lettura
  ///
  /// In it, this message translates to:
  /// **'Ingrandisci (Ctrl++)'**
  String get zoomIn;

  /// Suggerimento della percentuale di zoom
  ///
  /// In it, this message translates to:
  /// **'Zoom del riquadro di lettura: clic per tornare al 100% (Ctrl+0)'**
  String get zoomReset;

  /// Pulsante che chiude una finestra senza fare niente
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// Pulsante che chiude un avviso o una finestra
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// Pulsante che ripete un caricamento non riuscito
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// Lista vuota: nessuna cartella scelta
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella selezionata'**
  String get noFolderSelected;

  /// Titolo della ricerca: dove si cerca (la cartella)
  ///
  /// In it, this message translates to:
  /// **'in {folder}'**
  String searchWhereFolder(String folder);

  /// Titolo della ricerca: tutte le cartelle di un account
  ///
  /// In it, this message translates to:
  /// **'in tutte le cartelle di {account}'**
  String searchWhereAccount(String account);

  /// Titolo della ricerca
  ///
  /// In it, this message translates to:
  /// **'in tutte le cartelle'**
  String get searchWhereAllFolders;

  /// Titolo della ricerca
  ///
  /// In it, this message translates to:
  /// **'in tutti gli account'**
  String get searchWhereAllAccounts;

  /// Titolo della ricerca in corso; where = «in …»
  ///
  /// In it, this message translates to:
  /// **'Ricerca {where}…'**
  String searchInProgress(String where);

  /// Titolo dei risultati; where = «in …»
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 risultato} other{{count} risultati}} {where}'**
  String searchResultsTitle(int count, String where);

  /// Lista vuota con il filtro Da leggere
  ///
  /// In it, this message translates to:
  /// **'Nessun messaggio da leggere'**
  String get listNoUnread;

  /// Lista vuota
  ///
  /// In it, this message translates to:
  /// **'Cartella vuota'**
  String get listEmptyFolder;

  /// Gruppo della lista per mittente senza mittente
  ///
  /// In it, this message translates to:
  /// **'(mittente sconosciuto)'**
  String get unknownSender;

  /// Mail senza oggetto
  ///
  /// In it, this message translates to:
  /// **'(nessun oggetto)'**
  String get noSubject;

  /// Ricerca senza risultati sul computer
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato nella cache locale'**
  String get searchNoLocalResults;

  /// Striscia sopra la lista quando il server non risponde
  ///
  /// In it, this message translates to:
  /// **'Non connesso: mostro la copia sul computer. Spostare, eliminare, segnare come letto e inviare tornano disponibili da soli quando il server risponde.'**
  String get offlineStrip;

  /// Nome generico del fornitore dell'accesso OAuth2
  ///
  /// In it, this message translates to:
  /// **'il fornitore'**
  String get theProvider;

  /// Striscia rossa: token di rinnovo rifiutato
  ///
  /// In it, this message translates to:
  /// **'Accesso a {provider} scaduto: questo account non riceve né invia posta finché non accedi di nuovo.'**
  String loginExpired(String provider);

  /// Pulsante della striscia di accesso scaduto
  ///
  /// In it, this message translates to:
  /// **'Accedi di nuovo'**
  String get signInAgain;

  /// Striscia gialla sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Le risposte automatiche sono attive per questo account.'**
  String get autoReplyStrip;

  /// Pulsante che apre una finestra di modifica
  ///
  /// In it, this message translates to:
  /// **'Modifica…'**
  String get editEllipsis;

  /// Conferma dopo Disattiva
  ///
  /// In it, this message translates to:
  /// **'Risposte automatiche disattivate.'**
  String get autoReplyTurnedOff;

  /// Errore nel disattivare le risposte automatiche
  ///
  /// In it, this message translates to:
  /// **'Non disattivate: {error}'**
  String autoReplyNotTurnedOff(String error);

  /// Pulsante che spegne una funzione
  ///
  /// In it, this message translates to:
  /// **'Disattiva'**
  String get turnOff;

  /// Ricerca sul server in corso
  ///
  /// In it, this message translates to:
  /// **'Ricerca sul server…'**
  String get serverSearching;

  /// Errore della ricerca sul server
  ///
  /// In it, this message translates to:
  /// **'Ricerca sul server non riuscita: {error}'**
  String serverSearchFailed(String error);

  /// Esito della ricerca sul server
  ///
  /// In it, this message translates to:
  /// **'Il server non ha trovato altre mail.'**
  String get serverFoundNone;

  /// Esito della ricerca sul server
  ///
  /// In it, this message translates to:
  /// **'Il server ha trovato {count} mail in più (con l\'icona della nuvola).'**
  String serverFoundMore(int count);

  /// Aggiunto all'esito quando il server ne ha trovate troppe (inizia con uno spazio)
  ///
  /// In it, this message translates to:
  /// **' Mostrate le {count} più recenti.'**
  String serverTruncated(int count);

  /// Pulsante sotto i risultati
  ///
  /// In it, this message translates to:
  /// **'Cerca anche sul server'**
  String get searchServerToo;

  /// Spiegazione sotto Cerca anche sul server
  ///
  /// In it, this message translates to:
  /// **'Per le mail più vecchie del limite della cache e per Posta eliminata e Indesiderata,\ndi cui qui sono state cercate solo le intestazioni.'**
  String get searchServerHint;

  /// Suggerimento del triangolo della conversazione
  ///
  /// In it, this message translates to:
  /// **'Chiudi la conversazione'**
  String get conversationCollapse;

  /// Suggerimento del triangolo della conversazione
  ///
  /// In it, this message translates to:
  /// **'Mostra tutte le mail della conversazione'**
  String get conversationExpand;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per data: più recenti in cima'**
  String get sortDateNewest;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per data: più vecchi in cima'**
  String get sortDateOldest;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per mittente: A → Z'**
  String get sortFromAZ;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per mittente: Z → A'**
  String get sortFromZA;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per oggetto: A → Z'**
  String get sortSubjectAZ;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per oggetto: Z → A'**
  String get sortSubjectZA;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per dimensione: più grandi in cima'**
  String get sortSizeLargest;

  /// Menu dell'ordinamento sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per dimensione: più piccole in cima'**
  String get sortSizeSmallest;

  /// Ordinamento attuale, sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per data'**
  String get sortByDate;

  /// Ordinamento attuale, sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per mittente'**
  String get sortByFrom;

  /// Ordinamento attuale, sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per oggetto'**
  String get sortBySubject;

  /// Ordinamento attuale, sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Per dimensione'**
  String get sortBySize;

  /// Filtro sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get filterAll;

  /// Filtro sopra la lista
  ///
  /// In it, this message translates to:
  /// **'Da leggere'**
  String get filterUnread;

  /// Suggerimento del menu dell'ordinamento
  ///
  /// In it, this message translates to:
  /// **'Ordina per'**
  String get sortTooltip;

  /// Suggerimento dell'etichetta Conversazioni
  ///
  /// In it, this message translates to:
  /// **'Vista per conversazioni attiva in questa cartella: clic per cambiarla'**
  String get conversationBadgeTooltip;

  /// Etichetta sopra la lista con la vista per conversazioni
  ///
  /// In it, this message translates to:
  /// **'Conversazioni'**
  String get conversations;

  /// Suggerimento del numero accanto alla conversazione
  ///
  /// In it, this message translates to:
  /// **'{count} mail nella conversazione'**
  String conversationCount(int count);

  /// Suggerimento della graffetta nella lista
  ///
  /// In it, this message translates to:
  /// **'Contiene allegati'**
  String get hasAttachments;

  /// Suggerimento della bandierina
  ///
  /// In it, this message translates to:
  /// **'Contrassegnato: clic per completare'**
  String get flaggedClickToComplete;

  /// Suggerimento della bandierina con scadenza
  ///
  /// In it, this message translates to:
  /// **'Completare entro {date}: clic per completare'**
  String dueByClickToComplete(String date);

  /// Suggerimento della bandierina completata
  ///
  /// In it, this message translates to:
  /// **'Completato: clic per contrassegnare di nuovo'**
  String get completedClickToFlag;

  /// Suggerimento della bandierina vuota
  ///
  /// In it, this message translates to:
  /// **'Contrassegna per oggi'**
  String get flagToday;

  /// Suggerimento della nuvola nei risultati
  ///
  /// In it, this message translates to:
  /// **'Trovata sul server'**
  String get foundOnServer;

  /// Suggerimento delle intestazioni delle colonne
  ///
  /// In it, this message translates to:
  /// **'Ordina per {column}'**
  String sortByColumn(String column);

  /// Colonna della lista (riquadro di lettura in basso o spento)
  ///
  /// In it, this message translates to:
  /// **'Da'**
  String get columnFrom;

  /// Colonna della lista (riquadro di lettura in basso o spento)
  ///
  /// In it, this message translates to:
  /// **'Oggetto'**
  String get columnSubject;

  /// Colonna della lista (riquadro di lettura in basso o spento)
  ///
  /// In it, this message translates to:
  /// **'Ricevuto'**
  String get columnReceived;

  /// Colonna della lista (riquadro di lettura in basso o spento)
  ///
  /// In it, this message translates to:
  /// **'Dimensione'**
  String get columnSize;

  /// Colonna della lista (riquadro di lettura in basso o spento)
  ///
  /// In it, this message translates to:
  /// **'Categorie'**
  String get columnCategories;

  /// Riquadro di lettura con più mail selezionate
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 elemento selezionato} other{{count} elementi selezionati}}'**
  String selectedItems(int count);

  /// Riquadro di lettura vuoto
  ///
  /// In it, this message translates to:
  /// **'Seleziona un messaggio'**
  String get selectMessage;

  /// Riquadro di lettura senza la mail
  ///
  /// In it, this message translates to:
  /// **'Messaggio non disponibile'**
  String get messageUnavailable;

  /// Striscia della conferma di lettura
  ///
  /// In it, this message translates to:
  /// **'{sender} ha chiesto una conferma di lettura.'**
  String receiptRequested(String sender);

  /// Striscia della conferma di lettura
  ///
  /// In it, this message translates to:
  /// **'Non inviare'**
  String get receiptDecline;

  /// Striscia della conferma di lettura
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get receiptSend;

  /// Striscia sopra una bozza
  ///
  /// In it, this message translates to:
  /// **'Bozza: non ancora inviata.'**
  String get draftBanner;

  /// Pulsante della striscia della bozza
  ///
  /// In it, this message translates to:
  /// **'Modifica bozza'**
  String get editDraft;

  /// Intestazione della mail: destinatari
  ///
  /// In it, this message translates to:
  /// **'A'**
  String get headerTo;

  /// Intestazione della mail: copia
  ///
  /// In it, this message translates to:
  /// **'Cc'**
  String get headerCc;

  /// Suggerimento di una mail allegata
  ///
  /// In it, this message translates to:
  /// **'Apri \"{name}\"'**
  String openAttachment(String name);

  /// Suggerimento di un allegato
  ///
  /// In it, this message translates to:
  /// **'Salva \"{name}\"…'**
  String saveAttachment(String name);

  /// Avviso sopra la mail
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è stato inviato con priorità alta.'**
  String get importanceHighBanner;

  /// Avviso sopra la mail
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è stato inviato con priorità bassa.'**
  String get importanceLowBanner;

  /// Avviso sopra una mail della posta indesiderata
  ///
  /// In it, this message translates to:
  /// **'Questa mail è nella posta indesiderata: per sicurezza i collegamenti sono disattivati e le immagini remote bloccate. Se è una mail attendibile, riportala in Posta in arrivo.'**
  String get junkBanner;

  /// Pulsante: riporta la mail in Posta in arrivo
  ///
  /// In it, this message translates to:
  /// **'Non è posta indesiderata'**
  String get notJunk;

  /// Avviso sopra la mail
  ///
  /// In it, this message translates to:
  /// **'Immagini remote bloccate per proteggere la privacy.'**
  String get remoteImagesBlocked;

  /// Pulsante che carica le immagini remote
  ///
  /// In it, this message translates to:
  /// **'Mostra immagini'**
  String get showImages;

  /// Avviso nella vista Testo
  ///
  /// In it, this message translates to:
  /// **'Messaggio solo HTML: mostrato come testo semplificato.'**
  String get htmlOnlyAsText;

  /// Vista del corpo come testo (accanto a HTML)
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get bodyText;

  /// Conferma dopo il salvataggio di un file
  ///
  /// In it, this message translates to:
  /// **'Salvato in {path}'**
  String savedTo(String path);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Allegato non scaricato: {error}'**
  String attachmentNotDownloaded(String error);

  /// Errore del disco
  ///
  /// In it, this message translates to:
  /// **'File non scritto: {message} ({path})'**
  String fileNotWritten(String message, String path);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Mail allegata non aperta: {error}'**
  String attachedMailNotOpened(String error);

  /// Vista Testo di una mail senza corpo
  ///
  /// In it, this message translates to:
  /// **'(messaggio senza testo)'**
  String get messageWithoutText;

  /// Riga del contrassegno sotto le intestazioni
  ///
  /// In it, this message translates to:
  /// **'Completato'**
  String get completed;

  /// Riga del contrassegno sotto le intestazioni
  ///
  /// In it, this message translates to:
  /// **'Contrassegnato per completamento'**
  String get flaggedForFollowUp;

  /// Riga del contrassegno con scadenza
  ///
  /// In it, this message translates to:
  /// **'Completare entro {date}'**
  String dueBy(String date);

  /// Aggiunto alla scadenza passata (inizia con uno spazio)
  ///
  /// In it, this message translates to:
  /// **' (scaduto)'**
  String get overdueSuffix;

  /// Menu del tasto destro sulla mail
  ///
  /// In it, this message translates to:
  /// **'Aggiungi il mittente a Contatti'**
  String get addSenderToContacts;

  /// Menu del tasto destro (in Posta eliminata)
  ///
  /// In it, this message translates to:
  /// **'Interrompi Ignora conversazione'**
  String get stopIgnoringConversation;

  /// Menu del tasto destro
  ///
  /// In it, this message translates to:
  /// **'Ignora conversazione'**
  String get ignoreConversation;

  /// Menu del tasto destro
  ///
  /// In it, this message translates to:
  /// **'Pulisci conversazione'**
  String get cleanUpConversation;

  /// Errore nel preparare una risposta o una bozza
  ///
  /// In it, this message translates to:
  /// **'Bozza non disponibile: {error}'**
  String draftNotAvailable(String error);

  /// Titolo della finestra di composizione di una bozza riaperta
  ///
  /// In it, this message translates to:
  /// **'Bozza'**
  String get draftTitle;

  /// Titolo della conferma di eliminazione definitiva
  ///
  /// In it, this message translates to:
  /// **'Eliminare definitivamente?'**
  String get deletePermanentlyQuestion;

  /// Conferma di eliminazione definitiva di più mail
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 mail selezionata in Posta eliminata verrà cancellata} other{{count} mail selezionate in Posta eliminata verranno cancellate}} dal server.\nL\'operazione non è reversibile.'**
  String deletePermanentlyMany(int count);

  /// Conferma di eliminazione definitiva di una mail
  ///
  /// In it, this message translates to:
  /// **'\"{subject}\" verrà cancellato dal server.\nL\'operazione non è reversibile.'**
  String deletePermanentlyOne(String subject);

  /// Titolo della domanda quando si spegne la vista per conversazioni
  ///
  /// In it, this message translates to:
  /// **'Non mostrare come conversazioni'**
  String get dontShowAsConversations;

  /// Domanda quando si accende la vista per conversazioni
  ///
  /// In it, this message translates to:
  /// **'Le mail della stessa conversazione verranno raccolte in una riga, con le risposte che stanno in altre cartelle.\n\nApplicare a \"{folder}\" o a tutte le cartelle?'**
  String conversationsOnQuestion(String folder);

  /// Domanda quando si spegne la vista per conversazioni
  ///
  /// In it, this message translates to:
  /// **'Applicare a \"{folder}\" o a tutte le cartelle?'**
  String conversationsApplyQuestion(String folder);

  /// Pulsante: applica a tutte le cartelle
  ///
  /// In it, this message translates to:
  /// **'Tutte le cartelle'**
  String get allFolders;

  /// Pulsante: applica alla cartella aperta
  ///
  /// In it, this message translates to:
  /// **'Questa cartella'**
  String get thisFolder;

  /// Suggerimento del punto esclamativo rosso
  ///
  /// In it, this message translates to:
  /// **'Priorità alta'**
  String get importanceHigh;

  /// Suggerimento della freccia blu
  ///
  /// In it, this message translates to:
  /// **'Priorità bassa'**
  String get importanceLow;

  /// Nome della cartella INBOX (le altre cartelle tengono il nome del server)
  ///
  /// In it, this message translates to:
  /// **'Posta in arrivo'**
  String get folderInbox;

  /// Sezione in cima al riquadro delle cartelle
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get favorites;

  /// Tasto destro su una cartella
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dai Preferiti'**
  String get removeFromFavorites;

  /// Tasto destro su un Preferito
  ///
  /// In it, this message translates to:
  /// **'Sposta su'**
  String get moveUp;

  /// Tasto destro su un Preferito
  ///
  /// In it, this message translates to:
  /// **'Sposta giù'**
  String get moveDown;

  /// Tasto destro su una cartella
  ///
  /// In it, this message translates to:
  /// **'Mostra nei Preferiti'**
  String get showInFavorites;

  /// Tasto destro su una cartella
  ///
  /// In it, this message translates to:
  /// **'Pulisci cartella'**
  String get cleanUpFolder;

  /// Cartella sul computer con le mail da inviare
  ///
  /// In it, this message translates to:
  /// **'Posta in uscita'**
  String get outbox;

  /// Casella di Nuova cartella e Rinomina
  ///
  /// In it, this message translates to:
  /// **'Nome della cartella'**
  String get folderNameHint;

  /// Suggerimento dell'icona accanto all'account
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento automatico non attivo per {address}: le nuove mail compaiono solo con \"Aggiorna\"'**
  String noAutoUpdate(String address);

  /// Svuota cartella: numero non noto
  ///
  /// In it, this message translates to:
  /// **'Tutte le mail'**
  String get emptyFolderAllMails;

  /// Svuota cartella: una mail
  ///
  /// In it, this message translates to:
  /// **'L\'unica mail'**
  String get emptyFolderOnlyMail;

  /// Svuota cartella
  ///
  /// In it, this message translates to:
  /// **'Tutte le {count} mail'**
  String emptyFolderNMails(int count);

  /// Svuota cartella (inizia con uno spazio)
  ///
  /// In it, this message translates to:
  /// **' e la sottocartella, con le sue mail,'**
  String get emptyFolderOneSubfolder;

  /// Svuota cartella (inizia con uno spazio)
  ///
  /// In it, this message translates to:
  /// **' e le {count} sottocartelle, con le loro mail,'**
  String emptyFolderNSubfolders(int count);

  /// Titolo della conferma di Svuota cartella
  ///
  /// In it, this message translates to:
  /// **'Svuotare \"{folder}\"?'**
  String emptyFolderQuestion(String folder);

  /// Conferma di Svuota cartella; mails e also dalle voci emptyFolder…
  ///
  /// In it, this message translates to:
  /// **'{mails} di \"{folder}\"{also} verranno cancellate dal server.\nL\'operazione non è reversibile.'**
  String emptyFolderContent(String mails, String folder, String also);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare definitivamente la cartella?'**
  String get deleteFolderPermanentlyQuestion;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare la cartella?'**
  String get deleteFolderQuestion;

  /// Conferma di Elimina cartella in Posta eliminata
  ///
  /// In it, this message translates to:
  /// **'La cartella \"{folder}\", con tutte le mail e le sottocartelle, verrà cancellata dal server.\nL\'operazione non è reversibile.'**
  String deleteFolderPermanentlyContent(String folder);

  /// Conferma di Elimina cartella
  ///
  /// In it, this message translates to:
  /// **'La cartella \"{folder}\", con tutte le mail e le sottocartelle, verrà spostata in Posta eliminata.'**
  String deleteFolderContent(String folder);

  /// Scheda e titolo della finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Messaggio'**
  String get messageTab;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Elimina dal server, senza possibilità di recupero (poi la mail successiva)'**
  String get windowDeletePermanentlyTooltip;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Sposta in Posta eliminata e apri la mail successiva (Canc)'**
  String get windowDeleteTooltip;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Sposta nella cartella di archiviazione e apri la mail successiva'**
  String get windowArchiveTooltip;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Sposta in un\'altra cartella e apri la mail successiva'**
  String get windowMoveTooltip;

  /// Finestra della mail (nella finestra principale «Segna come non letto»)
  ///
  /// In it, this message translates to:
  /// **'Segna come da leggere'**
  String get markUnreadWindow;

  /// Gruppo della finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Zoom'**
  String get groupZoom;

  /// Pulsante dello zoom nella finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Zoom ({percent}%)'**
  String zoomPercent(int percent);

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Ingrandisci o riduci il testo della mail (Ctrl+rotella, Ctrl++, Ctrl+-, Ctrl+0)'**
  String get zoomTooltip;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Elemento precedente (Ctrl+,)'**
  String get previousItem;

  /// Finestra della mail
  ///
  /// In it, this message translates to:
  /// **'Elemento successivo (Ctrl+.)'**
  String get nextItem;

  /// Pulsante di chiusura delle finestre interne
  ///
  /// In it, this message translates to:
  /// **'Chiudi (Esc)'**
  String get closeEsc;

  /// Errore di Salva con nome
  ///
  /// In it, this message translates to:
  /// **'Mail non salvata: {error}'**
  String messageNotSaved(String error);

  /// Tipo di file nella finestra Apri file .eml
  ///
  /// In it, this message translates to:
  /// **'Messaggi di posta'**
  String get emlFilesLabel;

  /// Errore nell'aprire un file .eml
  ///
  /// In it, this message translates to:
  /// **'{name} non aperto: {reason}'**
  String fileNotOpened(String name, String reason);

  /// Finestra di un file .eml
  ///
  /// In it, this message translates to:
  /// **'Sola lettura'**
  String get readOnly;

  /// Pulsante della finestra di un file .eml
  ///
  /// In it, this message translates to:
  /// **'Salva con nome…'**
  String get saveAsShort;

  /// Titolo della finestra Sposta
  ///
  /// In it, this message translates to:
  /// **'Sposta elementi'**
  String get moveItems;

  /// Finestra Sposta elementi
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Sposta l\'elemento selezionato nella cartella:} other{Sposta i {count} elementi selezionati nella cartella:}}'**
  String moveItemsTo(int count);

  /// Finestra Sposta elementi
  ///
  /// In it, this message translates to:
  /// **'Cerca una cartella'**
  String get searchFolder;

  /// Finestra Sposta elementi
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella con questo nome'**
  String get noFolderWithName;

  /// Durata
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 minuto} other{{count} minuti}}'**
  String durationMinutes(int count);

  /// Durata
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 ora} other{{count} ore}}'**
  String durationHours(int count);

  /// Durata
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 giorno} other{{count} giorni}}'**
  String durationDays(int count);

  /// Durata
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 settimana} other{{count} settimane}}'**
  String durationWeeks(int count);

  /// Titolo della notifica di un promemoria
  ///
  /// In it, this message translates to:
  /// **'Promemoria: {title}'**
  String reminderNotification(String title);

  /// Titolo della finestra Promemoria e della notifica
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 promemoria} other{{count} promemoria}}'**
  String remindersCount(int count);

  /// Scadenza di un promemoria
  ///
  /// In it, this message translates to:
  /// **'Giornata intera, oggi'**
  String get reminderAllDayToday;

  /// Scadenza di un promemoria
  ///
  /// In it, this message translates to:
  /// **'Giornata intera, domani'**
  String get reminderAllDayTomorrow;

  /// Scadenza di un promemoria (count > 1)
  ///
  /// In it, this message translates to:
  /// **'Giornata intera, tra {count} giorni'**
  String reminderAllDayIn(int count);

  /// Scadenza di un promemoria
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Giornata intera, iniziata da 1 giorno} other{Giornata intera, iniziata da {count} giorni}}'**
  String reminderAllDayStarted(int count);

  /// Scadenza di un promemoria
  ///
  /// In it, this message translates to:
  /// **'Adesso'**
  String get reminderNow;

  /// Scadenza passata di un promemoria; span = durata
  ///
  /// In it, this message translates to:
  /// **'Iniziato da {span}'**
  String reminderStartedAgo(String span);

  /// Scadenza futura di un promemoria; span = durata
  ///
  /// In it, this message translates to:
  /// **'Tra {span}'**
  String reminderIn(String span);

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Inizio: {when}'**
  String reminderStart(String when);

  /// Finestra Promemoria (inizia con quattro spazi)
  ///
  /// In it, this message translates to:
  /// **'    Luogo: {location}'**
  String reminderLocation(String location);

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Ignora tutto'**
  String get dismissAll;

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Apri elemento'**
  String get openItem;

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get dismiss;

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Fare clic su Rimanda per ricevere un nuovo promemoria tra:'**
  String get snoozeHint;

  /// Finestra Promemoria
  ///
  /// In it, this message translates to:
  /// **'Rimanda'**
  String get snooze;

  /// Titolo della notifica; suffix = « · account» o vuoto
  ///
  /// In it, this message translates to:
  /// **'Nuova mail da {sender}{suffix}'**
  String newMailFrom(String sender, String suffix);

  /// Fine del testo della notifica con più mail (inizia con un a capo)
  ///
  /// In it, this message translates to:
  /// **'\n…e altre {count}'**
  String newMailMore(int count);

  /// Titolo della notifica con più mail
  ///
  /// In it, this message translates to:
  /// **'{count} nuove mail{suffix}'**
  String newMailCount(int count, String suffix);

  /// Pulsante delle notifiche su Linux (alcuni desktop lo mostrano); vale la lingua all'avvio
  ///
  /// In it, this message translates to:
  /// **'Apri mail'**
  String get openMailAction;

  /// Vista del calendario
  ///
  /// In it, this message translates to:
  /// **'Giorno'**
  String get viewDay;

  /// Vista del calendario
  ///
  /// In it, this message translates to:
  /// **'Settimana lavorativa'**
  String get viewWorkWeek;

  /// Vista del calendario
  ///
  /// In it, this message translates to:
  /// **'Settimana'**
  String get viewWeek;

  /// Vista del calendario
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get viewMonth;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Blu'**
  String get colorBlue;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Verde'**
  String get colorGreen;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Arancione'**
  String get colorOrange;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Viola'**
  String get colorPurple;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Verde acqua'**
  String get colorTeal;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Rosa'**
  String get colorPink;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Oro'**
  String get colorGold;

  /// Colore di un calendario
  ///
  /// In it, this message translates to:
  /// **'Grigio'**
  String get colorGray;

  /// Titolo della domanda
  ///
  /// In it, this message translates to:
  /// **'Eliminare un appuntamento ricorrente'**
  String get deleteRecurringTitle;

  /// Titolo della domanda
  ///
  /// In it, this message translates to:
  /// **'Aprire un appuntamento ricorrente'**
  String get openRecurringTitle;

  /// Domanda
  ///
  /// In it, this message translates to:
  /// **'Eliminare solo questa occorrenza o tutta la serie?'**
  String get deleteRecurringQuestion;

  /// Domanda
  ///
  /// In it, this message translates to:
  /// **'È un appuntamento ricorrente. Aprire solo questa occorrenza o tutta la serie?'**
  String get openRecurringQuestion;

  /// Pulsante della domanda sugli appuntamenti ricorrenti
  ///
  /// In it, this message translates to:
  /// **'Tutta la serie'**
  String get entireSeries;

  /// Pulsante della domanda sugli appuntamenti ricorrenti
  ///
  /// In it, this message translates to:
  /// **'Solo questa'**
  String get justThisOne;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Appuntamento non disponibile: {error}'**
  String appointmentNotAvailable(String error);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'appuntamento?'**
  String get deleteAppointmentQuestion;

  /// Conferma di eliminazione
  ///
  /// In it, this message translates to:
  /// **'«{title}» viene eliminato; con la sincronizzazione anche dal server. Non si può recuperare.'**
  String deleteAppointmentContent(String title);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Appuntamento non eliminato: {error}'**
  String appointmentNotDeleted(String error);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Caricare gli appuntamenti sul server?'**
  String get uploadAppointmentsQuestion;

  /// Conferma del caricamento
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un appuntamento è solo su questo computer. Verrà aggiunto} other{{count} appuntamenti sono solo su questo computer. Verranno aggiunti}} al calendario del server e da allora sincronizzati.\n\nGli appuntamenti già presenti sul server non vengono modificati.'**
  String uploadAppointmentsContent(int count);

  /// Pulsante della conferma
  ///
  /// In it, this message translates to:
  /// **'Carica sul server'**
  String get uploadToServer;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Appuntamenti non caricati: {error}'**
  String appointmentsNotUploaded(String error);

  /// Comando del Calendario
  ///
  /// In it, this message translates to:
  /// **'Nuovo appuntamento'**
  String get newAppointment;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Nuovo appuntamento (Ctrl+N)'**
  String get newAppointmentTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elimina l\'appuntamento selezionato (Canc)'**
  String get deleteSelectedAppointmentTooltip;

  /// Gruppo del Calendario
  ///
  /// In it, this message translates to:
  /// **'Vai a'**
  String get groupGoTo;

  /// Comando del Calendario
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get today;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Torna a oggi'**
  String get todayTooltip;

  /// Comando del Calendario
  ///
  /// In it, this message translates to:
  /// **'Prossimi 7 giorni'**
  String get next7Days;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Sette giorni a partire da oggi'**
  String get next7DaysTooltip;

  /// Gruppo del Calendario
  ///
  /// In it, this message translates to:
  /// **'Disponi'**
  String get groupArrange;

  /// Gruppo del Calendario
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione'**
  String get groupSync;

  /// Comando del Calendario
  ///
  /// In it, this message translates to:
  /// **'Sincronizza'**
  String get sync;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Sincronizza subito i calendari con il server (F9)'**
  String get syncCalendarsTooltip;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Appuntamenti non disponibili: {error}'**
  String appointmentsNotAvailable(String error);

  /// Striscia gialla del calendario
  ///
  /// In it, this message translates to:
  /// **'{name}: {count, plural, =1{un appuntamento è} other{{count} appuntamenti sono}} solo su questo computer, non ancora sul server.'**
  String uploadStrip(String name, int count);

  /// Pulsante della striscia
  ///
  /// In it, this message translates to:
  /// **'Carica sul server…'**
  String get uploadToServerEllipsis;

  /// Calendario vuoto (finisce con uno spazio)
  ///
  /// In it, this message translates to:
  /// **'Nessun appuntamento in questo periodo. '**
  String get calendarEmpty;

  /// Calendario vuoto senza sincronizzazione (finisce con uno spazio)
  ///
  /// In it, this message translates to:
  /// **'Per vedere quelli del server attiva «Sincronizza il calendario con il server (CalDAV)» in File → Opzioni → Account → Modifica. '**
  String get calendarEmptySyncHint;

  /// Calendario vuoto
  ///
  /// In it, this message translates to:
  /// **'Per crearne uno: «Nuovo appuntamento» (Ctrl+N) o doppio clic su uno spazio vuoto.'**
  String get calendarEmptyCreate;

  /// Freccia del calendario
  ///
  /// In it, this message translates to:
  /// **'Precedente'**
  String get previous;

  /// Freccia del calendario
  ///
  /// In it, this message translates to:
  /// **'Successivo'**
  String get next;

  /// Riquadro di sinistra del calendario
  ///
  /// In it, this message translates to:
  /// **'I miei calendari'**
  String get myCalendars;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Per vedere gli appuntamenti del server: File → Opzioni → Account → Modifica → «Sincronizza il calendario con il server (CalDAV)»'**
  String get localOnlyTooltip;

  /// Calendario non sincronizzato
  ///
  /// In it, this message translates to:
  /// **'Solo su questo computer'**
  String get localOnly;

  /// Menu del tasto destro su un calendario
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get color;

  /// Suggerimento del lucchetto
  ///
  /// In it, this message translates to:
  /// **'Sola lettura: gli appuntamenti si vedono ma non si modificano'**
  String get calendarReadOnlyTooltip;

  /// Suggerimento della nuvola
  ///
  /// In it, this message translates to:
  /// **'Sincronizzato con il server'**
  String get syncedWithServer;

  /// Calendarietto
  ///
  /// In it, this message translates to:
  /// **'Mese precedente'**
  String get previousMonth;

  /// Calendarietto
  ///
  /// In it, this message translates to:
  /// **'Mese successivo'**
  String get nextMonth;

  /// Suggerimento della linea rossa dell'ora attuale
  ///
  /// In it, this message translates to:
  /// **'Adesso ({time})'**
  String nowAt(String time);

  /// Vista Mese: appuntamenti che non ci stanno
  ///
  /// In it, this message translates to:
  /// **'+{count} altri'**
  String moreItems(int count);

  /// Stato della sincronizzazione di calendari e contatti
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione in corso…'**
  String get syncing;

  /// Stato della sincronizzazione
  ///
  /// In it, this message translates to:
  /// **'Sincronizzata'**
  String get synced;

  /// Stato della sincronizzazione (oggi)
  ///
  /// In it, this message translates to:
  /// **'Sincronizzata alle {time}'**
  String syncedAt(String time);

  /// Stato della sincronizzazione (un altro giorno)
  ///
  /// In it, this message translates to:
  /// **'Sincronizzata il {date} alle {time}'**
  String syncedOnAt(String date, String time);

  /// Stato della sincronizzazione (il testo italiano dice «dei contatti» anche per i calendari)
  ///
  /// In it, this message translates to:
  /// **'Server dei contatti non raggiungibile'**
  String get syncServerUnreachable;

  /// Stato della sincronizzazione
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non disponibile'**
  String get syncUnavailable;

  /// Stato della sincronizzazione
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non riuscita'**
  String get syncFailed;

  /// Errore nella finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'La fine è prima dell\'inizio.'**
  String get endBeforeStart;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa occorrenza?'**
  String get deleteOccurrenceQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'Solo questa occorrenza viene tolta dalla serie; le altre restano. Non si può recuperare.'**
  String get deleteOccurrenceContent;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'L\'appuntamento (con tutte le sue occorrenze, se è ricorrente) viene eliminato; con la sincronizzazione anche dal server. Non si può recuperare.'**
  String get deleteSeriesContent;

  /// Titolo della domanda alla chiusura
  ///
  /// In it, this message translates to:
  /// **'Salvare le modifiche?'**
  String get saveChangesQuestion;

  /// Domanda alla chiusura
  ///
  /// In it, this message translates to:
  /// **'Le modifiche all\'appuntamento non sono state salvate.'**
  String get appointmentNotSavedContent;

  /// Risposta
  ///
  /// In it, this message translates to:
  /// **'No'**
  String get no;

  /// Risposta
  ///
  /// In it, this message translates to:
  /// **'Sì'**
  String get yes;

  /// Titolo di un appuntamento senza oggetto
  ///
  /// In it, this message translates to:
  /// **'Senza titolo'**
  String get untitled;

  /// Scheda e titolo della finestra di una sola occorrenza
  ///
  /// In it, this message translates to:
  /// **'Occorrenza'**
  String get occurrence;

  /// Scheda e titolo della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Appuntamento'**
  String get appointment;

  /// Comando della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Salva e chiudi'**
  String get saveAndClose;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Salva e chiudi (Ctrl+S)'**
  String get saveAndCloseTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elimina solo questa occorrenza'**
  String get deleteOnlyOccurrenceTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elimina l\'appuntamento'**
  String get deleteAppointmentTooltip;

  /// Gruppo della barra (Appuntamento, composizione)
  ///
  /// In it, this message translates to:
  /// **'Opzioni'**
  String get groupOptions;

  /// Comando della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Ricorrenza'**
  String get recurrence;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Rendi ricorrente o cambia la ricorrenza'**
  String get recurrenceTooltip;

  /// Pulsante della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get reminder;

  /// Pulsante del promemoria con la scelta attuale
  ///
  /// In it, this message translates to:
  /// **'Promemoria: {value}'**
  String reminderValue(String value);

  /// Promemoria: nessuno
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get reminderNone;

  /// Promemoria: all'inizio dell'appuntamento
  ///
  /// In it, this message translates to:
  /// **'All\'inizio'**
  String get reminderAtStart;

  /// Ricorrenza che l'app non sa modificare
  ///
  /// In it, this message translates to:
  /// **'Ricorrenza personalizzata ({rule}): resta com\'è salvando'**
  String customRecurrence(String rule);

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Il calendario «{calendar}» è di sola lettura: l\'appuntamento si può vedere ma non modificare.'**
  String calendarReadOnly(String calendar);

  /// Campo della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Luogo'**
  String get location;

  /// Campo della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Inizio'**
  String get startTime;

  /// Campo della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get endTime;

  /// Casella della finestra Appuntamento
  ///
  /// In it, this message translates to:
  /// **'Giornata intera'**
  String get allDayEvent;

  /// Riga sotto le date
  ///
  /// In it, this message translates to:
  /// **'Ricorrenza: {text}'**
  String recurrenceValue(String text);

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Solo questa occorrenza della serie: le altre non cambiano.'**
  String get onlyThisOccurrenceHint;

  /// Campo delle note
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get notes;

  /// Settimana del mese nella ricorrenza («il primo lunedì»)
  ///
  /// In it, this message translates to:
  /// **'primo'**
  String get weekFirst;

  /// Settimana del mese nella ricorrenza («il primo lunedì»)
  ///
  /// In it, this message translates to:
  /// **'secondo'**
  String get weekSecond;

  /// Settimana del mese nella ricorrenza («il primo lunedì»)
  ///
  /// In it, this message translates to:
  /// **'terzo'**
  String get weekThird;

  /// Settimana del mese nella ricorrenza («il primo lunedì»)
  ///
  /// In it, this message translates to:
  /// **'quarto'**
  String get weekFourth;

  /// Settimana del mese nella ricorrenza («il primo lunedì»)
  ///
  /// In it, this message translates to:
  /// **'ultimo'**
  String get weekLast;

  /// Errore della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Ripetizione non valida (ogni 1–999).'**
  String get recurrenceBadInterval;

  /// Errore della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Numero di occorrenze non valido (1–999).'**
  String get recurrenceBadCount;

  /// Errore della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Scegliere almeno un giorno della settimana.'**
  String get recurrenceNoDays;

  /// Ricorrenza giornaliera; [n] = casella del numero (non tradurre i nomi tra parentesi quadre)
  ///
  /// In it, this message translates to:
  /// **'Ogni [n] giorni'**
  String get recurEveryNDays;

  /// Ricorrenza giornaliera
  ///
  /// In it, this message translates to:
  /// **'Ogni giorno feriale'**
  String get recurEveryWeekday;

  /// Ricorrenza settimanale; [n] = casella del numero
  ///
  /// In it, this message translates to:
  /// **'Ricorre ogni [n] settimane il:'**
  String get recurEveryNWeeksOn;

  /// Ricorrenza mensile; [day] e [n] = caselle
  ///
  /// In it, this message translates to:
  /// **'Il giorno [day] ogni [n] mesi'**
  String get recurMonthlyDay;

  /// Ricorrenza mensile; [week] = primo…ultimo, [weekday] = giorno della settimana
  ///
  /// In it, this message translates to:
  /// **'Il [week] [weekday] ogni mese'**
  String get recurMonthlyWeekday;

  /// Ricorrenza annuale; l'ordine delle caselle segue la lingua
  ///
  /// In it, this message translates to:
  /// **'Ogni [day] [month]'**
  String get recurYearlyDay;

  /// Ricorrenza annuale
  ///
  /// In it, this message translates to:
  /// **'Il [week] [weekday] di [month]'**
  String get recurYearlyWeekday;

  /// Titolo della finestra della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Ricorrenza appuntamento'**
  String get appointmentRecurrence;

  /// Finestra della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Criterio di ricorrenza'**
  String get recurrencePattern;

  /// Frequenza della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Giornaliera'**
  String get recurDaily;

  /// Frequenza della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Settimanale'**
  String get recurWeekly;

  /// Frequenza della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Mensile'**
  String get recurMonthly;

  /// Frequenza della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Annuale'**
  String get recurYearly;

  /// Finestra della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Intervallo ricorrenza'**
  String get recurrenceRange;

  /// Fine della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Nessuna data di fine'**
  String get recurNoEnd;

  /// Fine della ricorrenza; [n] = casella
  ///
  /// In it, this message translates to:
  /// **'Termina dopo [n] occorrenze'**
  String get recurEndAfter;

  /// Fine della ricorrenza; [date] = pulsante della data
  ///
  /// In it, this message translates to:
  /// **'Termina entro [date]'**
  String get recurEndBy;

  /// Pulsante della finestra della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'Rimuovi ricorrenza'**
  String get removeRecurrence;

  /// Dopo Invia con Ritarda recapito
  ///
  /// In it, this message translates to:
  /// **'Messaggio nella Posta in uscita: verrà inviato dopo il {when} (con l\'app aperta).'**
  String queuedSendAfter(String when);

  /// Dopo Invia senza connessione
  ///
  /// In it, this message translates to:
  /// **'Senza connessione: il messaggio è nella Posta in uscita e partirà da solo appena il server risponde.'**
  String get queuedOffline;

  /// Titolo dell'avviso
  ///
  /// In it, this message translates to:
  /// **'Messaggio inviato, copia non salvata'**
  String get sentCopyNotSavedTitle;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'La mail è stata inviata, ma la copia in Posta inviata non è stata salvata:\n{error}\n\nNon reinviarla: i destinatari l\'hanno già ricevuta.'**
  String sentCopyNotSaved(String error);

  /// Parte dell'esito dell'invio (inizia con uno spazio)
  ///
  /// In it, this message translates to:
  /// **' e salvato in \"{folder}\"'**
  String sentSavedIn(String folder);

  /// Esito dell'invio; where = « e salvato in …» o vuoto
  ///
  /// In it, this message translates to:
  /// **'Messaggio inviato{where}. Server: {response}'**
  String messageSent(String where, String response);

  /// Titolo della finestra di composizione
  ///
  /// In it, this message translates to:
  /// **'Nuovo messaggio'**
  String get newMessageTitle;

  /// Titolo della domanda
  ///
  /// In it, this message translates to:
  /// **'Passare a testo normale?'**
  String get toPlainTextQuestion;

  /// Domanda
  ///
  /// In it, this message translates to:
  /// **'La formattazione e le immagini nel testo andranno perse, anche tornando a HTML. Il messaggio originale citato verrà aggiunto come testo.'**
  String get toPlainTextContent;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get continueButton;

  /// Barra del titolo della composizione
  ///
  /// In it, this message translates to:
  /// **'Salvataggio della bozza…'**
  String get savingDraft;

  /// Scheda della composizione
  ///
  /// In it, this message translates to:
  /// **'Inserisci'**
  String get tabInsert;

  /// Scheda della composizione
  ///
  /// In it, this message translates to:
  /// **'Formato testo'**
  String get tabFormatText;

  /// Comando della composizione
  ///
  /// In it, this message translates to:
  /// **'Allega file'**
  String get attachFile;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Allega uno o più file dal computer'**
  String get attachFileTooltip;

  /// Comando della composizione
  ///
  /// In it, this message translates to:
  /// **'Salva copia in Posta inviata'**
  String get saveSentCopy;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Attivo: dopo l\'invio una copia va in Posta inviata (clic per non salvarla)'**
  String get saveSentCopyOnTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Non attivo: dopo l\'invio nessuna copia in Posta inviata (clic per salvarla)'**
  String get saveSentCopyOffTooltip;

  /// Comando della composizione
  ///
  /// In it, this message translates to:
  /// **'Salva bozza'**
  String get saveDraft;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Salva in Bozze (Ctrl+S); anche da sola ogni 3 minuti'**
  String get saveDraftTooltip;

  /// Comando e titolo della finestra
  ///
  /// In it, this message translates to:
  /// **'Ritarda recapito'**
  String get delayDelivery;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Non inviare prima di una data e un\'ora (resta nella Posta in uscita)'**
  String get delayDeliveryTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Invio dopo il {when}: clic per cambiare'**
  String delayDeliveryActiveTooltip(String when);

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Segna il messaggio come importante (clic di nuovo per toglierlo)'**
  String get importanceHighTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Segna il messaggio come poco importante (clic di nuovo per toglierlo)'**
  String get importanceLowTooltip;

  /// Gruppo della composizione
  ///
  /// In it, this message translates to:
  /// **'Includi'**
  String get groupInclude;

  /// Gruppo della composizione
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get groupSave;

  /// Gruppo della composizione
  ///
  /// In it, this message translates to:
  /// **'Mostra campi'**
  String get groupShowFields;

  /// Campo e comando: copia conoscenza nascosta
  ///
  /// In it, this message translates to:
  /// **'Ccn'**
  String get bcc;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Copia conoscenza nascosta: i destinatari in Ccn non si vedono tra loro né dagli altri'**
  String get bccTooltip;

  /// Gruppo della composizione
  ///
  /// In it, this message translates to:
  /// **'Rilevamento'**
  String get groupTracking;

  /// Comando della composizione
  ///
  /// In it, this message translates to:
  /// **'Richiedi conferma di lettura'**
  String get requestReadReceipt;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Attivo: il destinatario può mandarti una conferma quando legge il messaggio (clic per toglierlo)'**
  String get requestReadReceiptOnTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Chiedi al destinatario una conferma quando legge il messaggio (può rifiutarla)'**
  String get requestReadReceiptOffTooltip;

  /// Gruppo della composizione
  ///
  /// In it, this message translates to:
  /// **'Altre opzioni'**
  String get groupMoreOptions;

  /// Gruppo della scheda Formato testo
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get groupFormat;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Testo formattato, con immagini e collegamenti'**
  String get formatHtmlTooltip;

  /// Formato del messaggio
  ///
  /// In it, this message translates to:
  /// **'Testo normale'**
  String get plainText;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Solo testo, senza formattazione: lo leggono tutti i programmi di posta'**
  String get plainTextTooltip;

  /// Voce del menu Firma
  ///
  /// In it, this message translates to:
  /// **'Firme…'**
  String get signaturesEllipsis;

  /// Menu della composizione
  ///
  /// In it, this message translates to:
  /// **'Firma'**
  String get signature;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Inserisci una firma, o crea e modifica le firme'**
  String get signatureTooltip;

  /// Etichetta degli allegati della composizione
  ///
  /// In it, this message translates to:
  /// **'Allegati'**
  String get attachments;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Allegato del messaggio originale'**
  String get originalAttachment;

  /// Suggerimento della crocetta di un allegato
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get remove;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Allegati troppo grandi: {size}, massimo {max}.'**
  String attachmentsTooLarge(String size, String max);

  /// Testo segnaposto dell'editor
  ///
  /// In it, this message translates to:
  /// **'Testo del messaggio'**
  String get messageBody;

  /// Testo segnaposto dei campi A, Cc, Ccn
  ///
  /// In it, this message translates to:
  /// **'indirizzi separati da virgola'**
  String get addressesHint;

  /// Campo Da
  ///
  /// In it, this message translates to:
  /// **'(account non disponibile)'**
  String get accountUnavailable;

  /// Sopra la citazione
  ///
  /// In it, this message translates to:
  /// **'Messaggio originale (viene aggiunto in fondo, com\'è)'**
  String get originalMessageQuote;

  /// Pulsante sopra la citazione
  ///
  /// In it, this message translates to:
  /// **'Rimuovi citazione'**
  String get removeQuote;

  /// Errore dell'invio senza connessione
  ///
  /// In it, this message translates to:
  /// **'Non connesso al server e il messaggio originale (citazione o allegati) non è sul computer: la mail non è stata inviata e resta qui. Riprova quando torna la connessione.'**
  String get offlineSendMessage;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Invio non riuscito: {error}'**
  String sendFailed(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Bozza non salvata: allegati oltre {max}.'**
  String draftTooLarge(String max);

  /// Barra del titolo della composizione
  ///
  /// In it, this message translates to:
  /// **'Bozza salvata sul computer alle {time}: andrà in Bozze quando il server risponde'**
  String draftSavedLocally(String time);

  /// Barra del titolo della composizione
  ///
  /// In it, this message translates to:
  /// **'Bozza salvata alle {time}'**
  String draftSavedAt(String time);

  /// Barra del titolo della composizione
  ///
  /// In it, this message translates to:
  /// **'Bozza non salvata'**
  String get draftNotSaved;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Bozza non salvata: {error}'**
  String draftNotSavedError(String error);

  /// Titolo della conferma d'invio
  ///
  /// In it, this message translates to:
  /// **'Inviare il messaggio?'**
  String get sendQuestion;

  /// Riepilogo dell'invio
  ///
  /// In it, this message translates to:
  /// **'Copia in Posta inviata: {value}'**
  String sendSummaryCopy(String value);

  /// Riepilogo dell'invio
  ///
  /// In it, this message translates to:
  /// **'Recapito: non prima del {when}'**
  String sendSummaryDelivery(String when);

  /// Riepilogo dell'invio
  ///
  /// In it, this message translates to:
  /// **'Attenzione: l\'oggetto è vuoto.'**
  String get emptySubjectWarning;

  /// Riepilogo dell'invio: nessun allegato
  ///
  /// In it, this message translates to:
  /// **'nessuno'**
  String get attachmentsNone;

  /// Riepilogo dell'invio (inizia con una virgola)
  ///
  /// In it, this message translates to:
  /// **', file dal disco {size}'**
  String attachmentsFromDisk(String size);

  /// Domanda alla chiusura
  ///
  /// In it, this message translates to:
  /// **'Il messaggio non è stato inviato. Salvarlo in Bozze per finirlo dopo?'**
  String get composeSaveNew;

  /// Domanda alla chiusura
  ///
  /// In it, this message translates to:
  /// **'Il messaggio non è stato inviato. Salvare le ultime modifiche nella bozza?'**
  String get composeSaveExisting;

  /// Pulsante Invia durante l'invio
  ///
  /// In it, this message translates to:
  /// **'Invio…'**
  String get sending;

  /// Finestra Ritarda recapito
  ///
  /// In it, this message translates to:
  /// **'Non recapitare prima del:'**
  String get doNotDeliverBefore;

  /// Finestra Ritarda recapito
  ///
  /// In it, this message translates to:
  /// **'Dopo \"Invia\" la mail resta nella Posta in uscita e parte da sola a quell\'ora, se l\'app è aperta.'**
  String get delayDeliveryHint;

  /// Finestra Ritarda recapito
  ///
  /// In it, this message translates to:
  /// **'Scegli un momento nel futuro.'**
  String get chooseFutureTime;

  /// Pulsante della finestra Ritarda recapito
  ///
  /// In it, this message translates to:
  /// **'Nessun ritardo'**
  String get noDelay;

  /// Errore del campo A
  ///
  /// In it, this message translates to:
  /// **'Indicare almeno un destinatario'**
  String get recipientRequired;

  /// Errore dei campi degli indirizzi
  ///
  /// In it, this message translates to:
  /// **'Indirizzo non valido: {address}'**
  String invalidAddress(String address);

  /// Suggerimento nell'elenco dei completamenti
  ///
  /// In it, this message translates to:
  /// **'Non suggerire più questo indirizzo'**
  String get dontSuggestAddress;

  /// Elenco dei completamenti vuoto
  ///
  /// In it, this message translates to:
  /// **'Nessun altro suggerimento'**
  String get noMoreSuggestions;

  /// Spiegazione in cima alla Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Posta in uscita: mail sul computer che partono da sole quando è il momento e il server risponde, con l\'app aperta.'**
  String get outboxHint;

  /// Posta in uscita vuota
  ///
  /// In it, this message translates to:
  /// **'Nessuna mail in attesa di invio'**
  String get outboxEmpty;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare la mail?'**
  String get deleteOutboxQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'\"{subject}\" non verrà inviata.'**
  String deleteOutboxContent(String subject);

  /// Stato nella Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Non inviata: {error}'**
  String outboxNotSent(String error);

  /// Stato nella Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Invio dopo il {when}'**
  String outboxSendAfter(String when);

  /// Stato nella Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'In attesa di connessione'**
  String get outboxWaiting;

  /// Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'(nessun destinatario)'**
  String get noRecipients;

  /// Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Invia ora'**
  String get sendNow;

  /// Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Sposta in Bozze (per modificarla)'**
  String get moveToDrafts;

  /// Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Elimina (non verrà inviata)'**
  String get deleteOutboxTooltip;

  /// Valore sì in un riepilogo (minuscolo, dopo i due punti)
  ///
  /// In it, this message translates to:
  /// **'sì'**
  String get yesValue;

  /// Valore no in un riepilogo (minuscolo, dopo i due punti)
  ///
  /// In it, this message translates to:
  /// **'no'**
  String get noValue;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Automatico'**
  String get fontColorAutomatic;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Rosso scuro'**
  String get fontColorDarkRed;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Rosso'**
  String get fontColorRed;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Arancione'**
  String get fontColorOrange;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Giallo'**
  String get fontColorYellow;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Verde chiaro'**
  String get fontColorLightGreen;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Verde'**
  String get fontColorGreen;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Azzurro'**
  String get fontColorLightBlue;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Blu'**
  String get fontColorBlue;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Blu scuro'**
  String get fontColorDarkBlue;

  /// Colore del carattere (palette standard di Office)
  ///
  /// In it, this message translates to:
  /// **'Viola'**
  String get fontColorPurple;

  /// Al posto di un'immagine remota nell'editor
  ///
  /// In it, this message translates to:
  /// **'[immagine da internet]'**
  String get remoteImagePlaceholder;

  /// Gruppo della scheda Messaggio
  ///
  /// In it, this message translates to:
  /// **'Testo base'**
  String get groupBasicText;

  /// Gruppo della scheda Formato testo e suggerimento del menu del carattere
  ///
  /// In it, this message translates to:
  /// **'Carattere'**
  String get groupFont;

  /// Gruppo della scheda Formato testo
  ///
  /// In it, this message translates to:
  /// **'Paragrafo'**
  String get groupParagraph;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Collegamento (Ctrl+K)'**
  String get linkTooltip;

  /// Suggerimento (firme)
  ///
  /// In it, this message translates to:
  /// **'Immagine da file (es. un logo)'**
  String get imageFromFile;

  /// Carattere predefinito
  ///
  /// In it, this message translates to:
  /// **'Calibri (predefinito)'**
  String get defaultFont;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Dimensione carattere'**
  String get fontSize;

  /// Suggerimento del comando di formato
  ///
  /// In it, this message translates to:
  /// **'Grassetto (Ctrl+B)'**
  String get bold;

  /// Suggerimento del comando di formato
  ///
  /// In it, this message translates to:
  /// **'Corsivo (Ctrl+I)'**
  String get italic;

  /// Suggerimento del comando di formato
  ///
  /// In it, this message translates to:
  /// **'Sottolineato (Ctrl+U)'**
  String get underline;

  /// Suggerimento del comando di formato
  ///
  /// In it, this message translates to:
  /// **'Barrato'**
  String get strikethrough;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Colore carattere'**
  String get fontColor;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Colore evidenziazione testo'**
  String get highlightColor;

  /// Voce del menu dell'evidenziatore
  ///
  /// In it, this message translates to:
  /// **'Nessun colore'**
  String get noColor;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Cancella formattazione'**
  String get clearFormatting;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elenco puntato'**
  String get bullets;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elenco numerato'**
  String get numbering;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Riduci rientro'**
  String get decreaseIndent;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Aumenta rientro'**
  String get increaseIndent;

  /// Suggerimento dell'allineamento
  ///
  /// In it, this message translates to:
  /// **'Allinea a sinistra'**
  String get alignLeft;

  /// Suggerimento dell'allineamento
  ///
  /// In it, this message translates to:
  /// **'Centra'**
  String get center;

  /// Suggerimento dell'allineamento
  ///
  /// In it, this message translates to:
  /// **'Allinea a destra'**
  String get alignRight;

  /// Suggerimento dell'allineamento
  ///
  /// In it, this message translates to:
  /// **'Giustifica'**
  String get justify;

  /// Comando della scheda Inserisci
  ///
  /// In it, this message translates to:
  /// **'Collegamento'**
  String get link;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Inserisci o modifica un collegamento (Ctrl+K)'**
  String get linkButtonTooltip;

  /// Errore della finestra del collegamento
  ///
  /// In it, this message translates to:
  /// **'Indirizzo non valido: sono ammessi http, https e mailto.'**
  String get linkInvalid;

  /// Titolo della finestra del collegamento
  ///
  /// In it, this message translates to:
  /// **'Inserisci collegamento'**
  String get insertLink;

  /// Campo della finestra del collegamento
  ///
  /// In it, this message translates to:
  /// **'Indirizzo'**
  String get linkAddress;

  /// Testo segnaposto
  ///
  /// In it, this message translates to:
  /// **'https://… o un indirizzo email'**
  String get linkAddressHint;

  /// Pulsante della finestra del collegamento
  ///
  /// In it, this message translates to:
  /// **'Rimuovi collegamento'**
  String get removeLink;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Firma troppo grande: {size} di immagini, massimo {max}.'**
  String signatureTooLarge(String size, String max);

  /// Titolo della finestra del nome
  ///
  /// In it, this message translates to:
  /// **'Nuova firma'**
  String get newSignature;

  /// Titolo della finestra del nome
  ///
  /// In it, this message translates to:
  /// **'Rinomina firma'**
  String get renameSignature;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare la firma?'**
  String get deleteSignatureQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'\"{name}\" verrà eliminata da questo computer.'**
  String deleteSignatureContent(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Il file scelto non è un\'immagine (PNG, JPEG, GIF, BMP o WebP).'**
  String get notAnImage;

  /// Titolo della finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Firme e elementi decorativi'**
  String get signaturesAndStationery;

  /// Finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Seleziona la firma da modificare'**
  String get selectSignatureToEdit;

  /// Pulsante della finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Nuova'**
  String get newButton;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get rename;

  /// Finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Modifica firma'**
  String get editSignature;

  /// Finestra Firme vuota
  ///
  /// In it, this message translates to:
  /// **'Nessuna firma: crea la prima con \"Nuova\".'**
  String get noSignatures;

  /// Testo segnaposto dell'editor della firma
  ///
  /// In it, this message translates to:
  /// **'Testo della firma'**
  String get signatureText;

  /// Firma predefinita: nessuna
  ///
  /// In it, this message translates to:
  /// **'(nessuna)'**
  String get noneFeminine;

  /// Finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Scegli firma predefinita'**
  String get chooseDefaultSignature;

  /// Campo della finestra Firme
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get account;

  /// Firma predefinita per i messaggi nuovi
  ///
  /// In it, this message translates to:
  /// **'Nuovi messaggi'**
  String get newMessages;

  /// Firma predefinita per risposte e inoltri
  ///
  /// In it, this message translates to:
  /// **'Risposte/inoltri'**
  String get repliesForwards;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scrivi un nome.'**
  String get writeAName;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'C\'è già una firma con questo nome.'**
  String get signatureNameTaken;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Nome della firma'**
  String get signatureName;

  /// Nome della rubrica di un account
  ///
  /// In it, this message translates to:
  /// **'Contatti'**
  String get contacts;

  /// Titolo della finestra Rubrica e campo della rubrica
  ///
  /// In it, this message translates to:
  /// **'Rubrica'**
  String get addressBook;

  /// Testo segnaposto della ricerca nella rubrica
  ///
  /// In it, this message translates to:
  /// **'Cerca per nome, indirizzo o società'**
  String get addressBookSearch;

  /// Scelta della rubrica
  ///
  /// In it, this message translates to:
  /// **'Tutte le rubriche'**
  String get allAddressBooks;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Contatti non disponibili: {error}'**
  String contactsNotAvailable(String error);

  /// Rubrica vuota
  ///
  /// In it, this message translates to:
  /// **'Nessun contatto con un indirizzo.'**
  String get noContactsWithAddress;

  /// Ricerca nella rubrica senza risultati
  ///
  /// In it, this message translates to:
  /// **'Nessun contatto trovato.'**
  String get noContactsFound;

  /// Suggerimento della crocetta di un destinatario scelto nella rubrica
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get takeOut;

  /// Tipo di indirizzo email
  ///
  /// In it, this message translates to:
  /// **'Lavoro'**
  String get labelWork;

  /// Tipo di indirizzo o telefono
  ///
  /// In it, this message translates to:
  /// **'Casa'**
  String get labelHome;

  /// Tipo di indirizzo o telefono
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get labelOther;

  /// Tipo di telefono
  ///
  /// In it, this message translates to:
  /// **'Cellulare'**
  String get labelMobile;

  /// Tipo di telefono
  ///
  /// In it, this message translates to:
  /// **'Ufficio'**
  String get labelOffice;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare il contatto?'**
  String get deleteContactQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'«{name}» è solo su questo computer: eliminato, non si può recuperare.'**
  String deleteContactContent(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Contatto non eliminato: {error}'**
  String contactNotDeleted(String error);

  /// Tipo di file nella finestra Importa
  ///
  /// In it, this message translates to:
  /// **'Contatti (vCard, CSV)'**
  String get contactFilesLabel;

  /// Titolo dell'esito
  ///
  /// In it, this message translates to:
  /// **'Importazione completata'**
  String get importDone;

  /// Esito dell'importazione
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 contatto aggiunto} other{{count} contatti aggiunti}}'**
  String importAdded(int count);

  /// Esito dell'importazione
  ///
  /// In it, this message translates to:
  /// **'{count} già presenti (non aggiunti di nuovo)'**
  String importDuplicates(int count);

  /// Esito dell'importazione
  ///
  /// In it, this message translates to:
  /// **'{count} scartati (senza nome né indirizzo, o non validi)'**
  String importInvalid(int count);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Importazione non riuscita: {error}'**
  String importFailed(String error);

  /// Titolo della scelta del formato
  ///
  /// In it, this message translates to:
  /// **'Esporta contatti'**
  String get exportContacts;

  /// Formato vCard
  ///
  /// In it, this message translates to:
  /// **'Per Thunderbird, telefoni, Apple, Google'**
  String get exportVcfHint;

  /// Formato CSV
  ///
  /// In it, this message translates to:
  /// **'Colonne di Outlook: per Outlook, Gmail, Excel'**
  String get exportCsvHint;

  /// Esito dell'esportazione
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 contatto esportato} other{{count} contatti esportati}} in {path}'**
  String exportDone(int count, String path);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita: {error}'**
  String exportFailed(String error);

  /// Dopo Aggiungi il mittente a Contatti
  ///
  /// In it, this message translates to:
  /// **'«{name}» salvato in {book}'**
  String contactSavedIn(String name, String book);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Caricare i contatti sul server?'**
  String get uploadContactsQuestion;

  /// Conferma del caricamento
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un contatto della rubrica «{book}» è solo su questo computer. Verrà aggiunto} other{{count} contatti della rubrica «{book}» sono solo su questo computer. Verranno aggiunti}} alla rubrica «{serverBook}» del server dei contatti e da allora sincronizzati.\n\nI contatti già presenti sul server non vengono modificati.'**
  String uploadContactsContent(int count, String book, String serverBook);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Contatti non caricati: {error}'**
  String contactsNotUploaded(String error);

  /// Comando di Persone e titolo della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Nuovo contatto'**
  String get newContact;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Nuovo contatto nella rubrica aperta (Ctrl+N)'**
  String get newContactTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Elimina il contatto selezionato (Canc)'**
  String get deleteContactTooltip;

  /// Gruppo di Persone
  ///
  /// In it, this message translates to:
  /// **'Comunica'**
  String get groupCommunicate;

  /// Comando di Persone
  ///
  /// In it, this message translates to:
  /// **'Messaggio di posta'**
  String get emailMessage;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Nuova mail al contatto selezionato'**
  String get emailMessageTooltip;

  /// Comando
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get edit;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Apri il contatto selezionato (Invio o doppio clic)'**
  String get editContactTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Sincronizza subito la rubrica con il server dei contatti (F9)'**
  String get syncContactsTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione dei contatti non attiva: si accende nelle impostazioni dell\'account'**
  String get syncContactsOffTooltip;

  /// Gruppo di Persone
  ///
  /// In it, this message translates to:
  /// **'Importa/Esporta'**
  String get groupImportExport;

  /// Comando di Persone
  ///
  /// In it, this message translates to:
  /// **'Importa…'**
  String get importEllipsis;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Aggiungi contatti da un file vCard (.vcf) o CSV di Outlook o Gmail'**
  String get importTooltip;

  /// Comando di Persone
  ///
  /// In it, this message translates to:
  /// **'Esporta…'**
  String get exportEllipsis;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Salva tutta la rubrica in un file vCard o CSV'**
  String get exportTooltip;

  /// Comando e casella di ricerca di Persone
  ///
  /// In it, this message translates to:
  /// **'Cerca contatti'**
  String get searchContacts;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Cerca per nome, indirizzo, società o telefono (Ctrl+E)'**
  String get searchContactsTooltip;

  /// Riquadro di sinistra di Persone
  ///
  /// In it, this message translates to:
  /// **'I miei contatti'**
  String get myContacts;

  /// Striscia rossa
  ///
  /// In it, this message translates to:
  /// **'Il calendario non si sincronizza: serve un nuovo accesso con Google che permetta l\'accesso al calendario.'**
  String get reloginCalendar;

  /// Striscia rossa
  ///
  /// In it, this message translates to:
  /// **'I contatti non si sincronizzano: serve un nuovo accesso con Google che permetta l\'accesso ai contatti.'**
  String get reloginContacts;

  /// Striscia gialla di Persone
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un contatto è solo su questo computer: non è ancora sul server dei contatti.} other{{count} contatti sono solo su questo computer: non sono ancora sul server dei contatti.}}'**
  String contactsUploadStrip(int count);

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Cancella la ricerca'**
  String get clearSearch;

  /// Rubrica vuota
  ///
  /// In it, this message translates to:
  /// **'Nessun contatto. Usa «Nuovo contatto» o «Importa…».'**
  String get noContactsHint;

  /// Scheda vuota
  ///
  /// In it, this message translates to:
  /// **'Seleziona un contatto'**
  String get selectContact;

  /// Sezione della scheda e della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Posta elettronica'**
  String get emailSection;

  /// Sezione della scheda e della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Telefono'**
  String get phoneSection;

  /// Titolo della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Contatto'**
  String get contact;

  /// Campo del contatto
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get firstName;

  /// Campo del contatto
  ///
  /// In it, this message translates to:
  /// **'Cognome'**
  String get lastName;

  /// Campo del contatto
  ///
  /// In it, this message translates to:
  /// **'Nome visualizzato (se diverso da nome e cognome)'**
  String get displayAs;

  /// Campo del contatto
  ///
  /// In it, this message translates to:
  /// **'Società'**
  String get company;

  /// Pulsante della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Aggiungi indirizzo'**
  String get addAddress;

  /// Testo segnaposto del telefono
  ///
  /// In it, this message translates to:
  /// **'Numero'**
  String get phoneNumber;

  /// Pulsante della finestra del contatto
  ///
  /// In it, this message translates to:
  /// **'Aggiungi telefono'**
  String get addPhone;

  /// Crittografia della connessione: nessuna
  ///
  /// In it, this message translates to:
  /// **'Nessuna'**
  String get securityNone;

  /// Mail scaricate sul computer: tutte
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get bodyMonthsAll;

  /// Mail scaricate sul computer
  ///
  /// In it, this message translates to:
  /// **'Ultimi {months} mesi'**
  String bodyMonthsLast(int months);

  /// Finestra Account senza account; address = « (indirizzo)» o vuoto
  ///
  /// In it, this message translates to:
  /// **'Nessun account salvato nell\'app. In sviluppo il core usa gli user-secrets{address}.\nAggiungendo un account qui verranno usati solo gli account salvati qui: per continuare a vedere quello attuale, aggiungi anche lui.'**
  String noAccountsSaved(String address);

  /// Riga di un account nella finestra Account
  ///
  /// In it, this message translates to:
  /// **'accesso con {provider}'**
  String accountSignedInWith(String provider);

  /// Riga di un account IMAP
  ///
  /// In it, this message translates to:
  /// **'Mail scaricate: {months}'**
  String accountDownloadedMail(String months);

  /// Riga di un account
  ///
  /// In it, this message translates to:
  /// **'contatti sincronizzati (CardDAV)'**
  String get accountContactsSynced;

  /// Riga di un account
  ///
  /// In it, this message translates to:
  /// **'calendario sincronizzato (CalDAV)'**
  String get accountCalendarSynced;

  /// Pulsante di un account
  ///
  /// In it, this message translates to:
  /// **'Ricostruisci cache'**
  String get rebuildCache;

  /// Pulsante di un account
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dall\'app'**
  String get removeFromApp;

  /// Pulsante della finestra Account
  ///
  /// In it, this message translates to:
  /// **'Aggiungi account'**
  String get addAccount;

  /// Titolo della finestra Account
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get accountsTitle;

  /// Nota in fondo alla finestra Account
  ///
  /// In it, this message translates to:
  /// **'Modifiche non ancora salvate: valgono con «OK».'**
  String get pendingChangesOk;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Account non salvati: {error}'**
  String accountsNotSaved(String error);

  /// Riga di un account POP3
  ///
  /// In it, this message translates to:
  /// **'tolte dal server dopo lo scaricamento'**
  String get pop3RemovedAfterDownload;

  /// Riga di un account POP3
  ///
  /// In it, this message translates to:
  /// **'copia sul server per {days} giorni'**
  String pop3CopyForDays(int days);

  /// Riga di un account POP3
  ///
  /// In it, this message translates to:
  /// **'copia lasciata sul server'**
  String get pop3CopyLeft;

  /// Riga di un account POP3
  ///
  /// In it, this message translates to:
  /// **'Mail sul computer, {copy} · controllo ogni {minutes} minuti'**
  String pop3Summary(String copy, int minutes);

  /// Sezione della finestra Account
  ///
  /// In it, this message translates to:
  /// **'Dati di account rimossi'**
  String get removedAccountsData;

  /// Spiegazione della sezione
  ///
  /// In it, this message translates to:
  /// **'Mail scaricate e indice di ricerca di account tolti dall\'app. Restano sul computer finché non li elimini.'**
  String get removedAccountsDataInfo;

  /// Dati di un account rimosso
  ///
  /// In it, this message translates to:
  /// **'mail POP3: l\'unica copia è questa'**
  String get orphanPop3Only;

  /// Dati di un account rimosso
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 contatto} other{{count} contatti}}, solo su questo computer'**
  String orphanContacts(int count);

  /// Pulsante dei dati di un account rimosso
  ///
  /// In it, this message translates to:
  /// **'Elimina dati locali'**
  String get deleteLocalData;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Ricostruire la copia locale?'**
  String get rebuildQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'La copia sul computer di «{name}» (mail scaricate e indice di ricerca) viene cancellata e riscaricata dal server in background: può richiedere qualche minuto e usare la rete.\n\nSul server non viene modificato nulla.'**
  String rebuildContent(String name);

  /// Pulsante della conferma
  ///
  /// In it, this message translates to:
  /// **'Ricostruisci'**
  String get rebuild;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Ricostruzione della copia locale di «{name}» avviata.'**
  String rebuildStarted(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Copia locale non ricostruita: {error}'**
  String rebuildFailed(String error);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare i dati locali?'**
  String get deleteLocalDataQuestion;

  /// Conferma; contacts = frase dei contatti seguita da una riga vuota, o vuoto
  ///
  /// In it, this message translates to:
  /// **'Vengono cancellate dal computer le mail scaricate e l\'indice di ricerca di «{name}» ({size}), un account che non è più nell\'app.\n\n{contacts}Sul server non viene modificato nulla. L\'operazione non si può annullare: se aggiungerai di nuovo l\'account, le mail verranno riscaricate.'**
  String deleteLocalDataContent(String name, String size, String contacts);

  /// Parte della conferma
  ///
  /// In it, this message translates to:
  /// **'Si perdono anche i suoi {count} contatti: sono solo su questo computer. Per tenerli, aggiungi di nuovo l\'account ed esportali da Persone.'**
  String deleteLocalDataContacts(int count);

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Dati locali di «{name}» eliminati.'**
  String localDataDeleted(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Dati locali non eliminati: {error}'**
  String localDataNotDeleted(String error);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Rimuovere l\'account dall\'app?'**
  String get removeAccountQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'«{name}» ({email}) verrà tolto da PostinoVip, insieme alla password salvata nel portachiavi.\n\n{note} Anche i suoi contatti (Persone) restano sul computer.\n\nLa rimozione vale quando premi «OK» nella finestra Account.'**
  String removeAccountContent(String name, String email, String note);

  /// Parte della conferma
  ///
  /// In it, this message translates to:
  /// **'Sul server non viene modificato nulla. Le mail scaricate con POP3 restano sul computer (per alcune è l\'unica copia): le trovi in \"Dati di account rimossi\" e tornano visibili se aggiungi di nuovo l\'account.'**
  String get removeAccountPop3Note;

  /// Parte della conferma
  ///
  /// In it, this message translates to:
  /// **'Sul server non viene modificato nulla: le mail restano dove sono e puoi aggiungere di nuovo l\'account in qualsiasi momento. Le mail già scaricate restano sul computer: puoi eliminarle in seguito da \"Dati di account rimossi\".'**
  String get removeAccountImapNote;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare per sempre le mail?'**
  String get deleteForeverQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'«{name}» era un account POP3: le sue mail ({size}) sono state scaricate su questo computer e qui c\'è l\'unica copia. Quelle già tolte dal server non si potranno più recuperare.\n\nPer confermare scrivi: {expected}'**
  String deleteForeverContent(String name, String size, String expected);

  /// Pulsante della conferma
  ///
  /// In it, this message translates to:
  /// **'Elimina per sempre'**
  String get deleteForever;

  /// Errore dell'accesso con il browser
  ///
  /// In it, this message translates to:
  /// **'Il browser non si è aperto.'**
  String get browserNotOpened;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Accesso non avviato: {error}'**
  String signInNotStarted(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Accesso scaduto: riprova.'**
  String get signInExpired;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito: {error}'**
  String signInFailedError(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito.'**
  String get signInFailed;

  /// Avviso dopo l'accesso con Google
  ///
  /// In it, this message translates to:
  /// **'Accesso fatto, ma senza il permesso dei contatti: la sincronizzazione dei contatti resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.'**
  String get signInWithoutContacts;

  /// Avviso dopo l'accesso con Google
  ///
  /// In it, this message translates to:
  /// **'Accesso fatto, ma senza il permesso del calendario: la sincronizzazione del calendario resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.'**
  String get signInWithoutCalendar;

  /// Avviso dopo l'accesso con Google
  ///
  /// In it, this message translates to:
  /// **'Accesso fatto, ma senza il permesso dei contatti e del calendario: la sincronizzazione dei contatti e del calendario resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.'**
  String get signInWithoutContactsCalendar;

  /// Accesso con il browser in corso
  ///
  /// In it, this message translates to:
  /// **'In attesa dell\'accesso nella pagina di {company}, nel browser…'**
  String waitingSignIn(String company);

  /// Accesso riuscito
  ///
  /// In it, this message translates to:
  /// **'Accesso con {company} fatto: niente password da salvare.'**
  String signedInWith(String company);

  /// Spiegazione dell'accesso
  ///
  /// In it, this message translates to:
  /// **'Niente password: l\'accesso avviene nella pagina di {company}, nel browser. Al ritorno indirizzo e server si compilano da soli.'**
  String noPasswordSignIn(String company);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'{service} non è disponibile: il core non ha l\'ID dell\'app.'**
  String serviceUnavailable(String service);

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Accedi con {company}'**
  String signInWith(String company);

  /// Titolo al primo avvio
  ///
  /// In it, this message translates to:
  /// **'Benvenuto in PostinoVip'**
  String get welcomeTitle;

  /// Titolo della finestra
  ///
  /// In it, this message translates to:
  /// **'Nuovo account'**
  String get newAccount;

  /// Titolo della finestra
  ///
  /// In it, this message translates to:
  /// **'Modifica account'**
  String get editAccount;

  /// Primo avvio
  ///
  /// In it, this message translates to:
  /// **'Inserisci i dati della tua casella. La password viene conservata nel portachiavi di sistema.'**
  String get firstRunIntro;

  /// Campo della finestra
  ///
  /// In it, this message translates to:
  /// **'Tipo di account'**
  String get accountType;

  /// Spiegazione del tipo di account
  ///
  /// In it, this message translates to:
  /// **'IMAP: le mail restano sul server e si vedono da tutti i dispositivi (consigliato).\nPOP3: le mail vengono scaricate su questo computer. Non si può cambiare dopo.'**
  String get accountTypeHelp;

  /// Spiegazione dei servizi
  ///
  /// In it, this message translates to:
  /// **'{services}: accesso con il browser, senza password.'**
  String accountTypeServices(String services);

  /// Modifica account
  ///
  /// In it, this message translates to:
  /// **'Tipo di account: {type}'**
  String accountTypeValue(String type);

  /// Campo della finestra
  ///
  /// In it, this message translates to:
  /// **'Nome (facoltativo)'**
  String get nameOptional;

  /// Suggerimento del campo
  ///
  /// In it, this message translates to:
  /// **'es. Lavoro; se vuoto si mostra l\'indirizzo'**
  String get nameOptionalHint;

  /// Campo della finestra
  ///
  /// In it, this message translates to:
  /// **'Indirizzo email (anche nome utente)'**
  String get emailAddressUser;

  /// Errore del campo
  ///
  /// In it, this message translates to:
  /// **'Indirizzo non valido'**
  String get invalidAddressShort;

  /// Errore del campo
  ///
  /// In it, this message translates to:
  /// **'Questo account è già presente'**
  String get accountAlreadyPresent;

  /// Campo della finestra
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get password;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Nascondi password'**
  String get hidePassword;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Mostra password'**
  String get showPassword;

  /// Errore del campo
  ///
  /// In it, this message translates to:
  /// **'Password obbligatoria'**
  String get passwordRequired;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Questa casella è già configurata come {type} («{name}»). Si può usare in entrambi i modi, ma con le rimozioni dal server del POP3 le mail spariranno anche dall\'account IMAP.'**
  String sameMailboxOtherType(String type, String name);

  /// Server di ricezione
  ///
  /// In it, this message translates to:
  /// **'{type} (posta in arrivo)'**
  String incomingServer(String type);

  /// Server di invio
  ///
  /// In it, this message translates to:
  /// **'SMTP (posta in uscita)'**
  String get outgoingServer;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Il server di invio richiede l\'autenticazione'**
  String get smtpAuthTitle;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Con indirizzo e password della casella. Toglila solo per un server che accetta le mail senza login (es. sulla porta 25 della rete aziendale).'**
  String get smtpAuthSubtitle;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Mail scaricate sul computer'**
  String get downloadedMail;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Le più recenti vengono scaricate in background e si aprono subito; le altre quando le apri.\nPosta eliminata e Indesiderata: solo l\'elenco.'**
  String get downloadedMailHelp;

  /// Dopo la scelta consigliata, con lo spazio davanti
  ///
  /// In it, this message translates to:
  /// **' (consigliato)'**
  String get recommendedSuffix;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Sincronizza i contatti con Google (CardDAV)'**
  String get syncContactsGoogle;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Sincronizza i contatti con il server (CardDAV)'**
  String get syncContactsServer;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Per gli account Microsoft non è ancora disponibile.'**
  String get notYetForMicrosoft;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Prima fai «Accedi con Google».'**
  String get signInWithGoogleFirst;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'La rubrica di questo account diventa quella dei contatti Google. Spuntando la casella si apre il browser per permettere a PostinoVip l\'accesso ai contatti.'**
  String get syncContactsGoogleHelp;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'La rubrica di questo account diventa quella del server dei contatti, con le stesse credenziali. La prima volta i contatti che sono solo su questo computer vanno sul server solo dopo una conferma.'**
  String get syncContactsServerHelp;

  /// Attesa
  ///
  /// In it, this message translates to:
  /// **'Accesso con Google in corso nel browser: permetti l\'accesso ai contatti.'**
  String get contactsSignInWaiting;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del server dei contatti (facoltativo)'**
  String get contactsServerUrl;

  /// Spiegazione del campo
  ///
  /// In it, this message translates to:
  /// **'Vuoto: cercato da solo sul server di ricezione'**
  String get emptyFoundOnIncoming;

  /// Spiegazione del campo
  ///
  /// In it, this message translates to:
  /// **'Vuoto: cercato da solo su {host}'**
  String emptyFoundOn(String host);

  /// Errore del campo
  ///
  /// In it, this message translates to:
  /// **'Serve un indirizzo https://'**
  String get httpsRequired;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Verifica rubrica'**
  String get testAddressBook;

  /// Esito della verifica
  ///
  /// In it, this message translates to:
  /// **'Trovata: «{name}»'**
  String addressBookFound(String name);

  /// Esito della verifica
  ///
  /// In it, this message translates to:
  /// **'Rubrica non trovata.'**
  String get addressBookNotFound;

  /// Sezione della finestra dell'account
  ///
  /// In it, this message translates to:
  /// **'Calendario'**
  String get calendarSection;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Sincronizza il calendario con Google (CalDAV)'**
  String get syncCalendarGoogle;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Sincronizza il calendario con il server (CalDAV)'**
  String get syncCalendarServer;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'I calendari di Google diventano i calendari di questo account; quelli di sola lettura (es. le festività) si vedono ma non si modificano. Spuntando la casella si apre il browser per permettere a PostinoVip l\'accesso al calendario.'**
  String get syncCalendarGoogleHelp;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'I calendari del server che accettano appuntamenti diventano i calendari di questo account. La prima volta gli appuntamenti che sono solo su questo computer vanno sul server solo dopo una conferma.'**
  String get syncCalendarServerHelp;

  /// Attesa
  ///
  /// In it, this message translates to:
  /// **'Accesso con Google in corso nel browser: permetti l\'accesso al calendario.'**
  String get calendarSignInWaiting;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del server del calendario (facoltativo)'**
  String get calendarServerUrl;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Verifica calendario'**
  String get testCalendar;

  /// Esito della verifica
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Trovato} other{Trovati}}: {names}'**
  String calendarsFound(int count, String names);

  /// Testo tra virgolette
  ///
  /// In it, this message translates to:
  /// **'«{text}»'**
  String quoted(String text);

  /// Esito della verifica
  ///
  /// In it, this message translates to:
  /// **'Calendario non trovato.'**
  String get calendarNotFound;

  /// Errore della verifica
  ///
  /// In it, this message translates to:
  /// **'Scrivere prima indirizzo e password.'**
  String get enterAddressPasswordFirst;

  /// Errore della verifica
  ///
  /// In it, this message translates to:
  /// **'Scrivere il server di ricezione o l\'indirizzo del server del calendario.'**
  String get enterServerOrCalendarUrl;

  /// Errore della verifica
  ///
  /// In it, this message translates to:
  /// **'Scrivere il server di ricezione o l\'indirizzo del server dei contatti.'**
  String get enterServerOrContactsUrl;

  /// Sezione delle opzioni POP3
  ///
  /// In it, this message translates to:
  /// **'Recapito'**
  String get deliverySection;

  /// Opzione POP3
  ///
  /// In it, this message translates to:
  /// **'Lascia una copia dei messaggi sul server'**
  String get leaveCopyOnServer;

  /// Opzione POP3, seguita dal numero di giorni
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dal server dopo'**
  String get removeFromServerAfter;

  /// Dopo il numero di giorni
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get days;

  /// Opzione POP3
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dal server quando eliminati da \"Posta eliminata\"'**
  String get removeWhenDeleted;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Ogni mail verrà tolta dal server subito dopo averla scaricata: resterà solo su questo computer.'**
  String get pop3NoCopyWarning;

  /// Campo POP3
  ///
  /// In it, this message translates to:
  /// **'Controlla la posta ogni'**
  String get checkMailEvery;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Anche con Invia/ricevi (F9). Le mail stanno solo sul computer: conviene farne un backup.'**
  String get checkMailEveryHelp;

  /// Scelta dei minuti
  ///
  /// In it, this message translates to:
  /// **'{count} minuti'**
  String minutesCount(int count);

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Server'**
  String get server;

  /// Suggerimento del campo
  ///
  /// In it, this message translates to:
  /// **'es. mail.dominio.it'**
  String get serverHint;

  /// Errore del campo
  ///
  /// In it, this message translates to:
  /// **'Server obbligatorio'**
  String get serverRequired;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Porta'**
  String get port;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Crittografia'**
  String get encryption;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Senza crittografia password e mail viaggiano in chiaro: chiunque sulla rete può leggerle. Usala solo su una rete di cui ti fidi.'**
  String get unencryptedWarning;

  /// Nota
  ///
  /// In it, this message translates to:
  /// **'Certificato del server accettato da te (non firmato da un\'autorità riconosciuta).'**
  String get certificateTrustedByYou;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Non fidarti più'**
  String get stopTrusting;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Verifica non riuscita: {error}'**
  String testFailed(String error);

  /// Titolo della domanda
  ///
  /// In it, this message translates to:
  /// **'Fidarsi di questo certificato?'**
  String get trustCertificateQuestion;

  /// Domanda sul certificato
  ///
  /// In it, this message translates to:
  /// **'Il server {server} {address} ha presentato un certificato non valido:'**
  String invalidCertificatePresented(String server, String address);

  /// Riga del certificato
  ///
  /// In it, this message translates to:
  /// **'Intestato a'**
  String get certificateIssuedTo;

  /// Riga del certificato
  ///
  /// In it, this message translates to:
  /// **'Emesso da'**
  String get certificateIssuedBy;

  /// Riga del certificato
  ///
  /// In it, this message translates to:
  /// **'Valido'**
  String get certificateValid;

  /// Validità del certificato
  ///
  /// In it, this message translates to:
  /// **'dal {from} al {to}'**
  String certificateValidRange(String from, String to);

  /// Riga del certificato
  ///
  /// In it, this message translates to:
  /// **'Impronta SHA-256'**
  String get certificateFingerprint;

  /// Consiglio
  ///
  /// In it, this message translates to:
  /// **'Accettalo solo se sai che questo server usa un certificato proprio (es. un server aziendale o di casa); se possibile confronta l\'impronta con quella che ti dà l\'amministratore. Un certificato inatteso può voler dire che qualcuno sta cercando di intercettare la password.\n\nSe accetti, PostinoVip si fiderà solo di questo certificato: se il server ne presenterà un altro, te lo chiederà di nuovo.'**
  String get certificateAdvice;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Fidati del certificato'**
  String get trustCertificate;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Verifica connessione'**
  String get testConnection;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// Nota sotto i pulsanti
  ///
  /// In it, this message translates to:
  /// **'\"Salva\" si attiva dopo una verifica riuscita.'**
  String get saveAfterTest;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Account non salvato: {error}'**
  String accountNotSaved(String error);

  /// Server senza crittografia
  ///
  /// In it, this message translates to:
  /// **'ricezione ({address})'**
  String unencryptedIncoming(String address);

  /// Server senza crittografia
  ///
  /// In it, this message translates to:
  /// **'invio ({address})'**
  String unencryptedOutgoing(String address);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Connessione senza crittografia'**
  String get unencryptedTitle;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'Per {servers} hai scelto \"Nessuna\" crittografia: la password e le mail viaggiano in chiaro e chiunque sulla stessa rete (Wi-Fi pubblico, rete aziendale, fornitore) può leggerle o modificarle.\n\nSalvare comunque?'**
  String unencryptedContent(String servers);

  /// Tra due elementi di un elenco, con gli spazi
  ///
  /// In it, this message translates to:
  /// **' e '**
  String get andSeparator;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Salva senza crittografia'**
  String get saveUnencrypted;

  /// Esegui regole ora: su quali mail
  ///
  /// In it, this message translates to:
  /// **'Tutti i messaggi'**
  String get runFilterAll;

  /// Esegui regole ora: su quali mail
  ///
  /// In it, this message translates to:
  /// **'Messaggi letti'**
  String get runFilterRead;

  /// Esegui regole ora: su quali mail
  ///
  /// In it, this message translates to:
  /// **'Messaggi da leggere'**
  String get runFilterUnread;

  /// Nome proposto per una regola creata da una mail senza oggetto
  ///
  /// In it, this message translates to:
  /// **'Da {sender}'**
  String ruleNameFrom(String sender);

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Regola «{name}» creata: vale per le mail che arriveranno.'**
  String ruleCreated(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Regola non salvata: {error}'**
  String ruleNotSaved(String error);

  /// Tra due alternative, con gli spazi
  ///
  /// In it, this message translates to:
  /// **' o '**
  String get orSeparator;

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'da {words}'**
  String ruleDescFrom(String words);

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'A o Cc contiene {words}'**
  String ruleDescToOrCc(String words);

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'inviata solo a me'**
  String get ruleDescSentOnlyToMe;

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'io in A'**
  String get ruleDescMeInTo;

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'io in Cc'**
  String get ruleDescMeInCc;

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'oggetto contiene {words}'**
  String ruleDescSubject(String words);

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'oggetto o testo contiene {words}'**
  String ruleDescSubjectOrBody(String words);

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'con allegati'**
  String get ruleDescAttachments;

  /// Descrizione di una regola: condizione
  ///
  /// In it, this message translates to:
  /// **'più grande di {kb} KB'**
  String ruleDescSize(int kb);

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'sposta in {folder}'**
  String ruleDescMove(String folder);

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'copia in {folder}'**
  String ruleDescCopy(String folder);

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'elimina'**
  String get ruleDescDelete;

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'segna come letta'**
  String get ruleDescMarkRead;

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'contrassegna'**
  String get ruleDescFlag;

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'categoria {name}'**
  String ruleDescCategory(String name);

  /// Descrizione di una regola: azione
  ///
  /// In it, this message translates to:
  /// **'nessun\'altra regola'**
  String get ruleDescStop;

  /// Descrizione di una regola senza condizioni
  ///
  /// In it, this message translates to:
  /// **'Tutte le mail'**
  String get ruleDescAllMail;

  /// Descrizione di una regola
  ///
  /// In it, this message translates to:
  /// **'Se {conditions}'**
  String ruleDescIf(String conditions);

  /// Descrizione di una regola, con la virgola davanti
  ///
  /// In it, this message translates to:
  /// **', tranne se {exceptions}'**
  String ruleDescExcept(String exceptions);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Regole non lette: {error}'**
  String rulesNotRead(String error);

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Eliminare la regola?'**
  String get deleteRuleQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'La regola «{name}» non verrà più applicata. Le mail già smistate restano dove sono.'**
  String deleteRuleContent(String name);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Regole non salvate: {error}'**
  String rulesNotSaved(String error);

  /// Titolo della finestra
  ///
  /// In it, this message translates to:
  /// **'Regole e avvisi'**
  String get rulesAndAlerts;

  /// Scelta dell'account
  ///
  /// In it, this message translates to:
  /// **'Applica le modifiche a questa cartella'**
  String get applyChangesToFolder;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Nuova regola…'**
  String get newRuleEllipsis;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Esegui regole ora…'**
  String get runRulesNowEllipsis;

  /// Elenco vuoto
  ///
  /// In it, this message translates to:
  /// **'Nessuna regola. Con «Nuova regola…» smisti la posta in arrivo da sola.'**
  String get noRules;

  /// Nota
  ///
  /// In it, this message translates to:
  /// **'Le regole si applicano nell\'ordine dell\'elenco alle mail che arrivano nella Posta in arrivo mentre PostinoVip è aperto; quelle arrivate con l\'app chiusa vengono smistate alla riapertura.'**
  String get rulesInfo;

  /// Messaggio della finestra di scelta
  ///
  /// In it, this message translates to:
  /// **'Scegli la cartella:'**
  String get chooseFolderColon;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scrivi il nome della regola.'**
  String get ruleNameRequired;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scegli la cartella in cui spostare o copiare.'**
  String get ruleFolderRequired;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scegli almeno un\'azione nella scheda «Azioni».'**
  String get ruleActionRequired;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scrivi la dimensione in KB.'**
  String get ruleSizeRequired;

  /// Titolo della domanda
  ///
  /// In it, this message translates to:
  /// **'Regola per tutte le mail'**
  String get ruleForAllMail;

  /// Domanda
  ///
  /// In it, this message translates to:
  /// **'Senza condizioni la regola si applicherà a tutte le mail che ricevi. È corretto?'**
  String get ruleForAllMailContent;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Nuova regola'**
  String get newRule;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Modifica regola'**
  String get editRule;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Nome della regola'**
  String get ruleName;

  /// Scheda
  ///
  /// In it, this message translates to:
  /// **'Condizioni'**
  String get ruleConditions;

  /// Scheda
  ///
  /// In it, this message translates to:
  /// **'Azioni'**
  String get ruleActions;

  /// Scheda
  ///
  /// In it, this message translates to:
  /// **'Eccezioni'**
  String get ruleExceptions;

  /// Introduzione della scheda
  ///
  /// In it, this message translates to:
  /// **'Applica la regola alle mail che soddisfano tutte le condizioni scelte:'**
  String get ruleConditionsIntro;

  /// Introduzione della scheda
  ///
  /// In it, this message translates to:
  /// **'Tranne se è vera almeno una di queste:'**
  String get ruleExceptionsIntro;

  /// Condizione della regola, seguita dagli indirizzi
  ///
  /// In it, this message translates to:
  /// **'da'**
  String get ruleFrom;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'es. anna@esempio.it; esempio.it'**
  String get ruleFromHint;

  /// Condizione della regola
  ///
  /// In it, this message translates to:
  /// **'A o Cc contiene'**
  String get ruleToOrCc;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'nomi o indirizzi, separati da ;'**
  String get ruleToOrCcHint;

  /// Condizione della regola
  ///
  /// In it, this message translates to:
  /// **'il mio indirizzo è in A'**
  String get ruleMeInTo;

  /// Condizione della regola
  ///
  /// In it, this message translates to:
  /// **'il mio indirizzo è in Cc'**
  String get ruleMeInCc;

  /// Condizione della regola
  ///
  /// In it, this message translates to:
  /// **'l\'oggetto contiene'**
  String get ruleSubjectContains;

  /// Condizione della regola
  ///
  /// In it, this message translates to:
  /// **'l\'oggetto o il testo contiene'**
  String get ruleSubjectOrBodyContains;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'parole separate da ;'**
  String get ruleWordsHint;

  /// Condizione della regola, seguita dai KB
  ///
  /// In it, this message translates to:
  /// **'più grande di'**
  String get ruleLargerThan;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Scegli la cartella…'**
  String get chooseFolderEllipsis;

  /// Introduzione della scheda
  ///
  /// In it, this message translates to:
  /// **'Cosa fare con le mail che soddisfano le condizioni:'**
  String get ruleActionsIntro;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'sposta nella cartella'**
  String get ruleMoveTo;

  /// Titolo della scelta della cartella
  ///
  /// In it, this message translates to:
  /// **'Sposta nella cartella'**
  String get ruleMoveToTitle;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'copia nella cartella'**
  String get ruleCopyTo;

  /// Titolo della scelta della cartella
  ///
  /// In it, this message translates to:
  /// **'Copia nella cartella'**
  String get ruleCopyToTitle;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'elimina (in Posta eliminata)'**
  String get ruleDeleteAction;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'contrassegna per completamento'**
  String get ruleFlagAction;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'assegna la categoria'**
  String get ruleCategoryAction;

  /// Azione della regola
  ///
  /// In it, this message translates to:
  /// **'interrompi l\'elaborazione di altre regole'**
  String get ruleStopAction;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Regole non eseguite: {error}'**
  String rulesNotRun(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Avanzamento non disponibile: {error}'**
  String progressUnavailable(String error);

  /// Titolo della scelta della cartella
  ///
  /// In it, this message translates to:
  /// **'Esegui nella cartella'**
  String get runInFolder;

  /// Esito di Esegui regole ora
  ///
  /// In it, this message translates to:
  /// **'Interrotta per un errore: {error}'**
  String runStoppedError(String error);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Interrotta: esaminate {checked} mail su {total}'**
  String runStoppedChecked(int checked, int total);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Fatto: esaminate {checked} mail'**
  String runDoneChecked(int checked);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{head}, {applied} spostate o modificate'**
  String runOutcome(String head, int applied);

  /// Esito, con la virgola davanti
  ///
  /// In it, this message translates to:
  /// **', {count} azioni non riuscite (dettagli nel registro del core)'**
  String runFailedActions(int count);

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Esegui regole ora'**
  String get runRulesNow;

  /// Etichetta
  ///
  /// In it, this message translates to:
  /// **'Regole da eseguire:'**
  String get rulesToRun;

  /// Dopo il nome di una regola spenta, con lo spazio davanti
  ///
  /// In it, this message translates to:
  /// **' (disattivata)'**
  String get ruleDisabledSuffix;

  /// Etichetta, con lo spazio in fondo
  ///
  /// In it, this message translates to:
  /// **'Nella cartella: '**
  String get runInFolderLabel;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Includi sottocartelle'**
  String get includeSubfolders;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Applica le regole a'**
  String get applyRulesTo;

  /// Stato
  ///
  /// In it, this message translates to:
  /// **'Preparazione…'**
  String get preparing;

  /// Avanzamento
  ///
  /// In it, this message translates to:
  /// **'Esaminate {checked} mail su {total}'**
  String runProgress(int checked, int total);

  /// Stato
  ///
  /// In it, this message translates to:
  /// **'interruzione…'**
  String get stopping;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get stop;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Esegui ora'**
  String get runNow;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Impostazioni non lette: {error}'**
  String settingsNotRead(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scrivi il messaggio della risposta automatica.'**
  String get autoReplyTextRequired;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'L\'ora di fine deve venire dopo l\'ora di inizio.'**
  String get endAfterStart;

  /// Titolo della conferma
  ///
  /// In it, this message translates to:
  /// **'Attivare le risposte automatiche?'**
  String get turnOnAutoRepliesQuestion;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'Da ora PostinoVip risponderà da solo, una volta per mittente, alle mail che arrivano nella Posta in arrivo e in cui sei in A o Cc, finché resta aperto. Le risposte partono senza chiederti conferma.'**
  String get turnOnAutoRepliesContent;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get turnOn;

  /// Errore delle risposte automatiche
  ///
  /// In it, this message translates to:
  /// **'Non salvate: {error}'**
  String notSavedPlural(String error);

  /// Scelta
  ///
  /// In it, this message translates to:
  /// **'Non inviare risposte automatiche'**
  String get dontSendAutoReplies;

  /// Scelta
  ///
  /// In it, this message translates to:
  /// **'Invia risposte automatiche'**
  String get sendAutoReplies;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Invia solo durante questo intervallo di tempo'**
  String get onlyDuringRange;

  /// Etichetta
  ///
  /// In it, this message translates to:
  /// **'Inizio:'**
  String get startTimeColon;

  /// Etichetta
  ///
  /// In it, this message translates to:
  /// **'Fine:'**
  String get endTimeColon;

  /// Nota
  ///
  /// In it, this message translates to:
  /// **'Le risposte partono da questo computer mentre PostinoVip è aperto (le mail arrivate ad app chiusa ricevono la risposta alla riapertura): una sola per mittente, solo se sei in A o Cc, mai a mailing list, ad altre risposte automatiche o a mittenti come «noreply». Non vengono salvate in Posta inviata.'**
  String get autoRepliesInfo;

  /// Testo segnaposto dell'editor
  ///
  /// In it, this message translates to:
  /// **'es. Sono fuori sede fino a lunedì 16 novembre e risponderò al mio rientro.'**
  String get autoReplyPlaceholder;

  /// Livello del filtro
  ///
  /// In it, this message translates to:
  /// **'Nessun filtro automatico'**
  String get junkLevelNone;

  /// Spiegazione del livello
  ///
  /// In it, this message translates to:
  /// **'La posta dei mittenti bloccati viene comunque spostata nella cartella della posta indesiderata.'**
  String get junkLevelNoneInfo;

  /// Livello del filtro
  ///
  /// In it, this message translates to:
  /// **'Bassa'**
  String get junkLevelLow;

  /// Spiegazione del livello
  ///
  /// In it, this message translates to:
  /// **'Sposta la posta indesiderata più evidente: quella che il server ha segnato come spam.'**
  String get junkLevelLowInfo;

  /// Livello del filtro
  ///
  /// In it, this message translates to:
  /// **'Alta'**
  String get junkLevelHigh;

  /// Spiegazione del livello
  ///
  /// In it, this message translates to:
  /// **'Sposta anche le mail con un punteggio vicino alla soglia del server: può capitare anche a posta normale, controlla spesso la cartella della posta indesiderata.'**
  String get junkLevelHighInfo;

  /// Livello del filtro
  ///
  /// In it, this message translates to:
  /// **'Solo elenchi attendibili'**
  String get junkLevelSafeOnly;

  /// Spiegazione del livello
  ///
  /// In it, this message translates to:
  /// **'Solo la posta di mittenti attendibili, o inviata a destinatari attendibili, resta in Posta in arrivo.'**
  String get junkLevelSafeOnlyInfo;

  /// Scheda delle Opzioni posta indesiderata
  ///
  /// In it, this message translates to:
  /// **'Mittenti attendibili'**
  String get safeSenders;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'La posta proveniente da questi indirizzi o domini non verrà mai considerata posta indesiderata.'**
  String get safeSendersInfo;

  /// Scheda
  ///
  /// In it, this message translates to:
  /// **'Destinatari attendibili'**
  String get safeRecipients;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'La posta inviata a questi indirizzi o domini (per esempio una mailing list) non verrà mai considerata posta indesiderata.'**
  String get safeRecipientsInfo;

  /// Scheda
  ///
  /// In it, this message translates to:
  /// **'Mittenti bloccati'**
  String get blockedSenders;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'La posta proveniente da questi indirizzi o domini verrà sempre spostata nella cartella della posta indesiderata.'**
  String get blockedSendersInfo;

  /// Voce del menu Posta indesiderata
  ///
  /// In it, this message translates to:
  /// **'Non bloccare mai il mittente'**
  String get neverBlockSender;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Non bloccare mai il dominio del mittente'**
  String get neverBlockDomain;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Non bloccare mai questo gruppo o mailing list'**
  String get neverBlockGroup;

  /// Voce del menu, più mail selezionate
  ///
  /// In it, this message translates to:
  /// **'Non bloccare mai questi gruppi o mailing list'**
  String get neverBlockGroups;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Blocca mittente'**
  String get blockSender;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Opzioni posta indesiderata…'**
  String get junkOptionsEllipsis;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella della posta indesiderata'**
  String get noJunkFolder;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'L\'account «{name}» non ha una cartella della posta indesiderata: sceglila in «Opzioni posta indesiderata». Il mittente non è stato bloccato.'**
  String noJunkFolderContent(String name);

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Contrassegna come posta non indesiderata'**
  String get markAsNotJunk;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Il messaggio verrà riportato nella cartella Posta in arrivo.} other{I {count} messaggi verranno riportati nella cartella Posta in arrivo.}}'**
  String notJunkMoveBack(int count);

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Considera sempre attendibile la posta proveniente da «{sender}»'**
  String alwaysTrustSender(String sender);

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Considera sempre attendibile la posta proveniente da questi mittenti'**
  String get alwaysTrustSenders;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Opzioni non lette: {error}'**
  String optionsNotRead(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Opzioni non salvate: {error}'**
  String optionsNotSaved(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'valore non valido'**
  String get invalidValue;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Opzioni posta indesiderata'**
  String get junkOptions;

  /// Introduzione
  ///
  /// In it, this message translates to:
  /// **'Le mail nuove della Posta in arrivo che sembrano posta indesiderata vengono spostate in una cartella speciale, mentre PostinoVip è aperto. Il giudizio è quello del server della posta. Scegli il livello di protezione:'**
  String get junkOptionsIntro;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Cartella della posta indesiderata'**
  String get junkFolder;

  /// Scelta della cartella
  ///
  /// In it, this message translates to:
  /// **'Automatica: «{folder}»'**
  String junkFolderAutomatic(String folder);

  /// Scelta della cartella
  ///
  /// In it, this message translates to:
  /// **'Automatica (nessuna cartella trovata)'**
  String get junkFolderAutomaticNone;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Automatica: quella indicata dal server, o una con «spam», «junk» o «indesiderata» nel nome. Per una cartella nuova: scheda Cartella → Nuova cartella, poi sceglila qui.'**
  String get junkFolderInfo;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Senza una cartella il filtro non sposta nessuna mail.'**
  String get junkNoFolderWarning;

  /// Elenco vuoto
  ///
  /// In it, this message translates to:
  /// **'Nessuna voce'**
  String get noEntries;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Aggiungi…'**
  String get addEllipsis;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Considera attendibili anche i miei contatti'**
  String get trustContacts;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Scrivi un indirizzo (anna@esempio.it) o un dominio (@esempio.it).'**
  String get junkEntryInvalid;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Aggiungi indirizzo o dominio'**
  String get addAddressOrDomain;

  /// Titolo
  ///
  /// In it, this message translates to:
  /// **'Modifica indirizzo o dominio'**
  String get editAddressOrDomain;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Indirizzo di posta o nome di dominio Internet'**
  String get junkEntryLabel;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'es. anna@esempio.it oppure @esempio.it'**
  String get junkEntryHint;

  /// Suggerimento di Archivia disattivato
  ///
  /// In it, this message translates to:
  /// **'La mail è già nella cartella di archiviazione'**
  String get alreadyInArchive;

  /// Suggerimento di Archivia
  ///
  /// In it, this message translates to:
  /// **'Sposta nella cartella di archiviazione (Backspace)'**
  String get archiveTooltip;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Le mail sono già nella cartella di archiviazione'**
  String get mailsAlreadyInArchive;

  /// Nome proposto per la cartella di archiviazione nuova
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get archiveFolderName;

  /// Errore senza rete
  ///
  /// In it, this message translates to:
  /// **'Non disponibile senza connessione al server.'**
  String get offlineUnavailable;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'L\'account «{name}» non ha ancora una cartella di archiviazione. Sceglila: Archivia sposterà lì le mail, senza eliminarle.'**
  String archiveFirstTime(String name);

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Archivia sposta le mail di «{name}» in questa cartella, senza eliminarle.'**
  String archiveInfo(String name);

  /// Scelta
  ///
  /// In it, this message translates to:
  /// **'Usa una cartella esistente'**
  String get useExistingFolder;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Scegli una cartella'**
  String get chooseAFolder;

  /// Scelta
  ///
  /// In it, this message translates to:
  /// **'Crea una cartella nuova in cima all\'account'**
  String get createTopFolder;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'OK e archivia'**
  String get okAndArchive;

  /// Comando
  ///
  /// In it, this message translates to:
  /// **'Interrompi Ignora'**
  String get stopIgnore;

  /// Comando
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get ignore;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'La conversazione torna in Posta in arrivo e le mail nuove non vanno più in Posta eliminata'**
  String get stopIgnoreTooltip;

  /// Suggerimento
  ///
  /// In it, this message translates to:
  /// **'Sposta in Posta eliminata la conversazione e le mail che arriveranno'**
  String get ignoreTooltip;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'Le mail superflue della cartella «{name}» (quelle citate per intero da una risposta) verranno spostate in Posta eliminata. Le mail da leggere, contrassegnate, con categorie o firmate restano dove sono.'**
  String cleanUpFolderContent(String name);

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'La conversazione selezionata non verrà più ignorata e le sue mail in Posta eliminata verranno spostate in Posta in arrivo.'**
  String get stopIgnoreContent;

  /// Conferma
  ///
  /// In it, this message translates to:
  /// **'Le mail della conversazione selezionata in questa cartella e tutte quelle che arriveranno verranno spostate in Posta eliminata.'**
  String get ignoreContent;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Non visualizzare più questo messaggio'**
  String get dontShowAgain;

  /// Quando mostrare le notifiche
  ///
  /// In it, this message translates to:
  /// **'Sempre'**
  String get notifyAlways;

  /// Quando mostrare le notifiche
  ///
  /// In it, this message translates to:
  /// **'Solo con la finestra non in primo piano'**
  String get notifyUnfocused;

  /// Quando mostrare le notifiche
  ///
  /// In it, this message translates to:
  /// **'Mai'**
  String get notifyNever;

  /// Segna come letto
  ///
  /// In it, this message translates to:
  /// **'Subito all\'apertura'**
  String get readImmediately;

  /// Segna come letto
  ///
  /// In it, this message translates to:
  /// **'Dopo alcuni secondi di visualizzazione'**
  String get readAfterDelay;

  /// Segna come letto
  ///
  /// In it, this message translates to:
  /// **'Mai automaticamente (solo con il pulsante)'**
  String get readManual;

  /// Conferme di lettura
  ///
  /// In it, this message translates to:
  /// **'Chiedi ogni volta'**
  String get receiptAsk;

  /// Conferme di lettura
  ///
  /// In it, this message translates to:
  /// **'Invia sempre una conferma di lettura'**
  String get receiptAlways;

  /// Conferme di lettura
  ///
  /// In it, this message translates to:
  /// **'Non inviare mai una conferma di lettura'**
  String get receiptNever;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria rossa'**
  String get categoryRed;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria arancione'**
  String get categoryOrange;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria gialla'**
  String get categoryYellow;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria verde'**
  String get categoryGreen;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria blu'**
  String get categoryBlue;

  /// Nome predefinito della categoria
  ///
  /// In it, this message translates to:
  /// **'Categoria viola'**
  String get categoryPurple;

  /// Scadenza del contrassegno
  ///
  /// In it, this message translates to:
  /// **'Domani'**
  String get followUpTomorrow;

  /// Scadenza del contrassegno
  ///
  /// In it, this message translates to:
  /// **'Questa settimana'**
  String get followUpThisWeek;

  /// Scadenza del contrassegno
  ///
  /// In it, this message translates to:
  /// **'Settimana prossima'**
  String get followUpNextWeek;

  /// Scadenza del contrassegno
  ///
  /// In it, this message translates to:
  /// **'Nessuna data'**
  String get followUpNoDate;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Cancella tutte le categorie'**
  String get clearAllCategories;

  /// Voce del menu
  ///
  /// In it, this message translates to:
  /// **'Tutte le categorie…'**
  String get allCategoriesEllipsis;

  /// Voce del menu Completa
  ///
  /// In it, this message translates to:
  /// **'Data personalizzata…'**
  String get customDateEllipsis;

  /// Voce del menu Completa
  ///
  /// In it, this message translates to:
  /// **'Contrassegna come completato'**
  String get markComplete;

  /// Voce del menu Completa
  ///
  /// In it, this message translates to:
  /// **'Cancella contrassegno'**
  String get clearFlag;

  /// Titolo della scelta della data
  ///
  /// In it, this message translates to:
  /// **'Completare entro'**
  String get dueByTitle;

  /// Titolo della finestra delle categorie
  ///
  /// In it, this message translates to:
  /// **'Categorie'**
  String get categoriesTitle;

  /// Nota
  ///
  /// In it, this message translates to:
  /// **'I nomi valgono solo su questo computer; sul server ogni categoria è salvata con il suo colore.'**
  String get categoriesInfo;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Nomi predefiniti'**
  String get defaultNames;

  /// Informazioni su
  ///
  /// In it, this message translates to:
  /// **'Versione {version}'**
  String aboutVersion(String version);

  /// Informazioni su
  ///
  /// In it, this message translates to:
  /// **'Client di posta desktop: interfaccia in Flutter, core in C# con MailKit.'**
  String get aboutDescription;

  /// Note legali richieste dalla AGPL
  ///
  /// In it, this message translates to:
  /// **'Questo programma è software libero: puoi ridistribuirlo e/o modificarlo secondo i termini della {license}, pubblicata dalla Free Software Foundation.\n\nÈ distribuito nella speranza che sia utile, ma SENZA ALCUNA GARANZIA, nemmeno quella implicita di COMMERCIABILITÀ o di IDONEITÀ A UN PARTICOLARE SCOPO. Il testo completo della licenza è in \"Visualizza licenze\" → PostinoVip.'**
  String aboutLegal(String license);

  /// Informazioni su
  ///
  /// In it, this message translates to:
  /// **'Core: versione non disponibile ({error})'**
  String coreVersionUnavailable(String error);

  /// Informazioni su
  ///
  /// In it, this message translates to:
  /// **'Core: versione {version}'**
  String coreVersion(String version);

  /// Informazioni su
  ///
  /// In it, this message translates to:
  /// **'Attenzione: app e core hanno versioni diverse (ricompilare il core).'**
  String get coreVersionMismatch;

  /// Sezione delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Composizione messaggi'**
  String get composeMessages;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Componi messaggi in questo formato'**
  String get composeInFormat;

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Per i messaggi nuovi; risposte e inoltri hanno il formato del messaggio originale'**
  String get composeInFormatHelp;

  /// Sezione delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Firme'**
  String get signaturesSection;

  /// Numero di firme
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna firma} =1{1 firma} other{{count} firme}}'**
  String signatureCount(int count);

  /// Spiegazione
  ///
  /// In it, this message translates to:
  /// **'Aggiunte da sole ai nuovi messaggi e alle risposte, per account'**
  String get signaturesInfo;

  /// Sezione delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Segna come letto'**
  String get markAsReadSection;

  /// Sezione delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Conferme di lettura'**
  String get readReceiptsSection;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Chiedi sempre la conferma di lettura nei nuovi messaggi'**
  String get alwaysRequestReceipt;

  /// Etichetta
  ///
  /// In it, this message translates to:
  /// **'Per i messaggi ricevuti che chiedono una conferma:'**
  String get receiptForReceived;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Chiedi conferma prima di Ignora conversazione'**
  String get confirmBeforeIgnore;

  /// Casella
  ///
  /// In it, this message translates to:
  /// **'Chiedi conferma prima di Interrompi Ignora conversazione'**
  String get confirmBeforeStopIgnoring;

  /// Sezione delle Opzioni
  ///
  /// In it, this message translates to:
  /// **'Notifiche di nuova posta'**
  String get newMailNotifications;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Notifiche di sistema non disponibili: il motivo è nel terminale (\"[notifiche]\").'**
  String get notificationsUnavailable;

  /// Pulsante
  ///
  /// In it, this message translates to:
  /// **'Prova notifica'**
  String get testNotification;

  /// Testo della notifica di prova
  ///
  /// In it, this message translates to:
  /// **'Notifica di prova: se la vedi, le notifiche funzionano.'**
  String get testNotificationText;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Primo giorno della settimana'**
  String get firstDayOfWeek;

  /// Etichetta
  ///
  /// In it, this message translates to:
  /// **'Giorni lavorativi (Settimana lavorativa)'**
  String get workDays;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Inizio orario lavorativo'**
  String get workStart;

  /// Campo
  ///
  /// In it, this message translates to:
  /// **'Fine orario lavorativo'**
  String get workEnd;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Conferma di lettura non inviata: {error}'**
  String receiptNotSent(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Conferma di lettura non registrata: {error}'**
  String receiptNotRecorded(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Operazione non riuscita: {error}'**
  String operationFailed(String error);

  /// Avviso della Posta in uscita
  ///
  /// In it, this message translates to:
  /// **'Invio in corso: la mail parte appena il server risponde.'**
  String get outboxSending;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Mail eliminata dalla Posta in uscita: non verrà inviata.'**
  String get outboxDeleted;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Mail spostata in Bozze: aprila da lì per modificarla.'**
  String get outboxMovedToDrafts;

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Il server ha confermato la cartella «{folder}», ma non la mostra nell\'elenco delle cartelle.'**
  String folderNotListed(String folder);

  /// Avviso
  ///
  /// In it, this message translates to:
  /// **'Un\'altra operazione è in corso'**
  String get anotherOperation;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Cartella \"{folder}\" eliminata definitivamente'**
  String folderDeletedPermanently(String folder);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Cartella \"{folder}\" spostata in Posta eliminata'**
  String folderMovedToTrash(String folder);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Cartella non eliminata: {error}'**
  String folderNotDeleted(String error);

  /// Esito di Svuota cartella
  ///
  /// In it, this message translates to:
  /// **'\"{folder}\" svuotata: {mails}{folders} definitivamente'**
  String folderEmptied(String folder, String mails, String folders);

  /// Parte dell'esito
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 mail eliminata} other{{count} mail eliminate}}'**
  String emptiedMails(int count);

  /// Parte dell'esito, con lo spazio davanti
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{ e 1 cartella} other{ e {count} cartelle}}'**
  String emptiedFolders(int count);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Cartella non svuotata: {error}'**
  String folderNotEmptied(String error);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Cartella \"{folder}\" spostata in cima all\'account'**
  String folderMovedToTop(String folder);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Cartella \"{folder}\" spostata in \"{parent}\"'**
  String folderMovedInto(String folder, String parent);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Cartella non spostata: {error}'**
  String folderNotMoved(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Mail non disponibile senza connessione: non è ancora stata scaricata sul computer.'**
  String get mailNotDownloadedOffline;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Stato letto/non letto non aggiornato: {error}'**
  String readStateNotUpdated(String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Contrassegno o categorie non aggiornati: {error}'**
  String tagsNotUpdated(String error);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Spostato in \"{folder}\"'**
  String movedTo(String folder);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Eliminato definitivamente'**
  String get deletedPermanently;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail segnate come lette'**
  String markedRead(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail segnate come da leggere'**
  String markedUnread(int count);

  /// Esito parziale
  ///
  /// In it, this message translates to:
  /// **'{text}; le altre no: {error}'**
  String othersFailed(String text, String error);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Stato letto non aggiornato: {error}'**
  String readNotUpdated(String error);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail spostate in \"{folder}\"'**
  String mailsMovedTo(int count, String folder);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail eliminate definitivamente'**
  String mailsDeletedPermanently(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail spostate in Posta eliminata'**
  String mailsMovedToTrash(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 mail archiviata} other{{count} mail archiviate}}'**
  String mailsArchived(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Conversazione ignorata: le mail che arriveranno andranno in Posta eliminata'**
  String get conversationIgnored;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail spostate in Posta eliminata; anche quelle che arriveranno andranno lì'**
  String conversationIgnoredMoved(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'La conversazione non è più ignorata'**
  String get conversationNotIgnored;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail riportate in Posta in arrivo'**
  String mailsBackToInbox(int count);

  /// Esito di Pulisci
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna mail superflua da spostare} =1{1 mail superflua spostata in Posta eliminata} other{{count} mail superflue spostate in Posta eliminata}}'**
  String cleanUpDone(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'Nessuna mail spostata'**
  String get noMailMoved;

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail spostate nella posta indesiderata'**
  String mailsMovedToJunk(int count);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{sender} bloccato'**
  String senderBlocked(String sender);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mittenti bloccati ({senders})'**
  String sendersBlocked(int count, String senders);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{sender} attendibile'**
  String senderTrusted(String sender);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mittenti attendibili ({senders})'**
  String sendersTrusted(int count, String senders);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{entries} aggiunto} other{{entries} aggiunti}} tra i mittenti attendibili'**
  String addedToSafeSenders(int count, String entries);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{entries} aggiunto} other{{entries} aggiunti}} tra i destinatari attendibili'**
  String addedToSafeRecipients(int count, String entries);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Elenchi non aggiornati: {error}'**
  String listsNotUpdated(String error);

  /// Esito
  ///
  /// In it, this message translates to:
  /// **'{count} mail copiate in \"{folder}\"'**
  String mailsCopiedTo(int count, String folder);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Mail non copiate: {error}'**
  String mailsNotCopied(String error);

  /// Forma dell'ora (DateFormat di intl)
  ///
  /// In it, this message translates to:
  /// **'HH:mm'**
  String get fmtTime;

  /// Forma di giorno e mese (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'dd/MM'**
  String get fmtDayMonth;

  /// Forma della data (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'dd/MM/yyyy'**
  String get fmtDate;

  /// Giorno abbreviato e data (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'EEE dd/MM/yyyy'**
  String get fmtWeekdayDate;

  /// Giorno abbreviato, data e ora (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'EEE dd/MM/yyyy HH:mm'**
  String get fmtWeekdayDateTime;

  /// Giorno abbreviato e ora (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'EEE HH:mm'**
  String get fmtWeekdayTime;

  /// Data lunga con l'ora, come «Inviato:» nella stampa (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'EEEE d MMMM y HH:mm'**
  String get fmtLongDateTime;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Senza data'**
  String get groupNoDate;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get groupYesterday;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Settimana scorsa'**
  String get groupLastWeek;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Due settimane fa'**
  String get groupTwoWeeksAgo;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Tre settimane fa'**
  String get groupThreeWeeksAgo;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Prima in questo mese'**
  String get groupEarlierThisMonth;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Mese scorso'**
  String get groupLastMonth;

  /// Gruppo della lista
  ///
  /// In it, this message translates to:
  /// **'Più vecchi'**
  String get groupOlder;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Minuscola (meno di 10 KB)'**
  String get sizeTiny;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Piccola (10–25 KB)'**
  String get sizeSmall;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Media (25–100 KB)'**
  String get sizeMedium;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Grande (100–500 KB)'**
  String get sizeLarge;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Molto grande (500 KB–1 MB)'**
  String get sizeVeryLarge;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Enorme (1–5 MB)'**
  String get sizeHuge;

  /// Gruppo per dimensione
  ///
  /// In it, this message translates to:
  /// **'Gigantesca (oltre 5 MB)'**
  String get sizeEnormous;

  /// Dimensione in byte
  ///
  /// In it, this message translates to:
  /// **'{count} byte'**
  String sizeBytes(int count);

  /// Mese e anno (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'MMMM y'**
  String get fmtMonthYear;

  /// Data intera con il giorno (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'EEEE d MMMM y'**
  String get fmtFullDate;

  /// Ora piena della griglia del calendario (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'HH:mm'**
  String get fmtHour;

  /// Inizio di un periodo nello stesso mese (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d'**
  String get fmtRangeSameMonthStart;

  /// Fine di un periodo nello stesso mese (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d MMMM y'**
  String get fmtRangeSameMonthEnd;

  /// Inizio di un periodo su due mesi (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d MMMM'**
  String get fmtRangeOtherMonthStart;

  /// Fine di un periodo su due mesi (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d MMMM y'**
  String get fmtRangeOtherMonthEnd;

  /// Inizio di un periodo su due anni (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d MMMM y'**
  String get fmtRangeOtherYearStart;

  /// Fine di un periodo su due anni (DateFormat)
  ///
  /// In it, this message translates to:
  /// **'d MMMM y'**
  String get fmtRangeOtherYearEnd;

  /// Ricorrenza: «il primo» lunedì
  ///
  /// In it, this message translates to:
  /// **'il primo'**
  String get recurOrdinalFirst;

  /// Ricorrenza
  ///
  /// In it, this message translates to:
  /// **'il secondo'**
  String get recurOrdinalSecond;

  /// Ricorrenza
  ///
  /// In it, this message translates to:
  /// **'il terzo'**
  String get recurOrdinalThird;

  /// Ricorrenza
  ///
  /// In it, this message translates to:
  /// **'il quarto'**
  String get recurOrdinalFourth;

  /// Ricorrenza
  ///
  /// In it, this message translates to:
  /// **'l\'ultimo'**
  String get recurOrdinalLast;

  /// Descrizione della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Ogni giorno} other{Ogni {count} giorni}}'**
  String recurDescDaily(int count);

  /// Descrizione della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Ogni settimana} other{Ogni {count} settimane}}'**
  String recurDescWeekly(int count);

  /// Descrizione: settimanale con i giorni
  ///
  /// In it, this message translates to:
  /// **'{every} il {days}'**
  String recurDescWeeklyOn(String every, String days);

  /// Descrizione della ricorrenza
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Ogni mese} other{Ogni {count} mesi}}'**
  String recurDescMonthly(int count);

  /// Descrizione: mensile con il giorno
  ///
  /// In it, this message translates to:
  /// **'{every} il giorno {day}'**
  String recurDescMonthlyDay(String every, int day);

  /// Descrizione: mensile con «il secondo martedì»
  ///
  /// In it, this message translates to:
  /// **'{every} {which}'**
  String recurDescMonthlyWhich(String every, String which);

  /// Descrizione: annuale con «il secondo martedì»
  ///
  /// In it, this message translates to:
  /// **'Ogni anno {which} di {month}'**
  String recurDescYearlyWhich(String which, String month);

  /// Descrizione: annuale con il giorno
  ///
  /// In it, this message translates to:
  /// **'Ogni anno il {day} {month}'**
  String recurDescYearlyDay(String day, String month);

  /// Descrizione di una ricorrenza sconosciuta
  ///
  /// In it, this message translates to:
  /// **'Ricorrente'**
  String get recurDescRecurring;

  /// Fine della ricorrenza, con la virgola davanti
  ///
  /// In it, this message translates to:
  /// **', {count} volte'**
  String recurDescTimes(int count);

  /// Fine della ricorrenza, con la virgola davanti
  ///
  /// In it, this message translates to:
  /// **', fino al {date}'**
  String recurDescUntil(String date);

  /// Quando, appuntamento di un giorno intero
  ///
  /// In it, this message translates to:
  /// **'{date} (giornata intera)'**
  String whenAllDay(String date);

  /// Quando, appuntamento di più giorni interi
  ///
  /// In it, this message translates to:
  /// **'Da {start} a {end} (giornata intera)'**
  String whenAllDayRange(String start, String end);

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Richiesta non valida'**
  String get coreKindInvalidRequest;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Non trovato'**
  String get coreKindNotFound;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Non connesso'**
  String get coreKindOffline;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Errore del server mail'**
  String get coreKindServer;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Operazione non consentita'**
  String get coreKindConflict;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Non supportato dal server'**
  String get coreKindNotSupported;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Certificato del server non valido'**
  String get coreKindCertificate;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Accesso all\'account non riuscito'**
  String get coreKindOAuth;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Autenticazione con il server mail fallita'**
  String get coreKindAuth;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Configurazione non valida'**
  String get coreKindConfig;

  /// Tipo di errore del core (titolo)
  ///
  /// In it, this message translates to:
  /// **'Errore interno'**
  String get coreKindInternal;

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'intestato a un nome diverso da {host}'**
  String certNameMismatch(String host);

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'non firmato da un\'autorità riconosciuta (es. autofirmato)'**
  String get certUntrustedRoot;

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'scaduto o non ancora valido'**
  String get certNotTimeValid;

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'revocato'**
  String get certRevoked;

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'catena di certificazione non valida'**
  String get certChainInvalid;

  /// Problema del certificato
  ///
  /// In it, this message translates to:
  /// **'nessun certificato'**
  String get certNoCertificate;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il server non risponde: l\'operazione potrebbe non essere stata eseguita.'**
  String get coreTimeout;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Controllare username e password.'**
  String get coreAuthCheckCredentials;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Errore imprevisto, vedere il log del core.'**
  String get coreInternalUnexpected;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Certificato non valido per {address} ({problems}). Aprire l\'account in Impostazioni e ripetere \"Verifica connessione\".'**
  String coreCertificateChanged(String address, String problems);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il certificato del server {address} non è valido: {problems}.'**
  String coreTestCertificateInvalid(String address, String problems);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il server {address} non offre STARTTLS: scegliere un\'altra crittografia o un\'altra porta.'**
  String coreTestNoStartTls(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Autenticazione rifiutata: controllare indirizzo e password.'**
  String get coreTestAuthRejected;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Connessione cifrata non riuscita con {address}: la porta usa davvero questa crittografia?'**
  String coreTestTlsFailed(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server {address} non raggiungibile.'**
  String coreTestUnreachable(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Nessuna risposta da {address} entro {seconds} s: server, porta o crittografia errati?'**
  String coreTestNoAnswer(String address, String seconds);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Risposta inattesa da {address}: porta o protocollo errati?'**
  String coreTestUnexpectedAnswer(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il server POP3 {address} non supporta UIDL: necessario per non scaricare due volte le mail.'**
  String corePop3NoUidl(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server di accesso di {provider} non raggiungibile.'**
  String coreOAuthServerUnreachable(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Risposta non valida dal server di accesso di {provider} (HTTP {status}).'**
  String coreOAuthInvalidResponse(String provider, String status);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Accesso a {provider} scaduto o revocato: rifai «Accedi con {provider}».'**
  String coreOAuthExpired(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'PostinoVip non è registrato correttamente presso {provider} (client ID).'**
  String coreOAuthClientInvalid(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Accesso a {provider} non riuscito ({error}).'**
  String coreOAuthFailed(String provider, String error);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Accesso annullato.'**
  String get coreOAuthCancelled;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito (nessun codice).'**
  String get coreOAuthNoCode;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito ({error}).'**
  String coreOAuthFlowFailed(String error);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il fornitore non ha dato un token di rinnovo (manca offline_access?).'**
  String get coreOAuthNoRefreshToken;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server non raggiungibile ({reason}).'**
  String coreServerUnreachable(String reason);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server POP3 {address} non raggiungibile (nessuna risposta).'**
  String corePop3NoAnswer(String address);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server POP3 {address} non raggiungibile ({reason}).'**
  String corePop3Unreachable(String address, String reason);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server di invio non raggiungibile (nessuna risposta in {seconds} s): mail non inviata.'**
  String coreSmtpNoAnswer(String seconds);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server di invio non raggiungibile ({reason}): mail non inviata.'**
  String coreSmtpUnreachable(String reason);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server dei contatti non raggiungibile.'**
  String get coreContactsServerUnreachable;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Server del calendario non raggiungibile.'**
  String get coreCalendarServerUnreachable;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il server dei contatti non risponde.'**
  String get coreContactsServerNoAnswer;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'Il server del calendario non risponde.'**
  String get coreCalendarServerNoAnswer;

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'{provider} ha rifiutato l\'accesso al server dei contatti: rifai «Accedi con {provider}» permettendo l\'accesso ai contatti.'**
  String coreDavSignInRejectedContacts(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'{provider} ha rifiutato l\'accesso al server del calendario: rifai «Accedi con {provider}» permettendo l\'accesso al calendario.'**
  String coreDavSignInRejectedCalendar(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'L\'accesso con {provider} non comprende il permesso dei contatti: rifai «Accedi con {provider}».'**
  String coreDavScopeMissingContacts(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'L\'accesso con {provider} non comprende il permesso del calendario: rifai «Accedi con {provider}».'**
  String coreDavScopeMissingCalendar(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'L\'accesso con {provider} non comprende i contatti: nella schermata dell\'account usa «Accedi di nuovo» e permetti l\'accesso ai contatti.'**
  String coreAccountScopeMissingContacts(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'L\'accesso con {provider} non comprende il calendario: nella schermata dell\'account usa «Accedi di nuovo» e permetti l\'accesso al calendario.'**
  String coreAccountScopeMissingCalendar(String provider);

  /// Errore del core (dettaglio)
  ///
  /// In it, this message translates to:
  /// **'non connesso'**
  String get coreNotConnected;

  /// Errore dell'app verso il core
  ///
  /// In it, this message translates to:
  /// **'Core PostinoVip non raggiungibile su {address}: {error}'**
  String coreUnreachableApp(String address, String error);

  /// Errore dell'app verso il core
  ///
  /// In it, this message translates to:
  /// **'Risposta inattesa dal core'**
  String get coreUnexpectedResponse;

  /// Errore dell'app verso il core
  ///
  /// In it, this message translates to:
  /// **'Risposta inattesa dal core (versioni diverse di app e core?)'**
  String get coreUnexpectedResponseVersions;

  /// Errore dell'app verso il core
  ///
  /// In it, this message translates to:
  /// **'Eventi non disponibili'**
  String get coreEventsUnavailable;

  /// Errore dell'app verso il core
  ///
  /// In it, this message translates to:
  /// **'Risposta del core in formato inatteso ({path}): {error}. Il core è aggiornato e riavviato?'**
  String coreUnexpectedFormat(String path, String error);

  /// Al posto di un'immagine nella versione di solo testo della mail inviata (tra parentesi quadre)
  ///
  /// In it, this message translates to:
  /// **'immagine'**
  String get imagePlaceholder;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Scrivere il nome della cartella.'**
  String get coreErrScrivereIlNomeDellaCartella;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il nome può avere al massimo {maxLength} caratteri.'**
  String coreErrIlNomePuoAvereAl(String maxLength);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il nome contiene caratteri non validi.'**
  String get coreErrIlNomeContieneCaratteriNon;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il nome non può contenere il carattere \"{separator}\".'**
  String coreErrIlNomeNonPuoContenere(String separator);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\"INBOX\" è il nome riservato della Posta in arrivo.'**
  String get coreErrInboxIlNomeRiservatoDella;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il messaggio originale è disponibile solo con la copia locale.'**
  String get coreErrIlMessaggioOriginaleDisponibileSolo;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella non valida.'**
  String get coreErrCartellaNonValida;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La mail non chiede una conferma di lettura a questo indirizzo.'**
  String get coreErrLaMailNonChiedeUna;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Livello del filtro non valido.'**
  String get coreErrLivelloDelFiltroNonValido;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella della posta indesiderata: sceglierla in «Opzioni posta indesiderata».'**
  String get coreErrNessunaCartellaDellaPostaIndesiderata;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessun mittente da bloccare (le mail sono state inviate da questo account o non hanno mittente).'**
  String get coreErrNessunMittenteDaBloccareLe;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«Non è posta indesiderata» vale solo per le mail della cartella della posta indesiderata.'**
  String get coreErrNonPostaIndesiderataValeSolo;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna delle mail indicate è in \'{folder}\'.'**
  String coreErrNessunaDelleMailIndicateIn(String folder);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server POP3 non supporta UIDL: senza, non si può sapere quali mail sono già state scaricate.'**
  String get coreErrIlServerPop3NonSupporta;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Id non valido.'**
  String get coreErrIdNonValido;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Host SMTP non configurato.'**
  String get coreErrHostSmtpNonConfigurato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Allegati troppo grandi: {value} MB, massimo {value2} MB.'**
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il {serverLabel} ha rifiutato la richiesta (403).'**
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del {value} non ammesso: serve https ({scheme}://{host}).'**
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  );

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessun calendario trovato sul server del calendario.'**
  String get coreErrNessunCalendarioTrovatoSulServer;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna rubrica trovata sul server dei contatti.'**
  String get coreErrNessunaRubricaTrovataSulServer;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il {serverLabel} ha creato l\'elemento senza dire dove (manca Location).'**
  String coreErrIlHaCreatoElementoSenza(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il {serverLabel} ha creato l\'elemento fuori dalla raccolta.'**
  String coreErrIlHaCreatoElementoFuori(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Troppi reindirizzamenti dal {serverLabel}.'**
  String coreErrTroppiReindirizzamentiDal(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il {serverLabel} ha rifiutato nome utente o password.'**
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Certificato del {serverLabel} non valido.'**
  String coreErrCertificatoDelNonValido(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il {serverLabel} ha risposto {code} {reasonPhrase}.'**
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  );

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Risposta del {serverLabel} non leggibile.'**
  String coreErrRispostaDelNonLeggibile(String serverLabel);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il file non è una mail (.eml) leggibile.'**
  String get coreErrIlFileNonUnaMail;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il file non è una mail (.eml): mancano mittente, data, oggetto e destinatari.'**
  String get coreErrIlFileNonUnaMail2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il file .eml non è più aperto: riaprirlo.'**
  String get coreErrIlFileEmlNonPiu;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\' non trovato.'**
  String coreErrAccountNonTrovato(String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': un account POP3 richiede la copia locale (Cache:Enabled=false non è possibile).'**
  String coreErrAccountUnAccountPop3Richiede(String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': fornitore OAuth \'{provider}\' sconosciuto.'**
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': manca il client ID di {displayName} (sezione OAuth:{id2}).'**
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  );

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessun account configurato.'**
  String get coreErrNessunAccountConfigurato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Id account non valido: \'{id}\' (ammessi lettere, cifre, \'-\' e \'_\', massimo 64).'**
  String coreErrIdAccountNonValidoAmmessi(String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': limite della cache non valido ({bodyMonths} mesi; 0 = tutte).'**
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': indirizzo {name} non valido.'**
  String coreErrAccountIndirizzoNonValido(String id, String name);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account \'{id}\': {message}'**
  String coreErrAccount(String id, String message);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Id account ripetuto: \'{key}\'.'**
  String coreErrIdAccountRipetuto(String key);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{fullName}\' non trovata.'**
  String coreErrCartellaNonTrovata(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La cartella \'{fullName}\' esiste già.'**
  String coreErrLaCartellaEsisteGia(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{parent}\' non trovata.'**
  String coreErrCartellaNonTrovata2(String parent);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{folder}\' non trovata.'**
  String coreErrCartellaNonTrovata3(String folder);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Messaggio {uid} non trovato in \'{folder}\'.'**
  String coreErrMessaggioNonTrovatoIn(String uid, String folder);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La cartella \'{newFullName}\' esiste già.'**
  String coreErrLaCartellaEsisteGia2(String newFullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella non indicata.'**
  String get coreErrCartellaNonIndicata;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{fullName}\' non valida.'**
  String coreErrCartellaNonValida2(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{folder}\' assente dall\'indice dopo la sincronizzazione.'**
  String coreErrCartellaAssenteDallIndiceDopo(String folder);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Allegato {index} non trovato nel messaggio {uid}.'**
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Allegato {i} non trovato nel messaggio {uid}.'**
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella di origine e destinazione coincidono.'**
  String get coreErrCartellaDiOrigineDestinazioneCoincidono;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è già in Posta eliminata: usare l\'eliminazione definitiva.'**
  String get coreErrIlMessaggioGiaInPosta;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'L\'eliminazione definitiva è consentita solo in Posta eliminata.'**
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\'{folder}\' non può andare dentro sé stessa o una sua sottocartella.'**
  String coreErrNonPuoAndareDentroSe(String folder);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\'{folder}\' contiene la cartella speciale \'{special}\': non si svuota.'**
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella locale con ruolo {role}.'**
  String coreErrNessunaCartellaLocaleConRuolo(String role);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Messaggio {uid} non trovato in \'{fullName}\'.'**
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'nessuna risposta in {totalSeconds} s'**
  String coreErrNessunaRispostaIn(String totalSeconds);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Host IMAP non configurato.'**
  String get coreErrHostImapNonConfigurato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Messaggio {uid} non trovato in \'{folderName}\'.'**
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non permette di salvare le parole chiave {value} in \'{folderName}\'.'**
  String coreErrIlServerNonPermetteDi(String value, String folderName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non dichiara una cartella \\Sent (Posta inviata): copia non salvata.'**
  String get coreErrIlServerNonDichiaraUna;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non dichiara una cartella \\Drafts (Bozze): bozza non salvata.'**
  String get coreErrIlServerNonDichiaraUna2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non dichiara una cartella \\Drafts (Bozze).'**
  String get coreErrIlServerNonDichiaraUna3;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non dichiara una cartella \\Trash (Posta eliminata).'**
  String get coreErrIlServerNonDichiaraUna4;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non supporta MOVE né UIDPLUS: operazione rifiutata per non cancellare altri messaggi.'**
  String get coreErrIlServerNonSupportaMove;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La cartella \'{fullName}\' non può contenere sottocartelle.'**
  String coreErrLaCartellaNonPuoContenere(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il server non ha creato la cartella \'{clean}\'.'**
  String coreErrIlServerNonHaCreato(String clean);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\'{fullName}\' contiene la cartella speciale \'{fullName2}\': non si svuota.'**
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  );

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\'{fullName}\' non può andare dentro sé stessa o una sua sottocartella.'**
  String coreErrNonPuoAndareDentroSe2(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'\'{fullName}\' è una cartella speciale: non si può rinominare, spostare né eliminare.'**
  String coreErrUnaCartellaSpecialeNonSi(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{folderName}\' non trovata.'**
  String coreErrCartellaNonTrovata4(String folderName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'struttura (BODYSTRUCTURE) illeggibile in un gruppo di {count} mail di {fullName}: saltate, la mail difettosa sarà cercata in background ({message})'**
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  );

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Filtro \"Da leggere\" e ordine dal più vecchio richiedono la cache locale (Cache:Enabled=false).'**
  String get coreErrFiltroDaLeggereOrdineDal;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Le conversazioni richiedono la cache locale (Cache:Enabled=false).'**
  String get coreErrLeConversazioniRichiedonoLaCache;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La ricerca richiede la cache locale (Cache:Enabled=false).'**
  String get coreErrLaRicercaRichiedeLaCache;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Corpo {folderName}/{uid} appena salvato e non rileggibile.'**
  String coreErrCorpoAppenaSalvatoNonRileggibile(String folderName, String uid);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{fullName}\' assente dalla cache dopo la sincronizzazione.'**
  String coreErrCartellaAssenteDallaCacheDopo(String fullName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Impronta SHA-256 non valida.'**
  String get coreErrImprontaSha256NonValida;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'L\'account \'{id}\' è ancora configurato: per svuotarne la cache usare \"Ricostruisci cache\".'**
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessun dato locale per l\'account \'{id}\'.'**
  String coreErrNessunDatoLocalePerAccount(String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Ignora e Pulisci richiedono la copia locale (Cache:Enabled=false).'**
  String get coreErrIgnoraPulisciRichiedonoLaCopia;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella Posta eliminata in questo account.'**
  String get coreErrNessunaCartellaPostaEliminataIn;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La conversazione non è ignorata.'**
  String get coreErrLaConversazioneNonIgnorata;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Pulisci non vale per Posta eliminata e per la posta indesiderata.'**
  String get coreErrPulisciNonValePerPosta;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Le regole richiedono la copia locale.'**
  String get coreErrLeRegoleRichiedonoLaCopia;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Al massimo {maxRules} regole per account.'**
  String coreErrAlMassimoRegolePerAccount(String maxRules);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Ogni regola deve avere un nome.'**
  String get coreErrOgniRegolaDeveAvereUn;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«{name}…»: il nome può avere al massimo {maxNameLength} caratteri.'**
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«{name}»: «Elimina» e «Sposta» insieme non hanno senso, sceglierne uno.'**
  String coreErrEliminaSpostaInsiemeNonHanno(String name);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«{name}»: categoria non valida.'**
  String coreErrCategoriaNonValida(String name);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«{rule}»: dimensione non valida.'**
  String coreErrDimensioneNonValida(String rule);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'«{rule}»: troppe parole o parole troppo lunghe.'**
  String coreErrTroppeParoleParoleTroppoLunghe(String rule);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Scrivere il messaggio della risposta automatica.'**
  String get coreErrScrivereIlMessaggioDellaRisposta;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La fine deve venire dopo l\'inizio.'**
  String get coreErrLaFineDeveVenireDopo;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è troppo lungo.'**
  String get coreErrIlMessaggioTroppoLungo;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Contatto non trovato.'**
  String get coreErrContattoNonTrovato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La rubrica ha già {maxContacts} contatti.'**
  String coreErrLaRubricaHaGiaContatti(String maxContacts);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Formato non riconosciuto: usare vcf o csv.'**
  String get coreErrFormatoNonRiconosciutoUsareVcf;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indirizzo non valido: {address}'**
  String coreErrIndirizzoNonValido(String address);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Scrivere almeno un nome, la società o un indirizzo.'**
  String get coreErrScrivereAlmenoUnNomeLa;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Calendario non trovato.'**
  String get coreErrCalendarioNonTrovato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Appuntamento non valido.'**
  String get coreErrAppuntamentoNonValido;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Appuntamento non trovato.'**
  String get coreErrAppuntamentoNonTrovato;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Esiste già un appuntamento con lo stesso UID.'**
  String get coreErrEsisteGiaUnAppuntamentoCon;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il calendario ha già {maxItems} appuntamenti.'**
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Periodo non valido: al massimo {maxDays} giorni, con la fine dopo l\'inizio.'**
  String coreErrPeriodoNonValidoAlMassimo(String maxDays);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Appuntamento non leggibile.'**
  String get coreErrAppuntamentoNonLeggibile;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Occorrenza non valida.'**
  String get coreErrOccorrenzaNonValida;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Serie non trovata.'**
  String get coreErrSerieNonTrovata;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'L\'appuntamento non è ricorrente: si modifica tutto.'**
  String get coreErrAppuntamentoNonRicorrenteSiModifica;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Al massimo 20000 caratteri.'**
  String get coreErrAlMassimo20000Caratteri;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Promemoria non valido (da 0 minuti a 4 settimane prima).'**
  String get coreErrPromemoriaNonValidoDaMinuti;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La fine è prima dell\'inizio.'**
  String get coreErrLaFinePrimaDellInizio;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Serializzazione non riuscita.'**
  String get coreErrSerializzazioneNonRiuscita;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Manca il client ID di {displayName}: va registrata l\'app e scritto in oauth-clients.json (sezione OAuth:{id}).'**
  String coreErrMancaIlClientIdDi(String displayName, String id);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La sincronizzazione dei contatti non è disponibile con {displayName}.'**
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La sincronizzazione del calendario non è disponibile con {displayName}.'**
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Allegato {i} non trovato.'**
  String coreErrAllegatoNonTrovato(String i);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indicare la cartella del messaggio originale.'**
  String get coreErrIndicareLaCartellaDelMessaggio;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Modalità non valida: {mode} (reply, replyAll, forward).'**
  String coreErrModalitaNonValidaReplyReplyall(String mode);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'{configKey} mancante o più corto di {minLength} caratteri.'**
  String coreErrMancantePiuCortoDiCaratteri(String configKey, String minLength);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella dei dati dell\'utente non determinabile (HOME non impostata?): usare Cache:Directory.'**
  String get coreErrCartellaDeiDatiDellUtente;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indicare almeno una mail.'**
  String get coreErrIndicareAlmenoUnaMail;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Al massimo {maxBatch} mail per volta.'**
  String coreErrAlMassimoMailPerVolta(String maxBatch);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Allegato {index} non trovato.'**
  String coreErrAllegatoNonTrovato2(String index);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Una categoria non può essere aggiunta e tolta insieme.'**
  String get coreErrUnaCategoriaNonPuoEssere;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indicare la cartella di destinazione.'**
  String get coreErrIndicareLaCartellaDiDestinazione;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La scadenza vale solo con followUp \"flagged\".'**
  String get coreErrLaScadenzaValeSoloCon;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Le risposte automatiche richiedono la copia locale.'**
  String get coreErrLeRisposteAutomaticheRichiedonoLa;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La posta indesiderata richiede la copia locale (Cache:Enabled=false).'**
  String get coreErrLaPostaIndesiderataRichiedeLa;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La posta indesiderata richiede la copia locale.'**
  String get coreErrLaPostaIndesiderataRichiedeLa2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La cartella scelta non esiste.'**
  String get coreErrLaCartellaSceltaNonEsiste;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Scegliere una cartella diversa da Posta in arrivo, Posta inviata, Bozze e Posta eliminata.'**
  String get coreErrScegliereUnaCartellaDiversaDa;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'È la cartella di archiviazione: sceglierne un\'altra.'**
  String get coreErrLaCartellaDiArchiviazioneSceglierne;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Cartella \'{name}\' non trovata.'**
  String coreErrCartellaNonTrovata5(String name);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Archivia richiede la copia locale (Cache:Enabled=false).'**
  String get coreErrArchiviaRichiedeLaCopiaLocale;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna cartella di archiviazione: sceglierla con «Imposta cartella di archiviazione».'**
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Le mail sono già nella cartella di archiviazione.'**
  String get coreErrLeMailSonoGiaNella;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'I contatti richiedono la copia locale (Cache:Enabled=false).'**
  String get coreErrContattiRichiedonoLaCopiaLocale;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Contenuto del file non valido.'**
  String get coreErrContenutoDelFileNonValido;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'File troppo grande (al massimo 10 MB).'**
  String get coreErrFileTroppoGrandeAlMassimo;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La sincronizzazione dei contatti non è attiva per questo account.'**
  String get coreErrLaSincronizzazioneDeiContattiNon2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Da 1 a 50.'**
  String get coreErrDa50;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Indirizzo mancante.'**
  String get coreErrIndirizzoMancante;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Le regole richiedono la copia locale (Cache:Enabled=false).'**
  String get coreErrLeRegoleRichiedonoLaCopia2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Scegliere almeno una regola salvata.'**
  String get coreErrScegliereAlmenoUnaRegolaSalvata;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Account POP3: le mail sono solo sul computer, non c\'è una copia da ricostruire dal server.'**
  String get coreErrAccountPop3LeMailSono;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'I calendari richiedono la copia locale (Cache:Enabled=false).'**
  String get coreErrCalendariRichiedonoLaCopiaLocale;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Il calendario «{name}» è di sola lettura: non si possono creare, modificare o eliminare appuntamenti.'**
  String coreErrIlCalendarioDiSolaLettura(String name);

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La sincronizzazione del calendario non è attiva per questo account.'**
  String get coreErrLaSincronizzazioneDelCalendarioNon2;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Ritarda recapito richiede la cache locale (Cache:Enabled=false).'**
  String get coreErrRitardaRecapitoRichiedeLaCache;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La Posta in uscita richiede la cache locale (Cache:Enabled=false).'**
  String get coreErrLaPostaInUscitaRichiede;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Mail non trovata nella Posta in uscita.'**
  String get coreErrMailNonTrovataNellaPosta;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Nessuna conferma di lettura per le mail di Posta indesiderata, Posta inviata e Bozze.'**
  String get coreErrNessunaConfermaDiLetturaPer;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'Alla richiesta di conferma di lettura si è già risposto.'**
  String get coreErrAllaRichiestaDiConfermaDi;

  /// Errore del core (L6c)
  ///
  /// In it, this message translates to:
  /// **'La mail non chiede una conferma di lettura al suo mittente.'**
  String get coreErrLaMailNonChiedeUna2;

  /// Nome del server CardDAV dentro un errore del core
  ///
  /// In it, this message translates to:
  /// **'server dei contatti'**
  String get davContactsServerLabel;

  /// Nome del server CalDAV dentro un errore del core
  ///
  /// In it, this message translates to:
  /// **'server del calendario'**
  String get davCalendarServerLabel;

  /// Avviso della stampa
  ///
  /// In it, this message translates to:
  /// **'Aperta l\'anteprima nel visualizzatore PDF: stampa da lì.'**
  String get printPreviewOpened;

  /// Avviso della stampa
  ///
  /// In it, this message translates to:
  /// **'Nessun programma per aprire i PDF. File in {path}'**
  String printNoPdfViewer(String path);

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'Stampa non preparata: {message} ({path})'**
  String printNotPrepared(String message, String path);

  /// Nome proposto per salvare una mail senza oggetto (senza estensione)
  ///
  /// In it, this message translates to:
  /// **'messaggio'**
  String get defaultMessageFileName;

  /// Avviso della stampa
  ///
  /// In it, this message translates to:
  /// **'Preparazione del PDF…'**
  String get preparingPdf;

  /// Errore
  ///
  /// In it, this message translates to:
  /// **'PDF non creato: {error}'**
  String pdfNotCreated(String error);

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Da:'**
  String get printFrom;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Inviato:'**
  String get printSent;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'A:'**
  String get printTo;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Cc:'**
  String get printCc;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Oggetto:'**
  String get printSubject;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Priorità:'**
  String get printImportance;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Alta'**
  String get printHigh;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Bassa'**
  String get printLow;

  /// Intestazione della mail stampata
  ///
  /// In it, this message translates to:
  /// **'Allegati:'**
  String get printAttachments;

  /// Nome proposto per salvare un allegato senza nome
  ///
  /// In it, this message translates to:
  /// **'allegato'**
  String get defaultAttachmentFileName;

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Eseguibile del core non trovato. Compilarlo con \"cd core && dotnet build\" oppure indicarne il percorso in POSTINOVIP_CORE.'**
  String get coreExecutableNotFound;

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Impossibile avviare il core ({path}): {error}'**
  String coreCannotStart(String path, String error);

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Il core è terminato durante l\'avvio (codice {code}).'**
  String coreExitedAtStart(String code);

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Il core non ha risposto entro {seconds} s.'**
  String coreNoAnswerAtStart(String seconds);

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Il core non risponde correttamente: {error}'**
  String coreNotAnsweringCorrectly(String error);

  /// Attesa all'avvio
  ///
  /// In it, this message translates to:
  /// **'Avvio del core…'**
  String get startingCore;

  /// Errore all'avvio
  ///
  /// In it, this message translates to:
  /// **'Ultime righe del core:'**
  String get coreLastLines;

  /// Menu dell'app sul Mac
  ///
  /// In it, this message translates to:
  /// **'Informazioni su PostinoVip'**
  String get macMenuAbout;

  /// Menu dell'app sul Mac (⌘,)
  ///
  /// In it, this message translates to:
  /// **'Opzioni…'**
  String get macMenuOptions;

  /// Menu dell'app sul Mac
  ///
  /// In it, this message translates to:
  /// **'Servizi'**
  String get macMenuServices;

  /// Menu dell'app sul Mac (⌘H)
  ///
  /// In it, this message translates to:
  /// **'Nascondi PostinoVip'**
  String get macMenuHide;

  /// Menu dell'app sul Mac (⌥⌘H)
  ///
  /// In it, this message translates to:
  /// **'Nascondi altre'**
  String get macMenuHideOthers;

  /// Menu dell'app sul Mac
  ///
  /// In it, this message translates to:
  /// **'Mostra tutte'**
  String get macMenuShowAll;

  /// Menu dell'app sul Mac (⌘Q)
  ///
  /// In it, this message translates to:
  /// **'Esci da PostinoVip'**
  String get macMenuQuit;

  /// Menu Modifica sul Mac (nome di macOS in italiano: Composizione)
  ///
  /// In it, this message translates to:
  /// **'Composizione'**
  String get macMenuEdit;

  /// Menu Modifica sul Mac (⌘Z)
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get macMenuUndo;

  /// Menu Modifica sul Mac (⇧⌘Z)
  ///
  /// In it, this message translates to:
  /// **'Ripeti'**
  String get macMenuRedo;

  /// Menu Modifica sul Mac (⌘X)
  ///
  /// In it, this message translates to:
  /// **'Taglia'**
  String get macMenuCut;

  /// Menu Modifica sul Mac (⌘C)
  ///
  /// In it, this message translates to:
  /// **'Copia'**
  String get macMenuCopy;

  /// Menu Modifica sul Mac (⌘V)
  ///
  /// In it, this message translates to:
  /// **'Incolla'**
  String get macMenuPaste;

  /// Menu Modifica sul Mac (⌘A): testo, o tutte le mail della lista
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutto'**
  String get macMenuSelectAll;

  /// Menu Finestra sul Mac
  ///
  /// In it, this message translates to:
  /// **'Finestra'**
  String get macMenuWindow;

  /// Menu Finestra sul Mac (⌘M)
  ///
  /// In it, this message translates to:
  /// **'Contrai'**
  String get macMenuMinimize;

  /// Menu Finestra sul Mac: ingrandisce la finestra
  ///
  /// In it, this message translates to:
  /// **'Zoom'**
  String get macMenuZoom;

  /// Menu Finestra sul Mac (⌃⌘F): entra o esce
  ///
  /// In it, this message translates to:
  /// **'Tutto schermo'**
  String get macMenuFullScreen;

  /// Menu Finestra sul Mac
  ///
  /// In it, this message translates to:
  /// **'Porta tutto in primo piano'**
  String get macMenuBringAllToFront;

  /// Menu Visualizza sul Mac: mostra o nasconde la barra multifunzione della finestra principale
  ///
  /// In it, this message translates to:
  /// **'Barra multifunzione'**
  String get macMenuShowRibbon;

  /// Menu Visualizza sul Mac (⌘0): zoom del testo della mail al 100%
  ///
  /// In it, this message translates to:
  /// **'Dimensioni reali'**
  String get macMenuZoomReset;

  /// Menu File sul Mac (⌘W): chiude la finestra della mail, della composizione o dell'appuntamento
  ///
  /// In it, this message translates to:
  /// **'Chiudi finestra'**
  String get macMenuCloseWindow;

  /// Menu Visualizza sul Mac, nel calendario: sottomenu delle viste
  ///
  /// In it, this message translates to:
  /// **'Vista calendario'**
  String get macMenuCalendarView;

  /// File → Opzioni → Generale, solo sul Mac
  ///
  /// In it, this message translates to:
  /// **'Mostra la barra multifunzione'**
  String get optionsShowRibbon;

  /// Spiegazione sotto l'opzione, solo sul Mac
  ///
  /// In it, this message translates to:
  /// **'Nella finestra principale. I comandi restano nella barra dei menu in alto.'**
  String get optionsShowRibbonHelp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
