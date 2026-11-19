// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String statusItems(int count) {
    return 'Elemente: $count';
  }

  @override
  String statusUnread(int count) {
    return 'Ungelesen: $count';
  }

  @override
  String statusResults(int count) {
    return 'Ergebnisse: $count';
  }

  @override
  String statusContacts(int count) {
    return 'Kontakte: $count';
  }

  @override
  String statusFound(int count) {
    return 'Gefunden: $count';
  }

  @override
  String get statusConnected => 'Verbunden';

  @override
  String get statusDisconnected => 'Getrennt';

  @override
  String statusDisconnectedAccounts(String accounts) {
    return 'Getrennt: $accounts';
  }

  @override
  String get optionsTitle => 'Optionen';

  @override
  String get optionsClose => 'Schließen';

  @override
  String get optionsPageGeneral => 'Allgemein';

  @override
  String get optionsPageMail => 'E-Mail';

  @override
  String get optionsPageNotifications => 'Benachrichtigungen';

  @override
  String get optionsPageCalendar => 'Kalender';

  @override
  String get optionsAccountSection => 'Konten';

  @override
  String get optionsAccountNotConfigured => '(nicht konfiguriert)';

  @override
  String get optionsAccountFromUserSecrets =>
      'Daten aus user-secrets (Entwicklung)';

  @override
  String optionsAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
    );
    return '$_temp0';
  }

  @override
  String get optionsAccountManage => 'Verwalten…';

  @override
  String get optionsLookSection => 'Darstellung';

  @override
  String get optionsTheme => 'Design';

  @override
  String get optionsThemeHelper =>
      'Der Nachrichtentext bleibt auch bei dunklen Designs auf weißem Hintergrund';

  @override
  String get themeSystem => 'Systemeinstellung verwenden';

  @override
  String get themeColorful => 'Farbig';

  @override
  String get themeWhite => 'Weiß';

  @override
  String get themeDarkGray => 'Dunkelgrau';

  @override
  String get themeBlack => 'Schwarz';

  @override
  String get optionsModuleBar =>
      'Navigationsleiste (E-Mail, Kalender, Personen)';

  @override
  String get moduleBarLeft => 'Links';

  @override
  String get moduleBarBottom => 'Unten im Ordnerbereich';

  @override
  String get optionsLanguageSection => 'Sprache';

  @override
  String get optionsLanguage => 'Anzeigesprache';

  @override
  String get optionsLanguageHelper =>
      'Gilt auch für die Texte, die die App in Nachrichten schreibt (Kopfzeilen von Antworten, Lesebestätigungen)';

  @override
  String get languageSystem => 'Wie das System';

  @override
  String get tabHome => 'Start';

  @override
  String get tabSendReceive => 'Senden/Empfangen';

  @override
  String get tabFolder => 'Ordner';

  @override
  String get tabView => 'Ansicht';

  @override
  String get groupLayout => 'Layout';

  @override
  String get ribbonCollapse => 'Menüband reduzieren';

  @override
  String get ribbonCollapseTooltip =>
      'Nur die Registerkartennamen anzeigen (Strg+F1)';

  @override
  String get groupSendReceive => 'Senden und Empfangen';

  @override
  String get sendReceiveAll => 'Alle Ordner senden/empfangen';

  @override
  String get sendReceiveAllTooltip =>
      'Ordner und Nachrichten aller Konten aktualisieren (F9)';

  @override
  String get readingPane => 'Lesebereich';

  @override
  String get messagePreview => 'Nachrichtenvorschau';

  @override
  String get messagePreviewOff => 'Aus';

  @override
  String messagePreviewLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0';
  }

  @override
  String get groupMessages => 'Nachrichten';

  @override
  String get showAsConversations => 'Als Unterhaltungen anzeigen';

  @override
  String get showAsConversationsOnTooltip =>
      'In diesem Ordner aktiviert: klicken, um zur einfachen Liste zurückzukehren';

  @override
  String get showAsConversationsOffTooltip =>
      'Fasst die Nachrichten derselben Unterhaltung in einer Zeile zusammen';

  @override
  String get specialFolderHint =>
      'Posteingang, Gesendete Elemente, Gelöschte Elemente und die anderen Sonderordner können weder umbenannt noch gelöscht werden';

  @override
  String get groupNew => 'Neu';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get newFolderTooltip =>
      'Einen Unterordner des ausgewählten Ordners erstellen';

  @override
  String get groupActions => 'Aktionen';

  @override
  String get renameFolder => 'Ordner umbenennen';

  @override
  String get renameFolderTooltip =>
      'Den Namen des ausgewählten Ordners ändern (F2)';

  @override
  String get deleteFolder => 'Ordner löschen';

  @override
  String get deletePermanentlyTooltip =>
      'Vom Server löschen, ohne Wiederherstellungsmöglichkeit';

  @override
  String get deleteFolderTooltip =>
      'Den Ordner samt Inhalt nach „Gelöschte Elemente“ verschieben';

  @override
  String get emptyFolder => 'Ordner leeren';

  @override
  String get emptyFolderTooltip =>
      'Alle Nachrichten des Ordners vom Server löschen, ohne Wiederherstellungsmöglichkeit';

  @override
  String get emptyFolderOnlyTooltip =>
      'Nur für „Gelöschte Elemente“ und „Junk-E-Mail“';

  @override
  String get groupArchive => 'Archiv';

  @override
  String get setArchiveFolder => 'Archivordner festlegen';

  @override
  String get setArchiveFolderTooltip =>
      'Den Ordner auswählen oder erstellen, in den „Archivieren“ die Nachrichten dieses Kontos verschiebt';

  @override
  String get newMessage => 'Neue E-Mail';

  @override
  String get newMessageTooltip => 'Eine neue Nachricht schreiben';

  @override
  String get delete => 'Löschen';

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get moveToDeletedTooltip => 'Nach „Gelöschte Elemente“ verschieben';

  @override
  String get archive => 'Archivieren';

  @override
  String get cleanUp => 'Aufräumen';

  @override
  String get cleanUpTooltip =>
      'Redundante Nachrichten nach „Gelöschte Elemente“ verschieben: die in einer Antwort vollständig zitierten';

  @override
  String get junk => 'Junk-E-Mail';

  @override
  String get junkTooltip =>
      'Absender blockieren, Nie blockieren, Junk-E-Mail-Optionen';

  @override
  String get groupRespond => 'Antworten';

  @override
  String get move => 'Verschieben';

  @override
  String get moveTooltip => 'In einen anderen Ordner verschieben';

  @override
  String get moveOtherFolder => 'Anderer Ordner… (Strg+Umschalt+V)';

  @override
  String get rules => 'Regeln';

  @override
  String get rulesTooltip => 'Eingehende E-Mails automatisch sortieren';

  @override
  String get createRule => 'Regel erstellen…';

  @override
  String get manageRulesEllipsis => 'Regeln und Benachrichtigungen verwalten…';

  @override
  String get groupTags => 'Kategorien';

  @override
  String get markUnread => 'Als ungelesen markieren';

  @override
  String get markRead => 'Als gelesen markieren';

  @override
  String get categorize => 'Kategorisieren';

  @override
  String get categorizeTooltip => 'Eine Farbkategorie zuweisen';

  @override
  String get followUp => 'Nachverfolgung';

  @override
  String get followUpTooltip =>
      'Zur Nachverfolgung kennzeichnen, mit Fälligkeitsdatum';

  @override
  String get groupFind => 'Suchen';

  @override
  String get search => 'Suchen';

  @override
  String get searchTooltip => 'E-Mails durchsuchen';

  @override
  String get fileTab => 'Datei';

  @override
  String get openEml => '.eml-Datei öffnen…';

  @override
  String get saveAs => 'Speichern unter… (F12)';

  @override
  String get printMessage => 'Drucken… (Strg+P)';

  @override
  String get saveAsPdf => 'Als PDF speichern…';

  @override
  String get automaticReplies => 'Automatische Antworten';

  @override
  String get manageRules => 'Regeln und Benachrichtigungen verwalten';

  @override
  String get aboutApp => 'Über PostinoVip';

  @override
  String get ribbonShowAlways => 'Menüband immer anzeigen';

  @override
  String get ribbonTabsOnly => 'Nur Registerkarten anzeigen (Strg+F1)';

  @override
  String get ribbonDisplayOptions => 'Anzeigeoptionen für das Menüband';

  @override
  String get readingPaneRight => 'Rechts';

  @override
  String get readingPaneBottom => 'Unten';

  @override
  String get readingPaneOff => 'Aus';

  @override
  String get ribbonClassic => 'Klassisches Menüband';

  @override
  String get ribbonSimplified => 'Vereinfachtes Menüband';

  @override
  String get reply => 'Antworten';

  @override
  String get replyAll => 'Allen antworten';

  @override
  String get forward => 'Weiterleiten';

  @override
  String get sendReceiveAllF9 => 'Alle Ordner senden/empfangen (F9)';

  @override
  String get searchHelp =>
      'Wörter (auch Wortanfänge: \"rech\" findet \"Rechnung\"), \"genauer Ausdruck\"\nvon:anna   an:mario   betreff:besprechung\nanlage:pdf   anlagen:ja   anlagen:nein';

  @override
  String get searchClose => 'Suche schließen';

  @override
  String get searchScopeFolder => 'Aktueller Ordner';

  @override
  String get searchScopeAccount => 'Aktuelles Postfach';

  @override
  String get searchScopeAllAccounts => 'Alle Postfächer';

  @override
  String get moduleMail => 'E-Mail (Strg+1)';

  @override
  String get moduleCalendar => 'Kalender (Strg+2)';

  @override
  String get modulePeople => 'Personen (Strg+3)';

  @override
  String get zoomOut => 'Verkleinern (Strg+-)';

  @override
  String get zoomIn => 'Vergrößern (Strg++)';

  @override
  String get zoomReset =>
      'Zoom des Lesebereichs: klicken, um zu 100 % zurückzukehren (Strg+0)';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get noFolderSelected => 'Kein Ordner ausgewählt';

  @override
  String searchWhereFolder(String folder) {
    return 'in $folder';
  }

  @override
  String searchWhereAccount(String account) {
    return 'in allen Ordnern von $account';
  }

  @override
  String get searchWhereAllFolders => 'in allen Ordnern';

  @override
  String get searchWhereAllAccounts => 'in allen Konten';

  @override
  String searchInProgress(String where) {
    return 'Suche $where…';
  }

  @override
  String searchResultsTitle(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse',
      one: '1 Ergebnis',
    );
    return '$_temp0 $where';
  }

  @override
  String get listNoUnread => 'Keine ungelesenen Nachrichten';

  @override
  String get listEmptyFolder => 'Dieser Ordner ist leer';

  @override
  String get unknownSender => '(unbekannter Absender)';

  @override
  String get noSubject => '(kein Betreff)';

  @override
  String get searchNoLocalResults => 'Keine Ergebnisse in der lokalen Kopie';

  @override
  String get offlineStrip =>
      'Keine Verbindung: Es wird die Kopie auf diesem Computer angezeigt. Verschieben, Löschen, Als gelesen markieren und Senden werden automatisch fortgesetzt, sobald der Server antwortet.';

  @override
  String get theProvider => 'der Anbieter';

  @override
  String loginExpired(String provider) {
    return 'Die Anmeldung bei $provider ist abgelaufen: Dieses Konto empfängt und sendet keine E-Mails, bis Sie sich erneut anmelden.';
  }

  @override
  String get signInAgain => 'Erneut anmelden';

  @override
  String get autoReplyStrip =>
      'Automatische Antworten sind für dieses Konto aktiviert.';

  @override
  String get editEllipsis => 'Bearbeiten…';

  @override
  String get autoReplyTurnedOff => 'Automatische Antworten deaktiviert.';

  @override
  String autoReplyNotTurnedOff(String error) {
    return 'Nicht deaktiviert: $error';
  }

  @override
  String get turnOff => 'Deaktivieren';

  @override
  String get serverSearching => 'Suche auf dem Server…';

  @override
  String serverSearchFailed(String error) {
    return 'Suche auf dem Server fehlgeschlagen: $error';
  }

  @override
  String get serverFoundNone =>
      'Der Server hat keine weiteren Nachrichten gefunden.';

  @override
  String serverFoundMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Der Server hat $count weitere Nachrichten gefunden',
      one: 'Der Server hat 1 weitere Nachricht gefunden',
    );
    return '$_temp0 (mit dem Wolkensymbol).';
  }

  @override
  String serverTruncated(int count) {
    return ' Die $count neuesten werden angezeigt.';
  }

  @override
  String get searchServerToo => 'Auch auf dem Server suchen';

  @override
  String get searchServerHint =>
      'Für Nachrichten, die älter sind als die Grenze der lokalen Kopie, und für „Gelöschte Elemente“ und „Junk-E-Mail“,\nin denen hier nur die Kopfzeilen durchsucht wurden.';

  @override
  String get conversationCollapse => 'Unterhaltung reduzieren';

  @override
  String get conversationExpand => 'Alle Nachrichten der Unterhaltung anzeigen';

  @override
  String get sortDateNewest => 'Nach Datum: neueste oben';

  @override
  String get sortDateOldest => 'Nach Datum: älteste oben';

  @override
  String get sortFromAZ => 'Nach Absender: A → Z';

  @override
  String get sortFromZA => 'Nach Absender: Z → A';

  @override
  String get sortSubjectAZ => 'Nach Betreff: A → Z';

  @override
  String get sortSubjectZA => 'Nach Betreff: Z → A';

  @override
  String get sortSizeLargest => 'Nach Größe: größte oben';

  @override
  String get sortSizeSmallest => 'Nach Größe: kleinste oben';

  @override
  String get sortByDate => 'Nach Datum';

  @override
  String get sortByFrom => 'Nach Absender';

  @override
  String get sortBySubject => 'Nach Betreff';

  @override
  String get sortBySize => 'Nach Größe';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterUnread => 'Ungelesen';

  @override
  String get sortTooltip => 'Sortieren nach';

  @override
  String get conversationBadgeTooltip =>
      'Die Unterhaltungsansicht ist in diesem Ordner aktiviert: klicken, um sie zu ändern';

  @override
  String get conversations => 'Unterhaltungen';

  @override
  String conversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 in der Unterhaltung';
  }

  @override
  String get hasAttachments => 'Mit Anlagen';

  @override
  String get flaggedClickToComplete =>
      'Gekennzeichnet: klicken, um als erledigt zu markieren';

  @override
  String dueByClickToComplete(String date) {
    return 'Fällig am $date: klicken, um als erledigt zu markieren';
  }

  @override
  String get completedClickToFlag =>
      'Erledigt: klicken, um erneut zu kennzeichnen';

  @override
  String get flagToday => 'Für heute kennzeichnen';

  @override
  String get foundOnServer => 'Auf dem Server gefunden';

  @override
  String sortByColumn(String column) {
    return 'Nach $column sortieren';
  }

  @override
  String get columnFrom => 'Von';

  @override
  String get columnSubject => 'Betreff';

  @override
  String get columnReceived => 'Erhalten';

  @override
  String get columnSize => 'Größe';

  @override
  String get columnCategories => 'Kategorien';

  @override
  String selectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente ausgewählt',
      one: '1 Element ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get selectMessage => 'Wählen Sie ein Element zum Lesen aus';

  @override
  String get messageUnavailable => 'Nachricht nicht verfügbar';

  @override
  String receiptRequested(String sender) {
    return '$sender hat eine Lesebestätigung angefordert.';
  }

  @override
  String get receiptDecline => 'Nicht senden';

  @override
  String get receiptSend => 'Senden';

  @override
  String get draftBanner => 'Entwurf: noch nicht gesendet.';

  @override
  String get editDraft => 'Entwurf bearbeiten';

  @override
  String get headerTo => 'An';

  @override
  String get headerCc => 'Cc';

  @override
  String openAttachment(String name) {
    return '„$name“ öffnen';
  }

  @override
  String saveAttachment(String name) {
    return '„$name“ speichern…';
  }

  @override
  String get importanceHighBanner =>
      'Diese Nachricht wurde mit hoher Wichtigkeit gesendet.';

  @override
  String get importanceLowBanner =>
      'Diese Nachricht wurde mit niedriger Wichtigkeit gesendet.';

  @override
  String get junkBanner =>
      'Diese Nachricht befindet sich in „Junk-E-Mail“: Aus Sicherheitsgründen sind Links deaktiviert und externe Bilder blockiert. Wenn die Nachricht vertrauenswürdig ist, verschieben Sie sie zurück in den Posteingang.';

  @override
  String get notJunk => 'Keine Junk-E-Mail';

  @override
  String get remoteImagesBlocked =>
      'Externe Bilder wurden zum Schutz Ihrer Privatsphäre blockiert.';

  @override
  String get showImages => 'Bilder anzeigen';

  @override
  String get htmlOnlyAsText =>
      'Nachricht nur in HTML: als vereinfachter Text angezeigt.';

  @override
  String get bodyText => 'Text';

  @override
  String savedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String attachmentNotDownloaded(String error) {
    return 'Anlage nicht heruntergeladen: $error';
  }

  @override
  String fileNotWritten(String message, String path) {
    return 'Datei nicht geschrieben: $message ($path)';
  }

  @override
  String attachedMailNotOpened(String error) {
    return 'Angehängte Nachricht nicht geöffnet: $error';
  }

  @override
  String get messageWithoutText => '(Nachricht ohne Text)';

  @override
  String get completed => 'Erledigt';

  @override
  String get flaggedForFollowUp => 'Zur Nachverfolgung gekennzeichnet';

  @override
  String dueBy(String date) {
    return 'Fällig am $date';
  }

  @override
  String get overdueSuffix => ' (überfällig)';

  @override
  String get addSenderToContacts => 'Absender zu Kontakten hinzufügen';

  @override
  String get stopIgnoringConversation => 'Unterhaltung nicht mehr ignorieren';

  @override
  String get ignoreConversation => 'Unterhaltung ignorieren';

  @override
  String get cleanUpConversation => 'Unterhaltung aufräumen';

  @override
  String draftNotAvailable(String error) {
    return 'Entwurf nicht verfügbar: $error';
  }

  @override
  String get draftTitle => 'Entwurf';

  @override
  String get deletePermanentlyQuestion => 'Endgültig löschen?';

  @override
  String deletePermanentlyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählte Nachrichten in „Gelöschte Elemente“ werden',
      one: '1 ausgewählte Nachricht in „Gelöschte Elemente“ wird',
    );
    return '$_temp0 vom Server gelöscht.\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String deletePermanentlyOne(String subject) {
    return '„$subject“ wird vom Server gelöscht.\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get dontShowAsConversations => 'Nicht als Unterhaltungen anzeigen';

  @override
  String conversationsOnQuestion(String folder) {
    return 'Nachrichten derselben Unterhaltung werden in einer Zeile zusammengefasst, einschließlich der Antworten in anderen Ordnern.\n\nAuf „$folder“ oder auf alle Ordner anwenden?';
  }

  @override
  String conversationsApplyQuestion(String folder) {
    return 'Auf „$folder“ oder auf alle Ordner anwenden?';
  }

  @override
  String get allFolders => 'Alle Ordner';

  @override
  String get thisFolder => 'Diesen Ordner';

  @override
  String get importanceHigh => 'Wichtigkeit: hoch';

  @override
  String get importanceLow => 'Wichtigkeit: niedrig';

  @override
  String get folderInbox => 'Posteingang';

  @override
  String get favorites => 'Favoriten';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get showInFavorites => 'In Favoriten anzeigen';

  @override
  String get cleanUpFolder => 'Ordner aufräumen';

  @override
  String get outbox => 'Postausgang';

  @override
  String get folderNameHint => 'Ordnername';

  @override
  String noAutoUpdate(String address) {
    return 'Die automatische Aktualisierung ist für $address deaktiviert: Neue Nachrichten erscheinen nur mit „Senden/Empfangen“';
  }

  @override
  String get emptyFolderAllMails => 'Alle Nachrichten';

  @override
  String get emptyFolderOnlyMail => 'Die einzige Nachricht';

  @override
  String emptyFolderNMails(int count) {
    return 'Alle $count Nachrichten';
  }

  @override
  String get emptyFolderOneSubfolder =>
      ' und der Unterordner mit seinen Nachrichten';

  @override
  String emptyFolderNSubfolders(int count) {
    return ' und die $count Unterordner mit ihren Nachrichten';
  }

  @override
  String emptyFolderQuestion(String folder) {
    return '„$folder“ leeren?';
  }

  @override
  String emptyFolderContent(String mails, String folder, String also) {
    return 'Vom Server gelöscht wird: $mails in „$folder“$also.\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteFolderPermanentlyQuestion => 'Ordner endgültig löschen?';

  @override
  String get deleteFolderQuestion => 'Ordner löschen?';

  @override
  String deleteFolderPermanentlyContent(String folder) {
    return 'Der Ordner „$folder“ wird mit allen Nachrichten und Unterordnern vom Server gelöscht.\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String deleteFolderContent(String folder) {
    return 'Der Ordner „$folder“ wird mit allen Nachrichten und Unterordnern nach „Gelöschte Elemente“ verschoben.';
  }

  @override
  String get messageTab => 'Nachricht';

  @override
  String get windowDeletePermanentlyTooltip =>
      'Vom Server löschen, ohne Wiederherstellungsmöglichkeit (dann die nächste Nachricht)';

  @override
  String get windowDeleteTooltip =>
      'Nach „Gelöschte Elemente“ verschieben und die nächste Nachricht öffnen (Entf)';

  @override
  String get windowArchiveTooltip =>
      'In den Archivordner verschieben und die nächste Nachricht öffnen';

  @override
  String get windowMoveTooltip =>
      'In einen anderen Ordner verschieben und die nächste Nachricht öffnen';

  @override
  String get markUnreadWindow => 'Als ungelesen markieren';

  @override
  String get groupZoom => 'Zoom';

  @override
  String zoomPercent(int percent) {
    return 'Zoom ($percent %)';
  }

  @override
  String get zoomTooltip =>
      'Nachrichtentext vergrößern oder verkleinern (Strg+Mausrad, Strg++, Strg+-, Strg+0)';

  @override
  String get previousItem => 'Vorheriges Element (Strg+,)';

  @override
  String get nextItem => 'Nächstes Element (Strg+.)';

  @override
  String get closeEsc => 'Schließen (Esc)';

  @override
  String messageNotSaved(String error) {
    return 'Nachricht nicht gespeichert: $error';
  }

  @override
  String get emlFilesLabel => 'E-Mail-Nachrichten';

  @override
  String fileNotOpened(String name, String reason) {
    return '$name nicht geöffnet: $reason';
  }

  @override
  String get readOnly => 'Schreibgeschützt';

  @override
  String get saveAsShort => 'Speichern unter…';

  @override
  String get moveItems => 'Elemente verschieben';

  @override
  String moveItemsTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die $count ausgewählten Elemente in den Ordner verschieben:',
      one: 'Das ausgewählte Element in den Ordner verschieben:',
    );
    return '$_temp0';
  }

  @override
  String get searchFolder => 'Ordner suchen';

  @override
  String get noFolderWithName => 'Kein Ordner mit diesem Namen';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String reminderNotification(String title) {
    return 'Erinnerung: $title';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Erinnerungen',
      one: '1 Erinnerung',
    );
    return '$_temp0';
  }

  @override
  String get reminderAllDayToday => 'Ganztägig, heute';

  @override
  String get reminderAllDayTomorrow => 'Ganztägig, morgen';

  @override
  String reminderAllDayIn(int count) {
    return 'Ganztägig, in $count Tagen';
  }

  @override
  String reminderAllDayStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ganztägig, vor $count Tagen begonnen',
      one: 'Ganztägig, vor 1 Tag begonnen',
    );
    return '$_temp0';
  }

  @override
  String get reminderNow => 'Jetzt';

  @override
  String reminderStartedAgo(String span) {
    return 'Seit $span überfällig';
  }

  @override
  String reminderIn(String span) {
    return 'In $span';
  }

  @override
  String reminderStart(String when) {
    return 'Beginn: $when';
  }

  @override
  String reminderLocation(String location) {
    return '    Ort: $location';
  }

  @override
  String get dismissAll => 'Alle schließen';

  @override
  String get openItem => 'Element öffnen';

  @override
  String get dismiss => 'Schließen';

  @override
  String get snoozeHint =>
      'Klicken Sie auf „Erneut erinnern“, um erneut erinnert zu werden in:';

  @override
  String get snooze => 'Erneut erinnern';

  @override
  String newMailFrom(String sender, String suffix) {
    return 'Neue Nachricht von $sender$suffix';
  }

  @override
  String newMailMore(int count) {
    return '\n…und $count weitere';
  }

  @override
  String newMailCount(int count, String suffix) {
    return '$count neue Nachrichten$suffix';
  }

  @override
  String get openMailAction => 'Nachricht öffnen';

  @override
  String get viewDay => 'Tag';

  @override
  String get viewWorkWeek => 'Arbeitswoche';

  @override
  String get viewWeek => 'Woche';

  @override
  String get viewMonth => 'Monat';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorGreen => 'Grün';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPurple => 'Lila';

  @override
  String get colorTeal => 'Blaugrün';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorGold => 'Gold';

  @override
  String get colorGray => 'Grau';

  @override
  String get deleteRecurringTitle => 'Serientermin löschen';

  @override
  String get openRecurringTitle => 'Serientermin öffnen';

  @override
  String get deleteRecurringQuestion =>
      'Nur dieses Vorkommen oder die ganze Serie löschen?';

  @override
  String get openRecurringQuestion =>
      'Dies ist ein Serientermin. Nur dieses Vorkommen oder die ganze Serie öffnen?';

  @override
  String get entireSeries => 'Die ganze Serie';

  @override
  String get justThisOne => 'Nur dieses';

  @override
  String appointmentNotAvailable(String error) {
    return 'Termin nicht verfügbar: $error';
  }

  @override
  String get deleteAppointmentQuestion => 'Termin löschen?';

  @override
  String deleteAppointmentContent(String title) {
    return '„$title“ wird gelöscht, mit der Synchronisierung auch vom Server. Der Termin kann nicht wiederhergestellt werden.';
  }

  @override
  String appointmentNotDeleted(String error) {
    return 'Termin nicht gelöscht: $error';
  }

  @override
  String get uploadAppointmentsQuestion => 'Termine auf den Server hochladen?';

  @override
  String uploadAppointmentsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine sind nur auf diesem Computer. Sie werden',
      one: 'Ein Termin ist nur auf diesem Computer. Er wird',
    );
    return '$_temp0 dem Serverkalender hinzugefügt und ab dann synchronisiert.\n\nDie Termine, die bereits auf dem Server sind, werden nicht geändert.';
  }

  @override
  String get uploadToServer => 'Auf den Server hochladen';

  @override
  String appointmentsNotUploaded(String error) {
    return 'Termine nicht hochgeladen: $error';
  }

  @override
  String get newAppointment => 'Neuer Termin';

  @override
  String get newAppointmentTooltip => 'Neuer Termin (Strg+N)';

  @override
  String get deleteSelectedAppointmentTooltip =>
      'Den ausgewählten Termin löschen (Entf)';

  @override
  String get groupGoTo => 'Gehe zu';

  @override
  String get today => 'Heute';

  @override
  String get todayTooltip => 'Zurück zu heute';

  @override
  String get next7Days => 'Nächste 7 Tage';

  @override
  String get next7DaysTooltip => 'Sieben Tage ab heute';

  @override
  String get groupArrange => 'Anordnen';

  @override
  String get groupSync => 'Synchronisierung';

  @override
  String get sync => 'Abgleichen';

  @override
  String get syncCalendarsTooltip =>
      'Kalender jetzt mit dem Server synchronisieren (F9)';

  @override
  String appointmentsNotAvailable(String error) {
    return 'Termine nicht verfügbar: $error';
  }

  @override
  String uploadStrip(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine sind',
      one: 'ein Termin ist',
    );
    return '$name: $_temp0 nur auf diesem Computer, noch nicht auf dem Server.';
  }

  @override
  String get uploadToServerEllipsis => 'Auf den Server hochladen…';

  @override
  String get calendarEmpty => 'Keine Termine in diesem Zeitraum. ';

  @override
  String get calendarEmptySyncHint =>
      'Um die Termine des Servers zu sehen, aktivieren Sie „Kalender mit dem Server synchronisieren (CalDAV)“ unter Datei → Optionen → Konten → Bearbeiten. ';

  @override
  String get calendarEmptyCreate =>
      'Zum Erstellen: „Neuer Termin“ (Strg+N) oder Doppelklick auf einen freien Bereich.';

  @override
  String get previous => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get myCalendars => 'Meine Kalender';

  @override
  String get localOnlyTooltip =>
      'Um die Termine des Servers zu sehen: Datei → Optionen → Konten → Bearbeiten → „Kalender mit dem Server synchronisieren (CalDAV)“';

  @override
  String get localOnly => 'Nur auf diesem Computer';

  @override
  String get color => 'Farbe';

  @override
  String get calendarReadOnlyTooltip =>
      'Schreibgeschützt: Termine können angezeigt, aber nicht geändert werden';

  @override
  String get syncedWithServer => 'Mit dem Server synchronisiert';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String nowAt(String time) {
    return 'Jetzt ($time)';
  }

  @override
  String moreItems(int count) {
    return '+$count weitere';
  }

  @override
  String get syncing => 'Synchronisierung…';

  @override
  String get synced => 'Synchronisiert';

  @override
  String syncedAt(String time) {
    return 'Synchronisiert um $time';
  }

  @override
  String syncedOnAt(String date, String time) {
    return 'Synchronisiert am $date um $time';
  }

  @override
  String get syncServerUnreachable => 'Server nicht erreichbar';

  @override
  String get syncUnavailable => 'Synchronisierung nicht verfügbar';

  @override
  String get syncFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String get endBeforeStart => 'Das Ende liegt vor dem Beginn.';

  @override
  String get deleteOccurrenceQuestion => 'Dieses Vorkommen löschen?';

  @override
  String get deleteOccurrenceContent =>
      'Nur dieses Vorkommen wird aus der Serie entfernt, die anderen bleiben. Es kann nicht wiederhergestellt werden.';

  @override
  String get deleteSeriesContent =>
      'Der Termin (mit allen Vorkommen, falls es ein Serientermin ist) wird gelöscht, mit der Synchronisierung auch vom Server. Er kann nicht wiederhergestellt werden.';

  @override
  String get saveChangesQuestion => 'Änderungen speichern?';

  @override
  String get appointmentNotSavedContent =>
      'Die Änderungen am Termin wurden nicht gespeichert.';

  @override
  String get no => 'Nein';

  @override
  String get yes => 'Ja';

  @override
  String get untitled => 'Ohne Titel';

  @override
  String get occurrence => 'Vorkommen';

  @override
  String get appointment => 'Termin';

  @override
  String get saveAndClose => 'Speichern und schließen';

  @override
  String get saveAndCloseTooltip => 'Speichern und schließen (Strg+S)';

  @override
  String get deleteOnlyOccurrenceTooltip => 'Nur dieses Vorkommen löschen';

  @override
  String get deleteAppointmentTooltip => 'Termin löschen';

  @override
  String get groupOptions => 'Optionen';

  @override
  String get recurrence => 'Serientyp';

  @override
  String get recurrenceTooltip => 'Als Serie festlegen oder die Serie ändern';

  @override
  String get reminder => 'Erinnerung';

  @override
  String reminderValue(String value) {
    return 'Erinnerung: $value';
  }

  @override
  String get reminderNone => 'Keine';

  @override
  String get reminderAtStart => 'Zum Beginn';

  @override
  String customRecurrence(String rule) {
    return 'Benutzerdefinierte Serie ($rule): wird beim Speichern unverändert beibehalten';
  }

  @override
  String calendarReadOnly(String calendar) {
    return 'Der Kalender „$calendar“ ist schreibgeschützt: Der Termin kann angezeigt, aber nicht geändert werden.';
  }

  @override
  String get location => 'Ort';

  @override
  String get startTime => 'Beginn';

  @override
  String get endTime => 'Ende';

  @override
  String get allDayEvent => 'Ganztägiges Ereignis';

  @override
  String recurrenceValue(String text) {
    return 'Serie: $text';
  }

  @override
  String get onlyThisOccurrenceHint =>
      'Nur dieses Vorkommen der Serie: Die anderen ändern sich nicht.';

  @override
  String get notes => 'Notizen';

  @override
  String get weekFirst => 'ersten';

  @override
  String get weekSecond => 'zweiten';

  @override
  String get weekThird => 'dritten';

  @override
  String get weekFourth => 'vierten';

  @override
  String get weekLast => 'letzten';

  @override
  String get recurrenceBadInterval => 'Ungültige Wiederholung (alle 1–999).';

  @override
  String get recurrenceBadCount => 'Ungültige Anzahl von Terminen (1–999).';

  @override
  String get recurrenceNoDays => 'Wählen Sie mindestens einen Wochentag aus.';

  @override
  String get recurEveryNDays => 'Alle [n] Tag(e)';

  @override
  String get recurEveryWeekday => 'Jeden Arbeitstag';

  @override
  String get recurEveryNWeeksOn => 'Jede/Alle [n] Woche(n) am:';

  @override
  String get recurMonthlyDay => 'Am [day]. Tag jedes [n]. Monats';

  @override
  String get recurMonthlyWeekday => 'Am [week] [weekday] jedes Monats';

  @override
  String get recurYearlyDay => 'Jeden [day]. [month]';

  @override
  String get recurYearlyWeekday => 'Am [week] [weekday] im [month]';

  @override
  String get appointmentRecurrence => 'Terminserie';

  @override
  String get recurrencePattern => 'Serienmuster';

  @override
  String get recurDaily => 'Täglich';

  @override
  String get recurWeekly => 'Wöchentlich';

  @override
  String get recurMonthly => 'Monatlich';

  @override
  String get recurYearly => 'Jährlich';

  @override
  String get recurrenceRange => 'Seriendauer';

  @override
  String get recurNoEnd => 'Kein Enddatum';

  @override
  String get recurEndAfter => 'Endet nach [n] Terminen';

  @override
  String get recurEndBy => 'Endet am [date]';

  @override
  String get removeRecurrence => 'Serie entfernen';

  @override
  String queuedSendAfter(String when) {
    return 'Nachricht im Postausgang: Sie wird nach $when gesendet (bei geöffneter App).';
  }

  @override
  String get queuedOffline =>
      'Keine Verbindung: Die Nachricht liegt im Postausgang und wird automatisch gesendet, sobald der Server antwortet.';

  @override
  String get sentCopyNotSavedTitle =>
      'Nachricht gesendet, Kopie nicht gespeichert';

  @override
  String sentCopyNotSaved(String error) {
    return 'Die Nachricht wurde gesendet, aber die Kopie in „Gesendete Elemente“ wurde nicht gespeichert:\n$error\n\nSenden Sie sie nicht erneut: Die Empfänger haben sie bereits erhalten.';
  }

  @override
  String sentSavedIn(String folder) {
    return ' und in „$folder“ gespeichert';
  }

  @override
  String messageSent(String where, String response) {
    return 'Nachricht gesendet$where. Server: $response';
  }

  @override
  String get newMessageTitle => 'Neue Nachricht';

  @override
  String get toPlainTextQuestion => 'In Nur-Text umwandeln?';

  @override
  String get toPlainTextContent =>
      'Formatierungen und Bilder im Text gehen verloren, auch wenn Sie wieder zu HTML wechseln. Die zitierte Originalnachricht wird als Text hinzugefügt.';

  @override
  String get continueButton => 'Weiter';

  @override
  String get savingDraft => 'Entwurf wird gespeichert…';

  @override
  String get tabInsert => 'Einfügen';

  @override
  String get tabFormatText => 'Text formatieren';

  @override
  String get attachFile => 'Datei anfügen';

  @override
  String get attachFileTooltip =>
      'Eine oder mehrere Dateien vom Computer anfügen';

  @override
  String get saveSentCopy => 'Kopie speichern';

  @override
  String get saveSentCopyOnTooltip =>
      'Ein: Nach dem Senden wird eine Kopie in „Gesendete Elemente“ abgelegt (klicken, um sie nicht zu speichern)';

  @override
  String get saveSentCopyOffTooltip =>
      'Aus: keine Kopie in „Gesendete Elemente“ nach dem Senden (klicken, um sie zu speichern)';

  @override
  String get saveDraft => 'Entwurf speichern';

  @override
  String get saveDraftTooltip =>
      'In „Entwürfe“ speichern (Strg+S); auch automatisch alle 3 Minuten';

  @override
  String get delayDelivery => 'Übermittlung verzögern';

  @override
  String get delayDeliveryTooltip =>
      'Nicht vor einem Datum und einer Uhrzeit senden (bleibt im Postausgang)';

  @override
  String delayDeliveryActiveTooltip(String when) {
    return 'Senden nach $when: klicken, um es zu ändern';
  }

  @override
  String get importanceHighTooltip =>
      'Nachricht als wichtig markieren (erneut klicken, um es zu entfernen)';

  @override
  String get importanceLowTooltip =>
      'Nachricht als weniger wichtig markieren (erneut klicken, um es zu entfernen)';

  @override
  String get groupInclude => 'Einschließen';

  @override
  String get groupSave => 'Speichern';

  @override
  String get groupShowFields => 'Felder anzeigen';

  @override
  String get bcc => 'Bcc';

  @override
  String get bccTooltip =>
      'Blindkopie: Bcc-Empfänger sehen sich gegenseitig nicht und werden von den anderen nicht gesehen';

  @override
  String get groupTracking => 'Verlauf';

  @override
  String get requestReadReceipt => 'Lesebestätigung anfordern';

  @override
  String get requestReadReceiptOnTooltip =>
      'Ein: Der Empfänger kann Ihnen eine Bestätigung senden, wenn er die Nachricht liest (klicken, um es zu entfernen)';

  @override
  String get requestReadReceiptOffTooltip =>
      'Den Empfänger um eine Bestätigung bitten, wenn er die Nachricht liest (er kann ablehnen)';

  @override
  String get groupMoreOptions => 'Weitere Optionen';

  @override
  String get groupFormat => 'Format';

  @override
  String get formatHtmlTooltip => 'Formatierter Text mit Bildern und Links';

  @override
  String get plainText => 'Nur-Text';

  @override
  String get plainTextTooltip =>
      'Nur Text, ohne Formatierung: Jedes E-Mail-Programm kann ihn lesen';

  @override
  String get signaturesEllipsis => 'Signaturen…';

  @override
  String get signature => 'Signatur';

  @override
  String get signatureTooltip =>
      'Eine Signatur einfügen oder Signaturen erstellen und bearbeiten';

  @override
  String get attachments => 'Anlagen';

  @override
  String get originalAttachment => 'Anlage der Originalnachricht';

  @override
  String get remove => 'Entfernen';

  @override
  String attachmentsTooLarge(String size, String max) {
    return 'Anlagen zu groß: $size, maximal $max.';
  }

  @override
  String get messageBody => 'Nachrichtentext';

  @override
  String get addressesHint => 'durch Kommas getrennte Adressen';

  @override
  String get accountUnavailable => '(Konto nicht verfügbar)';

  @override
  String get originalMessageQuote =>
      'Originalnachricht (wird unverändert am Ende angefügt)';

  @override
  String get removeQuote => 'Zitat entfernen';

  @override
  String get offlineSendMessage =>
      'Keine Verbindung zum Server, und die Originalnachricht (Zitat oder Anlagen) ist nicht auf diesem Computer: Die Nachricht wurde nicht gesendet und bleibt hier. Versuchen Sie es erneut, wenn die Verbindung wieder besteht.';

  @override
  String sendFailed(String error) {
    return 'Senden fehlgeschlagen: $error';
  }

  @override
  String draftTooLarge(String max) {
    return 'Entwurf nicht gespeichert: Anlagen über $max.';
  }

  @override
  String draftSavedLocally(String time) {
    return 'Entwurf um $time auf diesem Computer gespeichert: Er wird in „Entwürfe“ abgelegt, sobald der Server antwortet';
  }

  @override
  String draftSavedAt(String time) {
    return 'Entwurf um $time gespeichert';
  }

  @override
  String get draftNotSaved => 'Entwurf nicht gespeichert';

  @override
  String draftNotSavedError(String error) {
    return 'Entwurf nicht gespeichert: $error';
  }

  @override
  String get sendQuestion => 'Nachricht senden?';

  @override
  String sendSummaryCopy(String value) {
    return 'Kopie in „Gesendete Elemente“: $value';
  }

  @override
  String sendSummaryDelivery(String when) {
    return 'Übermittlung: nicht vor $when';
  }

  @override
  String get emptySubjectWarning => 'Achtung: Der Betreff ist leer.';

  @override
  String get attachmentsNone => 'keine';

  @override
  String attachmentsFromDisk(String size) {
    return ', Dateien vom Datenträger $size';
  }

  @override
  String get composeSaveNew =>
      'Die Nachricht wurde nicht gesendet. In „Entwürfe“ speichern, um sie später fertigzustellen?';

  @override
  String get composeSaveExisting =>
      'Die Nachricht wurde nicht gesendet. Die letzten Änderungen im Entwurf speichern?';

  @override
  String get sending => 'Wird gesendet…';

  @override
  String get doNotDeliverBefore => 'Übermittlung nicht vor:';

  @override
  String get delayDeliveryHint =>
      'Nach „Senden“ bleibt die Nachricht im Postausgang und wird zu diesem Zeitpunkt automatisch gesendet, wenn die App geöffnet ist.';

  @override
  String get chooseFutureTime => 'Wählen Sie einen Zeitpunkt in der Zukunft.';

  @override
  String get noDelay => 'Keine Verzögerung';

  @override
  String get recipientRequired => 'Geben Sie mindestens einen Empfänger ein';

  @override
  String invalidAddress(String address) {
    return 'Ungültige Adresse: $address';
  }

  @override
  String get dontSuggestAddress => 'Diese Adresse nicht mehr vorschlagen';

  @override
  String get noMoreSuggestions => 'Keine weiteren Vorschläge';

  @override
  String get outboxHint =>
      'Postausgang: Nachrichten auf diesem Computer, die automatisch gesendet werden, wenn es Zeit ist und der Server antwortet, bei geöffneter App.';

  @override
  String get outboxEmpty => 'Keine Nachrichten, die auf das Senden warten';

  @override
  String get deleteOutboxQuestion => 'Nachricht löschen?';

  @override
  String deleteOutboxContent(String subject) {
    return '„$subject“ wird nicht gesendet.';
  }

  @override
  String outboxNotSent(String error) {
    return 'Nicht gesendet: $error';
  }

  @override
  String outboxSendAfter(String when) {
    return 'Senden nach $when';
  }

  @override
  String get outboxWaiting => 'Warten auf Verbindung';

  @override
  String get noRecipients => '(keine Empfänger)';

  @override
  String get sendNow => 'Jetzt senden';

  @override
  String get moveToDrafts => 'In „Entwürfe“ verschieben (zum Bearbeiten)';

  @override
  String get deleteOutboxTooltip => 'Löschen (wird nicht gesendet)';

  @override
  String get yesValue => 'ja';

  @override
  String get noValue => 'nein';

  @override
  String get fontColorAutomatic => 'Automatisch';

  @override
  String get fontColorDarkRed => 'Dunkelrot';

  @override
  String get fontColorRed => 'Rot';

  @override
  String get fontColorOrange => 'Orange';

  @override
  String get fontColorYellow => 'Gelb';

  @override
  String get fontColorLightGreen => 'Hellgrün';

  @override
  String get fontColorGreen => 'Grün';

  @override
  String get fontColorLightBlue => 'Hellblau';

  @override
  String get fontColorBlue => 'Blau';

  @override
  String get fontColorDarkBlue => 'Dunkelblau';

  @override
  String get fontColorPurple => 'Lila';

  @override
  String get remoteImagePlaceholder => '[Bild aus dem Internet]';

  @override
  String get groupBasicText => 'Basistext';

  @override
  String get groupFont => 'Schriftart';

  @override
  String get groupParagraph => 'Absatz';

  @override
  String get linkTooltip => 'Link (Strg+K)';

  @override
  String get imageFromFile => 'Bild aus Datei (z. B. ein Logo)';

  @override
  String get defaultFont => 'Calibri (Standard)';

  @override
  String get fontSize => 'Schriftgrad';

  @override
  String get bold => 'Fett (Strg+B)';

  @override
  String get italic => 'Kursiv (Strg+I)';

  @override
  String get underline => 'Unterstrichen (Strg+U)';

  @override
  String get strikethrough => 'Durchgestrichen';

  @override
  String get fontColor => 'Schriftfarbe';

  @override
  String get highlightColor => 'Texthervorhebungsfarbe';

  @override
  String get noColor => 'Keine Farbe';

  @override
  String get clearFormatting => 'Alle Formatierungen löschen';

  @override
  String get bullets => 'Aufzählungszeichen';

  @override
  String get numbering => 'Nummerierung';

  @override
  String get decreaseIndent => 'Einzug verkleinern';

  @override
  String get increaseIndent => 'Einzug vergrößern';

  @override
  String get alignLeft => 'Linksbündig';

  @override
  String get center => 'Zentriert';

  @override
  String get alignRight => 'Rechtsbündig';

  @override
  String get justify => 'Blocksatz';

  @override
  String get link => 'Link';

  @override
  String get linkButtonTooltip =>
      'Einen Link einfügen oder bearbeiten (Strg+K)';

  @override
  String get linkInvalid =>
      'Ungültige Adresse: Nur http, https und mailto sind zulässig.';

  @override
  String get insertLink => 'Link einfügen';

  @override
  String get linkAddress => 'Adresse';

  @override
  String get linkAddressHint => 'https://… oder eine E-Mail-Adresse';

  @override
  String get removeLink => 'Link entfernen';

  @override
  String signatureTooLarge(String size, String max) {
    return 'Signatur zu groß: $size an Bildern, maximal $max.';
  }

  @override
  String get newSignature => 'Neue Signatur';

  @override
  String get renameSignature => 'Signatur umbenennen';

  @override
  String get deleteSignatureQuestion => 'Signatur löschen?';

  @override
  String deleteSignatureContent(String name) {
    return '„$name“ wird von diesem Computer gelöscht.';
  }

  @override
  String get notAnImage =>
      'Die ausgewählte Datei ist kein Bild (PNG, JPEG, GIF, BMP oder WebP).';

  @override
  String get signaturesAndStationery => 'Signaturen und Briefpapier';

  @override
  String get selectSignatureToEdit => 'Zu bearbeitende Signatur auswählen';

  @override
  String get newButton => 'Neu';

  @override
  String get rename => 'Umbenennen';

  @override
  String get editSignature => 'Signatur bearbeiten';

  @override
  String get noSignatures =>
      'Keine Signaturen: Erstellen Sie die erste mit „Neu“.';

  @override
  String get signatureText => 'Signaturtext';

  @override
  String get noneFeminine => '(keine)';

  @override
  String get chooseDefaultSignature => 'Standardsignatur auswählen';

  @override
  String get account => 'E-Mail-Konto';

  @override
  String get newMessages => 'Neue Nachrichten';

  @override
  String get repliesForwards => 'Antworten/Weiterleitungen';

  @override
  String get writeAName => 'Geben Sie einen Namen ein.';

  @override
  String get signatureNameTaken =>
      'Es gibt bereits eine Signatur mit diesem Namen.';

  @override
  String get signatureName => 'Name der Signatur';

  @override
  String get contacts => 'Kontakte';

  @override
  String get addressBook => 'Adressbuch';

  @override
  String get addressBookSearch => 'Nach Name, Adresse oder Firma suchen';

  @override
  String get allAddressBooks => 'Alle Adressbücher';

  @override
  String contactsNotAvailable(String error) {
    return 'Kontakte nicht verfügbar: $error';
  }

  @override
  String get noContactsWithAddress => 'Keine Kontakte mit Adresse.';

  @override
  String get noContactsFound => 'Keine Kontakte gefunden.';

  @override
  String get takeOut => 'Entfernen';

  @override
  String get labelWork => 'Geschäftlich';

  @override
  String get labelHome => 'Privat';

  @override
  String get labelOther => 'Sonstige';

  @override
  String get labelMobile => 'Mobil';

  @override
  String get labelOffice => 'Geschäftlich';

  @override
  String get deleteContactQuestion => 'Kontakt löschen?';

  @override
  String deleteContactContent(String name) {
    return '„$name“ ist nur auf diesem Computer: Nach dem Löschen kann der Kontakt nicht wiederhergestellt werden.';
  }

  @override
  String contactNotDeleted(String error) {
    return 'Kontakt nicht gelöscht: $error';
  }

  @override
  String get contactFilesLabel => 'Kontakte (vCard, CSV)';

  @override
  String get importDone => 'Import abgeschlossen';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kontakte hinzugefügt',
      one: '1 Kontakt hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    return '$count bereits vorhanden (nicht erneut hinzugefügt)';
  }

  @override
  String importInvalid(int count) {
    return '$count verworfen (ohne Name oder Adresse oder ungültig)';
  }

  @override
  String importFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get exportContacts => 'Kontakte exportieren';

  @override
  String get exportVcfHint => 'Für Thunderbird, Telefone, Apple, Google';

  @override
  String get exportCsvHint => 'Outlook-Spalten: für Outlook, Gmail, Excel';

  @override
  String exportDone(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kontakte',
      one: '1 Kontakt',
    );
    return '$_temp0 nach $path exportiert';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String contactSavedIn(String name, String book) {
    return '„$name“ in $book gespeichert';
  }

  @override
  String get uploadContactsQuestion => 'Kontakte auf den Server hochladen?';

  @override
  String uploadContactsContent(int count, String book, String serverBook) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Kontakte des Adressbuchs „$book“ sind nur auf diesem Computer. Sie werden',
      one:
          'Ein Kontakt des Adressbuchs „$book“ ist nur auf diesem Computer. Er wird',
    );
    return '$_temp0 dem Adressbuch „$serverBook“ des Kontaktservers hinzugefügt und ab dann synchronisiert.\n\nDie Kontakte, die bereits auf dem Server sind, werden nicht geändert.';
  }

  @override
  String contactsNotUploaded(String error) {
    return 'Kontakte nicht hochgeladen: $error';
  }

  @override
  String get newContact => 'Neuer Kontakt';

  @override
  String get newContactTooltip =>
      'Neuer Kontakt im geöffneten Adressbuch (Strg+N)';

  @override
  String get deleteContactTooltip => 'Den ausgewählten Kontakt löschen (Entf)';

  @override
  String get groupCommunicate => 'Kommunizieren';

  @override
  String get emailMessage => 'E-Mail';

  @override
  String get emailMessageTooltip =>
      'Neue Nachricht an den ausgewählten Kontakt';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editContactTooltip =>
      'Den ausgewählten Kontakt öffnen (Eingabe oder Doppelklick)';

  @override
  String get syncContactsTooltip =>
      'Adressbuch jetzt mit dem Kontaktserver synchronisieren (F9)';

  @override
  String get syncContactsOffTooltip =>
      'Die Kontaktsynchronisierung ist deaktiviert: Aktivieren Sie sie in den Kontoeinstellungen';

  @override
  String get groupImportExport => 'Import/Export';

  @override
  String get importEllipsis => 'Importieren…';

  @override
  String get importTooltip =>
      'Kontakte aus einer vCard-Datei (.vcf) oder einer CSV-Datei von Outlook oder Gmail hinzufügen';

  @override
  String get exportEllipsis => 'Exportieren…';

  @override
  String get exportTooltip =>
      'Das gesamte Adressbuch in einer vCard- oder CSV-Datei speichern';

  @override
  String get searchContacts => 'Kontakte suchen';

  @override
  String get searchContactsTooltip =>
      'Nach Name, Adresse, Firma oder Telefon suchen (Strg+E)';

  @override
  String get myContacts => 'Meine Kontakte';

  @override
  String get reloginCalendar =>
      'Der Kalender wird nicht synchronisiert: Sie müssen sich erneut bei Google anmelden und den Zugriff auf den Kalender erlauben.';

  @override
  String get reloginContacts =>
      'Die Kontakte werden nicht synchronisiert: Sie müssen sich erneut bei Google anmelden und den Zugriff auf die Kontakte erlauben.';

  @override
  String contactsUploadStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Kontakte sind nur auf diesem Computer: Sie sind noch nicht auf dem Kontaktserver.',
      one: 'Ein Kontakt ist nur auf diesem Computer: Er ist noch nicht auf dem Kontaktserver.',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get noContactsHint =>
      'Keine Kontakte. Verwenden Sie „Neuer Kontakt“ oder „Importieren…“.';

  @override
  String get selectContact => 'Wählen Sie einen Kontakt aus';

  @override
  String get emailSection => 'E-Mail';

  @override
  String get phoneSection => 'Telefon';

  @override
  String get contact => 'Kontakt';

  @override
  String get firstName => 'Vorname';

  @override
  String get lastName => 'Nachname';

  @override
  String get displayAs =>
      'Anzeigen als (falls abweichend von Vor- und Nachname)';

  @override
  String get company => 'Firma';

  @override
  String get addAddress => 'Adresse hinzufügen';

  @override
  String get phoneNumber => 'Nummer';

  @override
  String get addPhone => 'Telefon hinzufügen';

  @override
  String get securityNone => 'Keine';

  @override
  String get bodyMonthsAll => 'Alle';

  @override
  String bodyMonthsLast(int months) {
    return 'Letzte $months Monate';
  }

  @override
  String noAccountsSaved(String address) {
    return 'Keine Konten in der App gespeichert. Während der Entwicklung verwendet der Core user-secrets$address.\nSobald Sie hier ein Konto hinzufügen, werden nur die hier gespeicherten Konten verwendet: Um das aktuelle weiterhin zu sehen, fügen Sie es ebenfalls hinzu.';
  }

  @override
  String accountSignedInWith(String provider) {
    return 'angemeldet mit $provider';
  }

  @override
  String accountDownloadedMail(String months) {
    return 'Heruntergeladene E-Mails: $months';
  }

  @override
  String get accountContactsSynced => 'Kontakte synchronisiert (CardDAV)';

  @override
  String get accountCalendarSynced => 'Kalender synchronisiert (CalDAV)';

  @override
  String get rebuildCache => 'Lokale Kopie neu erstellen';

  @override
  String get removeFromApp => 'Aus der App entfernen';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get accountsTitle => 'Konten';

  @override
  String get pendingChangesOk =>
      'Änderungen noch nicht gespeichert: Sie werden übernommen, wenn Sie auf OK klicken.';

  @override
  String accountsNotSaved(String error) {
    return 'Konten nicht gespeichert: $error';
  }

  @override
  String get pop3RemovedAfterDownload =>
      'nach dem Herunterladen vom Server entfernt';

  @override
  String pop3CopyForDays(int days) {
    return 'Kopie auf dem Server für $days Tage';
  }

  @override
  String get pop3CopyLeft => 'Kopie auf dem Server belassen';

  @override
  String pop3Summary(String copy, int minutes) {
    return 'E-Mails auf diesem Computer, $copy · alle $minutes Minuten abgerufen';
  }

  @override
  String get removedAccountsData => 'Daten entfernter Konten';

  @override
  String get removedAccountsDataInfo =>
      'Heruntergeladene E-Mails und Suchindex von Konten, die aus der App entfernt wurden. Sie bleiben auf diesem Computer, bis Sie sie löschen.';

  @override
  String get orphanPop3Only => 'POP3-E-Mails: Dies ist die einzige Kopie';

  @override
  String orphanContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kontakte',
      one: '1 Kontakt',
    );
    return '$_temp0, nur auf diesem Computer';
  }

  @override
  String get deleteLocalData => 'Lokale Daten löschen';

  @override
  String get rebuildQuestion => 'Lokale Kopie neu erstellen?';

  @override
  String rebuildContent(String name) {
    return 'Die Kopie von „$name“ auf diesem Computer (heruntergeladene E-Mails und Suchindex) wird gelöscht und im Hintergrund erneut vom Server heruntergeladen: Das kann einige Minuten dauern und das Netzwerk belasten.\n\nAuf dem Server wird nichts geändert.';
  }

  @override
  String get rebuild => 'Neu erstellen';

  @override
  String rebuildStarted(String name) {
    return 'Die Neuerstellung der lokalen Kopie von „$name“ wurde gestartet.';
  }

  @override
  String rebuildFailed(String error) {
    return 'Lokale Kopie nicht neu erstellt: $error';
  }

  @override
  String get deleteLocalDataQuestion => 'Lokale Daten löschen?';

  @override
  String deleteLocalDataContent(String name, String size, String contacts) {
    return 'Die heruntergeladenen E-Mails und der Suchindex von „$name“ ($size), einem Konto, das nicht mehr in der App ist, werden von diesem Computer gelöscht.\n\n${contacts}Auf dem Server wird nichts geändert. Dies kann nicht rückgängig gemacht werden: Wenn Sie das Konto erneut hinzufügen, werden die E-Mails erneut heruntergeladen.';
  }

  @override
  String deleteLocalDataContacts(int count) {
    return 'Auch die $count Kontakte gehen verloren: Sie sind nur auf diesem Computer. Um sie zu behalten, fügen Sie das Konto erneut hinzu und exportieren Sie sie unter „Personen“.';
  }

  @override
  String localDataDeleted(String name) {
    return 'Lokale Daten von „$name“ gelöscht.';
  }

  @override
  String localDataNotDeleted(String error) {
    return 'Lokale Daten nicht gelöscht: $error';
  }

  @override
  String get removeAccountQuestion => 'Konto aus der App entfernen?';

  @override
  String removeAccountContent(String name, String email, String note) {
    return '„$name“ ($email) wird zusammen mit dem im Schlüsselbund gespeicherten Kennwort aus PostinoVip entfernt.\n\n$note Die Kontakte (Personen) bleiben ebenfalls auf diesem Computer.\n\nDas Entfernen wird übernommen, wenn Sie im Fenster „Konten“ auf OK klicken.';
  }

  @override
  String get removeAccountPop3Note =>
      'Auf dem Server wird nichts geändert. Die mit POP3 heruntergeladenen E-Mails bleiben auf diesem Computer (für einige ist es die einzige Kopie): Sie finden sie unter „Daten entfernter Konten“, und sie erscheinen wieder, wenn Sie das Konto erneut hinzufügen.';

  @override
  String get removeAccountImapNote =>
      'Auf dem Server wird nichts geändert: Die E-Mails bleiben, wo sie sind, und Sie können das Konto jederzeit erneut hinzufügen. Die bereits heruntergeladenen E-Mails bleiben auf diesem Computer: Sie können sie später unter „Daten entfernter Konten“ löschen.';

  @override
  String get deleteForeverQuestion => 'E-Mails endgültig löschen?';

  @override
  String deleteForeverContent(String name, String size, String expected) {
    return '„$name“ war ein POP3-Konto: Die E-Mails ($size) wurden auf diesen Computer heruntergeladen, und dies ist die einzige Kopie. Bereits vom Server entfernte E-Mails können nicht mehr wiederhergestellt werden.\n\nZur Bestätigung eingeben: $expected';
  }

  @override
  String get deleteForever => 'Endgültig löschen';

  @override
  String get browserNotOpened => 'Der Browser wurde nicht geöffnet.';

  @override
  String signInNotStarted(String error) {
    return 'Anmeldung nicht gestartet: $error';
  }

  @override
  String get signInExpired => 'Anmeldung abgelaufen: Versuchen Sie es erneut.';

  @override
  String signInFailedError(String error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String get signInFailed => 'Anmeldung fehlgeschlagen.';

  @override
  String get signInWithoutContacts =>
      'Angemeldet, aber ohne Berechtigung für Kontakte: Die Kontaktsynchronisierung bleibt deaktiviert. Um sie zu aktivieren, setzen Sie das Häkchen erneut und erlauben Sie den Zugriff.';

  @override
  String get signInWithoutCalendar =>
      'Angemeldet, aber ohne Berechtigung für den Kalender: Die Kalendersynchronisierung bleibt deaktiviert. Um sie zu aktivieren, setzen Sie das Häkchen erneut und erlauben Sie den Zugriff.';

  @override
  String get signInWithoutContactsCalendar =>
      'Angemeldet, aber ohne Berechtigung für Kontakte und Kalender: Die Synchronisierung von Kontakten und Kalender bleibt deaktiviert. Um sie zu aktivieren, setzen Sie das Häkchen erneut und erlauben Sie den Zugriff.';

  @override
  String waitingSignIn(String company) {
    return 'Warten auf die Anmeldung auf der Seite von $company im Browser…';
  }

  @override
  String signedInWith(String company) {
    return 'Mit $company angemeldet: kein Kennwort zu speichern.';
  }

  @override
  String noPasswordSignIn(String company) {
    return 'Kein Kennwort: Sie melden sich auf der Seite von $company im Browser an. Wenn Sie zurückkehren, werden Adresse und Server automatisch ausgefüllt.';
  }

  @override
  String serviceUnavailable(String service) {
    return '$service ist nicht verfügbar: Dem Core fehlt die App-ID.';
  }

  @override
  String signInWith(String company) {
    return 'Mit $company anmelden';
  }

  @override
  String get welcomeTitle => 'Willkommen bei PostinoVip';

  @override
  String get newAccount => 'Neues Konto';

  @override
  String get editAccount => 'Konto ändern';

  @override
  String get firstRunIntro =>
      'Geben Sie die Daten Ihres Postfachs ein. Das Kennwort wird im Schlüsselbund des Systems gespeichert.';

  @override
  String get accountType => 'Kontotyp';

  @override
  String get accountTypeHelp =>
      'IMAP: Die E-Mails bleiben auf dem Server und sind auf allen Geräten sichtbar (empfohlen).\nPOP3: Die E-Mails werden auf diesen Computer heruntergeladen. Dies kann später nicht geändert werden.';

  @override
  String accountTypeServices(String services) {
    return '$services: Anmeldung über den Browser, ohne Kennwort.';
  }

  @override
  String accountTypeValue(String type) {
    return 'Kontotyp: $type';
  }

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get nameOptionalHint =>
      'z. B. Arbeit; wenn leer, wird die Adresse angezeigt';

  @override
  String get emailAddressUser => 'E-Mail-Adresse (auch der Benutzername)';

  @override
  String get invalidAddressShort => 'Ungültige Adresse';

  @override
  String get accountAlreadyPresent => 'Dieses Konto ist bereits vorhanden';

  @override
  String get password => 'Kennwort';

  @override
  String get hidePassword => 'Kennwort ausblenden';

  @override
  String get showPassword => 'Kennwort anzeigen';

  @override
  String get passwordRequired => 'Kennwort erforderlich';

  @override
  String sameMailboxOtherType(String type, String name) {
    return 'Dieses Postfach ist bereits als $type eingerichtet („$name“). Es kann auf beide Arten verwendet werden, aber wenn POP3 E-Mails vom Server entfernt, verschwinden sie auch aus dem IMAP-Konto.';
  }

  @override
  String incomingServer(String type) {
    return '$type (Posteingang)';
  }

  @override
  String get outgoingServer => 'SMTP (Postausgang)';

  @override
  String get smtpAuthTitle =>
      'Der Postausgangsserver (SMTP) erfordert Authentifizierung';

  @override
  String get smtpAuthSubtitle =>
      'Mit Adresse und Kennwort des Postfachs. Nur für einen Server deaktivieren, der E-Mails ohne Anmeldung annimmt (z. B. an Port 25 eines Firmennetzwerks).';

  @override
  String get downloadedMail => 'Auf diesen Computer heruntergeladene E-Mails';

  @override
  String get downloadedMailHelp =>
      'Die neuesten werden im Hintergrund heruntergeladen und öffnen sich sofort, die anderen beim Öffnen.\n„Gelöschte Elemente“ und „Junk-E-Mail“: nur die Liste.';

  @override
  String get recommendedSuffix => ' (empfohlen)';

  @override
  String get syncContactsGoogle =>
      'Kontakte mit Google synchronisieren (CardDAV)';

  @override
  String get syncContactsServer =>
      'Kontakte mit dem Server synchronisieren (CardDAV)';

  @override
  String get notYetForMicrosoft => 'Für Microsoft-Konten noch nicht verfügbar.';

  @override
  String get signInWithGoogleFirst =>
      'Klicken Sie zuerst auf „Mit Google anmelden“.';

  @override
  String get syncContactsGoogleHelp =>
      'Das Adressbuch dieses Kontos wird zu Ihren Google-Kontakten. Beim Aktivieren öffnet sich der Browser, um PostinoVip den Zugriff auf Ihre Kontakte zu erlauben.';

  @override
  String get syncContactsServerHelp =>
      'Das Adressbuch dieses Kontos wird zu dem des Kontaktservers, mit denselben Anmeldedaten. Beim ersten Mal werden Kontakte, die nur auf diesem Computer sind, erst nach Ihrer Bestätigung auf den Server übertragen.';

  @override
  String get contactsSignInWaiting =>
      'Anmeldung bei Google im Browser: Erlauben Sie den Zugriff auf die Kontakte.';

  @override
  String get contactsServerUrl => 'Adresse des Kontaktservers (optional)';

  @override
  String get emptyFoundOnIncoming =>
      'Leer: wird automatisch auf dem Posteingangsserver gesucht';

  @override
  String emptyFoundOn(String host) {
    return 'Leer: wird automatisch auf $host gesucht';
  }

  @override
  String get httpsRequired => 'Eine https://-Adresse ist erforderlich';

  @override
  String get testAddressBook => 'Adressbuch testen';

  @override
  String addressBookFound(String name) {
    return 'Gefunden: „$name“';
  }

  @override
  String get addressBookNotFound => 'Adressbuch nicht gefunden.';

  @override
  String get calendarSection => 'Kalender';

  @override
  String get syncCalendarGoogle =>
      'Kalender mit Google synchronisieren (CalDAV)';

  @override
  String get syncCalendarServer =>
      'Kalender mit dem Server synchronisieren (CalDAV)';

  @override
  String get syncCalendarGoogleHelp =>
      'Ihre Google-Kalender werden zu den Kalendern dieses Kontos; schreibgeschützte (z. B. Feiertage) sind sichtbar, aber nicht änderbar. Beim Aktivieren öffnet sich der Browser, um PostinoVip den Zugriff auf Ihren Kalender zu erlauben.';

  @override
  String get syncCalendarServerHelp =>
      'Die Serverkalender, die Termine annehmen, werden zu den Kalendern dieses Kontos. Beim ersten Mal werden Termine, die nur auf diesem Computer sind, erst nach Ihrer Bestätigung auf den Server übertragen.';

  @override
  String get calendarSignInWaiting =>
      'Anmeldung bei Google im Browser: Erlauben Sie den Zugriff auf den Kalender.';

  @override
  String get calendarServerUrl => 'Adresse des Kalenderservers (optional)';

  @override
  String get testCalendar => 'Kalender testen';

  @override
  String calendarsFound(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gefunden',
    );
    return '$_temp0: $names';
  }

  @override
  String quoted(String text) {
    return '„$text“';
  }

  @override
  String get calendarNotFound => 'Kalender nicht gefunden.';

  @override
  String get enterAddressPasswordFirst =>
      'Geben Sie zuerst Adresse und Kennwort ein.';

  @override
  String get enterServerOrCalendarUrl =>
      'Geben Sie den Posteingangsserver oder die Adresse des Kalenderservers ein.';

  @override
  String get enterServerOrContactsUrl =>
      'Geben Sie den Posteingangsserver oder die Adresse des Kontaktservers ein.';

  @override
  String get deliverySection => 'Übermittlung';

  @override
  String get leaveCopyOnServer =>
      'Eine Kopie der Nachrichten auf dem Server belassen';

  @override
  String get removeFromServerAfter => 'Vom Server entfernen nach';

  @override
  String get days => 'Tagen';

  @override
  String get removeWhenDeleted =>
      'Vom Server entfernen, wenn aus „Gelöschte Elemente“ gelöscht';

  @override
  String get pop3NoCopyWarning =>
      'Jede Nachricht wird direkt nach dem Herunterladen vom Server entfernt: Sie bleibt nur auf diesem Computer.';

  @override
  String get checkMailEvery => 'Auf neue E-Mails prüfen alle';

  @override
  String get checkMailEveryHelp =>
      'Auch mit Senden/Empfangen (F9). Die E-Mails sind nur auf diesem Computer: Eine Sicherung ist empfehlenswert.';

  @override
  String minutesCount(int count) {
    return '$count Minuten';
  }

  @override
  String get server => 'Server';

  @override
  String get serverHint => 'z. B. mail.domain.de';

  @override
  String get serverRequired => 'Server erforderlich';

  @override
  String get port => 'Port';

  @override
  String get encryption => 'Verschlüsselung';

  @override
  String get unencryptedWarning =>
      'Ohne Verschlüsselung werden Kennwort und E-Mails im Klartext übertragen: Jeder im Netzwerk kann sie lesen. Nur in einem vertrauenswürdigen Netzwerk verwenden.';

  @override
  String get certificateTrustedByYou =>
      'Von Ihnen akzeptiertes Serverzertifikat (nicht von einer anerkannten Stelle signiert).';

  @override
  String get stopTrusting => 'Nicht mehr vertrauen';

  @override
  String testFailed(String error) {
    return 'Test fehlgeschlagen: $error';
  }

  @override
  String get trustCertificateQuestion => 'Diesem Zertifikat vertrauen?';

  @override
  String invalidCertificatePresented(String server, String address) {
    return 'Der $server-Server $address hat ein ungültiges Zertifikat vorgelegt:';
  }

  @override
  String get certificateIssuedTo => 'Ausgestellt für';

  @override
  String get certificateIssuedBy => 'Ausgestellt von';

  @override
  String get certificateValid => 'Gültig';

  @override
  String certificateValidRange(String from, String to) {
    return 'vom $from bis $to';
  }

  @override
  String get certificateFingerprint => 'SHA-256-Fingerabdruck';

  @override
  String get certificateAdvice =>
      'Akzeptieren Sie es nur, wenn Sie wissen, dass dieser Server ein eigenes Zertifikat verwendet (z. B. ein Firmen- oder Heimserver); vergleichen Sie wenn möglich den Fingerabdruck mit dem, den Ihr Administrator Ihnen nennt. Ein unerwartetes Zertifikat kann bedeuten, dass jemand versucht, Ihr Kennwort abzufangen.\n\nWenn Sie es akzeptieren, vertraut PostinoVip nur diesem Zertifikat: Legt der Server ein anderes vor, werden Sie erneut gefragt.';

  @override
  String get trustCertificate => 'Dem Zertifikat vertrauen';

  @override
  String get testConnection => 'Kontoeinstellungen testen';

  @override
  String get save => 'Speichern';

  @override
  String get saveAfterTest =>
      '„Speichern“ ist nach einem erfolgreichen Test verfügbar.';

  @override
  String accountNotSaved(String error) {
    return 'Konto nicht gespeichert: $error';
  }

  @override
  String unencryptedIncoming(String address) {
    return 'Posteingang ($address)';
  }

  @override
  String unencryptedOutgoing(String address) {
    return 'Postausgang ($address)';
  }

  @override
  String get unencryptedTitle => 'Verbindung ohne Verschlüsselung';

  @override
  String unencryptedContent(String servers) {
    return 'Für $servers haben Sie die Verschlüsselung „Keine“ gewählt: Kennwort und E-Mails werden im Klartext übertragen, und jeder im selben Netzwerk (öffentliches WLAN, Firmennetzwerk, Anbieter) kann sie lesen oder ändern.\n\nTrotzdem speichern?';
  }

  @override
  String get andSeparator => ' und ';

  @override
  String get saveUnencrypted => 'Ohne Verschlüsselung speichern';

  @override
  String get runFilterAll => 'Alle Nachrichten';

  @override
  String get runFilterRead => 'Gelesene Nachrichten';

  @override
  String get runFilterUnread => 'Ungelesene Nachrichten';

  @override
  String ruleNameFrom(String sender) {
    return 'Von $sender';
  }

  @override
  String ruleCreated(String name) {
    return 'Regel „$name“ erstellt: Sie gilt für E-Mails, die ab jetzt eintreffen.';
  }

  @override
  String ruleNotSaved(String error) {
    return 'Regel nicht gespeichert: $error';
  }

  @override
  String get orSeparator => ' oder ';

  @override
  String ruleDescFrom(String words) {
    return 'von $words';
  }

  @override
  String ruleDescToOrCc(String words) {
    return 'An oder Cc enthält $words';
  }

  @override
  String get ruleDescSentOnlyToMe => 'nur an mich gesendet';

  @override
  String get ruleDescMeInTo => 'ich in An';

  @override
  String get ruleDescMeInCc => 'ich in Cc';

  @override
  String ruleDescSubject(String words) {
    return 'Betreff enthält $words';
  }

  @override
  String ruleDescSubjectOrBody(String words) {
    return 'Betreff oder Text enthält $words';
  }

  @override
  String get ruleDescAttachments => 'mit Anlagen';

  @override
  String ruleDescSize(int kb) {
    return 'größer als $kb KB';
  }

  @override
  String ruleDescMove(String folder) {
    return 'nach $folder verschieben';
  }

  @override
  String ruleDescCopy(String folder) {
    return 'nach $folder kopieren';
  }

  @override
  String get ruleDescDelete => 'löschen';

  @override
  String get ruleDescMarkRead => 'als gelesen markieren';

  @override
  String get ruleDescFlag => 'zur Nachverfolgung kennzeichnen';

  @override
  String ruleDescCategory(String name) {
    return 'Kategorie $name';
  }

  @override
  String get ruleDescStop => 'keine weiteren Regeln anwenden';

  @override
  String get ruleDescAllMail => 'Alle E-Mails';

  @override
  String ruleDescIf(String conditions) {
    return 'Wenn $conditions';
  }

  @override
  String ruleDescExcept(String exceptions) {
    return ', außer wenn $exceptions';
  }

  @override
  String rulesNotRead(String error) {
    return 'Regeln nicht gelesen: $error';
  }

  @override
  String get deleteRuleQuestion => 'Regel löschen?';

  @override
  String deleteRuleContent(String name) {
    return 'Die Regel „$name“ wird nicht mehr angewendet. Bereits sortierte E-Mails bleiben, wo sie sind.';
  }

  @override
  String rulesNotSaved(String error) {
    return 'Regeln nicht gespeichert: $error';
  }

  @override
  String get rulesAndAlerts => 'Regeln und Benachrichtigungen';

  @override
  String get applyChangesToFolder => 'Änderungen auf diesen Ordner anwenden';

  @override
  String get newRuleEllipsis => 'Neue Regel…';

  @override
  String get runRulesNowEllipsis => 'Regeln jetzt anwenden…';

  @override
  String get noRules =>
      'Keine Regeln. Mit „Neue Regel…“ werden eingehende E-Mails automatisch sortiert.';

  @override
  String get rulesInfo =>
      'Regeln werden in der Reihenfolge der Liste auf E-Mails angewendet, die im Posteingang eintreffen, während PostinoVip geöffnet ist; E-Mails, die bei geschlossener App eingetroffen sind, werden beim erneuten Öffnen sortiert.';

  @override
  String get chooseFolderColon => 'Wählen Sie den Ordner:';

  @override
  String get ruleNameRequired => 'Geben Sie den Namen der Regel ein.';

  @override
  String get ruleFolderRequired =>
      'Wählen Sie den Zielordner zum Verschieben oder Kopieren.';

  @override
  String get ruleActionRequired =>
      'Wählen Sie mindestens eine Aktion auf der Registerkarte „Aktionen“.';

  @override
  String get ruleSizeRequired => 'Geben Sie die Größe in KB ein.';

  @override
  String get ruleForAllMail => 'Regel für alle E-Mails';

  @override
  String get ruleForAllMailContent =>
      'Ohne Bedingungen gilt die Regel für alle E-Mails, die Sie erhalten. Ist das richtig?';

  @override
  String get newRule => 'Neue Regel';

  @override
  String get editRule => 'Regel ändern';

  @override
  String get ruleName => 'Name der Regel';

  @override
  String get ruleConditions => 'Bedingungen';

  @override
  String get ruleActions => 'Aktionen';

  @override
  String get ruleExceptions => 'Ausnahmen';

  @override
  String get ruleConditionsIntro =>
      'Regel auf E-Mails anwenden, die alle ausgewählten Bedingungen erfüllen:';

  @override
  String get ruleExceptionsIntro =>
      'Außer wenn mindestens eine davon zutrifft:';

  @override
  String get ruleFrom => 'von';

  @override
  String get ruleFromHint => 'z. B. anna@example.com; example.com';

  @override
  String get ruleToOrCc => 'An oder Cc enthält';

  @override
  String get ruleToOrCcHint => 'Namen oder Adressen, getrennt durch ;';

  @override
  String get ruleMeInTo => 'meine Adresse steht im Feld „An“';

  @override
  String get ruleMeInCc => 'meine Adresse steht im Feld „Cc“';

  @override
  String get ruleSubjectContains => 'der Betreff enthält';

  @override
  String get ruleSubjectOrBodyContains => 'der Betreff oder Text enthält';

  @override
  String get ruleWordsHint => 'Wörter, getrennt durch ;';

  @override
  String get ruleLargerThan => 'größer als';

  @override
  String get chooseFolderEllipsis => 'Ordner auswählen…';

  @override
  String get ruleActionsIntro =>
      'Was mit E-Mails geschehen soll, die die Bedingungen erfüllen:';

  @override
  String get ruleMoveTo => 'in den Ordner verschieben';

  @override
  String get ruleMoveToTitle => 'In Ordner verschieben';

  @override
  String get ruleCopyTo => 'in den Ordner kopieren';

  @override
  String get ruleCopyToTitle => 'In Ordner kopieren';

  @override
  String get ruleDeleteAction => 'löschen (nach „Gelöschte Elemente“)';

  @override
  String get ruleFlagAction => 'zur Nachverfolgung kennzeichnen';

  @override
  String get ruleCategoryAction => 'der Kategorie zuordnen';

  @override
  String get ruleStopAction => 'keine weiteren Regeln anwenden';

  @override
  String rulesNotRun(String error) {
    return 'Regeln nicht angewendet: $error';
  }

  @override
  String progressUnavailable(String error) {
    return 'Fortschritt nicht verfügbar: $error';
  }

  @override
  String get runInFolder => 'Im Ordner anwenden';

  @override
  String runStoppedError(String error) {
    return 'Wegen eines Fehlers angehalten: $error';
  }

  @override
  String runStoppedChecked(int checked, int total) {
    return 'Angehalten: $checked von $total Nachrichten geprüft';
  }

  @override
  String runDoneChecked(int checked) {
    return 'Fertig: $checked Nachrichten geprüft';
  }

  @override
  String runOutcome(String head, int applied) {
    return '$head, $applied verschoben oder geändert';
  }

  @override
  String runFailedActions(int count) {
    return ', $count Aktionen fehlgeschlagen (Details im Core-Protokoll)';
  }

  @override
  String get runRulesNow => 'Regeln jetzt anwenden';

  @override
  String get rulesToRun => 'Anzuwendende Regeln auswählen:';

  @override
  String get ruleDisabledSuffix => ' (deaktiviert)';

  @override
  String get runInFolderLabel => 'Im Ordner anwenden: ';

  @override
  String get includeSubfolders => 'Unterordner einbeziehen';

  @override
  String get applyRulesTo => 'Regeln anwenden auf';

  @override
  String get preparing => 'Vorbereitung…';

  @override
  String runProgress(int checked, int total) {
    return '$checked von $total Nachrichten geprüft';
  }

  @override
  String get stopping => 'wird angehalten…';

  @override
  String get stop => 'Anhalten';

  @override
  String get runNow => 'Jetzt anwenden';

  @override
  String settingsNotRead(String error) {
    return 'Einstellungen nicht gelesen: $error';
  }

  @override
  String get autoReplyTextRequired =>
      'Schreiben Sie die Nachricht der automatischen Antwort.';

  @override
  String get endAfterStart => 'Das Ende muss nach dem Beginn liegen.';

  @override
  String get turnOnAutoRepliesQuestion => 'Automatische Antworten aktivieren?';

  @override
  String get turnOnAutoRepliesContent =>
      'Ab jetzt antwortet PostinoVip automatisch, einmal pro Absender, auf E-Mails im Posteingang, in denen Sie unter „An“ oder „Cc“ stehen, solange die App geöffnet ist. Die Antworten werden ohne Rückfrage gesendet.';

  @override
  String get turnOn => 'Aktivieren';

  @override
  String notSavedPlural(String error) {
    return 'Nicht gespeichert: $error';
  }

  @override
  String get dontSendAutoReplies => 'Keine automatischen Antworten senden';

  @override
  String get sendAutoReplies => 'Automatische Antworten senden';

  @override
  String get onlyDuringRange => 'Nur in diesem Zeitraum senden';

  @override
  String get startTimeColon => 'Beginn:';

  @override
  String get endTimeColon => 'Ende:';

  @override
  String get autoRepliesInfo =>
      'Die Antworten werden von diesem Computer gesendet, während PostinoVip geöffnet ist (E-Mails, die bei geschlossener App eingetroffen sind, erhalten die Antwort beim erneuten Öffnen): nur eine pro Absender, nur wenn Sie unter „An“ oder „Cc“ stehen, nie an Verteilerlisten, andere automatische Antworten oder Absender wie „noreply“. Sie werden nicht in „Gesendete Elemente“ gespeichert.';

  @override
  String get autoReplyPlaceholder =>
      'z. B. Ich bin bis Montag, 16. November, nicht im Büro und antworte nach meiner Rückkehr.';

  @override
  String get junkLevelNone => 'Keine automatische Filterung';

  @override
  String get junkLevelNoneInfo =>
      'E-Mails von blockierten Absendern werden weiterhin in den Ordner „Junk-E-Mail“ verschoben.';

  @override
  String get junkLevelLow => 'Niedrig';

  @override
  String get junkLevelLowInfo =>
      'Die offensichtlichsten Junk-E-Mails verschieben: die vom Server als Spam markierten.';

  @override
  String get junkLevelHigh => 'Hoch';

  @override
  String get junkLevelHighInfo =>
      'Auch E-Mails mit einer Bewertung nahe der Serverschwelle verschieben: Dabei können auch normale E-Mails erfasst werden, prüfen Sie den Ordner „Junk-E-Mail“ daher häufig.';

  @override
  String get junkLevelSafeOnly => 'Nur sichere Listen';

  @override
  String get junkLevelSafeOnlyInfo =>
      'Nur E-Mails von Personen oder Domänen auf Ihrer Liste sicherer Absender oder an Ihre Liste sicherer Empfänger bleiben im Posteingang.';

  @override
  String get safeSenders => 'Sichere Absender';

  @override
  String get safeSendersInfo =>
      'E-Mails von diesen Adressen oder Domänen werden nie als Junk-E-Mail behandelt.';

  @override
  String get safeRecipients => 'Sichere Empfänger';

  @override
  String get safeRecipientsInfo =>
      'E-Mails an diese Adressen oder Domänen (z. B. eine Verteilerliste) werden nie als Junk-E-Mail behandelt.';

  @override
  String get blockedSenders => 'Blockierte Absender';

  @override
  String get blockedSendersInfo =>
      'E-Mails von diesen Adressen oder Domänen werden immer in den Ordner „Junk-E-Mail“ verschoben.';

  @override
  String get neverBlockSender => 'Absender nie blockieren';

  @override
  String get neverBlockDomain => 'Domäne des Absenders nie blockieren';

  @override
  String get neverBlockGroup =>
      'Diese Gruppe oder Verteilerliste nie blockieren';

  @override
  String get neverBlockGroups =>
      'Diese Gruppen oder Verteilerlisten nie blockieren';

  @override
  String get blockSender => 'Absender blockieren';

  @override
  String get junkOptionsEllipsis => 'Junk-E-Mail-Optionen…';

  @override
  String get noJunkFolder => 'Kein Junk-E-Mail-Ordner';

  @override
  String noJunkFolderContent(String name) {
    return 'Das Konto „$name“ hat keinen Junk-E-Mail-Ordner: Wählen Sie einen unter „Junk-E-Mail-Optionen“. Der Absender wurde nicht blockiert.';
  }

  @override
  String get markAsNotJunk => 'Als „Keine Junk-E-Mail“ markieren';

  @override
  String notJunkMoveBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Diese $count Nachrichten werden zurück in den Ordner „Posteingang“ verschoben.',
      one:
          'Diese Nachricht wird zurück in den Ordner „Posteingang“ verschoben.',
    );
    return '$_temp0';
  }

  @override
  String alwaysTrustSender(String sender) {
    return 'E-Mails von „$sender“ immer vertrauen';
  }

  @override
  String get alwaysTrustSenders =>
      'E-Mails von diesen Absendern immer vertrauen';

  @override
  String optionsNotRead(String error) {
    return 'Optionen nicht gelesen: $error';
  }

  @override
  String optionsNotSaved(String error) {
    return 'Optionen nicht gespeichert: $error';
  }

  @override
  String get invalidValue => 'ungültiger Wert';

  @override
  String get junkOptions => 'Junk-E-Mail-Optionen';

  @override
  String get junkOptionsIntro =>
      'Neue E-Mails im Posteingang, die wie Junk-E-Mail aussehen, werden in einen speziellen Ordner verschoben, während PostinoVip geöffnet ist. Die Bewertung stammt vom Mailserver. Wählen Sie die Schutzstufe:';

  @override
  String get junkFolder => 'Junk-E-Mail-Ordner';

  @override
  String junkFolderAutomatic(String folder) {
    return 'Automatisch: „$folder“';
  }

  @override
  String get junkFolderAutomaticNone => 'Automatisch (kein Ordner gefunden)';

  @override
  String get junkFolderInfo =>
      'Automatisch: der vom Server angegebene oder einer mit „spam“, „junk“ oder „indesiderata“ im Namen. Für einen neuen Ordner: Registerkarte „Ordner“ → „Neuer Ordner“, dann hier auswählen.';

  @override
  String get junkNoFolderWarning =>
      'Ohne Ordner verschiebt der Filter keine E-Mails.';

  @override
  String get noEntries => 'Keine Einträge';

  @override
  String get addEllipsis => 'Hinzufügen…';

  @override
  String get trustContacts => 'Auch E-Mails von meinen Kontakten vertrauen';

  @override
  String get junkEntryInvalid =>
      'Geben Sie eine Adresse (anna@example.com) oder eine Domäne (@example.com) ein.';

  @override
  String get addAddressOrDomain => 'Adresse oder Domäne hinzufügen';

  @override
  String get editAddressOrDomain => 'Adresse oder Domäne bearbeiten';

  @override
  String get junkEntryLabel =>
      'Geben Sie eine E-Mail-Adresse oder einen Internetdomänennamen ein';

  @override
  String get junkEntryHint => 'z. B. anna@example.com oder @example.com';

  @override
  String get alreadyInArchive => 'Die Nachricht ist bereits im Archivordner';

  @override
  String get archiveTooltip => 'In den Archivordner verschieben (Rücktaste)';

  @override
  String get mailsAlreadyInArchive =>
      'Die Nachrichten sind bereits im Archivordner';

  @override
  String get archiveFolderName => 'Archiv';

  @override
  String get offlineUnavailable =>
      'Ohne Verbindung zum Server nicht verfügbar.';

  @override
  String archiveFirstTime(String name) {
    return 'Das Konto „$name“ hat noch keinen Archivordner. Wählen Sie ihn aus: „Archivieren“ verschiebt E-Mails dorthin, ohne sie zu löschen.';
  }

  @override
  String archiveInfo(String name) {
    return '„Archivieren“ verschiebt E-Mails von „$name“ in diesen Ordner, ohne sie zu löschen.';
  }

  @override
  String get useExistingFolder => 'Einen vorhandenen Ordner verwenden';

  @override
  String get chooseAFolder => 'Wählen Sie einen Ordner';

  @override
  String get createTopFolder =>
      'Einen neuen Ordner auf oberster Ebene des Kontos erstellen';

  @override
  String get okAndArchive => 'OK und archivieren';

  @override
  String get stopIgnore => 'Nicht mehr ignorieren';

  @override
  String get ignore => 'Ignorieren';

  @override
  String get stopIgnoreTooltip =>
      'Die Unterhaltung kehrt in den Posteingang zurück, und neue E-Mails gehen nicht mehr nach „Gelöschte Elemente“';

  @override
  String get ignoreTooltip =>
      'Die Unterhaltung und künftige Nachrichten nach „Gelöschte Elemente“ verschieben';

  @override
  String cleanUpFolderContent(String name) {
    return 'Redundante Nachrichten im Ordner „$name“ (die in einer Antwort vollständig zitierten) werden nach „Gelöschte Elemente“ verschoben. Ungelesene, gekennzeichnete, kategorisierte oder signierte Nachrichten bleiben, wo sie sind.';
  }

  @override
  String get stopIgnoreContent =>
      'Die ausgewählte Unterhaltung wird nicht mehr ignoriert, und ihre Nachrichten in „Gelöschte Elemente“ werden in den Posteingang verschoben.';

  @override
  String get ignoreContent =>
      'Die Nachrichten der ausgewählten Unterhaltung in diesem Ordner und alle künftigen Nachrichten werden nach „Gelöschte Elemente“ verschoben.';

  @override
  String get dontShowAgain => 'Diese Meldung nicht mehr anzeigen';

  @override
  String get notifyAlways => 'Immer';

  @override
  String get notifyUnfocused => 'Nur wenn das Fenster nicht im Vordergrund ist';

  @override
  String get notifyNever => 'Nie';

  @override
  String get readImmediately => 'Sobald sie geöffnet wird';

  @override
  String get readAfterDelay => 'Nachdem sie einige Sekunden angezeigt wurde';

  @override
  String get readManual => 'Nie automatisch (nur mit der Schaltfläche)';

  @override
  String get receiptAsk =>
      'Jedes Mal fragen, ob eine Lesebestätigung gesendet werden soll';

  @override
  String get receiptAlways => 'Immer eine Lesebestätigung senden';

  @override
  String get receiptNever => 'Nie eine Lesebestätigung senden';

  @override
  String get categoryRed => 'Rote Kategorie';

  @override
  String get categoryOrange => 'Orange Kategorie';

  @override
  String get categoryYellow => 'Gelbe Kategorie';

  @override
  String get categoryGreen => 'Grüne Kategorie';

  @override
  String get categoryBlue => 'Blaue Kategorie';

  @override
  String get categoryPurple => 'Lila Kategorie';

  @override
  String get followUpTomorrow => 'Morgen';

  @override
  String get followUpThisWeek => 'Diese Woche';

  @override
  String get followUpNextWeek => 'Nächste Woche';

  @override
  String get followUpNoDate => 'Kein Datum';

  @override
  String get clearAllCategories => 'Alle Kategorien löschen';

  @override
  String get allCategoriesEllipsis => 'Alle Kategorien…';

  @override
  String get customDateEllipsis => 'Benutzerdefiniert…';

  @override
  String get markComplete => 'Als erledigt markieren';

  @override
  String get clearFlag => 'Kennzeichnung löschen';

  @override
  String get dueByTitle => 'Fälligkeitsdatum';

  @override
  String get categoriesTitle => 'Farbkategorien';

  @override
  String get categoriesInfo =>
      'Die Namen gelten nur auf diesem Computer; auf dem Server wird jede Kategorie mit ihrer Farbe gespeichert.';

  @override
  String get defaultNames => 'Standardnamen';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Desktop-E-Mail-Client: Oberfläche in Flutter, Core in C# mit MailKit.';

  @override
  String aboutLegal(String license) {
    return 'Dieses Programm ist freie Software: Sie können es unter den Bedingungen der $license, veröffentlicht von der Free Software Foundation, weitergeben und/oder ändern.\n\nEs wird in der Hoffnung verbreitet, dass es nützlich ist, aber OHNE JEDE GEWÄHRLEISTUNG, sogar ohne die implizite Gewährleistung der MARKTREIFE oder der EIGNUNG FÜR EINEN BESTIMMTEN ZWECK. Der vollständige Lizenztext steht unter „Lizenzen anzeigen“ → PostinoVip.';
  }

  @override
  String coreVersionUnavailable(String error) {
    return 'Core: Version nicht verfügbar ($error)';
  }

  @override
  String coreVersion(String version) {
    return 'Core: Version $version';
  }

  @override
  String get coreVersionMismatch =>
      'Achtung: App und Core haben unterschiedliche Versionen (Core neu erstellen).';

  @override
  String get composeMessages => 'Nachrichten verfassen';

  @override
  String get composeInFormat => 'Nachrichten in diesem Format verfassen';

  @override
  String get composeInFormatHelp =>
      'Für neue Nachrichten; Antworten und Weiterleitungen verwenden das Format der Originalnachricht';

  @override
  String get signaturesSection => 'Signaturen';

  @override
  String signatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Signaturen',
      one: '1 Signatur',
      zero: 'Keine Signaturen',
    );
    return '$_temp0';
  }

  @override
  String get signaturesInfo =>
      'Werden neuen Nachrichten und Antworten automatisch hinzugefügt, pro Konto';

  @override
  String get markAsReadSection => 'Als gelesen markieren';

  @override
  String get readReceiptsSection => 'Lesebestätigungen';

  @override
  String get alwaysRequestReceipt =>
      'Für neue Nachrichten immer eine Lesebestätigung anfordern';

  @override
  String get receiptForReceived =>
      'Für jede empfangene Nachricht mit einer Anforderung einer Lesebestätigung:';

  @override
  String get confirmBeforeIgnore => 'Vor „Unterhaltung ignorieren“ fragen';

  @override
  String get confirmBeforeStopIgnoring =>
      'Vor „Unterhaltung nicht mehr ignorieren“ fragen';

  @override
  String get newMailNotifications => 'Benachrichtigungen bei neuen E-Mails';

  @override
  String get notificationsUnavailable =>
      'Systembenachrichtigungen nicht verfügbar: Der Grund steht im Terminal („[notifiche]“).';

  @override
  String get testNotification => 'Testbenachrichtigung';

  @override
  String get testNotificationText =>
      'Testbenachrichtigung: Wenn Sie sie sehen, funktionieren Benachrichtigungen.';

  @override
  String get firstDayOfWeek => 'Erster Wochentag';

  @override
  String get workDays => 'Arbeitstage (Arbeitswoche)';

  @override
  String get workStart => 'Beginn der Arbeitszeit';

  @override
  String get workEnd => 'Ende der Arbeitszeit';

  @override
  String receiptNotSent(String error) {
    return 'Lesebestätigung nicht gesendet: $error';
  }

  @override
  String receiptNotRecorded(String error) {
    return 'Lesebestätigung nicht vermerkt: $error';
  }

  @override
  String operationFailed(String error) {
    return 'Vorgang fehlgeschlagen: $error';
  }

  @override
  String get outboxSending =>
      'Wird gesendet: Die Nachricht geht hinaus, sobald der Server antwortet.';

  @override
  String get outboxDeleted =>
      'Nachricht aus dem Postausgang gelöscht: Sie wird nicht gesendet.';

  @override
  String get outboxMovedToDrafts =>
      'Nachricht nach „Entwürfe“ verschoben: Öffnen Sie sie dort, um sie zu bearbeiten.';

  @override
  String folderNotListed(String folder) {
    return 'Der Server hat den Ordner „$folder“ bestätigt, zeigt ihn aber nicht in der Ordnerliste an.';
  }

  @override
  String get anotherOperation => 'Ein anderer Vorgang wird ausgeführt';

  @override
  String folderDeletedPermanently(String folder) {
    return 'Ordner „$folder“ endgültig gelöscht';
  }

  @override
  String folderMovedToTrash(String folder) {
    return 'Ordner „$folder“ nach „Gelöschte Elemente“ verschoben';
  }

  @override
  String folderNotDeleted(String error) {
    return 'Ordner nicht gelöscht: $error';
  }

  @override
  String folderEmptied(String folder, String mails, String folders) {
    return '„$folder“ geleert: $mails$folders endgültig gelöscht';
  }

  @override
  String emptiedMails(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0';
  }

  @override
  String emptiedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' und $count Ordner',
      one: ' und 1 Ordner',
    );
    return '$_temp0';
  }

  @override
  String folderNotEmptied(String error) {
    return 'Ordner nicht geleert: $error';
  }

  @override
  String folderMovedToTop(String folder) {
    return 'Ordner „$folder“ auf die oberste Ebene des Kontos verschoben';
  }

  @override
  String folderMovedInto(String folder, String parent) {
    return 'Ordner „$folder“ nach „$parent“ verschoben';
  }

  @override
  String folderNotMoved(String error) {
    return 'Ordner nicht verschoben: $error';
  }

  @override
  String get mailNotDownloadedOffline =>
      'Nachricht offline nicht verfügbar: Sie wurde noch nicht auf diesen Computer heruntergeladen.';

  @override
  String readStateNotUpdated(String error) {
    return 'Gelesen-/Ungelesen-Status nicht aktualisiert: $error';
  }

  @override
  String tagsNotUpdated(String error) {
    return 'Kennzeichnung oder Kategorien nicht aktualisiert: $error';
  }

  @override
  String movedTo(String folder) {
    return 'Nach „$folder“ verschoben';
  }

  @override
  String get deletedPermanently => 'Endgültig gelöscht';

  @override
  String markedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 als gelesen markiert';
  }

  @override
  String markedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 als ungelesen markiert';
  }

  @override
  String othersFailed(String text, String error) {
    return '$text; die anderen sind fehlgeschlagen: $error';
  }

  @override
  String readNotUpdated(String error) {
    return 'Lesestatus nicht aktualisiert: $error';
  }

  @override
  String mailsMovedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 nach „$folder“ verschoben';
  }

  @override
  String mailsDeletedPermanently(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 endgültig gelöscht';
  }

  @override
  String mailsMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 nach „Gelöschte Elemente“ verschoben';
  }

  @override
  String mailsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten archiviert',
      one: '1 Nachricht archiviert',
    );
    return '$_temp0';
  }

  @override
  String get conversationIgnored =>
      'Unterhaltung ignoriert: Künftige Nachrichten werden nach „Gelöschte Elemente“ verschoben';

  @override
  String conversationIgnoredMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 nach „Gelöschte Elemente“ verschoben; künftige Nachrichten landen ebenfalls dort';
  }

  @override
  String get conversationNotIgnored =>
      'Die Unterhaltung wird nicht mehr ignoriert';

  @override
  String mailsBackToInbox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 zurück in den Posteingang verschoben';
  }

  @override
  String cleanUpDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count redundante Nachrichten nach „Gelöschte Elemente“ verschoben',
      one: '1 redundante Nachricht nach „Gelöschte Elemente“ verschoben',
      zero: 'Keine redundanten Nachrichten zu verschieben',
    );
    return '$_temp0';
  }

  @override
  String get noMailMoved => 'Keine Nachrichten verschoben';

  @override
  String mailsMovedToJunk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 nach „Junk-E-Mail“ verschoben';
  }

  @override
  String senderBlocked(String sender) {
    return '$sender blockiert';
  }

  @override
  String sendersBlocked(int count, String senders) {
    return '$count Absender blockiert ($senders)';
  }

  @override
  String senderTrusted(String sender) {
    return '$sender als vertrauenswürdig eingestuft';
  }

  @override
  String sendersTrusted(int count, String senders) {
    return '$count Absender als vertrauenswürdig eingestuft ($senders)';
  }

  @override
  String addedToSafeSenders(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries hinzugefügt',
    );
    return '$_temp0 zu „Sichere Absender“';
  }

  @override
  String addedToSafeRecipients(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries hinzugefügt',
    );
    return '$_temp0 zu „Sichere Empfänger“';
  }

  @override
  String listsNotUpdated(String error) {
    return 'Listen nicht aktualisiert: $error';
  }

  @override
  String mailsCopiedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0 nach „$folder“ kopiert';
  }

  @override
  String mailsNotCopied(String error) {
    return 'Nachrichten nicht kopiert: $error';
  }

  @override
  String get fmtTime => 'HH:mm';

  @override
  String get fmtDayMonth => 'dd.MM.';

  @override
  String get fmtDate => 'dd.MM.yyyy';

  @override
  String get fmtWeekdayDate => 'EEE dd.MM.yyyy';

  @override
  String get fmtWeekdayDateTime => 'EEE dd.MM.yyyy HH:mm';

  @override
  String get fmtWeekdayTime => 'EEE HH:mm';

  @override
  String get fmtLongDateTime => 'EEEE, d. MMMM y HH:mm';

  @override
  String get groupNoDate => 'Kein Datum';

  @override
  String get groupYesterday => 'Gestern';

  @override
  String get groupLastWeek => 'Letzte Woche';

  @override
  String get groupTwoWeeksAgo => 'Vor zwei Wochen';

  @override
  String get groupThreeWeeksAgo => 'Vor drei Wochen';

  @override
  String get groupEarlierThisMonth => 'Anfang dieses Monats';

  @override
  String get groupLastMonth => 'Letzter Monat';

  @override
  String get groupOlder => 'Älter';

  @override
  String get sizeTiny => 'Winzig (< 10 KB)';

  @override
  String get sizeSmall => 'Klein (10 - 25 KB)';

  @override
  String get sizeMedium => 'Mittel (25 - 100 KB)';

  @override
  String get sizeLarge => 'Groß (100 - 500 KB)';

  @override
  String get sizeVeryLarge => 'Sehr groß (500 KB - 1 MB)';

  @override
  String get sizeHuge => 'Riesig (1 - 5 MB)';

  @override
  String get sizeEnormous => 'Gigantisch (> 5 MB)';

  @override
  String sizeBytes(int count) {
    return '$count Bytes';
  }

  @override
  String get fmtMonthYear => 'MMMM y';

  @override
  String get fmtFullDate => 'EEEE, d. MMMM y';

  @override
  String get fmtHour => 'HH:00';

  @override
  String get fmtRangeSameMonthStart => 'd.';

  @override
  String get fmtRangeSameMonthEnd => 'd. MMMM y';

  @override
  String get fmtRangeOtherMonthStart => 'd. MMMM';

  @override
  String get fmtRangeOtherMonthEnd => 'd. MMMM y';

  @override
  String get fmtRangeOtherYearStart => 'd. MMMM y';

  @override
  String get fmtRangeOtherYearEnd => 'd. MMMM y';

  @override
  String get recurOrdinalFirst => 'am ersten';

  @override
  String get recurOrdinalSecond => 'am zweiten';

  @override
  String get recurOrdinalThird => 'am dritten';

  @override
  String get recurOrdinalFourth => 'am vierten';

  @override
  String get recurOrdinalLast => 'am letzten';

  @override
  String recurDescDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Jede Woche',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeeklyOn(String every, String days) {
    return '$every am $days';
  }

  @override
  String recurDescMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate',
      one: 'Jeden Monat',
    );
    return '$_temp0';
  }

  @override
  String recurDescMonthlyDay(String every, int day) {
    return '$every am $day.';
  }

  @override
  String recurDescMonthlyWhich(String every, String which) {
    return '$every $which';
  }

  @override
  String recurDescYearlyWhich(String which, String month) {
    return 'Jedes Jahr $which im $month';
  }

  @override
  String recurDescYearlyDay(String day, String month) {
    return 'Jedes Jahr am $day. $month';
  }

  @override
  String get recurDescRecurring => 'Serie';

  @override
  String recurDescTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count Mal',
      one: ', 1 Mal',
    );
    return '$_temp0';
  }

  @override
  String recurDescUntil(String date) {
    return ', bis $date';
  }

  @override
  String whenAllDay(String date) {
    return '$date (ganztägig)';
  }

  @override
  String whenAllDayRange(String start, String end) {
    return 'Vom $start bis $end (ganztägig)';
  }

  @override
  String get coreKindInvalidRequest => 'Ungültige Anfrage';

  @override
  String get coreKindNotFound => 'Nicht gefunden';

  @override
  String get coreKindOffline => 'Keine Verbindung';

  @override
  String get coreKindServer => 'Fehler des Mailservers';

  @override
  String get coreKindConflict => 'Vorgang nicht zulässig';

  @override
  String get coreKindNotSupported => 'Vom Server nicht unterstützt';

  @override
  String get coreKindCertificate => 'Ungültiges Serverzertifikat';

  @override
  String get coreKindOAuth => 'Anmeldung beim Konto fehlgeschlagen';

  @override
  String get coreKindAuth => 'Authentifizierung beim Mailserver fehlgeschlagen';

  @override
  String get coreKindConfig => 'Ungültige Konfiguration';

  @override
  String get coreKindInternal => 'Interner Fehler';

  @override
  String certNameMismatch(String host) {
    return 'für einen anderen Namen als $host ausgestellt';
  }

  @override
  String get certUntrustedRoot =>
      'nicht von einer anerkannten Stelle signiert (z. B. selbstsigniert)';

  @override
  String get certNotTimeValid => 'abgelaufen oder noch nicht gültig';

  @override
  String get certRevoked => 'widerrufen';

  @override
  String get certChainInvalid => 'ungültige Zertifikatkette';

  @override
  String get certNoCertificate => 'kein Zertifikat';

  @override
  String get coreTimeout =>
      'Der Server antwortet nicht: Der Vorgang wurde möglicherweise nicht ausgeführt.';

  @override
  String get coreAuthCheckCredentials =>
      'Überprüfen Sie Benutzername und Kennwort.';

  @override
  String get coreInternalUnexpected =>
      'Unerwarteter Fehler, siehe Core-Protokoll.';

  @override
  String coreCertificateChanged(String address, String problems) {
    return 'Ungültiges Zertifikat für $address ($problems). Öffnen Sie die Kontoeinstellungen und wiederholen Sie „Kontoeinstellungen testen“.';
  }

  @override
  String coreTestCertificateInvalid(String address, String problems) {
    return 'Das Zertifikat des Servers $address ist ungültig: $problems.';
  }

  @override
  String coreTestNoStartTls(String address) {
    return 'Der Server $address bietet kein STARTTLS an: Wählen Sie eine andere Verschlüsselung oder einen anderen Port.';
  }

  @override
  String get coreTestAuthRejected =>
      'Authentifizierung abgelehnt: Überprüfen Sie Adresse und Kennwort.';

  @override
  String coreTestTlsFailed(String address) {
    return 'Verschlüsselte Verbindung zu $address fehlgeschlagen: Verwendet der Port wirklich diese Verschlüsselung?';
  }

  @override
  String coreTestUnreachable(String address) {
    return 'Server $address nicht erreichbar.';
  }

  @override
  String coreTestNoAnswer(String address, String seconds) {
    return 'Keine Antwort von $address innerhalb von $seconds s: falscher Server, Port oder falsche Verschlüsselung?';
  }

  @override
  String coreTestUnexpectedAnswer(String address) {
    return 'Unerwartete Antwort von $address: falscher Port oder falsches Protokoll?';
  }

  @override
  String corePop3NoUidl(String address) {
    return 'Der POP3-Server $address unterstützt UIDL nicht: Es wird benötigt, um E-Mails nicht doppelt herunterzuladen.';
  }

  @override
  String coreOAuthServerUnreachable(String provider) {
    return 'Anmeldeserver von $provider nicht erreichbar.';
  }

  @override
  String coreOAuthInvalidResponse(String provider, String status) {
    return 'Ungültige Antwort des Anmeldeservers von $provider (HTTP $status).';
  }

  @override
  String coreOAuthExpired(String provider) {
    return 'Anmeldung bei $provider abgelaufen oder widerrufen: Wiederholen Sie „Mit $provider anmelden“.';
  }

  @override
  String coreOAuthClientInvalid(String provider) {
    return 'PostinoVip ist bei $provider nicht korrekt registriert (Client-ID).';
  }

  @override
  String coreOAuthFailed(String provider, String error) {
    return 'Anmeldung bei $provider fehlgeschlagen ($error).';
  }

  @override
  String get coreOAuthCancelled => 'Anmeldung abgebrochen.';

  @override
  String get coreOAuthNoCode => 'Anmeldung fehlgeschlagen (kein Code).';

  @override
  String coreOAuthFlowFailed(String error) {
    return 'Anmeldung fehlgeschlagen ($error).';
  }

  @override
  String get coreOAuthNoRefreshToken =>
      'Der Anbieter hat kein Aktualisierungstoken geliefert (offline_access fehlt?).';

  @override
  String coreServerUnreachable(String reason) {
    return 'Server nicht erreichbar ($reason).';
  }

  @override
  String corePop3NoAnswer(String address) {
    return 'POP3-Server $address nicht erreichbar (keine Antwort).';
  }

  @override
  String corePop3Unreachable(String address, String reason) {
    return 'POP3-Server $address nicht erreichbar ($reason).';
  }

  @override
  String coreSmtpNoAnswer(String seconds) {
    return 'Postausgangsserver nicht erreichbar (keine Antwort innerhalb von $seconds s): Nachricht nicht gesendet.';
  }

  @override
  String coreSmtpUnreachable(String reason) {
    return 'Postausgangsserver nicht erreichbar ($reason): Nachricht nicht gesendet.';
  }

  @override
  String get coreContactsServerUnreachable => 'Kontaktserver nicht erreichbar.';

  @override
  String get coreCalendarServerUnreachable =>
      'Kalenderserver nicht erreichbar.';

  @override
  String get coreContactsServerNoAnswer => 'Der Kontaktserver antwortet nicht.';

  @override
  String get coreCalendarServerNoAnswer =>
      'Der Kalenderserver antwortet nicht.';

  @override
  String coreDavSignInRejectedContacts(String provider) {
    return '$provider hat den Zugriff auf den Kontaktserver verweigert: Wiederholen Sie „Mit $provider anmelden“ und erlauben Sie den Zugriff auf die Kontakte.';
  }

  @override
  String coreDavSignInRejectedCalendar(String provider) {
    return '$provider hat den Zugriff auf den Kalenderserver verweigert: Wiederholen Sie „Mit $provider anmelden“ und erlauben Sie den Zugriff auf den Kalender.';
  }

  @override
  String coreDavScopeMissingContacts(String provider) {
    return 'Die Anmeldung mit $provider enthält keine Berechtigung für Kontakte: Wiederholen Sie „Mit $provider anmelden“.';
  }

  @override
  String coreDavScopeMissingCalendar(String provider) {
    return 'Die Anmeldung mit $provider enthält keine Berechtigung für den Kalender: Wiederholen Sie „Mit $provider anmelden“.';
  }

  @override
  String coreAccountScopeMissingContacts(String provider) {
    return 'Die Anmeldung mit $provider umfasst keine Kontakte: Verwenden Sie im Kontofenster „Erneut anmelden“ und erlauben Sie den Zugriff auf die Kontakte.';
  }

  @override
  String coreAccountScopeMissingCalendar(String provider) {
    return 'Die Anmeldung mit $provider umfasst keinen Kalender: Verwenden Sie im Kontofenster „Erneut anmelden“ und erlauben Sie den Zugriff auf den Kalender.';
  }

  @override
  String get coreNotConnected => 'nicht verbunden';

  @override
  String coreUnreachableApp(String address, String error) {
    return 'PostinoVip-Core unter $address nicht erreichbar: $error';
  }

  @override
  String get coreUnexpectedResponse => 'Unerwartete Antwort vom Core';

  @override
  String get coreUnexpectedResponseVersions =>
      'Unerwartete Antwort vom Core (unterschiedliche Versionen von App und Core?)';

  @override
  String get coreEventsUnavailable => 'Ereignisse nicht verfügbar';

  @override
  String coreUnexpectedFormat(String path, String error) {
    return 'Antwort des Core in unerwartetem Format ($path): $error. Ist der Core aktuell und neu gestartet?';
  }

  @override
  String get imagePlaceholder => 'Bild';

  @override
  String get coreErrScrivereIlNomeDellaCartella =>
      'Geben Sie den Ordnernamen ein.';

  @override
  String coreErrIlNomePuoAvereAl(String maxLength) {
    return 'Der Name darf höchstens $maxLength Zeichen lang sein.';
  }

  @override
  String get coreErrIlNomeContieneCaratteriNon =>
      'Der Name enthält ungültige Zeichen.';

  @override
  String coreErrIlNomeNonPuoContenere(String separator) {
    return 'Der Name darf das Zeichen „$separator“ nicht enthalten.';
  }

  @override
  String get coreErrInboxIlNomeRiservatoDella =>
      '„INBOX“ ist der reservierte Name des Posteingangs.';

  @override
  String get coreErrIlMessaggioOriginaleDisponibileSolo =>
      'Die Originalnachricht ist nur mit der lokalen Kopie verfügbar.';

  @override
  String get coreErrCartellaNonValida => 'Ungültiger Ordner.';

  @override
  String get coreErrLaMailNonChiedeUna =>
      'Die Nachricht fordert keine Lesebestätigung an diese Adresse an.';

  @override
  String get coreErrLivelloDelFiltroNonValido => 'Ungültige Filterstufe.';

  @override
  String get coreErrNessunaCartellaDellaPostaIndesiderata =>
      'Kein Junk-E-Mail-Ordner: Wählen Sie ihn unter „Junk-E-Mail-Optionen“.';

  @override
  String get coreErrNessunMittenteDaBloccareLe =>
      'Kein Absender zu blockieren (die Nachrichten wurden von diesem Konto gesendet oder haben keinen Absender).';

  @override
  String get coreErrNonPostaIndesiderataValeSolo =>
      '„Keine Junk-E-Mail“ gilt nur für Nachrichten im Ordner „Junk-E-Mail“.';

  @override
  String coreErrNessunaDelleMailIndicateIn(String folder) {
    return 'Keine der angegebenen Nachrichten befindet sich in \'$folder\'.';
  }

  @override
  String get coreErrIlServerPop3NonSupporta =>
      'Der POP3-Server unterstützt UIDL nicht: Ohne UIDL lässt sich nicht feststellen, welche Nachrichten bereits heruntergeladen wurden.';

  @override
  String get coreErrIdNonValido => 'Ungültige ID.';

  @override
  String get coreErrHostSmtpNonConfigurato => 'SMTP-Host nicht konfiguriert.';

  @override
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2) {
    return 'Anlagen zu groß: $value MB, maximal $value2 MB.';
  }

  @override
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel) {
    return 'Der $serverLabel hat die Anfrage abgelehnt (403).';
  }

  @override
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  ) {
    return 'Adresse für den $value nicht zulässig: https ist erforderlich ($scheme://$host).';
  }

  @override
  String get coreErrNessunCalendarioTrovatoSulServer =>
      'Kein Kalender auf dem Kalenderserver gefunden.';

  @override
  String get coreErrNessunaRubricaTrovataSulServer =>
      'Kein Adressbuch auf dem Kontaktserver gefunden.';

  @override
  String coreErrIlHaCreatoElementoSenza(String serverLabel) {
    return 'Der $serverLabel hat das Element erstellt, ohne anzugeben, wo (Location fehlt).';
  }

  @override
  String coreErrIlHaCreatoElementoFuori(String serverLabel) {
    return 'Der $serverLabel hat das Element außerhalb der Sammlung erstellt.';
  }

  @override
  String coreErrTroppiReindirizzamentiDal(String serverLabel) {
    return 'Zu viele Umleitungen vom $serverLabel.';
  }

  @override
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel) {
    return 'Der $serverLabel hat Benutzername oder Kennwort abgelehnt.';
  }

  @override
  String coreErrCertificatoDelNonValido(String serverLabel) {
    return 'Ungültiges Zertifikat vom $serverLabel.';
  }

  @override
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  ) {
    return 'Der $serverLabel hat mit $code $reasonPhrase geantwortet.';
  }

  @override
  String coreErrRispostaDelNonLeggibile(String serverLabel) {
    return 'Unlesbare Antwort vom $serverLabel.';
  }

  @override
  String get coreErrIlFileNonUnaMail =>
      'Die Datei ist keine lesbare Nachricht (.eml).';

  @override
  String get coreErrIlFileNonUnaMail2 =>
      'Die Datei ist keine Nachricht (.eml): Absender, Datum, Betreff und Empfänger fehlen.';

  @override
  String get coreErrIlFileEmlNonPiu =>
      'Die .eml-Datei ist nicht mehr geöffnet: Öffnen Sie sie erneut.';

  @override
  String coreErrAccountNonTrovato(String id) {
    return 'Konto \'$id\' nicht gefunden.';
  }

  @override
  String coreErrAccountUnAccountPop3Richiede(String id) {
    return 'Konto \'$id\': Ein POP3-Konto erfordert die lokale Kopie (Cache:Enabled=false ist nicht möglich).';
  }

  @override
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider) {
    return 'Konto \'$id\': unbekannter OAuth-Anbieter \'$provider\'.';
  }

  @override
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  ) {
    return 'Konto \'$id\': Die Client-ID von $displayName fehlt (Abschnitt OAuth:$id2).';
  }

  @override
  String get coreErrNessunAccountConfigurato => 'Kein Konto konfiguriert.';

  @override
  String coreErrIdAccountNonValidoAmmessi(String id) {
    return 'Ungültige Konto-ID: \'$id\' (Buchstaben, Ziffern, \'-\' und \'_\' zulässig, höchstens 64).';
  }

  @override
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths) {
    return 'Konto \'$id\': ungültige Grenze der lokalen Kopie ($bodyMonths Monate; 0 = alle).';
  }

  @override
  String coreErrAccountIndirizzoNonValido(String id, String name) {
    return 'Konto \'$id\': ungültige $name-Adresse.';
  }

  @override
  String coreErrAccount(String id, String message) {
    return 'Konto \'$id\': $message';
  }

  @override
  String coreErrIdAccountRipetuto(String key) {
    return 'Doppelte Konto-ID: \'$key\'.';
  }

  @override
  String coreErrCartellaNonTrovata(String fullName) {
    return 'Ordner \'$fullName\' nicht gefunden.';
  }

  @override
  String coreErrLaCartellaEsisteGia(String fullName) {
    return 'Der Ordner \'$fullName\' ist bereits vorhanden.';
  }

  @override
  String coreErrCartellaNonTrovata2(String parent) {
    return 'Ordner \'$parent\' nicht gefunden.';
  }

  @override
  String coreErrCartellaNonTrovata3(String folder) {
    return 'Ordner \'$folder\' nicht gefunden.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn(String uid, String folder) {
    return 'Nachricht $uid in \'$folder\' nicht gefunden.';
  }

  @override
  String coreErrLaCartellaEsisteGia2(String newFullName) {
    return 'Der Ordner \'$newFullName\' ist bereits vorhanden.';
  }

  @override
  String get coreErrCartellaNonIndicata => 'Ordner nicht angegeben.';

  @override
  String coreErrCartellaNonValida2(String fullName) {
    return 'Ungültiger Ordner \'$fullName\'.';
  }

  @override
  String coreErrCartellaAssenteDallIndiceDopo(String folder) {
    return 'Ordner \'$folder\' fehlt nach der Synchronisierung im Index.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid) {
    return 'Anlage $index in Nachricht $uid nicht gefunden.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid) {
    return 'Anlage $i in Nachricht $uid nicht gefunden.';
  }

  @override
  String get coreErrCartellaDiOrigineDestinazioneCoincidono =>
      'Quell- und Zielordner sind identisch.';

  @override
  String get coreErrIlMessaggioGiaInPosta =>
      'Die Nachricht ist bereits in „Gelöschte Elemente“: Verwenden Sie das endgültige Löschen.';

  @override
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn =>
      'Endgültiges Löschen ist nur in „Gelöschte Elemente“ zulässig.';

  @override
  String coreErrNonPuoAndareDentroSe(String folder) {
    return '\'$folder\' kann nicht in sich selbst oder einen seiner Unterordner verschoben werden.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special) {
    return '\'$folder\' enthält den Sonderordner \'$special\': Er wird nicht geleert.';
  }

  @override
  String coreErrNessunaCartellaLocaleConRuolo(String role) {
    return 'Kein lokaler Ordner mit der Rolle $role.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName) {
    return 'Nachricht $uid in \'$fullName\' nicht gefunden.';
  }

  @override
  String coreErrNessunaRispostaIn(String totalSeconds) {
    return 'keine Antwort innerhalb von $totalSeconds s';
  }

  @override
  String get coreErrHostImapNonConfigurato => 'IMAP-Host nicht konfiguriert.';

  @override
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName) {
    return 'Nachricht $uid in \'$folderName\' nicht gefunden.';
  }

  @override
  String coreErrIlServerNonPermetteDi(String value, String folderName) {
    return 'Der Server erlaubt nicht, die Schlüsselwörter $value in \'$folderName\' zu speichern.';
  }

  @override
  String get coreErrIlServerNonDichiaraUna =>
      'Der Server meldet keinen \\Sent-Ordner (Gesendete Elemente): Kopie nicht gespeichert.';

  @override
  String get coreErrIlServerNonDichiaraUna2 =>
      'Der Server meldet keinen \\Drafts-Ordner (Entwürfe): Entwurf nicht gespeichert.';

  @override
  String get coreErrIlServerNonDichiaraUna3 =>
      'Der Server meldet keinen \\Drafts-Ordner (Entwürfe).';

  @override
  String get coreErrIlServerNonDichiaraUna4 =>
      'Der Server meldet keinen \\Trash-Ordner (Gelöschte Elemente).';

  @override
  String get coreErrIlServerNonSupportaMove =>
      'Der Server unterstützt weder MOVE noch UIDPLUS: Vorgang abgelehnt, um keine anderen Nachrichten zu löschen.';

  @override
  String coreErrLaCartellaNonPuoContenere(String fullName) {
    return 'Der Ordner \'$fullName\' kann keine Unterordner enthalten.';
  }

  @override
  String coreErrIlServerNonHaCreato(String clean) {
    return 'Der Server hat den Ordner \'$clean\' nicht erstellt.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  ) {
    return '\'$fullName\' enthält den Sonderordner \'$fullName2\': Er wird nicht geleert.';
  }

  @override
  String coreErrNonPuoAndareDentroSe2(String fullName) {
    return '\'$fullName\' kann nicht in sich selbst oder einen seiner Unterordner verschoben werden.';
  }

  @override
  String coreErrUnaCartellaSpecialeNonSi(String fullName) {
    return '\'$fullName\' ist ein Sonderordner: Er kann nicht umbenannt, verschoben oder gelöscht werden.';
  }

  @override
  String coreErrCartellaNonTrovata4(String folderName) {
    return 'Ordner \'$folderName\' nicht gefunden.';
  }

  @override
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  ) {
    return 'unlesbare Struktur (BODYSTRUCTURE) in einer Gruppe von $count Nachrichten in $fullName: übersprungen, die fehlerhafte Nachricht wird im Hintergrund gesucht ($message)';
  }

  @override
  String get coreErrFiltroDaLeggereOrdineDal =>
      'Der Filter „Ungelesen“ und die Sortierung mit den ältesten zuerst erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrLeConversazioniRichiedonoLaCache =>
      'Unterhaltungen erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrLaRicercaRichiedeLaCache =>
      'Die Suche erfordert die lokale Kopie (Cache:Enabled=false).';

  @override
  String coreErrCorpoAppenaSalvatoNonRileggibile(
    String folderName,
    String uid,
  ) {
    return 'Text $folderName/$uid gerade gespeichert und nicht lesbar.';
  }

  @override
  String coreErrCartellaAssenteDallaCacheDopo(String fullName) {
    return 'Ordner \'$fullName\' fehlt nach der Synchronisierung in der lokalen Kopie.';
  }

  @override
  String get coreErrImprontaSha256NonValida =>
      'Ungültiger SHA-256-Fingerabdruck.';

  @override
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id) {
    return 'Das Konto \'$id\' ist noch konfiguriert: Um die lokale Kopie zu leeren, verwenden Sie „Lokale Kopie neu erstellen“.';
  }

  @override
  String coreErrNessunDatoLocalePerAccount(String id) {
    return 'Keine lokalen Daten für das Konto \'$id\'.';
  }

  @override
  String get coreErrIgnoraPulisciRichiedonoLaCopia =>
      'Ignorieren und Aufräumen erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaPostaEliminataIn =>
      'Kein Ordner „Gelöschte Elemente“ in diesem Konto.';

  @override
  String get coreErrLaConversazioneNonIgnorata =>
      'Die Unterhaltung wird nicht ignoriert.';

  @override
  String get coreErrPulisciNonValePerPosta =>
      'Aufräumen gilt nicht für „Gelöschte Elemente“ und „Junk-E-Mail“.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia =>
      'Regeln erfordern die lokale Kopie.';

  @override
  String coreErrAlMassimoRegolePerAccount(String maxRules) {
    return 'Höchstens $maxRules Regeln pro Konto.';
  }

  @override
  String get coreErrOgniRegolaDeveAvereUn =>
      'Jede Regel muss einen Namen haben.';

  @override
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength) {
    return '„$name…“: Der Name darf höchstens $maxNameLength Zeichen lang sein.';
  }

  @override
  String coreErrEliminaSpostaInsiemeNonHanno(String name) {
    return '„$name“: „Löschen“ und „Verschieben“ zusammen ergeben keinen Sinn, wählen Sie eins.';
  }

  @override
  String coreErrCategoriaNonValida(String name) {
    return '„$name“: ungültige Kategorie.';
  }

  @override
  String coreErrDimensioneNonValida(String rule) {
    return '„$rule“: ungültige Größe.';
  }

  @override
  String coreErrTroppeParoleParoleTroppoLunghe(String rule) {
    return '„$rule“: zu viele oder zu lange Wörter.';
  }

  @override
  String get coreErrScrivereIlMessaggioDellaRisposta =>
      'Schreiben Sie die Nachricht der automatischen Antwort.';

  @override
  String get coreErrLaFineDeveVenireDopo =>
      'Das Ende muss nach dem Beginn liegen.';

  @override
  String get coreErrIlMessaggioTroppoLungo => 'Die Nachricht ist zu lang.';

  @override
  String get coreErrContattoNonTrovato => 'Kontakt nicht gefunden.';

  @override
  String coreErrLaRubricaHaGiaContatti(String maxContacts) {
    return 'Das Adressbuch hat bereits $maxContacts Kontakte.';
  }

  @override
  String get coreErrFormatoNonRiconosciutoUsareVcf =>
      'Format nicht erkannt: Verwenden Sie vcf oder csv.';

  @override
  String coreErrIndirizzoNonValido(String address) {
    return 'Ungültige Adresse: $address';
  }

  @override
  String get coreErrScrivereAlmenoUnNomeLa =>
      'Geben Sie mindestens einen Namen, die Firma oder eine Adresse ein.';

  @override
  String get coreErrCalendarioNonTrovato => 'Kalender nicht gefunden.';

  @override
  String get coreErrAppuntamentoNonValido => 'Ungültiger Termin.';

  @override
  String get coreErrAppuntamentoNonTrovato => 'Termin nicht gefunden.';

  @override
  String get coreErrEsisteGiaUnAppuntamentoCon =>
      'Ein Termin mit derselben UID ist bereits vorhanden.';

  @override
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems) {
    return 'Der Kalender hat bereits $maxItems Termine.';
  }

  @override
  String coreErrPeriodoNonValidoAlMassimo(String maxDays) {
    return 'Ungültiger Zeitraum: höchstens $maxDays Tage, mit dem Ende nach dem Beginn.';
  }

  @override
  String get coreErrAppuntamentoNonLeggibile => 'Termin nicht lesbar.';

  @override
  String get coreErrOccorrenzaNonValida => 'Ungültiges Vorkommen.';

  @override
  String get coreErrSerieNonTrovata => 'Serie nicht gefunden.';

  @override
  String get coreErrAppuntamentoNonRicorrenteSiModifica =>
      'Der Termin ist kein Serientermin: Er wird vollständig geändert.';

  @override
  String get coreErrAlMassimo20000Caratteri => 'Höchstens 20000 Zeichen.';

  @override
  String get coreErrPromemoriaNonValidoDaMinuti =>
      'Ungültige Erinnerung (von 0 Minuten bis 4 Wochen vorher).';

  @override
  String get coreErrLaFinePrimaDellInizio => 'Das Ende liegt vor dem Beginn.';

  @override
  String get coreErrSerializzazioneNonRiuscita =>
      'Serialisierung fehlgeschlagen.';

  @override
  String coreErrMancaIlClientIdDi(String displayName, String id) {
    return 'Die Client-ID von $displayName fehlt: Die App muss registriert und die ID in oauth-clients.json eingetragen werden (Abschnitt OAuth:$id).';
  }

  @override
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName) {
    return 'Die Kontaktsynchronisierung ist mit $displayName nicht verfügbar.';
  }

  @override
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName) {
    return 'Die Kalendersynchronisierung ist mit $displayName nicht verfügbar.';
  }

  @override
  String coreErrAllegatoNonTrovato(String i) {
    return 'Anlage $i nicht gefunden.';
  }

  @override
  String get coreErrIndicareLaCartellaDelMessaggio =>
      'Geben Sie den Ordner der Originalnachricht an.';

  @override
  String coreErrModalitaNonValidaReplyReplyall(String mode) {
    return 'Ungültiger Modus: $mode (reply, replyAll, forward).';
  }

  @override
  String coreErrMancantePiuCortoDiCaratteri(
    String configKey,
    String minLength,
  ) {
    return '$configKey fehlt oder ist kürzer als $minLength Zeichen.';
  }

  @override
  String get coreErrCartellaDeiDatiDellUtente =>
      'Der Datenordner des Benutzers kann nicht ermittelt werden (HOME nicht gesetzt?): Verwenden Sie Cache:Directory.';

  @override
  String get coreErrIndicareAlmenoUnaMail =>
      'Geben Sie mindestens eine Nachricht an.';

  @override
  String coreErrAlMassimoMailPerVolta(String maxBatch) {
    return 'Höchstens $maxBatch Nachrichten auf einmal.';
  }

  @override
  String coreErrAllegatoNonTrovato2(String index) {
    return 'Anlage $index nicht gefunden.';
  }

  @override
  String get coreErrUnaCategoriaNonPuoEssere =>
      'Eine Kategorie kann nicht gleichzeitig hinzugefügt und entfernt werden.';

  @override
  String get coreErrIndicareLaCartellaDiDestinazione =>
      'Geben Sie den Zielordner an.';

  @override
  String get coreErrLaScadenzaValeSoloCon =>
      'Das Fälligkeitsdatum gilt nur mit followUp „flagged“.';

  @override
  String get coreErrLeRisposteAutomaticheRichiedonoLa =>
      'Automatische Antworten erfordern die lokale Kopie.';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa =>
      'Junk-E-Mail erfordert die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa2 =>
      'Junk-E-Mail erfordert die lokale Kopie.';

  @override
  String get coreErrLaCartellaSceltaNonEsiste =>
      'Der ausgewählte Ordner ist nicht vorhanden.';

  @override
  String get coreErrScegliereUnaCartellaDiversaDa =>
      'Wählen Sie einen anderen Ordner als Posteingang, Gesendete Elemente, Entwürfe und Gelöschte Elemente.';

  @override
  String get coreErrLaCartellaDiArchiviazioneSceglierne =>
      'Das ist der Archivordner: Wählen Sie einen anderen.';

  @override
  String coreErrCartellaNonTrovata5(String name) {
    return 'Ordner \'$name\' nicht gefunden.';
  }

  @override
  String get coreErrArchiviaRichiedeLaCopiaLocale =>
      'Archivieren erfordert die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla =>
      'Kein Archivordner: Wählen Sie ihn mit „Archivordner festlegen“.';

  @override
  String get coreErrLeMailSonoGiaNella =>
      'Die Nachrichten sind bereits im Archivordner.';

  @override
  String get coreErrContattiRichiedonoLaCopiaLocale =>
      'Kontakte erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrContenutoDelFileNonValido => 'Ungültiger Dateiinhalt.';

  @override
  String get coreErrFileTroppoGrandeAlMassimo =>
      'Datei zu groß (höchstens 10 MB).';

  @override
  String get coreErrLaSincronizzazioneDeiContattiNon2 =>
      'Die Kontaktsynchronisierung ist für dieses Konto nicht aktiv.';

  @override
  String get coreErrDa50 => 'Von 1 bis 50.';

  @override
  String get coreErrIndirizzoMancante => 'Adresse fehlt.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia2 =>
      'Regeln erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrScegliereAlmenoUnaRegolaSalvata =>
      'Wählen Sie mindestens eine gespeicherte Regel.';

  @override
  String get coreErrAccountPop3LeMailSono =>
      'POP3-Konto: Die E-Mails sind nur auf diesem Computer, es gibt keine Kopie, die vom Server neu erstellt werden könnte.';

  @override
  String get coreErrCalendariRichiedonoLaCopiaLocale =>
      'Kalender erfordern die lokale Kopie (Cache:Enabled=false).';

  @override
  String coreErrIlCalendarioDiSolaLettura(String name) {
    return 'Der Kalender „$name“ ist schreibgeschützt: Termine können nicht erstellt, geändert oder gelöscht werden.';
  }

  @override
  String get coreErrLaSincronizzazioneDelCalendarioNon2 =>
      'Die Kalendersynchronisierung ist für dieses Konto nicht aktiv.';

  @override
  String get coreErrRitardaRecapitoRichiedeLaCache =>
      'Übermittlung verzögern erfordert die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaInUscitaRichiede =>
      'Der Postausgang erfordert die lokale Kopie (Cache:Enabled=false).';

  @override
  String get coreErrMailNonTrovataNellaPosta =>
      'Nachricht im Postausgang nicht gefunden.';

  @override
  String get coreErrNessunaConfermaDiLetturaPer =>
      'Keine Lesebestätigungen für Nachrichten in Junk-E-Mail, Gesendete Elemente und Entwürfe.';

  @override
  String get coreErrAllaRichiestaDiConfermaDi =>
      'Die Anforderung der Lesebestätigung wurde bereits beantwortet.';

  @override
  String get coreErrLaMailNonChiedeUna2 =>
      'Die Nachricht fordert keine Lesebestätigung an ihren Absender an.';

  @override
  String get davContactsServerLabel => 'Kontaktserver';

  @override
  String get davCalendarServerLabel => 'Kalenderserver';

  @override
  String get printPreviewOpened =>
      'Vorschau im PDF-Viewer geöffnet: Drucken Sie von dort.';

  @override
  String printNoPdfViewer(String path) {
    return 'Kein Programm zum Öffnen von PDF-Dateien. Datei unter $path';
  }

  @override
  String printNotPrepared(String message, String path) {
    return 'Druck nicht vorbereitet: $message ($path)';
  }

  @override
  String get defaultMessageFileName => 'Nachricht';

  @override
  String get preparingPdf => 'PDF wird vorbereitet…';

  @override
  String pdfNotCreated(String error) {
    return 'PDF nicht erstellt: $error';
  }

  @override
  String get printFrom => 'Von:';

  @override
  String get printSent => 'Gesendet:';

  @override
  String get printTo => 'An:';

  @override
  String get printCc => 'Cc:';

  @override
  String get printSubject => 'Betreff:';

  @override
  String get printImportance => 'Wichtigkeit:';

  @override
  String get printHigh => 'Hoch';

  @override
  String get printLow => 'Niedrig';

  @override
  String get printAttachments => 'Anlagen:';

  @override
  String get defaultAttachmentFileName => 'Anlage';

  @override
  String get coreExecutableNotFound =>
      'Ausführbare Datei des Core nicht gefunden. Erstellen Sie sie mit „cd core && dotnet build“ oder geben Sie den Pfad in POSTINOVIP_CORE an.';

  @override
  String coreCannotStart(String path, String error) {
    return 'Der Core kann nicht gestartet werden ($path): $error';
  }

  @override
  String coreExitedAtStart(String code) {
    return 'Der Core wurde beim Start beendet (Code $code).';
  }

  @override
  String coreNoAnswerAtStart(String seconds) {
    return 'Der Core hat nicht innerhalb von $seconds s geantwortet.';
  }

  @override
  String coreNotAnsweringCorrectly(String error) {
    return 'Der Core antwortet nicht korrekt: $error';
  }

  @override
  String get startingCore => 'Core wird gestartet…';

  @override
  String get coreLastLines => 'Letzte Zeilen des Core:';

  @override
  String get macMenuAbout => 'Über PostinoVip';

  @override
  String get macMenuOptions => 'Optionen…';

  @override
  String get macMenuServices => 'Dienste';

  @override
  String get macMenuHide => 'PostinoVip ausblenden';

  @override
  String get macMenuHideOthers => 'Andere ausblenden';

  @override
  String get macMenuShowAll => 'Alle einblenden';

  @override
  String get macMenuQuit => 'PostinoVip beenden';

  @override
  String get macMenuEdit => 'Bearbeiten';

  @override
  String get macMenuUndo => 'Widerrufen';

  @override
  String get macMenuRedo => 'Wiederholen';

  @override
  String get macMenuCut => 'Ausschneiden';

  @override
  String get macMenuCopy => 'Kopieren';

  @override
  String get macMenuPaste => 'Einsetzen';

  @override
  String get macMenuSelectAll => 'Alles auswählen';

  @override
  String get macMenuWindow => 'Fenster';

  @override
  String get macMenuMinimize => 'Im Dock ablegen';

  @override
  String get macMenuZoom => 'Zoomen';

  @override
  String get macMenuFullScreen => 'Vollbild';

  @override
  String get macMenuBringAllToFront => 'Alle nach vorne bringen';

  @override
  String get macMenuShowRibbon => 'Menüband';

  @override
  String get macMenuZoomReset => 'Originalgröße';

  @override
  String get macMenuCloseWindow => 'Fenster schließen';

  @override
  String get macMenuCalendarView => 'Kalenderansicht';

  @override
  String get optionsShowRibbon => 'Menüband anzeigen';

  @override
  String get optionsShowRibbonHelp =>
      'Im Hauptfenster. Die Befehle bleiben in der Menüleiste oben.';
}
