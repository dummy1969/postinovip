// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String statusItems(int count) {
    return 'Elementi: $count';
  }

  @override
  String statusUnread(int count) {
    return 'Da leggere: $count';
  }

  @override
  String statusResults(int count) {
    return 'Risultati: $count';
  }

  @override
  String statusContacts(int count) {
    return 'Contatti: $count';
  }

  @override
  String statusFound(int count) {
    return 'Trovati: $count';
  }

  @override
  String get statusConnected => 'Connesso';

  @override
  String get statusDisconnected => 'Disconnesso';

  @override
  String statusDisconnectedAccounts(String accounts) {
    return 'Disconnesso: $accounts';
  }

  @override
  String get optionsTitle => 'Opzioni';

  @override
  String get optionsClose => 'Chiudi';

  @override
  String get optionsPageGeneral => 'Generale';

  @override
  String get optionsPageMail => 'Posta';

  @override
  String get optionsPageNotifications => 'Notifiche';

  @override
  String get optionsPageCalendar => 'Calendario';

  @override
  String get optionsAccountSection => 'Account';

  @override
  String get optionsAccountNotConfigured => '(non configurato)';

  @override
  String get optionsAccountFromUserSecrets => 'Dati da user-secrets (sviluppo)';

  @override
  String optionsAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count account',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String get optionsAccountManage => 'Gestisci…';

  @override
  String get optionsLookSection => 'Aspetto';

  @override
  String get optionsTheme => 'Tema';

  @override
  String get optionsThemeHelper =>
      'Il testo delle mail resta su fondo bianco anche con i temi scuri';

  @override
  String get themeSystem => 'Usa impostazione di sistema';

  @override
  String get themeColorful => 'Colorato';

  @override
  String get themeWhite => 'Bianco';

  @override
  String get themeDarkGray => 'Grigio scuro';

  @override
  String get themeBlack => 'Nero';

  @override
  String get optionsModuleBar =>
      'Barra dei moduli (Posta, Calendario, Persone)';

  @override
  String get moduleBarLeft => 'A sinistra';

  @override
  String get moduleBarBottom => 'In basso nel riquadro di sinistra';

  @override
  String get optionsLanguageSection => 'Lingua';

  @override
  String get optionsLanguage => 'Lingua dell\'interfaccia';

  @override
  String get optionsLanguageHelper =>
      'La traduzione è in corso: alcune parti dell\'app sono ancora solo in italiano';

  @override
  String get languageSystem => 'Come il sistema';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSendReceive => 'Invia/Ricevi';

  @override
  String get tabFolder => 'Cartella';

  @override
  String get tabView => 'Visualizza';

  @override
  String get groupLayout => 'Layout';

  @override
  String get ribbonCollapse => 'Comprimi barra multifunzione';

  @override
  String get ribbonCollapseTooltip =>
      'Mostra solo i nomi delle schede (Ctrl+F1)';

  @override
  String get groupSendReceive => 'Invia e ricevi';

  @override
  String get sendReceiveAll => 'Invia/ricevi tutte le cartelle';

  @override
  String get sendReceiveAllTooltip =>
      'Aggiorna cartelle e messaggi di tutti gli account (F9)';

  @override
  String get readingPane => 'Riquadro di lettura';

  @override
  String get messagePreview => 'Anteprima messaggio';

  @override
  String get messagePreviewOff => 'Disattivata';

  @override
  String messagePreviewLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe',
      one: '1 riga',
    );
    return '$_temp0';
  }

  @override
  String get groupMessages => 'Messaggi';

  @override
  String get showAsConversations => 'Mostra come conversazioni';

  @override
  String get showAsConversationsOnTooltip =>
      'Attivo in questa cartella: clic per tornare alla lista semplice';

  @override
  String get showAsConversationsOffTooltip =>
      'Raccoglie in una riga le mail della stessa conversazione';

  @override
  String get specialFolderHint =>
      'Posta in arrivo, Posta inviata, Posta eliminata e le altre cartelle speciali non si possono rinominare né eliminare';

  @override
  String get groupNew => 'Nuovo';

  @override
  String get newFolder => 'Nuova cartella';

  @override
  String get newFolderTooltip =>
      'Crea una sottocartella della cartella selezionata';

  @override
  String get groupActions => 'Azioni';

  @override
  String get renameFolder => 'Rinomina cartella';

  @override
  String get renameFolderTooltip =>
      'Cambia il nome della cartella selezionata (F2)';

  @override
  String get deleteFolder => 'Elimina cartella';

  @override
  String get deletePermanentlyTooltip =>
      'Elimina dal server, senza possibilità di recupero';

  @override
  String get deleteFolderTooltip =>
      'Sposta la cartella, con il suo contenuto, in Posta eliminata';

  @override
  String get emptyFolder => 'Svuota cartella';

  @override
  String get emptyFolderTooltip =>
      'Elimina dal server tutte le mail della cartella, senza possibilità di recupero';

  @override
  String get emptyFolderOnlyTooltip =>
      'Solo per Posta eliminata e Posta indesiderata';

  @override
  String get groupArchive => 'Archivio';

  @override
  String get setArchiveFolder => 'Imposta cartella di archiviazione';

  @override
  String get setArchiveFolderTooltip =>
      'Scegli o crea la cartella in cui Archivia sposta le mail di questo account';

  @override
  String get newMessage => 'Nuovo messaggio';

  @override
  String get newMessageTooltip => 'Scrivi un nuovo messaggio';

  @override
  String get delete => 'Elimina';

  @override
  String get deletePermanently => 'Elimina definitivamente';

  @override
  String get moveToDeletedTooltip => 'Sposta in Posta eliminata';

  @override
  String get archive => 'Archivia';

  @override
  String get cleanUp => 'Pulisci';

  @override
  String get cleanUpTooltip =>
      'Sposta in Posta eliminata le mail superflue: quelle citate per intero da una risposta';

  @override
  String get junk => 'Posta indesiderata';

  @override
  String get junkTooltip =>
      'Blocca mittente, Non bloccare mai, Opzioni posta indesiderata';

  @override
  String get groupRespond => 'Rispondi';

  @override
  String get move => 'Sposta';

  @override
  String get moveTooltip => 'Sposta in un\'altra cartella';

  @override
  String get moveOtherFolder => 'Altra cartella… (Ctrl+Maiusc+V)';

  @override
  String get rules => 'Regole';

  @override
  String get rulesTooltip => 'Smista da sola la posta in arrivo';

  @override
  String get createRule => 'Crea regola…';

  @override
  String get manageRulesEllipsis => 'Gestisci regole e avvisi…';

  @override
  String get groupTags => 'Tag';

  @override
  String get markUnread => 'Segna come non letto';

  @override
  String get markRead => 'Segna come letto';

  @override
  String get categorize => 'Categorizza';

  @override
  String get categorizeTooltip => 'Assegna una categoria colorata';

  @override
  String get followUp => 'Completa';

  @override
  String get followUpTooltip =>
      'Contrassegna per completamento, con una scadenza';

  @override
  String get groupFind => 'Trova';

  @override
  String get search => 'Cerca';

  @override
  String get searchTooltip => 'Cerca nella posta';

  @override
  String get fileTab => 'File';

  @override
  String get openEml => 'Apri file .eml…';

  @override
  String get saveAs => 'Salva con nome… (F12)';

  @override
  String get printMessage => 'Stampa… (Ctrl+P)';

  @override
  String get saveAsPdf => 'Salva come PDF…';

  @override
  String get automaticReplies => 'Risposte automatiche';

  @override
  String get manageRules => 'Gestisci regole e avvisi';

  @override
  String get aboutApp => 'Informazioni su PostinoVip';

  @override
  String get ribbonShowAlways => 'Mostra sempre la barra multifunzione';

  @override
  String get ribbonTabsOnly => 'Mostra solo le schede (Ctrl+F1)';

  @override
  String get ribbonDisplayOptions =>
      'Opzioni di visualizzazione della barra multifunzione';

  @override
  String get readingPaneRight => 'A destra';

  @override
  String get readingPaneBottom => 'In basso';

  @override
  String get readingPaneOff => 'Disattivato';

  @override
  String get ribbonClassic => 'Barra multifunzione classica';

  @override
  String get ribbonSimplified => 'Barra multifunzione semplificata';

  @override
  String get reply => 'Rispondi';

  @override
  String get replyAll => 'Rispondi a tutti';

  @override
  String get forward => 'Inoltra';

  @override
  String get sendReceiveAllF9 => 'Invia/ricevi tutte le cartelle (F9)';

  @override
  String get searchHelp =>
      'Parole (anche iniziali: \"fatt\" trova \"fattura\"), \"frase esatta\"\nda:anna   a:mario   oggetto:riunione\nallegato:pdf   allegati:sì   allegati:no';

  @override
  String get searchClose => 'Chiudi la ricerca';

  @override
  String get searchScopeFolder => 'Cartella attuale';

  @override
  String get searchScopeAccount => 'Tutte le cartelle';

  @override
  String get searchScopeAllAccounts => 'Tutti gli account';

  @override
  String get moduleMail => 'Posta (Ctrl+1)';

  @override
  String get moduleCalendar => 'Calendario (Ctrl+2)';

  @override
  String get modulePeople => 'Persone (Ctrl+3)';

  @override
  String get zoomOut => 'Riduci (Ctrl+-)';

  @override
  String get zoomIn => 'Ingrandisci (Ctrl++)';

  @override
  String get zoomReset =>
      'Zoom del riquadro di lettura: clic per tornare al 100% (Ctrl+0)';

  @override
  String get cancel => 'Annulla';

  @override
  String get close => 'Chiudi';

  @override
  String get retry => 'Riprova';

  @override
  String get noFolderSelected => 'Nessuna cartella selezionata';

  @override
  String searchWhereFolder(String folder) {
    return 'in $folder';
  }

  @override
  String searchWhereAccount(String account) {
    return 'in tutte le cartelle di $account';
  }

  @override
  String get searchWhereAllFolders => 'in tutte le cartelle';

  @override
  String get searchWhereAllAccounts => 'in tutti gli account';

  @override
  String searchInProgress(String where) {
    return 'Ricerca $where…';
  }

  @override
  String searchResultsTitle(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '1 risultato',
    );
    return '$_temp0 $where';
  }

  @override
  String get listNoUnread => 'Nessun messaggio da leggere';

  @override
  String get listEmptyFolder => 'Cartella vuota';

  @override
  String get unknownSender => '(mittente sconosciuto)';

  @override
  String get noSubject => '(nessun oggetto)';

  @override
  String get searchNoLocalResults => 'Nessun risultato nella cache locale';

  @override
  String get offlineStrip =>
      'Non connesso: mostro la copia sul computer. Spostare, eliminare, segnare come letto e inviare tornano disponibili da soli quando il server risponde.';

  @override
  String get theProvider => 'il fornitore';

  @override
  String loginExpired(String provider) {
    return 'Accesso a $provider scaduto: questo account non riceve né invia posta finché non accedi di nuovo.';
  }

  @override
  String get signInAgain => 'Accedi di nuovo';

  @override
  String get autoReplyStrip =>
      'Le risposte automatiche sono attive per questo account.';

  @override
  String get editEllipsis => 'Modifica…';

  @override
  String get autoReplyTurnedOff => 'Risposte automatiche disattivate.';

  @override
  String autoReplyNotTurnedOff(String error) {
    return 'Non disattivate: $error';
  }

  @override
  String get turnOff => 'Disattiva';

  @override
  String get serverSearching => 'Ricerca sul server…';

  @override
  String serverSearchFailed(String error) {
    return 'Ricerca sul server non riuscita: $error';
  }

  @override
  String get serverFoundNone => 'Il server non ha trovato altre mail.';

  @override
  String serverFoundMore(int count) {
    return 'Il server ha trovato $count mail in più (con l\'icona della nuvola).';
  }

  @override
  String serverTruncated(int count) {
    return ' Mostrate le $count più recenti.';
  }

  @override
  String get searchServerToo => 'Cerca anche sul server';

  @override
  String get searchServerHint =>
      'Per le mail più vecchie del limite della cache e per Posta eliminata e Indesiderata,\ndi cui qui sono state cercate solo le intestazioni.';

  @override
  String get conversationCollapse => 'Chiudi la conversazione';

  @override
  String get conversationExpand => 'Mostra tutte le mail della conversazione';

  @override
  String get sortDateNewest => 'Per data: più recenti in cima';

  @override
  String get sortDateOldest => 'Per data: più vecchi in cima';

  @override
  String get sortFromAZ => 'Per mittente: A → Z';

  @override
  String get sortFromZA => 'Per mittente: Z → A';

  @override
  String get sortSubjectAZ => 'Per oggetto: A → Z';

  @override
  String get sortSubjectZA => 'Per oggetto: Z → A';

  @override
  String get sortSizeLargest => 'Per dimensione: più grandi in cima';

  @override
  String get sortSizeSmallest => 'Per dimensione: più piccole in cima';

  @override
  String get sortByDate => 'Per data';

  @override
  String get sortByFrom => 'Per mittente';

  @override
  String get sortBySubject => 'Per oggetto';

  @override
  String get sortBySize => 'Per dimensione';

  @override
  String get filterAll => 'Tutti';

  @override
  String get filterUnread => 'Da leggere';

  @override
  String get sortTooltip => 'Ordina per';

  @override
  String get conversationBadgeTooltip =>
      'Vista per conversazioni attiva in questa cartella: clic per cambiarla';

  @override
  String get conversations => 'Conversazioni';

  @override
  String conversationCount(int count) {
    return '$count mail nella conversazione';
  }

  @override
  String get hasAttachments => 'Contiene allegati';

  @override
  String get flaggedClickToComplete => 'Contrassegnato: clic per completare';

  @override
  String dueByClickToComplete(String date) {
    return 'Completare entro $date: clic per completare';
  }

  @override
  String get completedClickToFlag =>
      'Completato: clic per contrassegnare di nuovo';

  @override
  String get flagToday => 'Contrassegna per oggi';

  @override
  String get foundOnServer => 'Trovata sul server';

  @override
  String sortByColumn(String column) {
    return 'Ordina per $column';
  }

  @override
  String get columnFrom => 'Da';

  @override
  String get columnSubject => 'Oggetto';

  @override
  String get columnReceived => 'Ricevuto';

  @override
  String get columnSize => 'Dimensione';

  @override
  String get columnCategories => 'Categorie';

  @override
  String selectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi selezionati',
      one: '1 elemento selezionato',
    );
    return '$_temp0';
  }

  @override
  String get selectMessage => 'Seleziona un messaggio';

  @override
  String get messageUnavailable => 'Messaggio non disponibile';

  @override
  String receiptRequested(String sender) {
    return '$sender ha chiesto una conferma di lettura.';
  }

  @override
  String get receiptDecline => 'Non inviare';

  @override
  String get receiptSend => 'Invia';

  @override
  String get draftBanner => 'Bozza: non ancora inviata.';

  @override
  String get editDraft => 'Modifica bozza';

  @override
  String get headerTo => 'A';

  @override
  String get headerCc => 'Cc';

  @override
  String openAttachment(String name) {
    return 'Apri \"$name\"';
  }

  @override
  String saveAttachment(String name) {
    return 'Salva \"$name\"…';
  }

  @override
  String get importanceHighBanner =>
      'Il messaggio è stato inviato con priorità alta.';

  @override
  String get importanceLowBanner =>
      'Il messaggio è stato inviato con priorità bassa.';

  @override
  String get junkBanner =>
      'Questa mail è nella posta indesiderata: per sicurezza i collegamenti sono disattivati e le immagini remote bloccate. Se è una mail attendibile, riportala in Posta in arrivo.';

  @override
  String get notJunk => 'Non è posta indesiderata';

  @override
  String get remoteImagesBlocked =>
      'Immagini remote bloccate per proteggere la privacy.';

  @override
  String get showImages => 'Mostra immagini';

  @override
  String get htmlOnlyAsText =>
      'Messaggio solo HTML: mostrato come testo semplificato.';

  @override
  String get bodyText => 'Testo';

  @override
  String savedTo(String path) {
    return 'Salvato in $path';
  }

  @override
  String attachmentNotDownloaded(String error) {
    return 'Allegato non scaricato: $error';
  }

  @override
  String fileNotWritten(String message, String path) {
    return 'File non scritto: $message ($path)';
  }

  @override
  String attachedMailNotOpened(String error) {
    return 'Mail allegata non aperta: $error';
  }

  @override
  String get messageWithoutText => '(messaggio senza testo)';

  @override
  String get completed => 'Completato';

  @override
  String get flaggedForFollowUp => 'Contrassegnato per completamento';

  @override
  String dueBy(String date) {
    return 'Completare entro $date';
  }

  @override
  String get overdueSuffix => ' (scaduto)';

  @override
  String get addSenderToContacts => 'Aggiungi il mittente a Contatti';

  @override
  String get stopIgnoringConversation => 'Interrompi Ignora conversazione';

  @override
  String get ignoreConversation => 'Ignora conversazione';

  @override
  String get cleanUpConversation => 'Pulisci conversazione';

  @override
  String draftNotAvailable(String error) {
    return 'Bozza non disponibile: $error';
  }

  @override
  String get draftTitle => 'Bozza';

  @override
  String get deletePermanentlyQuestion => 'Eliminare definitivamente?';

  @override
  String deletePermanentlyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mail selezionate in Posta eliminata verranno cancellate',
      one: '1 mail selezionata in Posta eliminata verrà cancellata',
    );
    return '$_temp0 dal server.\nL\'operazione non è reversibile.';
  }

  @override
  String deletePermanentlyOne(String subject) {
    return '\"$subject\" verrà cancellato dal server.\nL\'operazione non è reversibile.';
  }

  @override
  String get dontShowAsConversations => 'Non mostrare come conversazioni';

  @override
  String conversationsOnQuestion(String folder) {
    return 'Le mail della stessa conversazione verranno raccolte in una riga, con le risposte che stanno in altre cartelle.\n\nApplicare a \"$folder\" o a tutte le cartelle?';
  }

  @override
  String conversationsApplyQuestion(String folder) {
    return 'Applicare a \"$folder\" o a tutte le cartelle?';
  }

  @override
  String get allFolders => 'Tutte le cartelle';

  @override
  String get thisFolder => 'Questa cartella';

  @override
  String get importanceHigh => 'Priorità alta';

  @override
  String get importanceLow => 'Priorità bassa';

  @override
  String get folderInbox => 'Posta in arrivo';

  @override
  String get favorites => 'Preferiti';

  @override
  String get removeFromFavorites => 'Rimuovi dai Preferiti';

  @override
  String get moveUp => 'Sposta su';

  @override
  String get moveDown => 'Sposta giù';

  @override
  String get showInFavorites => 'Mostra nei Preferiti';

  @override
  String get cleanUpFolder => 'Pulisci cartella';

  @override
  String get outbox => 'Posta in uscita';

  @override
  String get folderNameHint => 'Nome della cartella';

  @override
  String noAutoUpdate(String address) {
    return 'Aggiornamento automatico non attivo per $address: le nuove mail compaiono solo con \"Aggiorna\"';
  }

  @override
  String get emptyFolderAllMails => 'Tutte le mail';

  @override
  String get emptyFolderOnlyMail => 'L\'unica mail';

  @override
  String emptyFolderNMails(int count) {
    return 'Tutte le $count mail';
  }

  @override
  String get emptyFolderOneSubfolder => ' e la sottocartella, con le sue mail,';

  @override
  String emptyFolderNSubfolders(int count) {
    return ' e le $count sottocartelle, con le loro mail,';
  }

  @override
  String emptyFolderQuestion(String folder) {
    return 'Svuotare \"$folder\"?';
  }

  @override
  String emptyFolderContent(String mails, String folder, String also) {
    return '$mails di \"$folder\"$also verranno cancellate dal server.\nL\'operazione non è reversibile.';
  }

  @override
  String get deleteFolderPermanentlyQuestion =>
      'Eliminare definitivamente la cartella?';

  @override
  String get deleteFolderQuestion => 'Eliminare la cartella?';

  @override
  String deleteFolderPermanentlyContent(String folder) {
    return 'La cartella \"$folder\", con tutte le mail e le sottocartelle, verrà cancellata dal server.\nL\'operazione non è reversibile.';
  }

  @override
  String deleteFolderContent(String folder) {
    return 'La cartella \"$folder\", con tutte le mail e le sottocartelle, verrà spostata in Posta eliminata.';
  }

  @override
  String get messageTab => 'Messaggio';

  @override
  String get windowDeletePermanentlyTooltip =>
      'Elimina dal server, senza possibilità di recupero (poi la mail successiva)';

  @override
  String get windowDeleteTooltip =>
      'Sposta in Posta eliminata e apri la mail successiva (Canc)';

  @override
  String get windowArchiveTooltip =>
      'Sposta nella cartella di archiviazione e apri la mail successiva';

  @override
  String get windowMoveTooltip =>
      'Sposta in un\'altra cartella e apri la mail successiva';

  @override
  String get markUnreadWindow => 'Segna come da leggere';

  @override
  String get groupZoom => 'Zoom';

  @override
  String zoomPercent(int percent) {
    return 'Zoom ($percent%)';
  }

  @override
  String get zoomTooltip =>
      'Ingrandisci o riduci il testo della mail (Ctrl+rotella, Ctrl++, Ctrl+-, Ctrl+0)';

  @override
  String get previousItem => 'Elemento precedente (Ctrl+,)';

  @override
  String get nextItem => 'Elemento successivo (Ctrl+.)';

  @override
  String get closeEsc => 'Chiudi (Esc)';

  @override
  String messageNotSaved(String error) {
    return 'Mail non salvata: $error';
  }

  @override
  String get emlFilesLabel => 'Messaggi di posta';

  @override
  String fileNotOpened(String name, String reason) {
    return '$name non aperto: $reason';
  }

  @override
  String get readOnly => 'Sola lettura';

  @override
  String get saveAsShort => 'Salva con nome…';

  @override
  String get moveItems => 'Sposta elementi';

  @override
  String moveItemsTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sposta i $count elementi selezionati nella cartella:',
      one: 'Sposta l\'elemento selezionato nella cartella:',
    );
    return '$_temp0';
  }

  @override
  String get searchFolder => 'Cerca una cartella';

  @override
  String get noFolderWithName => 'Nessuna cartella con questo nome';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuti',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settimane',
      one: '1 settimana',
    );
    return '$_temp0';
  }

  @override
  String reminderNotification(String title) {
    return 'Promemoria: $title';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count promemoria',
      one: '1 promemoria',
    );
    return '$_temp0';
  }

  @override
  String get reminderAllDayToday => 'Giornata intera, oggi';

  @override
  String get reminderAllDayTomorrow => 'Giornata intera, domani';

  @override
  String reminderAllDayIn(int count) {
    return 'Giornata intera, tra $count giorni';
  }

  @override
  String reminderAllDayStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Giornata intera, iniziata da $count giorni',
      one: 'Giornata intera, iniziata da 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get reminderNow => 'Adesso';

  @override
  String reminderStartedAgo(String span) {
    return 'Iniziato da $span';
  }

  @override
  String reminderIn(String span) {
    return 'Tra $span';
  }

  @override
  String reminderStart(String when) {
    return 'Inizio: $when';
  }

  @override
  String reminderLocation(String location) {
    return '    Luogo: $location';
  }

  @override
  String get dismissAll => 'Ignora tutto';

  @override
  String get openItem => 'Apri elemento';

  @override
  String get dismiss => 'Ignora';

  @override
  String get snoozeHint =>
      'Fare clic su Rimanda per ricevere un nuovo promemoria tra:';

  @override
  String get snooze => 'Rimanda';

  @override
  String newMailFrom(String sender, String suffix) {
    return 'Nuova mail da $sender$suffix';
  }

  @override
  String newMailMore(int count) {
    return '\n…e altre $count';
  }

  @override
  String newMailCount(int count, String suffix) {
    return '$count nuove mail$suffix';
  }

  @override
  String get openMailAction => 'Apri mail';

  @override
  String get viewDay => 'Giorno';

  @override
  String get viewWorkWeek => 'Settimana lavorativa';

  @override
  String get viewWeek => 'Settimana';

  @override
  String get viewMonth => 'Mese';

  @override
  String get colorBlue => 'Blu';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorOrange => 'Arancione';

  @override
  String get colorPurple => 'Viola';

  @override
  String get colorTeal => 'Verde acqua';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorGold => 'Oro';

  @override
  String get colorGray => 'Grigio';

  @override
  String get deleteRecurringTitle => 'Eliminare un appuntamento ricorrente';

  @override
  String get openRecurringTitle => 'Aprire un appuntamento ricorrente';

  @override
  String get deleteRecurringQuestion =>
      'Eliminare solo questa occorrenza o tutta la serie?';

  @override
  String get openRecurringQuestion =>
      'È un appuntamento ricorrente. Aprire solo questa occorrenza o tutta la serie?';

  @override
  String get entireSeries => 'Tutta la serie';

  @override
  String get justThisOne => 'Solo questa';

  @override
  String appointmentNotAvailable(String error) {
    return 'Appuntamento non disponibile: $error';
  }

  @override
  String get deleteAppointmentQuestion => 'Eliminare l\'appuntamento?';

  @override
  String deleteAppointmentContent(String title) {
    return '«$title» viene eliminato; con la sincronizzazione anche dal server. Non si può recuperare.';
  }

  @override
  String appointmentNotDeleted(String error) {
    return 'Appuntamento non eliminato: $error';
  }

  @override
  String get uploadAppointmentsQuestion =>
      'Caricare gli appuntamenti sul server?';

  @override
  String uploadAppointmentsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count appuntamenti sono solo su questo computer. Verranno aggiunti',
      one: 'Un appuntamento è solo su questo computer. Verrà aggiunto',
    );
    return '$_temp0 al calendario del server e da allora sincronizzati.\n\nGli appuntamenti già presenti sul server non vengono modificati.';
  }

  @override
  String get uploadToServer => 'Carica sul server';

  @override
  String appointmentsNotUploaded(String error) {
    return 'Appuntamenti non caricati: $error';
  }

  @override
  String get newAppointment => 'Nuovo appuntamento';

  @override
  String get newAppointmentTooltip => 'Nuovo appuntamento (Ctrl+N)';

  @override
  String get deleteSelectedAppointmentTooltip =>
      'Elimina l\'appuntamento selezionato (Canc)';

  @override
  String get groupGoTo => 'Vai a';

  @override
  String get today => 'Oggi';

  @override
  String get todayTooltip => 'Torna a oggi';

  @override
  String get next7Days => 'Prossimi 7 giorni';

  @override
  String get next7DaysTooltip => 'Sette giorni a partire da oggi';

  @override
  String get groupArrange => 'Disponi';

  @override
  String get groupSync => 'Sincronizzazione';

  @override
  String get sync => 'Sincronizza';

  @override
  String get syncCalendarsTooltip =>
      'Sincronizza subito i calendari con il server (F9)';

  @override
  String appointmentsNotAvailable(String error) {
    return 'Appuntamenti non disponibili: $error';
  }

  @override
  String uploadStrip(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appuntamenti sono',
      one: 'un appuntamento è',
    );
    return '$name: $_temp0 solo su questo computer, non ancora sul server.';
  }

  @override
  String get uploadToServerEllipsis => 'Carica sul server…';

  @override
  String get calendarEmpty => 'Nessun appuntamento in questo periodo. ';

  @override
  String get calendarEmptySyncHint =>
      'Per vedere quelli del server attiva «Sincronizza il calendario con il server (CalDAV)» in File → Opzioni → Account → Modifica. ';

  @override
  String get calendarEmptyCreate =>
      'Per crearne uno: «Nuovo appuntamento» (Ctrl+N) o doppio clic su uno spazio vuoto.';

  @override
  String get previous => 'Precedente';

  @override
  String get next => 'Successivo';

  @override
  String get myCalendars => 'I miei calendari';

  @override
  String get localOnlyTooltip =>
      'Per vedere gli appuntamenti del server: File → Opzioni → Account → Modifica → «Sincronizza il calendario con il server (CalDAV)»';

  @override
  String get localOnly => 'Solo su questo computer';

  @override
  String get color => 'Colore';

  @override
  String get calendarReadOnlyTooltip =>
      'Sola lettura: gli appuntamenti si vedono ma non si modificano';

  @override
  String get syncedWithServer => 'Sincronizzato con il server';

  @override
  String get previousMonth => 'Mese precedente';

  @override
  String get nextMonth => 'Mese successivo';

  @override
  String nowAt(String time) {
    return 'Adesso ($time)';
  }

  @override
  String moreItems(int count) {
    return '+$count altri';
  }

  @override
  String get syncing => 'Sincronizzazione in corso…';

  @override
  String get synced => 'Sincronizzata';

  @override
  String syncedAt(String time) {
    return 'Sincronizzata alle $time';
  }

  @override
  String syncedOnAt(String date, String time) {
    return 'Sincronizzata il $date alle $time';
  }

  @override
  String get syncServerUnreachable => 'Server dei contatti non raggiungibile';

  @override
  String get syncUnavailable => 'Sincronizzazione non disponibile';

  @override
  String get syncFailed => 'Sincronizzazione non riuscita';

  @override
  String get endBeforeStart => 'La fine è prima dell\'inizio.';

  @override
  String get deleteOccurrenceQuestion => 'Eliminare questa occorrenza?';

  @override
  String get deleteOccurrenceContent =>
      'Solo questa occorrenza viene tolta dalla serie; le altre restano. Non si può recuperare.';

  @override
  String get deleteSeriesContent =>
      'L\'appuntamento (con tutte le sue occorrenze, se è ricorrente) viene eliminato; con la sincronizzazione anche dal server. Non si può recuperare.';

  @override
  String get saveChangesQuestion => 'Salvare le modifiche?';

  @override
  String get appointmentNotSavedContent =>
      'Le modifiche all\'appuntamento non sono state salvate.';

  @override
  String get no => 'No';

  @override
  String get yes => 'Sì';

  @override
  String get untitled => 'Senza titolo';

  @override
  String get occurrence => 'Occorrenza';

  @override
  String get appointment => 'Appuntamento';

  @override
  String get saveAndClose => 'Salva e chiudi';

  @override
  String get saveAndCloseTooltip => 'Salva e chiudi (Ctrl+S)';

  @override
  String get deleteOnlyOccurrenceTooltip => 'Elimina solo questa occorrenza';

  @override
  String get deleteAppointmentTooltip => 'Elimina l\'appuntamento';

  @override
  String get groupOptions => 'Opzioni';

  @override
  String get recurrence => 'Ricorrenza';

  @override
  String get recurrenceTooltip => 'Rendi ricorrente o cambia la ricorrenza';

  @override
  String get reminder => 'Promemoria';

  @override
  String reminderValue(String value) {
    return 'Promemoria: $value';
  }

  @override
  String get reminderNone => 'Nessuno';

  @override
  String get reminderAtStart => 'All\'inizio';

  @override
  String customRecurrence(String rule) {
    return 'Ricorrenza personalizzata ($rule): resta com\'è salvando';
  }

  @override
  String calendarReadOnly(String calendar) {
    return 'Il calendario «$calendar» è di sola lettura: l\'appuntamento si può vedere ma non modificare.';
  }

  @override
  String get location => 'Luogo';

  @override
  String get startTime => 'Inizio';

  @override
  String get endTime => 'Fine';

  @override
  String get allDayEvent => 'Giornata intera';

  @override
  String recurrenceValue(String text) {
    return 'Ricorrenza: $text';
  }

  @override
  String get onlyThisOccurrenceHint =>
      'Solo questa occorrenza della serie: le altre non cambiano.';

  @override
  String get notes => 'Note';

  @override
  String get weekFirst => 'primo';

  @override
  String get weekSecond => 'secondo';

  @override
  String get weekThird => 'terzo';

  @override
  String get weekFourth => 'quarto';

  @override
  String get weekLast => 'ultimo';

  @override
  String get recurrenceBadInterval => 'Ripetizione non valida (ogni 1–999).';

  @override
  String get recurrenceBadCount => 'Numero di occorrenze non valido (1–999).';

  @override
  String get recurrenceNoDays => 'Scegliere almeno un giorno della settimana.';

  @override
  String get recurEveryNDays => 'Ogni [n] giorni';

  @override
  String get recurEveryWeekday => 'Ogni giorno feriale';

  @override
  String get recurEveryNWeeksOn => 'Ricorre ogni [n] settimane il:';

  @override
  String get recurMonthlyDay => 'Il giorno [day] ogni [n] mesi';

  @override
  String get recurMonthlyWeekday => 'Il [week] [weekday] ogni mese';

  @override
  String get recurYearlyDay => 'Ogni [day] [month]';

  @override
  String get recurYearlyWeekday => 'Il [week] [weekday] di [month]';

  @override
  String get appointmentRecurrence => 'Ricorrenza appuntamento';

  @override
  String get recurrencePattern => 'Criterio di ricorrenza';

  @override
  String get recurDaily => 'Giornaliera';

  @override
  String get recurWeekly => 'Settimanale';

  @override
  String get recurMonthly => 'Mensile';

  @override
  String get recurYearly => 'Annuale';

  @override
  String get recurrenceRange => 'Intervallo ricorrenza';

  @override
  String get recurNoEnd => 'Nessuna data di fine';

  @override
  String get recurEndAfter => 'Termina dopo [n] occorrenze';

  @override
  String get recurEndBy => 'Termina entro [date]';

  @override
  String get removeRecurrence => 'Rimuovi ricorrenza';

  @override
  String queuedSendAfter(String when) {
    return 'Messaggio nella Posta in uscita: verrà inviato dopo il $when (con l\'app aperta).';
  }

  @override
  String get queuedOffline =>
      'Senza connessione: il messaggio è nella Posta in uscita e partirà da solo appena il server risponde.';

  @override
  String get sentCopyNotSavedTitle => 'Messaggio inviato, copia non salvata';

  @override
  String sentCopyNotSaved(String error) {
    return 'La mail è stata inviata, ma la copia in Posta inviata non è stata salvata:\n$error\n\nNon reinviarla: i destinatari l\'hanno già ricevuta.';
  }

  @override
  String sentSavedIn(String folder) {
    return ' e salvato in \"$folder\"';
  }

  @override
  String messageSent(String where, String response) {
    return 'Messaggio inviato$where. Server: $response';
  }

  @override
  String get newMessageTitle => 'Nuovo messaggio';

  @override
  String get toPlainTextQuestion => 'Passare a testo normale?';

  @override
  String get toPlainTextContent =>
      'La formattazione e le immagini nel testo andranno perse, anche tornando a HTML. Il messaggio originale citato verrà aggiunto come testo.';

  @override
  String get continueButton => 'Continua';

  @override
  String get savingDraft => 'Salvataggio della bozza…';

  @override
  String get tabInsert => 'Inserisci';

  @override
  String get tabFormatText => 'Formato testo';

  @override
  String get attachFile => 'Allega file';

  @override
  String get attachFileTooltip => 'Allega uno o più file dal computer';

  @override
  String get saveSentCopy => 'Salva copia in Posta inviata';

  @override
  String get saveSentCopyOnTooltip =>
      'Attivo: dopo l\'invio una copia va in Posta inviata (clic per non salvarla)';

  @override
  String get saveSentCopyOffTooltip =>
      'Non attivo: dopo l\'invio nessuna copia in Posta inviata (clic per salvarla)';

  @override
  String get saveDraft => 'Salva bozza';

  @override
  String get saveDraftTooltip =>
      'Salva in Bozze (Ctrl+S); anche da sola ogni 3 minuti';

  @override
  String get delayDelivery => 'Ritarda recapito';

  @override
  String get delayDeliveryTooltip =>
      'Non inviare prima di una data e un\'ora (resta nella Posta in uscita)';

  @override
  String delayDeliveryActiveTooltip(String when) {
    return 'Invio dopo il $when: clic per cambiare';
  }

  @override
  String get importanceHighTooltip =>
      'Segna il messaggio come importante (clic di nuovo per toglierlo)';

  @override
  String get importanceLowTooltip =>
      'Segna il messaggio come poco importante (clic di nuovo per toglierlo)';

  @override
  String get groupInclude => 'Includi';

  @override
  String get groupSave => 'Salva';

  @override
  String get groupShowFields => 'Mostra campi';

  @override
  String get bcc => 'Ccn';

  @override
  String get bccTooltip =>
      'Copia conoscenza nascosta: i destinatari in Ccn non si vedono tra loro né dagli altri';

  @override
  String get groupTracking => 'Rilevamento';

  @override
  String get requestReadReceipt => 'Richiedi conferma di lettura';

  @override
  String get requestReadReceiptOnTooltip =>
      'Attivo: il destinatario può mandarti una conferma quando legge il messaggio (clic per toglierlo)';

  @override
  String get requestReadReceiptOffTooltip =>
      'Chiedi al destinatario una conferma quando legge il messaggio (può rifiutarla)';

  @override
  String get groupMoreOptions => 'Altre opzioni';

  @override
  String get groupFormat => 'Formato';

  @override
  String get formatHtmlTooltip =>
      'Testo formattato, con immagini e collegamenti';

  @override
  String get plainText => 'Testo normale';

  @override
  String get plainTextTooltip =>
      'Solo testo, senza formattazione: lo leggono tutti i programmi di posta';

  @override
  String get signaturesEllipsis => 'Firme…';

  @override
  String get signature => 'Firma';

  @override
  String get signatureTooltip =>
      'Inserisci una firma, o crea e modifica le firme';

  @override
  String get attachments => 'Allegati';

  @override
  String get originalAttachment => 'Allegato del messaggio originale';

  @override
  String get remove => 'Rimuovi';

  @override
  String attachmentsTooLarge(String size, String max) {
    return 'Allegati troppo grandi: $size, massimo $max.';
  }

  @override
  String get messageBody => 'Testo del messaggio';

  @override
  String get addressesHint => 'indirizzi separati da virgola';

  @override
  String get accountUnavailable => '(account non disponibile)';

  @override
  String get originalMessageQuote =>
      'Messaggio originale (viene aggiunto in fondo, com\'è)';

  @override
  String get removeQuote => 'Rimuovi citazione';

  @override
  String get offlineSendMessage =>
      'Non connesso al server e il messaggio originale (citazione o allegati) non è sul computer: la mail non è stata inviata e resta qui. Riprova quando torna la connessione.';

  @override
  String sendFailed(String error) {
    return 'Invio non riuscito: $error';
  }

  @override
  String draftTooLarge(String max) {
    return 'Bozza non salvata: allegati oltre $max.';
  }

  @override
  String draftSavedLocally(String time) {
    return 'Bozza salvata sul computer alle $time: andrà in Bozze quando il server risponde';
  }

  @override
  String draftSavedAt(String time) {
    return 'Bozza salvata alle $time';
  }

  @override
  String get draftNotSaved => 'Bozza non salvata';

  @override
  String draftNotSavedError(String error) {
    return 'Bozza non salvata: $error';
  }

  @override
  String get sendQuestion => 'Inviare il messaggio?';

  @override
  String sendSummaryCopy(String value) {
    return 'Copia in Posta inviata: $value';
  }

  @override
  String sendSummaryDelivery(String when) {
    return 'Recapito: non prima del $when';
  }

  @override
  String get emptySubjectWarning => 'Attenzione: l\'oggetto è vuoto.';

  @override
  String get attachmentsNone => 'nessuno';

  @override
  String attachmentsFromDisk(String size) {
    return ', file dal disco $size';
  }

  @override
  String get composeSaveNew =>
      'Il messaggio non è stato inviato. Salvarlo in Bozze per finirlo dopo?';

  @override
  String get composeSaveExisting =>
      'Il messaggio non è stato inviato. Salvare le ultime modifiche nella bozza?';

  @override
  String get sending => 'Invio…';

  @override
  String get doNotDeliverBefore => 'Non recapitare prima del:';

  @override
  String get delayDeliveryHint =>
      'Dopo \"Invia\" la mail resta nella Posta in uscita e parte da sola a quell\'ora, se l\'app è aperta.';

  @override
  String get chooseFutureTime => 'Scegli un momento nel futuro.';

  @override
  String get noDelay => 'Nessun ritardo';

  @override
  String get recipientRequired => 'Indicare almeno un destinatario';

  @override
  String invalidAddress(String address) {
    return 'Indirizzo non valido: $address';
  }

  @override
  String get dontSuggestAddress => 'Non suggerire più questo indirizzo';

  @override
  String get noMoreSuggestions => 'Nessun altro suggerimento';

  @override
  String get outboxHint =>
      'Posta in uscita: mail sul computer che partono da sole quando è il momento e il server risponde, con l\'app aperta.';

  @override
  String get outboxEmpty => 'Nessuna mail in attesa di invio';

  @override
  String get deleteOutboxQuestion => 'Eliminare la mail?';

  @override
  String deleteOutboxContent(String subject) {
    return '\"$subject\" non verrà inviata.';
  }

  @override
  String outboxNotSent(String error) {
    return 'Non inviata: $error';
  }

  @override
  String outboxSendAfter(String when) {
    return 'Invio dopo il $when';
  }

  @override
  String get outboxWaiting => 'In attesa di connessione';

  @override
  String get noRecipients => '(nessun destinatario)';

  @override
  String get sendNow => 'Invia ora';

  @override
  String get moveToDrafts => 'Sposta in Bozze (per modificarla)';

  @override
  String get deleteOutboxTooltip => 'Elimina (non verrà inviata)';

  @override
  String get yesValue => 'sì';

  @override
  String get noValue => 'no';

  @override
  String get fontColorAutomatic => 'Automatico';

  @override
  String get fontColorDarkRed => 'Rosso scuro';

  @override
  String get fontColorRed => 'Rosso';

  @override
  String get fontColorOrange => 'Arancione';

  @override
  String get fontColorYellow => 'Giallo';

  @override
  String get fontColorLightGreen => 'Verde chiaro';

  @override
  String get fontColorGreen => 'Verde';

  @override
  String get fontColorLightBlue => 'Azzurro';

  @override
  String get fontColorBlue => 'Blu';

  @override
  String get fontColorDarkBlue => 'Blu scuro';

  @override
  String get fontColorPurple => 'Viola';

  @override
  String get remoteImagePlaceholder => '[immagine da internet]';

  @override
  String get groupBasicText => 'Testo base';

  @override
  String get groupFont => 'Carattere';

  @override
  String get groupParagraph => 'Paragrafo';

  @override
  String get linkTooltip => 'Collegamento (Ctrl+K)';

  @override
  String get imageFromFile => 'Immagine da file (es. un logo)';

  @override
  String get defaultFont => 'Calibri (predefinito)';

  @override
  String get fontSize => 'Dimensione carattere';

  @override
  String get bold => 'Grassetto (Ctrl+B)';

  @override
  String get italic => 'Corsivo (Ctrl+I)';

  @override
  String get underline => 'Sottolineato (Ctrl+U)';

  @override
  String get strikethrough => 'Barrato';

  @override
  String get fontColor => 'Colore carattere';

  @override
  String get highlightColor => 'Colore evidenziazione testo';

  @override
  String get noColor => 'Nessun colore';

  @override
  String get clearFormatting => 'Cancella formattazione';

  @override
  String get bullets => 'Elenco puntato';

  @override
  String get numbering => 'Elenco numerato';

  @override
  String get decreaseIndent => 'Riduci rientro';

  @override
  String get increaseIndent => 'Aumenta rientro';

  @override
  String get alignLeft => 'Allinea a sinistra';

  @override
  String get center => 'Centra';

  @override
  String get alignRight => 'Allinea a destra';

  @override
  String get justify => 'Giustifica';

  @override
  String get link => 'Collegamento';

  @override
  String get linkButtonTooltip =>
      'Inserisci o modifica un collegamento (Ctrl+K)';

  @override
  String get linkInvalid =>
      'Indirizzo non valido: sono ammessi http, https e mailto.';

  @override
  String get insertLink => 'Inserisci collegamento';

  @override
  String get linkAddress => 'Indirizzo';

  @override
  String get linkAddressHint => 'https://… o un indirizzo email';

  @override
  String get removeLink => 'Rimuovi collegamento';

  @override
  String signatureTooLarge(String size, String max) {
    return 'Firma troppo grande: $size di immagini, massimo $max.';
  }

  @override
  String get newSignature => 'Nuova firma';

  @override
  String get renameSignature => 'Rinomina firma';

  @override
  String get deleteSignatureQuestion => 'Eliminare la firma?';

  @override
  String deleteSignatureContent(String name) {
    return '\"$name\" verrà eliminata da questo computer.';
  }

  @override
  String get notAnImage =>
      'Il file scelto non è un\'immagine (PNG, JPEG, GIF, BMP o WebP).';

  @override
  String get signaturesAndStationery => 'Firme e elementi decorativi';

  @override
  String get selectSignatureToEdit => 'Seleziona la firma da modificare';

  @override
  String get newButton => 'Nuova';

  @override
  String get rename => 'Rinomina';

  @override
  String get editSignature => 'Modifica firma';

  @override
  String get noSignatures => 'Nessuna firma: crea la prima con \"Nuova\".';

  @override
  String get signatureText => 'Testo della firma';

  @override
  String get noneFeminine => '(nessuna)';

  @override
  String get chooseDefaultSignature => 'Scegli firma predefinita';

  @override
  String get account => 'Account';

  @override
  String get newMessages => 'Nuovi messaggi';

  @override
  String get repliesForwards => 'Risposte/inoltri';

  @override
  String get writeAName => 'Scrivi un nome.';

  @override
  String get signatureNameTaken => 'C\'è già una firma con questo nome.';

  @override
  String get signatureName => 'Nome della firma';

  @override
  String get contacts => 'Contatti';

  @override
  String get addressBook => 'Rubrica';

  @override
  String get addressBookSearch => 'Cerca per nome, indirizzo o società';

  @override
  String get allAddressBooks => 'Tutte le rubriche';

  @override
  String contactsNotAvailable(String error) {
    return 'Contatti non disponibili: $error';
  }

  @override
  String get noContactsWithAddress => 'Nessun contatto con un indirizzo.';

  @override
  String get noContactsFound => 'Nessun contatto trovato.';

  @override
  String get takeOut => 'Togli';

  @override
  String get labelWork => 'Lavoro';

  @override
  String get labelHome => 'Casa';

  @override
  String get labelOther => 'Altro';

  @override
  String get labelMobile => 'Cellulare';

  @override
  String get labelOffice => 'Ufficio';

  @override
  String get deleteContactQuestion => 'Eliminare il contatto?';

  @override
  String deleteContactContent(String name) {
    return '«$name» è solo su questo computer: eliminato, non si può recuperare.';
  }

  @override
  String contactNotDeleted(String error) {
    return 'Contatto non eliminato: $error';
  }

  @override
  String get contactFilesLabel => 'Contatti (vCard, CSV)';

  @override
  String get importDone => 'Importazione completata';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contatti aggiunti',
      one: '1 contatto aggiunto',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    return '$count già presenti (non aggiunti di nuovo)';
  }

  @override
  String importInvalid(int count) {
    return '$count scartati (senza nome né indirizzo, o non validi)';
  }

  @override
  String importFailed(String error) {
    return 'Importazione non riuscita: $error';
  }

  @override
  String get exportContacts => 'Esporta contatti';

  @override
  String get exportVcfHint => 'Per Thunderbird, telefoni, Apple, Google';

  @override
  String get exportCsvHint => 'Colonne di Outlook: per Outlook, Gmail, Excel';

  @override
  String exportDone(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contatti esportati',
      one: '1 contatto esportato',
    );
    return '$_temp0 in $path';
  }

  @override
  String exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String contactSavedIn(String name, String book) {
    return '«$name» salvato in $book';
  }

  @override
  String get uploadContactsQuestion => 'Caricare i contatti sul server?';

  @override
  String uploadContactsContent(int count, String book, String serverBook) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contatti della rubrica «$book» sono solo su questo computer. Verranno aggiunti',
      one:
          'Un contatto della rubrica «$book» è solo su questo computer. Verrà aggiunto',
    );
    return '$_temp0 alla rubrica «$serverBook» del server dei contatti e da allora sincronizzati.\n\nI contatti già presenti sul server non vengono modificati.';
  }

  @override
  String contactsNotUploaded(String error) {
    return 'Contatti non caricati: $error';
  }

  @override
  String get newContact => 'Nuovo contatto';

  @override
  String get newContactTooltip =>
      'Nuovo contatto nella rubrica aperta (Ctrl+N)';

  @override
  String get deleteContactTooltip => 'Elimina il contatto selezionato (Canc)';

  @override
  String get groupCommunicate => 'Comunica';

  @override
  String get emailMessage => 'Messaggio di posta';

  @override
  String get emailMessageTooltip => 'Nuova mail al contatto selezionato';

  @override
  String get edit => 'Modifica';

  @override
  String get editContactTooltip =>
      'Apri il contatto selezionato (Invio o doppio clic)';

  @override
  String get syncContactsTooltip =>
      'Sincronizza subito la rubrica con il server dei contatti (F9)';

  @override
  String get syncContactsOffTooltip =>
      'Sincronizzazione dei contatti non attiva: si accende nelle impostazioni dell\'account';

  @override
  String get groupImportExport => 'Importa/Esporta';

  @override
  String get importEllipsis => 'Importa…';

  @override
  String get importTooltip =>
      'Aggiungi contatti da un file vCard (.vcf) o CSV di Outlook o Gmail';

  @override
  String get exportEllipsis => 'Esporta…';

  @override
  String get exportTooltip => 'Salva tutta la rubrica in un file vCard o CSV';

  @override
  String get searchContacts => 'Cerca contatti';

  @override
  String get searchContactsTooltip =>
      'Cerca per nome, indirizzo, società o telefono (Ctrl+E)';

  @override
  String get myContacts => 'I miei contatti';

  @override
  String get reloginCalendar =>
      'Il calendario non si sincronizza: serve un nuovo accesso con Google che permetta l\'accesso al calendario.';

  @override
  String get reloginContacts =>
      'I contatti non si sincronizzano: serve un nuovo accesso con Google che permetta l\'accesso ai contatti.';

  @override
  String contactsUploadStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contatti sono solo su questo computer: non sono ancora sul server dei contatti.',
      one: 'Un contatto è solo su questo computer: non è ancora sul server dei contatti.',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Cancella la ricerca';

  @override
  String get noContactsHint =>
      'Nessun contatto. Usa «Nuovo contatto» o «Importa…».';

  @override
  String get selectContact => 'Seleziona un contatto';

  @override
  String get emailSection => 'Posta elettronica';

  @override
  String get phoneSection => 'Telefono';

  @override
  String get contact => 'Contatto';

  @override
  String get firstName => 'Nome';

  @override
  String get lastName => 'Cognome';

  @override
  String get displayAs => 'Nome visualizzato (se diverso da nome e cognome)';

  @override
  String get company => 'Società';

  @override
  String get addAddress => 'Aggiungi indirizzo';

  @override
  String get phoneNumber => 'Numero';

  @override
  String get addPhone => 'Aggiungi telefono';

  @override
  String get securityNone => 'Nessuna';

  @override
  String get bodyMonthsAll => 'Tutte';

  @override
  String bodyMonthsLast(int months) {
    return 'Ultimi $months mesi';
  }

  @override
  String noAccountsSaved(String address) {
    return 'Nessun account salvato nell\'app. In sviluppo il core usa gli user-secrets$address.\nAggiungendo un account qui verranno usati solo gli account salvati qui: per continuare a vedere quello attuale, aggiungi anche lui.';
  }

  @override
  String accountSignedInWith(String provider) {
    return 'accesso con $provider';
  }

  @override
  String accountDownloadedMail(String months) {
    return 'Mail scaricate: $months';
  }

  @override
  String get accountContactsSynced => 'contatti sincronizzati (CardDAV)';

  @override
  String get accountCalendarSynced => 'calendario sincronizzato (CalDAV)';

  @override
  String get rebuildCache => 'Ricostruisci cache';

  @override
  String get removeFromApp => 'Rimuovi dall\'app';

  @override
  String get addAccount => 'Aggiungi account';

  @override
  String get accountsTitle => 'Account';

  @override
  String get pendingChangesOk =>
      'Modifiche non ancora salvate: valgono con «OK».';

  @override
  String accountsNotSaved(String error) {
    return 'Account non salvati: $error';
  }

  @override
  String get pop3RemovedAfterDownload =>
      'tolte dal server dopo lo scaricamento';

  @override
  String pop3CopyForDays(int days) {
    return 'copia sul server per $days giorni';
  }

  @override
  String get pop3CopyLeft => 'copia lasciata sul server';

  @override
  String pop3Summary(String copy, int minutes) {
    return 'Mail sul computer, $copy · controllo ogni $minutes minuti';
  }

  @override
  String get removedAccountsData => 'Dati di account rimossi';

  @override
  String get removedAccountsDataInfo =>
      'Mail scaricate e indice di ricerca di account tolti dall\'app. Restano sul computer finché non li elimini.';

  @override
  String get orphanPop3Only => 'mail POP3: l\'unica copia è questa';

  @override
  String orphanContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contatti',
      one: '1 contatto',
    );
    return '$_temp0, solo su questo computer';
  }

  @override
  String get deleteLocalData => 'Elimina dati locali';

  @override
  String get rebuildQuestion => 'Ricostruire la copia locale?';

  @override
  String rebuildContent(String name) {
    return 'La copia sul computer di «$name» (mail scaricate e indice di ricerca) viene cancellata e riscaricata dal server in background: può richiedere qualche minuto e usare la rete.\n\nSul server non viene modificato nulla.';
  }

  @override
  String get rebuild => 'Ricostruisci';

  @override
  String rebuildStarted(String name) {
    return 'Ricostruzione della copia locale di «$name» avviata.';
  }

  @override
  String rebuildFailed(String error) {
    return 'Copia locale non ricostruita: $error';
  }

  @override
  String get deleteLocalDataQuestion => 'Eliminare i dati locali?';

  @override
  String deleteLocalDataContent(String name, String size, String contacts) {
    return 'Vengono cancellate dal computer le mail scaricate e l\'indice di ricerca di «$name» ($size), un account che non è più nell\'app.\n\n${contacts}Sul server non viene modificato nulla. L\'operazione non si può annullare: se aggiungerai di nuovo l\'account, le mail verranno riscaricate.';
  }

  @override
  String deleteLocalDataContacts(int count) {
    return 'Si perdono anche i suoi $count contatti: sono solo su questo computer. Per tenerli, aggiungi di nuovo l\'account ed esportali da Persone.';
  }

  @override
  String localDataDeleted(String name) {
    return 'Dati locali di «$name» eliminati.';
  }

  @override
  String localDataNotDeleted(String error) {
    return 'Dati locali non eliminati: $error';
  }

  @override
  String get removeAccountQuestion => 'Rimuovere l\'account dall\'app?';

  @override
  String removeAccountContent(String name, String email, String note) {
    return '«$name» ($email) verrà tolto da PostinoVip, insieme alla password salvata nel portachiavi.\n\n$note Anche i suoi contatti (Persone) restano sul computer.\n\nLa rimozione vale quando premi «OK» nella finestra Account.';
  }

  @override
  String get removeAccountPop3Note =>
      'Sul server non viene modificato nulla. Le mail scaricate con POP3 restano sul computer (per alcune è l\'unica copia): le trovi in \"Dati di account rimossi\" e tornano visibili se aggiungi di nuovo l\'account.';

  @override
  String get removeAccountImapNote =>
      'Sul server non viene modificato nulla: le mail restano dove sono e puoi aggiungere di nuovo l\'account in qualsiasi momento. Le mail già scaricate restano sul computer: puoi eliminarle in seguito da \"Dati di account rimossi\".';

  @override
  String get deleteForeverQuestion => 'Eliminare per sempre le mail?';

  @override
  String deleteForeverContent(String name, String size, String expected) {
    return '«$name» era un account POP3: le sue mail ($size) sono state scaricate su questo computer e qui c\'è l\'unica copia. Quelle già tolte dal server non si potranno più recuperare.\n\nPer confermare scrivi: $expected';
  }

  @override
  String get deleteForever => 'Elimina per sempre';

  @override
  String get browserNotOpened => 'Il browser non si è aperto.';

  @override
  String signInNotStarted(String error) {
    return 'Accesso non avviato: $error';
  }

  @override
  String get signInExpired => 'Accesso scaduto: riprova.';

  @override
  String signInFailedError(String error) {
    return 'Accesso non riuscito: $error';
  }

  @override
  String get signInFailed => 'Accesso non riuscito.';

  @override
  String get signInWithoutContacts =>
      'Accesso fatto, ma senza il permesso dei contatti: la sincronizzazione dei contatti resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.';

  @override
  String get signInWithoutCalendar =>
      'Accesso fatto, ma senza il permesso del calendario: la sincronizzazione del calendario resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.';

  @override
  String get signInWithoutContactsCalendar =>
      'Accesso fatto, ma senza il permesso dei contatti e del calendario: la sincronizzazione dei contatti e del calendario resta spenta. Per attivarla spunta di nuovo la casella e permetti l\'accesso.';

  @override
  String waitingSignIn(String company) {
    return 'In attesa dell\'accesso nella pagina di $company, nel browser…';
  }

  @override
  String signedInWith(String company) {
    return 'Accesso con $company fatto: niente password da salvare.';
  }

  @override
  String noPasswordSignIn(String company) {
    return 'Niente password: l\'accesso avviene nella pagina di $company, nel browser. Al ritorno indirizzo e server si compilano da soli.';
  }

  @override
  String serviceUnavailable(String service) {
    return '$service non è disponibile: il core non ha l\'ID dell\'app.';
  }

  @override
  String signInWith(String company) {
    return 'Accedi con $company';
  }

  @override
  String get welcomeTitle => 'Benvenuto in PostinoVip';

  @override
  String get newAccount => 'Nuovo account';

  @override
  String get editAccount => 'Modifica account';

  @override
  String get firstRunIntro =>
      'Inserisci i dati della tua casella. La password viene conservata nel portachiavi di sistema.';

  @override
  String get accountType => 'Tipo di account';

  @override
  String get accountTypeHelp =>
      'IMAP: le mail restano sul server e si vedono da tutti i dispositivi (consigliato).\nPOP3: le mail vengono scaricate su questo computer. Non si può cambiare dopo.';

  @override
  String accountTypeServices(String services) {
    return '$services: accesso con il browser, senza password.';
  }

  @override
  String accountTypeValue(String type) {
    return 'Tipo di account: $type';
  }

  @override
  String get nameOptional => 'Nome (facoltativo)';

  @override
  String get nameOptionalHint => 'es. Lavoro; se vuoto si mostra l\'indirizzo';

  @override
  String get emailAddressUser => 'Indirizzo email (anche nome utente)';

  @override
  String get invalidAddressShort => 'Indirizzo non valido';

  @override
  String get accountAlreadyPresent => 'Questo account è già presente';

  @override
  String get password => 'Password';

  @override
  String get hidePassword => 'Nascondi password';

  @override
  String get showPassword => 'Mostra password';

  @override
  String get passwordRequired => 'Password obbligatoria';

  @override
  String sameMailboxOtherType(String type, String name) {
    return 'Questa casella è già configurata come $type («$name»). Si può usare in entrambi i modi, ma con le rimozioni dal server del POP3 le mail spariranno anche dall\'account IMAP.';
  }

  @override
  String incomingServer(String type) {
    return '$type (posta in arrivo)';
  }

  @override
  String get outgoingServer => 'SMTP (posta in uscita)';

  @override
  String get smtpAuthTitle => 'Il server di invio richiede l\'autenticazione';

  @override
  String get smtpAuthSubtitle =>
      'Con indirizzo e password della casella. Toglila solo per un server che accetta le mail senza login (es. sulla porta 25 della rete aziendale).';

  @override
  String get downloadedMail => 'Mail scaricate sul computer';

  @override
  String get downloadedMailHelp =>
      'Le più recenti vengono scaricate in background e si aprono subito; le altre quando le apri.\nPosta eliminata e Indesiderata: solo l\'elenco.';

  @override
  String get recommendedSuffix => ' (consigliato)';

  @override
  String get syncContactsGoogle =>
      'Sincronizza i contatti con Google (CardDAV)';

  @override
  String get syncContactsServer =>
      'Sincronizza i contatti con il server (CardDAV)';

  @override
  String get notYetForMicrosoft =>
      'Per gli account Microsoft non è ancora disponibile.';

  @override
  String get signInWithGoogleFirst => 'Prima fai «Accedi con Google».';

  @override
  String get syncContactsGoogleHelp =>
      'La rubrica di questo account diventa quella dei contatti Google. Spuntando la casella si apre il browser per permettere a PostinoVip l\'accesso ai contatti.';

  @override
  String get syncContactsServerHelp =>
      'La rubrica di questo account diventa quella del server dei contatti, con le stesse credenziali. La prima volta i contatti che sono solo su questo computer vanno sul server solo dopo una conferma.';

  @override
  String get contactsSignInWaiting =>
      'Accesso con Google in corso nel browser: permetti l\'accesso ai contatti.';

  @override
  String get contactsServerUrl =>
      'Indirizzo del server dei contatti (facoltativo)';

  @override
  String get emptyFoundOnIncoming =>
      'Vuoto: cercato da solo sul server di ricezione';

  @override
  String emptyFoundOn(String host) {
    return 'Vuoto: cercato da solo su $host';
  }

  @override
  String get httpsRequired => 'Serve un indirizzo https://';

  @override
  String get testAddressBook => 'Verifica rubrica';

  @override
  String addressBookFound(String name) {
    return 'Trovata: «$name»';
  }

  @override
  String get addressBookNotFound => 'Rubrica non trovata.';

  @override
  String get calendarSection => 'Calendario';

  @override
  String get syncCalendarGoogle =>
      'Sincronizza il calendario con Google (CalDAV)';

  @override
  String get syncCalendarServer =>
      'Sincronizza il calendario con il server (CalDAV)';

  @override
  String get syncCalendarGoogleHelp =>
      'I calendari di Google diventano i calendari di questo account; quelli di sola lettura (es. le festività) si vedono ma non si modificano. Spuntando la casella si apre il browser per permettere a PostinoVip l\'accesso al calendario.';

  @override
  String get syncCalendarServerHelp =>
      'I calendari del server che accettano appuntamenti diventano i calendari di questo account. La prima volta gli appuntamenti che sono solo su questo computer vanno sul server solo dopo una conferma.';

  @override
  String get calendarSignInWaiting =>
      'Accesso con Google in corso nel browser: permetti l\'accesso al calendario.';

  @override
  String get calendarServerUrl =>
      'Indirizzo del server del calendario (facoltativo)';

  @override
  String get testCalendar => 'Verifica calendario';

  @override
  String calendarsFound(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trovati',
      one: 'Trovato',
    );
    return '$_temp0: $names';
  }

  @override
  String quoted(String text) {
    return '«$text»';
  }

  @override
  String get calendarNotFound => 'Calendario non trovato.';

  @override
  String get enterAddressPasswordFirst =>
      'Scrivere prima indirizzo e password.';

  @override
  String get enterServerOrCalendarUrl =>
      'Scrivere il server di ricezione o l\'indirizzo del server del calendario.';

  @override
  String get enterServerOrContactsUrl =>
      'Scrivere il server di ricezione o l\'indirizzo del server dei contatti.';

  @override
  String get deliverySection => 'Recapito';

  @override
  String get leaveCopyOnServer => 'Lascia una copia dei messaggi sul server';

  @override
  String get removeFromServerAfter => 'Rimuovi dal server dopo';

  @override
  String get days => 'giorni';

  @override
  String get removeWhenDeleted =>
      'Rimuovi dal server quando eliminati da \"Posta eliminata\"';

  @override
  String get pop3NoCopyWarning =>
      'Ogni mail verrà tolta dal server subito dopo averla scaricata: resterà solo su questo computer.';

  @override
  String get checkMailEvery => 'Controlla la posta ogni';

  @override
  String get checkMailEveryHelp =>
      'Anche con Invia/ricevi (F9). Le mail stanno solo sul computer: conviene farne un backup.';

  @override
  String minutesCount(int count) {
    return '$count minuti';
  }

  @override
  String get server => 'Server';

  @override
  String get serverHint => 'es. mail.dominio.it';

  @override
  String get serverRequired => 'Server obbligatorio';

  @override
  String get port => 'Porta';

  @override
  String get encryption => 'Crittografia';

  @override
  String get unencryptedWarning =>
      'Senza crittografia password e mail viaggiano in chiaro: chiunque sulla rete può leggerle. Usala solo su una rete di cui ti fidi.';

  @override
  String get certificateTrustedByYou =>
      'Certificato del server accettato da te (non firmato da un\'autorità riconosciuta).';

  @override
  String get stopTrusting => 'Non fidarti più';

  @override
  String testFailed(String error) {
    return 'Verifica non riuscita: $error';
  }

  @override
  String get trustCertificateQuestion => 'Fidarsi di questo certificato?';

  @override
  String invalidCertificatePresented(String server, String address) {
    return 'Il server $server $address ha presentato un certificato non valido:';
  }

  @override
  String get certificateIssuedTo => 'Intestato a';

  @override
  String get certificateIssuedBy => 'Emesso da';

  @override
  String get certificateValid => 'Valido';

  @override
  String certificateValidRange(String from, String to) {
    return 'dal $from al $to';
  }

  @override
  String get certificateFingerprint => 'Impronta SHA-256';

  @override
  String get certificateAdvice =>
      'Accettalo solo se sai che questo server usa un certificato proprio (es. un server aziendale o di casa); se possibile confronta l\'impronta con quella che ti dà l\'amministratore. Un certificato inatteso può voler dire che qualcuno sta cercando di intercettare la password.\n\nSe accetti, PostinoVip si fiderà solo di questo certificato: se il server ne presenterà un altro, te lo chiederà di nuovo.';

  @override
  String get trustCertificate => 'Fidati del certificato';

  @override
  String get testConnection => 'Verifica connessione';

  @override
  String get save => 'Salva';

  @override
  String get saveAfterTest => '\"Salva\" si attiva dopo una verifica riuscita.';

  @override
  String accountNotSaved(String error) {
    return 'Account non salvato: $error';
  }

  @override
  String unencryptedIncoming(String address) {
    return 'ricezione ($address)';
  }

  @override
  String unencryptedOutgoing(String address) {
    return 'invio ($address)';
  }

  @override
  String get unencryptedTitle => 'Connessione senza crittografia';

  @override
  String unencryptedContent(String servers) {
    return 'Per $servers hai scelto \"Nessuna\" crittografia: la password e le mail viaggiano in chiaro e chiunque sulla stessa rete (Wi-Fi pubblico, rete aziendale, fornitore) può leggerle o modificarle.\n\nSalvare comunque?';
  }

  @override
  String get andSeparator => ' e ';

  @override
  String get saveUnencrypted => 'Salva senza crittografia';

  @override
  String get runFilterAll => 'Tutti i messaggi';

  @override
  String get runFilterRead => 'Messaggi letti';

  @override
  String get runFilterUnread => 'Messaggi da leggere';

  @override
  String ruleNameFrom(String sender) {
    return 'Da $sender';
  }

  @override
  String ruleCreated(String name) {
    return 'Regola «$name» creata: vale per le mail che arriveranno.';
  }

  @override
  String ruleNotSaved(String error) {
    return 'Regola non salvata: $error';
  }

  @override
  String get orSeparator => ' o ';

  @override
  String ruleDescFrom(String words) {
    return 'da $words';
  }

  @override
  String ruleDescToOrCc(String words) {
    return 'A o Cc contiene $words';
  }

  @override
  String get ruleDescSentOnlyToMe => 'inviata solo a me';

  @override
  String get ruleDescMeInTo => 'io in A';

  @override
  String get ruleDescMeInCc => 'io in Cc';

  @override
  String ruleDescSubject(String words) {
    return 'oggetto contiene $words';
  }

  @override
  String ruleDescSubjectOrBody(String words) {
    return 'oggetto o testo contiene $words';
  }

  @override
  String get ruleDescAttachments => 'con allegati';

  @override
  String ruleDescSize(int kb) {
    return 'più grande di $kb KB';
  }

  @override
  String ruleDescMove(String folder) {
    return 'sposta in $folder';
  }

  @override
  String ruleDescCopy(String folder) {
    return 'copia in $folder';
  }

  @override
  String get ruleDescDelete => 'elimina';

  @override
  String get ruleDescMarkRead => 'segna come letta';

  @override
  String get ruleDescFlag => 'contrassegna';

  @override
  String ruleDescCategory(String name) {
    return 'categoria $name';
  }

  @override
  String get ruleDescStop => 'nessun\'altra regola';

  @override
  String get ruleDescAllMail => 'Tutte le mail';

  @override
  String ruleDescIf(String conditions) {
    return 'Se $conditions';
  }

  @override
  String ruleDescExcept(String exceptions) {
    return ', tranne se $exceptions';
  }

  @override
  String rulesNotRead(String error) {
    return 'Regole non lette: $error';
  }

  @override
  String get deleteRuleQuestion => 'Eliminare la regola?';

  @override
  String deleteRuleContent(String name) {
    return 'La regola «$name» non verrà più applicata. Le mail già smistate restano dove sono.';
  }

  @override
  String rulesNotSaved(String error) {
    return 'Regole non salvate: $error';
  }

  @override
  String get rulesAndAlerts => 'Regole e avvisi';

  @override
  String get applyChangesToFolder => 'Applica le modifiche a questa cartella';

  @override
  String get newRuleEllipsis => 'Nuova regola…';

  @override
  String get runRulesNowEllipsis => 'Esegui regole ora…';

  @override
  String get noRules =>
      'Nessuna regola. Con «Nuova regola…» smisti la posta in arrivo da sola.';

  @override
  String get rulesInfo =>
      'Le regole si applicano nell\'ordine dell\'elenco alle mail che arrivano nella Posta in arrivo mentre PostinoVip è aperto; quelle arrivate con l\'app chiusa vengono smistate alla riapertura.';

  @override
  String get chooseFolderColon => 'Scegli la cartella:';

  @override
  String get ruleNameRequired => 'Scrivi il nome della regola.';

  @override
  String get ruleFolderRequired =>
      'Scegli la cartella in cui spostare o copiare.';

  @override
  String get ruleActionRequired =>
      'Scegli almeno un\'azione nella scheda «Azioni».';

  @override
  String get ruleSizeRequired => 'Scrivi la dimensione in KB.';

  @override
  String get ruleForAllMail => 'Regola per tutte le mail';

  @override
  String get ruleForAllMailContent =>
      'Senza condizioni la regola si applicherà a tutte le mail che ricevi. È corretto?';

  @override
  String get newRule => 'Nuova regola';

  @override
  String get editRule => 'Modifica regola';

  @override
  String get ruleName => 'Nome della regola';

  @override
  String get ruleConditions => 'Condizioni';

  @override
  String get ruleActions => 'Azioni';

  @override
  String get ruleExceptions => 'Eccezioni';

  @override
  String get ruleConditionsIntro =>
      'Applica la regola alle mail che soddisfano tutte le condizioni scelte:';

  @override
  String get ruleExceptionsIntro => 'Tranne se è vera almeno una di queste:';

  @override
  String get ruleFrom => 'da';

  @override
  String get ruleFromHint => 'es. anna@esempio.it; esempio.it';

  @override
  String get ruleToOrCc => 'A o Cc contiene';

  @override
  String get ruleToOrCcHint => 'nomi o indirizzi, separati da ;';

  @override
  String get ruleMeInTo => 'il mio indirizzo è in A';

  @override
  String get ruleMeInCc => 'il mio indirizzo è in Cc';

  @override
  String get ruleSubjectContains => 'l\'oggetto contiene';

  @override
  String get ruleSubjectOrBodyContains => 'l\'oggetto o il testo contiene';

  @override
  String get ruleWordsHint => 'parole separate da ;';

  @override
  String get ruleLargerThan => 'più grande di';

  @override
  String get chooseFolderEllipsis => 'Scegli la cartella…';

  @override
  String get ruleActionsIntro =>
      'Cosa fare con le mail che soddisfano le condizioni:';

  @override
  String get ruleMoveTo => 'sposta nella cartella';

  @override
  String get ruleMoveToTitle => 'Sposta nella cartella';

  @override
  String get ruleCopyTo => 'copia nella cartella';

  @override
  String get ruleCopyToTitle => 'Copia nella cartella';

  @override
  String get ruleDeleteAction => 'elimina (in Posta eliminata)';

  @override
  String get ruleFlagAction => 'contrassegna per completamento';

  @override
  String get ruleCategoryAction => 'assegna la categoria';

  @override
  String get ruleStopAction => 'interrompi l\'elaborazione di altre regole';

  @override
  String rulesNotRun(String error) {
    return 'Regole non eseguite: $error';
  }

  @override
  String progressUnavailable(String error) {
    return 'Avanzamento non disponibile: $error';
  }

  @override
  String get runInFolder => 'Esegui nella cartella';

  @override
  String runStoppedError(String error) {
    return 'Interrotta per un errore: $error';
  }

  @override
  String runStoppedChecked(int checked, int total) {
    return 'Interrotta: esaminate $checked mail su $total';
  }

  @override
  String runDoneChecked(int checked) {
    return 'Fatto: esaminate $checked mail';
  }

  @override
  String runOutcome(String head, int applied) {
    return '$head, $applied spostate o modificate';
  }

  @override
  String runFailedActions(int count) {
    return ', $count azioni non riuscite (dettagli nel registro del core)';
  }

  @override
  String get runRulesNow => 'Esegui regole ora';

  @override
  String get rulesToRun => 'Regole da eseguire:';

  @override
  String get ruleDisabledSuffix => ' (disattivata)';

  @override
  String get runInFolderLabel => 'Nella cartella: ';

  @override
  String get includeSubfolders => 'Includi sottocartelle';

  @override
  String get applyRulesTo => 'Applica le regole a';

  @override
  String get preparing => 'Preparazione…';

  @override
  String runProgress(int checked, int total) {
    return 'Esaminate $checked mail su $total';
  }

  @override
  String get stopping => 'interruzione…';

  @override
  String get stop => 'Interrompi';

  @override
  String get runNow => 'Esegui ora';

  @override
  String settingsNotRead(String error) {
    return 'Impostazioni non lette: $error';
  }

  @override
  String get autoReplyTextRequired =>
      'Scrivi il messaggio della risposta automatica.';

  @override
  String get endAfterStart =>
      'L\'ora di fine deve venire dopo l\'ora di inizio.';

  @override
  String get turnOnAutoRepliesQuestion => 'Attivare le risposte automatiche?';

  @override
  String get turnOnAutoRepliesContent =>
      'Da ora PostinoVip risponderà da solo, una volta per mittente, alle mail che arrivano nella Posta in arrivo e in cui sei in A o Cc, finché resta aperto. Le risposte partono senza chiederti conferma.';

  @override
  String get turnOn => 'Attiva';

  @override
  String notSavedPlural(String error) {
    return 'Non salvate: $error';
  }

  @override
  String get dontSendAutoReplies => 'Non inviare risposte automatiche';

  @override
  String get sendAutoReplies => 'Invia risposte automatiche';

  @override
  String get onlyDuringRange => 'Invia solo durante questo intervallo di tempo';

  @override
  String get startTimeColon => 'Inizio:';

  @override
  String get endTimeColon => 'Fine:';

  @override
  String get autoRepliesInfo =>
      'Le risposte partono da questo computer mentre PostinoVip è aperto (le mail arrivate ad app chiusa ricevono la risposta alla riapertura): una sola per mittente, solo se sei in A o Cc, mai a mailing list, ad altre risposte automatiche o a mittenti come «noreply». Non vengono salvate in Posta inviata.';

  @override
  String get autoReplyPlaceholder =>
      'es. Sono fuori sede fino a lunedì 16 novembre e risponderò al mio rientro.';

  @override
  String get junkLevelNone => 'Nessun filtro automatico';

  @override
  String get junkLevelNoneInfo =>
      'La posta dei mittenti bloccati viene comunque spostata nella cartella della posta indesiderata.';

  @override
  String get junkLevelLow => 'Bassa';

  @override
  String get junkLevelLowInfo =>
      'Sposta la posta indesiderata più evidente: quella che il server ha segnato come spam.';

  @override
  String get junkLevelHigh => 'Alta';

  @override
  String get junkLevelHighInfo =>
      'Sposta anche le mail con un punteggio vicino alla soglia del server: può capitare anche a posta normale, controlla spesso la cartella della posta indesiderata.';

  @override
  String get junkLevelSafeOnly => 'Solo elenchi attendibili';

  @override
  String get junkLevelSafeOnlyInfo =>
      'Solo la posta di mittenti attendibili, o inviata a destinatari attendibili, resta in Posta in arrivo.';

  @override
  String get safeSenders => 'Mittenti attendibili';

  @override
  String get safeSendersInfo =>
      'La posta proveniente da questi indirizzi o domini non verrà mai considerata posta indesiderata.';

  @override
  String get safeRecipients => 'Destinatari attendibili';

  @override
  String get safeRecipientsInfo =>
      'La posta inviata a questi indirizzi o domini (per esempio una mailing list) non verrà mai considerata posta indesiderata.';

  @override
  String get blockedSenders => 'Mittenti bloccati';

  @override
  String get blockedSendersInfo =>
      'La posta proveniente da questi indirizzi o domini verrà sempre spostata nella cartella della posta indesiderata.';

  @override
  String get neverBlockSender => 'Non bloccare mai il mittente';

  @override
  String get neverBlockDomain => 'Non bloccare mai il dominio del mittente';

  @override
  String get neverBlockGroup => 'Non bloccare mai questo gruppo o mailing list';

  @override
  String get neverBlockGroups =>
      'Non bloccare mai questi gruppi o mailing list';

  @override
  String get blockSender => 'Blocca mittente';

  @override
  String get junkOptionsEllipsis => 'Opzioni posta indesiderata…';

  @override
  String get noJunkFolder => 'Nessuna cartella della posta indesiderata';

  @override
  String noJunkFolderContent(String name) {
    return 'L\'account «$name» non ha una cartella della posta indesiderata: sceglila in «Opzioni posta indesiderata». Il mittente non è stato bloccato.';
  }

  @override
  String get markAsNotJunk => 'Contrassegna come posta non indesiderata';

  @override
  String notJunkMoveBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'I $count messaggi verranno riportati nella cartella Posta in arrivo.',
      one: 'Il messaggio verrà riportato nella cartella Posta in arrivo.',
    );
    return '$_temp0';
  }

  @override
  String alwaysTrustSender(String sender) {
    return 'Considera sempre attendibile la posta proveniente da «$sender»';
  }

  @override
  String get alwaysTrustSenders =>
      'Considera sempre attendibile la posta proveniente da questi mittenti';

  @override
  String optionsNotRead(String error) {
    return 'Opzioni non lette: $error';
  }

  @override
  String optionsNotSaved(String error) {
    return 'Opzioni non salvate: $error';
  }

  @override
  String get invalidValue => 'valore non valido';

  @override
  String get junkOptions => 'Opzioni posta indesiderata';

  @override
  String get junkOptionsIntro =>
      'Le mail nuove della Posta in arrivo che sembrano posta indesiderata vengono spostate in una cartella speciale, mentre PostinoVip è aperto. Il giudizio è quello del server della posta. Scegli il livello di protezione:';

  @override
  String get junkFolder => 'Cartella della posta indesiderata';

  @override
  String junkFolderAutomatic(String folder) {
    return 'Automatica: «$folder»';
  }

  @override
  String get junkFolderAutomaticNone => 'Automatica (nessuna cartella trovata)';

  @override
  String get junkFolderInfo =>
      'Automatica: quella indicata dal server, o una con «spam», «junk» o «indesiderata» nel nome. Per una cartella nuova: scheda Cartella → Nuova cartella, poi sceglila qui.';

  @override
  String get junkNoFolderWarning =>
      'Senza una cartella il filtro non sposta nessuna mail.';

  @override
  String get noEntries => 'Nessuna voce';

  @override
  String get addEllipsis => 'Aggiungi…';

  @override
  String get trustContacts => 'Considera attendibili anche i miei contatti';

  @override
  String get junkEntryInvalid =>
      'Scrivi un indirizzo (anna@esempio.it) o un dominio (@esempio.it).';

  @override
  String get addAddressOrDomain => 'Aggiungi indirizzo o dominio';

  @override
  String get editAddressOrDomain => 'Modifica indirizzo o dominio';

  @override
  String get junkEntryLabel => 'Indirizzo di posta o nome di dominio Internet';

  @override
  String get junkEntryHint => 'es. anna@esempio.it oppure @esempio.it';

  @override
  String get alreadyInArchive =>
      'La mail è già nella cartella di archiviazione';

  @override
  String get archiveTooltip =>
      'Sposta nella cartella di archiviazione (Backspace)';

  @override
  String get mailsAlreadyInArchive =>
      'Le mail sono già nella cartella di archiviazione';

  @override
  String get archiveFolderName => 'Archivio';

  @override
  String get offlineUnavailable =>
      'Non disponibile senza connessione al server.';

  @override
  String archiveFirstTime(String name) {
    return 'L\'account «$name» non ha ancora una cartella di archiviazione. Sceglila: Archivia sposterà lì le mail, senza eliminarle.';
  }

  @override
  String archiveInfo(String name) {
    return 'Archivia sposta le mail di «$name» in questa cartella, senza eliminarle.';
  }

  @override
  String get useExistingFolder => 'Usa una cartella esistente';

  @override
  String get chooseAFolder => 'Scegli una cartella';

  @override
  String get createTopFolder => 'Crea una cartella nuova in cima all\'account';

  @override
  String get okAndArchive => 'OK e archivia';

  @override
  String get stopIgnore => 'Interrompi Ignora';

  @override
  String get ignore => 'Ignora';

  @override
  String get stopIgnoreTooltip =>
      'La conversazione torna in Posta in arrivo e le mail nuove non vanno più in Posta eliminata';

  @override
  String get ignoreTooltip =>
      'Sposta in Posta eliminata la conversazione e le mail che arriveranno';

  @override
  String cleanUpFolderContent(String name) {
    return 'Le mail superflue della cartella «$name» (quelle citate per intero da una risposta) verranno spostate in Posta eliminata. Le mail da leggere, contrassegnate, con categorie o firmate restano dove sono.';
  }

  @override
  String get stopIgnoreContent =>
      'La conversazione selezionata non verrà più ignorata e le sue mail in Posta eliminata verranno spostate in Posta in arrivo.';

  @override
  String get ignoreContent =>
      'Le mail della conversazione selezionata in questa cartella e tutte quelle che arriveranno verranno spostate in Posta eliminata.';

  @override
  String get dontShowAgain => 'Non visualizzare più questo messaggio';

  @override
  String get notifyAlways => 'Sempre';

  @override
  String get notifyUnfocused => 'Solo con la finestra non in primo piano';

  @override
  String get notifyNever => 'Mai';

  @override
  String get readImmediately => 'Subito all\'apertura';

  @override
  String get readAfterDelay => 'Dopo alcuni secondi di visualizzazione';

  @override
  String get readManual => 'Mai automaticamente (solo con il pulsante)';

  @override
  String get receiptAsk => 'Chiedi ogni volta';

  @override
  String get receiptAlways => 'Invia sempre una conferma di lettura';

  @override
  String get receiptNever => 'Non inviare mai una conferma di lettura';

  @override
  String get categoryRed => 'Categoria rossa';

  @override
  String get categoryOrange => 'Categoria arancione';

  @override
  String get categoryYellow => 'Categoria gialla';

  @override
  String get categoryGreen => 'Categoria verde';

  @override
  String get categoryBlue => 'Categoria blu';

  @override
  String get categoryPurple => 'Categoria viola';

  @override
  String get followUpTomorrow => 'Domani';

  @override
  String get followUpThisWeek => 'Questa settimana';

  @override
  String get followUpNextWeek => 'Settimana prossima';

  @override
  String get followUpNoDate => 'Nessuna data';

  @override
  String get clearAllCategories => 'Cancella tutte le categorie';

  @override
  String get allCategoriesEllipsis => 'Tutte le categorie…';

  @override
  String get customDateEllipsis => 'Data personalizzata…';

  @override
  String get markComplete => 'Contrassegna come completato';

  @override
  String get clearFlag => 'Cancella contrassegno';

  @override
  String get dueByTitle => 'Completare entro';

  @override
  String get categoriesTitle => 'Categorie';

  @override
  String get categoriesInfo =>
      'I nomi valgono solo su questo computer; sul server ogni categoria è salvata con il suo colore.';

  @override
  String get defaultNames => 'Nomi predefiniti';

  @override
  String aboutVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get aboutDescription =>
      'Client di posta desktop: interfaccia in Flutter, core in C# con MailKit.';

  @override
  String aboutLegal(String license) {
    return 'Questo programma è software libero: puoi ridistribuirlo e/o modificarlo secondo i termini della $license, pubblicata dalla Free Software Foundation.\n\nÈ distribuito nella speranza che sia utile, ma SENZA ALCUNA GARANZIA, nemmeno quella implicita di COMMERCIABILITÀ o di IDONEITÀ A UN PARTICOLARE SCOPO. Il testo completo della licenza è in \"Visualizza licenze\" → PostinoVip.';
  }

  @override
  String coreVersionUnavailable(String error) {
    return 'Core: versione non disponibile ($error)';
  }

  @override
  String coreVersion(String version) {
    return 'Core: versione $version';
  }

  @override
  String get coreVersionMismatch =>
      'Attenzione: app e core hanno versioni diverse (ricompilare il core).';

  @override
  String get composeMessages => 'Composizione messaggi';

  @override
  String get composeInFormat => 'Componi messaggi in questo formato';

  @override
  String get composeInFormatHelp =>
      'Per i messaggi nuovi; risposte e inoltri hanno il formato del messaggio originale';

  @override
  String get signaturesSection => 'Firme';

  @override
  String signatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count firme',
      one: '1 firma',
      zero: 'Nessuna firma',
    );
    return '$_temp0';
  }

  @override
  String get signaturesInfo =>
      'Aggiunte da sole ai nuovi messaggi e alle risposte, per account';

  @override
  String get markAsReadSection => 'Segna come letto';

  @override
  String get readReceiptsSection => 'Conferme di lettura';

  @override
  String get alwaysRequestReceipt =>
      'Chiedi sempre la conferma di lettura nei nuovi messaggi';

  @override
  String get receiptForReceived =>
      'Per i messaggi ricevuti che chiedono una conferma:';

  @override
  String get confirmBeforeIgnore =>
      'Chiedi conferma prima di Ignora conversazione';

  @override
  String get confirmBeforeStopIgnoring =>
      'Chiedi conferma prima di Interrompi Ignora conversazione';

  @override
  String get newMailNotifications => 'Notifiche di nuova posta';

  @override
  String get notificationsUnavailable =>
      'Notifiche di sistema non disponibili: il motivo è nel terminale (\"[notifiche]\").';

  @override
  String get testNotification => 'Prova notifica';

  @override
  String get testNotificationText =>
      'Notifica di prova: se la vedi, le notifiche funzionano.';

  @override
  String get firstDayOfWeek => 'Primo giorno della settimana';

  @override
  String get workDays => 'Giorni lavorativi (Settimana lavorativa)';

  @override
  String get workStart => 'Inizio orario lavorativo';

  @override
  String get workEnd => 'Fine orario lavorativo';

  @override
  String receiptNotSent(String error) {
    return 'Conferma di lettura non inviata: $error';
  }

  @override
  String receiptNotRecorded(String error) {
    return 'Conferma di lettura non registrata: $error';
  }

  @override
  String operationFailed(String error) {
    return 'Operazione non riuscita: $error';
  }

  @override
  String get outboxSending =>
      'Invio in corso: la mail parte appena il server risponde.';

  @override
  String get outboxDeleted =>
      'Mail eliminata dalla Posta in uscita: non verrà inviata.';

  @override
  String get outboxMovedToDrafts =>
      'Mail spostata in Bozze: aprila da lì per modificarla.';

  @override
  String folderNotListed(String folder) {
    return 'Il server ha confermato la cartella «$folder», ma non la mostra nell\'elenco delle cartelle.';
  }

  @override
  String get anotherOperation => 'Un\'altra operazione è in corso';

  @override
  String folderDeletedPermanently(String folder) {
    return 'Cartella \"$folder\" eliminata definitivamente';
  }

  @override
  String folderMovedToTrash(String folder) {
    return 'Cartella \"$folder\" spostata in Posta eliminata';
  }

  @override
  String folderNotDeleted(String error) {
    return 'Cartella non eliminata: $error';
  }

  @override
  String folderEmptied(String folder, String mails, String folders) {
    return '\"$folder\" svuotata: $mails$folders definitivamente';
  }

  @override
  String emptiedMails(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mail eliminate',
      one: '1 mail eliminata',
    );
    return '$_temp0';
  }

  @override
  String emptiedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' e $count cartelle',
      one: ' e 1 cartella',
    );
    return '$_temp0';
  }

  @override
  String folderNotEmptied(String error) {
    return 'Cartella non svuotata: $error';
  }

  @override
  String folderMovedToTop(String folder) {
    return 'Cartella \"$folder\" spostata in cima all\'account';
  }

  @override
  String folderMovedInto(String folder, String parent) {
    return 'Cartella \"$folder\" spostata in \"$parent\"';
  }

  @override
  String folderNotMoved(String error) {
    return 'Cartella non spostata: $error';
  }

  @override
  String get mailNotDownloadedOffline =>
      'Mail non disponibile senza connessione: non è ancora stata scaricata sul computer.';

  @override
  String readStateNotUpdated(String error) {
    return 'Stato letto/non letto non aggiornato: $error';
  }

  @override
  String tagsNotUpdated(String error) {
    return 'Contrassegno o categorie non aggiornati: $error';
  }

  @override
  String movedTo(String folder) {
    return 'Spostato in \"$folder\"';
  }

  @override
  String get deletedPermanently => 'Eliminato definitivamente';

  @override
  String markedRead(int count) {
    return '$count mail segnate come lette';
  }

  @override
  String markedUnread(int count) {
    return '$count mail segnate come da leggere';
  }

  @override
  String othersFailed(String text, String error) {
    return '$text; le altre no: $error';
  }

  @override
  String readNotUpdated(String error) {
    return 'Stato letto non aggiornato: $error';
  }

  @override
  String mailsMovedTo(int count, String folder) {
    return '$count mail spostate in \"$folder\"';
  }

  @override
  String mailsDeletedPermanently(int count) {
    return '$count mail eliminate definitivamente';
  }

  @override
  String mailsMovedToTrash(int count) {
    return '$count mail spostate in Posta eliminata';
  }

  @override
  String mailsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mail archiviate',
      one: '1 mail archiviata',
    );
    return '$_temp0';
  }

  @override
  String get conversationIgnored =>
      'Conversazione ignorata: le mail che arriveranno andranno in Posta eliminata';

  @override
  String conversationIgnoredMoved(int count) {
    return '$count mail spostate in Posta eliminata; anche quelle che arriveranno andranno lì';
  }

  @override
  String get conversationNotIgnored => 'La conversazione non è più ignorata';

  @override
  String mailsBackToInbox(int count) {
    return '$count mail riportate in Posta in arrivo';
  }

  @override
  String cleanUpDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mail superflue spostate in Posta eliminata',
      one: '1 mail superflua spostata in Posta eliminata',
      zero: 'Nessuna mail superflua da spostare',
    );
    return '$_temp0';
  }

  @override
  String get noMailMoved => 'Nessuna mail spostata';

  @override
  String mailsMovedToJunk(int count) {
    return '$count mail spostate nella posta indesiderata';
  }

  @override
  String senderBlocked(String sender) {
    return '$sender bloccato';
  }

  @override
  String sendersBlocked(int count, String senders) {
    return '$count mittenti bloccati ($senders)';
  }

  @override
  String senderTrusted(String sender) {
    return '$sender attendibile';
  }

  @override
  String sendersTrusted(int count, String senders) {
    return '$count mittenti attendibili ($senders)';
  }

  @override
  String addedToSafeSenders(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries aggiunti',
      one: '$entries aggiunto',
    );
    return '$_temp0 tra i mittenti attendibili';
  }

  @override
  String addedToSafeRecipients(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries aggiunti',
      one: '$entries aggiunto',
    );
    return '$_temp0 tra i destinatari attendibili';
  }

  @override
  String listsNotUpdated(String error) {
    return 'Elenchi non aggiornati: $error';
  }

  @override
  String mailsCopiedTo(int count, String folder) {
    return '$count mail copiate in \"$folder\"';
  }

  @override
  String mailsNotCopied(String error) {
    return 'Mail non copiate: $error';
  }

  @override
  String get fmtTime => 'HH:mm';

  @override
  String get fmtDayMonth => 'dd/MM';

  @override
  String get fmtDate => 'dd/MM/yyyy';

  @override
  String get fmtWeekdayDate => 'EEE dd/MM/yyyy';

  @override
  String get fmtWeekdayDateTime => 'EEE dd/MM/yyyy HH:mm';

  @override
  String get fmtWeekdayTime => 'EEE HH:mm';

  @override
  String get fmtLongDateTime => 'EEEE d MMMM y HH:mm';

  @override
  String get groupNoDate => 'Senza data';

  @override
  String get groupYesterday => 'Ieri';

  @override
  String get groupLastWeek => 'Settimana scorsa';

  @override
  String get groupTwoWeeksAgo => 'Due settimane fa';

  @override
  String get groupThreeWeeksAgo => 'Tre settimane fa';

  @override
  String get groupEarlierThisMonth => 'Prima in questo mese';

  @override
  String get groupLastMonth => 'Mese scorso';

  @override
  String get groupOlder => 'Più vecchi';

  @override
  String get sizeTiny => 'Minuscola (meno di 10 KB)';

  @override
  String get sizeSmall => 'Piccola (10–25 KB)';

  @override
  String get sizeMedium => 'Media (25–100 KB)';

  @override
  String get sizeLarge => 'Grande (100–500 KB)';

  @override
  String get sizeVeryLarge => 'Molto grande (500 KB–1 MB)';

  @override
  String get sizeHuge => 'Enorme (1–5 MB)';

  @override
  String get sizeEnormous => 'Gigantesca (oltre 5 MB)';

  @override
  String sizeBytes(int count) {
    return '$count byte';
  }

  @override
  String get fmtMonthYear => 'MMMM y';

  @override
  String get fmtFullDate => 'EEEE d MMMM y';

  @override
  String get fmtHour => 'HH:mm';

  @override
  String get fmtRangeSameMonthStart => 'd';

  @override
  String get fmtRangeSameMonthEnd => 'd MMMM y';

  @override
  String get fmtRangeOtherMonthStart => 'd MMMM';

  @override
  String get fmtRangeOtherMonthEnd => 'd MMMM y';

  @override
  String get fmtRangeOtherYearStart => 'd MMMM y';

  @override
  String get fmtRangeOtherYearEnd => 'd MMMM y';

  @override
  String get recurOrdinalFirst => 'il primo';

  @override
  String get recurOrdinalSecond => 'il secondo';

  @override
  String get recurOrdinalThird => 'il terzo';

  @override
  String get recurOrdinalFourth => 'il quarto';

  @override
  String get recurOrdinalLast => 'l\'ultimo';

  @override
  String recurDescDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ogni $count giorni',
      one: 'Ogni giorno',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ogni $count settimane',
      one: 'Ogni settimana',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeeklyOn(String every, String days) {
    return '$every il $days';
  }

  @override
  String recurDescMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ogni $count mesi',
      one: 'Ogni mese',
    );
    return '$_temp0';
  }

  @override
  String recurDescMonthlyDay(String every, int day) {
    return '$every il giorno $day';
  }

  @override
  String recurDescMonthlyWhich(String every, String which) {
    return '$every $which';
  }

  @override
  String recurDescYearlyWhich(String which, String month) {
    return 'Ogni anno $which di $month';
  }

  @override
  String recurDescYearlyDay(String day, String month) {
    return 'Ogni anno il $day $month';
  }

  @override
  String get recurDescRecurring => 'Ricorrente';

  @override
  String recurDescTimes(int count) {
    return ', $count volte';
  }

  @override
  String recurDescUntil(String date) {
    return ', fino al $date';
  }

  @override
  String whenAllDay(String date) {
    return '$date (giornata intera)';
  }

  @override
  String whenAllDayRange(String start, String end) {
    return 'Da $start a $end (giornata intera)';
  }

  @override
  String get coreKindInvalidRequest => 'Richiesta non valida';

  @override
  String get coreKindNotFound => 'Non trovato';

  @override
  String get coreKindOffline => 'Non connesso';

  @override
  String get coreKindServer => 'Errore del server mail';

  @override
  String get coreKindConflict => 'Operazione non consentita';

  @override
  String get coreKindNotSupported => 'Non supportato dal server';

  @override
  String get coreKindCertificate => 'Certificato del server non valido';

  @override
  String get coreKindOAuth => 'Accesso all\'account non riuscito';

  @override
  String get coreKindAuth => 'Autenticazione con il server mail fallita';

  @override
  String get coreKindConfig => 'Configurazione non valida';

  @override
  String get coreKindInternal => 'Errore interno';

  @override
  String certNameMismatch(String host) {
    return 'intestato a un nome diverso da $host';
  }

  @override
  String get certUntrustedRoot =>
      'non firmato da un\'autorità riconosciuta (es. autofirmato)';

  @override
  String get certNotTimeValid => 'scaduto o non ancora valido';

  @override
  String get certRevoked => 'revocato';

  @override
  String get certChainInvalid => 'catena di certificazione non valida';

  @override
  String get certNoCertificate => 'nessun certificato';

  @override
  String get coreTimeout =>
      'Il server non risponde: l\'operazione potrebbe non essere stata eseguita.';

  @override
  String get coreAuthCheckCredentials => 'Controllare username e password.';

  @override
  String get coreInternalUnexpected =>
      'Errore imprevisto, vedere il log del core.';

  @override
  String coreCertificateChanged(String address, String problems) {
    return 'Certificato non valido per $address ($problems). Aprire l\'account in Impostazioni e ripetere \"Verifica connessione\".';
  }

  @override
  String coreTestCertificateInvalid(String address, String problems) {
    return 'Il certificato del server $address non è valido: $problems.';
  }

  @override
  String coreTestNoStartTls(String address) {
    return 'Il server $address non offre STARTTLS: scegliere un\'altra crittografia o un\'altra porta.';
  }

  @override
  String get coreTestAuthRejected =>
      'Autenticazione rifiutata: controllare indirizzo e password.';

  @override
  String coreTestTlsFailed(String address) {
    return 'Connessione cifrata non riuscita con $address: la porta usa davvero questa crittografia?';
  }

  @override
  String coreTestUnreachable(String address) {
    return 'Server $address non raggiungibile.';
  }

  @override
  String coreTestNoAnswer(String address, String seconds) {
    return 'Nessuna risposta da $address entro $seconds s: server, porta o crittografia errati?';
  }

  @override
  String coreTestUnexpectedAnswer(String address) {
    return 'Risposta inattesa da $address: porta o protocollo errati?';
  }

  @override
  String corePop3NoUidl(String address) {
    return 'Il server POP3 $address non supporta UIDL: necessario per non scaricare due volte le mail.';
  }

  @override
  String coreOAuthServerUnreachable(String provider) {
    return 'Server di accesso di $provider non raggiungibile.';
  }

  @override
  String coreOAuthInvalidResponse(String provider, String status) {
    return 'Risposta non valida dal server di accesso di $provider (HTTP $status).';
  }

  @override
  String coreOAuthExpired(String provider) {
    return 'Accesso a $provider scaduto o revocato: rifai «Accedi con $provider».';
  }

  @override
  String coreOAuthClientInvalid(String provider) {
    return 'PostinoVip non è registrato correttamente presso $provider (client ID).';
  }

  @override
  String coreOAuthFailed(String provider, String error) {
    return 'Accesso a $provider non riuscito ($error).';
  }

  @override
  String get coreOAuthCancelled => 'Accesso annullato.';

  @override
  String get coreOAuthNoCode => 'Accesso non riuscito (nessun codice).';

  @override
  String coreOAuthFlowFailed(String error) {
    return 'Accesso non riuscito ($error).';
  }

  @override
  String get coreOAuthNoRefreshToken =>
      'Il fornitore non ha dato un token di rinnovo (manca offline_access?).';

  @override
  String coreServerUnreachable(String reason) {
    return 'Server non raggiungibile ($reason).';
  }

  @override
  String corePop3NoAnswer(String address) {
    return 'Server POP3 $address non raggiungibile (nessuna risposta).';
  }

  @override
  String corePop3Unreachable(String address, String reason) {
    return 'Server POP3 $address non raggiungibile ($reason).';
  }

  @override
  String coreSmtpNoAnswer(String seconds) {
    return 'Server di invio non raggiungibile (nessuna risposta in $seconds s): mail non inviata.';
  }

  @override
  String coreSmtpUnreachable(String reason) {
    return 'Server di invio non raggiungibile ($reason): mail non inviata.';
  }

  @override
  String get coreContactsServerUnreachable =>
      'Server dei contatti non raggiungibile.';

  @override
  String get coreCalendarServerUnreachable =>
      'Server del calendario non raggiungibile.';

  @override
  String get coreContactsServerNoAnswer =>
      'Il server dei contatti non risponde.';

  @override
  String get coreCalendarServerNoAnswer =>
      'Il server del calendario non risponde.';

  @override
  String coreDavSignInRejectedContacts(String provider) {
    return '$provider ha rifiutato l\'accesso al server dei contatti: rifai «Accedi con $provider» permettendo l\'accesso ai contatti.';
  }

  @override
  String coreDavSignInRejectedCalendar(String provider) {
    return '$provider ha rifiutato l\'accesso al server del calendario: rifai «Accedi con $provider» permettendo l\'accesso al calendario.';
  }

  @override
  String coreDavScopeMissingContacts(String provider) {
    return 'L\'accesso con $provider non comprende il permesso dei contatti: rifai «Accedi con $provider».';
  }

  @override
  String coreDavScopeMissingCalendar(String provider) {
    return 'L\'accesso con $provider non comprende il permesso del calendario: rifai «Accedi con $provider».';
  }

  @override
  String coreAccountScopeMissingContacts(String provider) {
    return 'L\'accesso con $provider non comprende i contatti: nella schermata dell\'account usa «Accedi di nuovo» e permetti l\'accesso ai contatti.';
  }

  @override
  String coreAccountScopeMissingCalendar(String provider) {
    return 'L\'accesso con $provider non comprende il calendario: nella schermata dell\'account usa «Accedi di nuovo» e permetti l\'accesso al calendario.';
  }

  @override
  String get coreNotConnected => 'non connesso';

  @override
  String coreUnreachableApp(String address, String error) {
    return 'Core PostinoVip non raggiungibile su $address: $error';
  }

  @override
  String get coreUnexpectedResponse => 'Risposta inattesa dal core';

  @override
  String get coreUnexpectedResponseVersions =>
      'Risposta inattesa dal core (versioni diverse di app e core?)';

  @override
  String get coreEventsUnavailable => 'Eventi non disponibili';

  @override
  String coreUnexpectedFormat(String path, String error) {
    return 'Risposta del core in formato inatteso ($path): $error. Il core è aggiornato e riavviato?';
  }

  @override
  String get imagePlaceholder => 'immagine';

  @override
  String get coreErrScrivereIlNomeDellaCartella =>
      'Scrivere il nome della cartella.';

  @override
  String coreErrIlNomePuoAvereAl(String maxLength) {
    return 'Il nome può avere al massimo $maxLength caratteri.';
  }

  @override
  String get coreErrIlNomeContieneCaratteriNon =>
      'Il nome contiene caratteri non validi.';

  @override
  String coreErrIlNomeNonPuoContenere(String separator) {
    return 'Il nome non può contenere il carattere \"$separator\".';
  }

  @override
  String get coreErrInboxIlNomeRiservatoDella =>
      '\"INBOX\" è il nome riservato della Posta in arrivo.';

  @override
  String get coreErrIlMessaggioOriginaleDisponibileSolo =>
      'Il messaggio originale è disponibile solo con la copia locale.';

  @override
  String get coreErrCartellaNonValida => 'Cartella non valida.';

  @override
  String get coreErrLaMailNonChiedeUna =>
      'La mail non chiede una conferma di lettura a questo indirizzo.';

  @override
  String get coreErrLivelloDelFiltroNonValido =>
      'Livello del filtro non valido.';

  @override
  String get coreErrNessunaCartellaDellaPostaIndesiderata =>
      'Nessuna cartella della posta indesiderata: sceglierla in «Opzioni posta indesiderata».';

  @override
  String get coreErrNessunMittenteDaBloccareLe =>
      'Nessun mittente da bloccare (le mail sono state inviate da questo account o non hanno mittente).';

  @override
  String get coreErrNonPostaIndesiderataValeSolo =>
      '«Non è posta indesiderata» vale solo per le mail della cartella della posta indesiderata.';

  @override
  String coreErrNessunaDelleMailIndicateIn(String folder) {
    return 'Nessuna delle mail indicate è in \'$folder\'.';
  }

  @override
  String get coreErrIlServerPop3NonSupporta =>
      'Il server POP3 non supporta UIDL: senza, non si può sapere quali mail sono già state scaricate.';

  @override
  String get coreErrIdNonValido => 'Id non valido.';

  @override
  String get coreErrHostSmtpNonConfigurato => 'Host SMTP non configurato.';

  @override
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2) {
    return 'Allegati troppo grandi: $value MB, massimo $value2 MB.';
  }

  @override
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel) {
    return 'Il $serverLabel ha rifiutato la richiesta (403).';
  }

  @override
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  ) {
    return 'Indirizzo del $value non ammesso: serve https ($scheme://$host).';
  }

  @override
  String get coreErrNessunCalendarioTrovatoSulServer =>
      'Nessun calendario trovato sul server del calendario.';

  @override
  String get coreErrNessunaRubricaTrovataSulServer =>
      'Nessuna rubrica trovata sul server dei contatti.';

  @override
  String coreErrIlHaCreatoElementoSenza(String serverLabel) {
    return 'Il $serverLabel ha creato l\'elemento senza dire dove (manca Location).';
  }

  @override
  String coreErrIlHaCreatoElementoFuori(String serverLabel) {
    return 'Il $serverLabel ha creato l\'elemento fuori dalla raccolta.';
  }

  @override
  String coreErrTroppiReindirizzamentiDal(String serverLabel) {
    return 'Troppi reindirizzamenti dal $serverLabel.';
  }

  @override
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel) {
    return 'Il $serverLabel ha rifiutato nome utente o password.';
  }

  @override
  String coreErrCertificatoDelNonValido(String serverLabel) {
    return 'Certificato del $serverLabel non valido.';
  }

  @override
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  ) {
    return 'Il $serverLabel ha risposto $code $reasonPhrase.';
  }

  @override
  String coreErrRispostaDelNonLeggibile(String serverLabel) {
    return 'Risposta del $serverLabel non leggibile.';
  }

  @override
  String get coreErrIlFileNonUnaMail =>
      'Il file non è una mail (.eml) leggibile.';

  @override
  String get coreErrIlFileNonUnaMail2 =>
      'Il file non è una mail (.eml): mancano mittente, data, oggetto e destinatari.';

  @override
  String get coreErrIlFileEmlNonPiu =>
      'Il file .eml non è più aperto: riaprirlo.';

  @override
  String coreErrAccountNonTrovato(String id) {
    return 'Account \'$id\' non trovato.';
  }

  @override
  String coreErrAccountUnAccountPop3Richiede(String id) {
    return 'Account \'$id\': un account POP3 richiede la copia locale (Cache:Enabled=false non è possibile).';
  }

  @override
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider) {
    return 'Account \'$id\': fornitore OAuth \'$provider\' sconosciuto.';
  }

  @override
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  ) {
    return 'Account \'$id\': manca il client ID di $displayName (sezione OAuth:$id2).';
  }

  @override
  String get coreErrNessunAccountConfigurato => 'Nessun account configurato.';

  @override
  String coreErrIdAccountNonValidoAmmessi(String id) {
    return 'Id account non valido: \'$id\' (ammessi lettere, cifre, \'-\' e \'_\', massimo 64).';
  }

  @override
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths) {
    return 'Account \'$id\': limite della cache non valido ($bodyMonths mesi; 0 = tutte).';
  }

  @override
  String coreErrAccountIndirizzoNonValido(String id, String name) {
    return 'Account \'$id\': indirizzo $name non valido.';
  }

  @override
  String coreErrAccount(String id, String message) {
    return 'Account \'$id\': $message';
  }

  @override
  String coreErrIdAccountRipetuto(String key) {
    return 'Id account ripetuto: \'$key\'.';
  }

  @override
  String coreErrCartellaNonTrovata(String fullName) {
    return 'Cartella \'$fullName\' non trovata.';
  }

  @override
  String coreErrLaCartellaEsisteGia(String fullName) {
    return 'La cartella \'$fullName\' esiste già.';
  }

  @override
  String coreErrCartellaNonTrovata2(String parent) {
    return 'Cartella \'$parent\' non trovata.';
  }

  @override
  String coreErrCartellaNonTrovata3(String folder) {
    return 'Cartella \'$folder\' non trovata.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn(String uid, String folder) {
    return 'Messaggio $uid non trovato in \'$folder\'.';
  }

  @override
  String coreErrLaCartellaEsisteGia2(String newFullName) {
    return 'La cartella \'$newFullName\' esiste già.';
  }

  @override
  String get coreErrCartellaNonIndicata => 'Cartella non indicata.';

  @override
  String coreErrCartellaNonValida2(String fullName) {
    return 'Cartella \'$fullName\' non valida.';
  }

  @override
  String coreErrCartellaAssenteDallIndiceDopo(String folder) {
    return 'Cartella \'$folder\' assente dall\'indice dopo la sincronizzazione.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid) {
    return 'Allegato $index non trovato nel messaggio $uid.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid) {
    return 'Allegato $i non trovato nel messaggio $uid.';
  }

  @override
  String get coreErrCartellaDiOrigineDestinazioneCoincidono =>
      'Cartella di origine e destinazione coincidono.';

  @override
  String get coreErrIlMessaggioGiaInPosta =>
      'Il messaggio è già in Posta eliminata: usare l\'eliminazione definitiva.';

  @override
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn =>
      'L\'eliminazione definitiva è consentita solo in Posta eliminata.';

  @override
  String coreErrNonPuoAndareDentroSe(String folder) {
    return '\'$folder\' non può andare dentro sé stessa o una sua sottocartella.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special) {
    return '\'$folder\' contiene la cartella speciale \'$special\': non si svuota.';
  }

  @override
  String coreErrNessunaCartellaLocaleConRuolo(String role) {
    return 'Nessuna cartella locale con ruolo $role.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName) {
    return 'Messaggio $uid non trovato in \'$fullName\'.';
  }

  @override
  String coreErrNessunaRispostaIn(String totalSeconds) {
    return 'nessuna risposta in $totalSeconds s';
  }

  @override
  String get coreErrHostImapNonConfigurato => 'Host IMAP non configurato.';

  @override
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName) {
    return 'Messaggio $uid non trovato in \'$folderName\'.';
  }

  @override
  String coreErrIlServerNonPermetteDi(String value, String folderName) {
    return 'Il server non permette di salvare le parole chiave $value in \'$folderName\'.';
  }

  @override
  String get coreErrIlServerNonDichiaraUna =>
      'Il server non dichiara una cartella \\Sent (Posta inviata): copia non salvata.';

  @override
  String get coreErrIlServerNonDichiaraUna2 =>
      'Il server non dichiara una cartella \\Drafts (Bozze): bozza non salvata.';

  @override
  String get coreErrIlServerNonDichiaraUna3 =>
      'Il server non dichiara una cartella \\Drafts (Bozze).';

  @override
  String get coreErrIlServerNonDichiaraUna4 =>
      'Il server non dichiara una cartella \\Trash (Posta eliminata).';

  @override
  String get coreErrIlServerNonSupportaMove =>
      'Il server non supporta MOVE né UIDPLUS: operazione rifiutata per non cancellare altri messaggi.';

  @override
  String coreErrLaCartellaNonPuoContenere(String fullName) {
    return 'La cartella \'$fullName\' non può contenere sottocartelle.';
  }

  @override
  String coreErrIlServerNonHaCreato(String clean) {
    return 'Il server non ha creato la cartella \'$clean\'.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  ) {
    return '\'$fullName\' contiene la cartella speciale \'$fullName2\': non si svuota.';
  }

  @override
  String coreErrNonPuoAndareDentroSe2(String fullName) {
    return '\'$fullName\' non può andare dentro sé stessa o una sua sottocartella.';
  }

  @override
  String coreErrUnaCartellaSpecialeNonSi(String fullName) {
    return '\'$fullName\' è una cartella speciale: non si può rinominare, spostare né eliminare.';
  }

  @override
  String coreErrCartellaNonTrovata4(String folderName) {
    return 'Cartella \'$folderName\' non trovata.';
  }

  @override
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  ) {
    return 'struttura (BODYSTRUCTURE) illeggibile in un gruppo di $count mail di $fullName: saltate, la mail difettosa sarà cercata in background ($message)';
  }

  @override
  String get coreErrFiltroDaLeggereOrdineDal =>
      'Filtro \"Da leggere\" e ordine dal più vecchio richiedono la cache locale (Cache:Enabled=false).';

  @override
  String get coreErrLeConversazioniRichiedonoLaCache =>
      'Le conversazioni richiedono la cache locale (Cache:Enabled=false).';

  @override
  String get coreErrLaRicercaRichiedeLaCache =>
      'La ricerca richiede la cache locale (Cache:Enabled=false).';

  @override
  String coreErrCorpoAppenaSalvatoNonRileggibile(
    String folderName,
    String uid,
  ) {
    return 'Corpo $folderName/$uid appena salvato e non rileggibile.';
  }

  @override
  String coreErrCartellaAssenteDallaCacheDopo(String fullName) {
    return 'Cartella \'$fullName\' assente dalla cache dopo la sincronizzazione.';
  }

  @override
  String get coreErrImprontaSha256NonValida => 'Impronta SHA-256 non valida.';

  @override
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id) {
    return 'L\'account \'$id\' è ancora configurato: per svuotarne la cache usare \"Ricostruisci cache\".';
  }

  @override
  String coreErrNessunDatoLocalePerAccount(String id) {
    return 'Nessun dato locale per l\'account \'$id\'.';
  }

  @override
  String get coreErrIgnoraPulisciRichiedonoLaCopia =>
      'Ignora e Pulisci richiedono la copia locale (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaPostaEliminataIn =>
      'Nessuna cartella Posta eliminata in questo account.';

  @override
  String get coreErrLaConversazioneNonIgnorata =>
      'La conversazione non è ignorata.';

  @override
  String get coreErrPulisciNonValePerPosta =>
      'Pulisci non vale per Posta eliminata e per la posta indesiderata.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia =>
      'Le regole richiedono la copia locale.';

  @override
  String coreErrAlMassimoRegolePerAccount(String maxRules) {
    return 'Al massimo $maxRules regole per account.';
  }

  @override
  String get coreErrOgniRegolaDeveAvereUn => 'Ogni regola deve avere un nome.';

  @override
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength) {
    return '«$name…»: il nome può avere al massimo $maxNameLength caratteri.';
  }

  @override
  String coreErrEliminaSpostaInsiemeNonHanno(String name) {
    return '«$name»: «Elimina» e «Sposta» insieme non hanno senso, sceglierne uno.';
  }

  @override
  String coreErrCategoriaNonValida(String name) {
    return '«$name»: categoria non valida.';
  }

  @override
  String coreErrDimensioneNonValida(String rule) {
    return '«$rule»: dimensione non valida.';
  }

  @override
  String coreErrTroppeParoleParoleTroppoLunghe(String rule) {
    return '«$rule»: troppe parole o parole troppo lunghe.';
  }

  @override
  String get coreErrScrivereIlMessaggioDellaRisposta =>
      'Scrivere il messaggio della risposta automatica.';

  @override
  String get coreErrLaFineDeveVenireDopo =>
      'La fine deve venire dopo l\'inizio.';

  @override
  String get coreErrIlMessaggioTroppoLungo => 'Il messaggio è troppo lungo.';

  @override
  String get coreErrContattoNonTrovato => 'Contatto non trovato.';

  @override
  String coreErrLaRubricaHaGiaContatti(String maxContacts) {
    return 'La rubrica ha già $maxContacts contatti.';
  }

  @override
  String get coreErrFormatoNonRiconosciutoUsareVcf =>
      'Formato non riconosciuto: usare vcf o csv.';

  @override
  String coreErrIndirizzoNonValido(String address) {
    return 'Indirizzo non valido: $address';
  }

  @override
  String get coreErrScrivereAlmenoUnNomeLa =>
      'Scrivere almeno un nome, la società o un indirizzo.';

  @override
  String get coreErrCalendarioNonTrovato => 'Calendario non trovato.';

  @override
  String get coreErrAppuntamentoNonValido => 'Appuntamento non valido.';

  @override
  String get coreErrAppuntamentoNonTrovato => 'Appuntamento non trovato.';

  @override
  String get coreErrEsisteGiaUnAppuntamentoCon =>
      'Esiste già un appuntamento con lo stesso UID.';

  @override
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems) {
    return 'Il calendario ha già $maxItems appuntamenti.';
  }

  @override
  String coreErrPeriodoNonValidoAlMassimo(String maxDays) {
    return 'Periodo non valido: al massimo $maxDays giorni, con la fine dopo l\'inizio.';
  }

  @override
  String get coreErrAppuntamentoNonLeggibile => 'Appuntamento non leggibile.';

  @override
  String get coreErrOccorrenzaNonValida => 'Occorrenza non valida.';

  @override
  String get coreErrSerieNonTrovata => 'Serie non trovata.';

  @override
  String get coreErrAppuntamentoNonRicorrenteSiModifica =>
      'L\'appuntamento non è ricorrente: si modifica tutto.';

  @override
  String get coreErrAlMassimo20000Caratteri => 'Al massimo 20000 caratteri.';

  @override
  String get coreErrPromemoriaNonValidoDaMinuti =>
      'Promemoria non valido (da 0 minuti a 4 settimane prima).';

  @override
  String get coreErrLaFinePrimaDellInizio => 'La fine è prima dell\'inizio.';

  @override
  String get coreErrSerializzazioneNonRiuscita =>
      'Serializzazione non riuscita.';

  @override
  String coreErrMancaIlClientIdDi(String displayName, String id) {
    return 'Manca il client ID di $displayName: va registrata l\'app e scritto in oauth-clients.json (sezione OAuth:$id).';
  }

  @override
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName) {
    return 'La sincronizzazione dei contatti non è disponibile con $displayName.';
  }

  @override
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName) {
    return 'La sincronizzazione del calendario non è disponibile con $displayName.';
  }

  @override
  String coreErrAllegatoNonTrovato(String i) {
    return 'Allegato $i non trovato.';
  }

  @override
  String get coreErrIndicareLaCartellaDelMessaggio =>
      'Indicare la cartella del messaggio originale.';

  @override
  String coreErrModalitaNonValidaReplyReplyall(String mode) {
    return 'Modalità non valida: $mode (reply, replyAll, forward).';
  }

  @override
  String coreErrMancantePiuCortoDiCaratteri(
    String configKey,
    String minLength,
  ) {
    return '$configKey mancante o più corto di $minLength caratteri.';
  }

  @override
  String get coreErrCartellaDeiDatiDellUtente =>
      'Cartella dei dati dell\'utente non determinabile (HOME non impostata?): usare Cache:Directory.';

  @override
  String get coreErrIndicareAlmenoUnaMail => 'Indicare almeno una mail.';

  @override
  String coreErrAlMassimoMailPerVolta(String maxBatch) {
    return 'Al massimo $maxBatch mail per volta.';
  }

  @override
  String coreErrAllegatoNonTrovato2(String index) {
    return 'Allegato $index non trovato.';
  }

  @override
  String get coreErrUnaCategoriaNonPuoEssere =>
      'Una categoria non può essere aggiunta e tolta insieme.';

  @override
  String get coreErrIndicareLaCartellaDiDestinazione =>
      'Indicare la cartella di destinazione.';

  @override
  String get coreErrLaScadenzaValeSoloCon =>
      'La scadenza vale solo con followUp \"flagged\".';

  @override
  String get coreErrLeRisposteAutomaticheRichiedonoLa =>
      'Le risposte automatiche richiedono la copia locale.';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa =>
      'La posta indesiderata richiede la copia locale (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa2 =>
      'La posta indesiderata richiede la copia locale.';

  @override
  String get coreErrLaCartellaSceltaNonEsiste =>
      'La cartella scelta non esiste.';

  @override
  String get coreErrScegliereUnaCartellaDiversaDa =>
      'Scegliere una cartella diversa da Posta in arrivo, Posta inviata, Bozze e Posta eliminata.';

  @override
  String get coreErrLaCartellaDiArchiviazioneSceglierne =>
      'È la cartella di archiviazione: sceglierne un\'altra.';

  @override
  String coreErrCartellaNonTrovata5(String name) {
    return 'Cartella \'$name\' non trovata.';
  }

  @override
  String get coreErrArchiviaRichiedeLaCopiaLocale =>
      'Archivia richiede la copia locale (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla =>
      'Nessuna cartella di archiviazione: sceglierla con «Imposta cartella di archiviazione».';

  @override
  String get coreErrLeMailSonoGiaNella =>
      'Le mail sono già nella cartella di archiviazione.';

  @override
  String get coreErrContattiRichiedonoLaCopiaLocale =>
      'I contatti richiedono la copia locale (Cache:Enabled=false).';

  @override
  String get coreErrContenutoDelFileNonValido =>
      'Contenuto del file non valido.';

  @override
  String get coreErrFileTroppoGrandeAlMassimo =>
      'File troppo grande (al massimo 10 MB).';

  @override
  String get coreErrLaSincronizzazioneDeiContattiNon2 =>
      'La sincronizzazione dei contatti non è attiva per questo account.';

  @override
  String get coreErrDa50 => 'Da 1 a 50.';

  @override
  String get coreErrIndirizzoMancante => 'Indirizzo mancante.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia2 =>
      'Le regole richiedono la copia locale (Cache:Enabled=false).';

  @override
  String get coreErrScegliereAlmenoUnaRegolaSalvata =>
      'Scegliere almeno una regola salvata.';

  @override
  String get coreErrAccountPop3LeMailSono =>
      'Account POP3: le mail sono solo sul computer, non c\'è una copia da ricostruire dal server.';

  @override
  String get coreErrCalendariRichiedonoLaCopiaLocale =>
      'I calendari richiedono la copia locale (Cache:Enabled=false).';

  @override
  String coreErrIlCalendarioDiSolaLettura(String name) {
    return 'Il calendario «$name» è di sola lettura: non si possono creare, modificare o eliminare appuntamenti.';
  }

  @override
  String get coreErrLaSincronizzazioneDelCalendarioNon2 =>
      'La sincronizzazione del calendario non è attiva per questo account.';

  @override
  String get coreErrRitardaRecapitoRichiedeLaCache =>
      'Ritarda recapito richiede la cache locale (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaInUscitaRichiede =>
      'La Posta in uscita richiede la cache locale (Cache:Enabled=false).';

  @override
  String get coreErrMailNonTrovataNellaPosta =>
      'Mail non trovata nella Posta in uscita.';

  @override
  String get coreErrNessunaConfermaDiLetturaPer =>
      'Nessuna conferma di lettura per le mail di Posta indesiderata, Posta inviata e Bozze.';

  @override
  String get coreErrAllaRichiestaDiConfermaDi =>
      'Alla richiesta di conferma di lettura si è già risposto.';

  @override
  String get coreErrLaMailNonChiedeUna2 =>
      'La mail non chiede una conferma di lettura al suo mittente.';

  @override
  String get davContactsServerLabel => 'server dei contatti';

  @override
  String get davCalendarServerLabel => 'server del calendario';

  @override
  String get printPreviewOpened =>
      'Aperta l\'anteprima nel visualizzatore PDF: stampa da lì.';

  @override
  String printNoPdfViewer(String path) {
    return 'Nessun programma per aprire i PDF. File in $path';
  }

  @override
  String printNotPrepared(String message, String path) {
    return 'Stampa non preparata: $message ($path)';
  }

  @override
  String get defaultMessageFileName => 'messaggio';

  @override
  String get preparingPdf => 'Preparazione del PDF…';

  @override
  String pdfNotCreated(String error) {
    return 'PDF non creato: $error';
  }

  @override
  String get printFrom => 'Da:';

  @override
  String get printSent => 'Inviato:';

  @override
  String get printTo => 'A:';

  @override
  String get printCc => 'Cc:';

  @override
  String get printSubject => 'Oggetto:';

  @override
  String get printImportance => 'Priorità:';

  @override
  String get printHigh => 'Alta';

  @override
  String get printLow => 'Bassa';

  @override
  String get printAttachments => 'Allegati:';

  @override
  String get defaultAttachmentFileName => 'allegato';

  @override
  String get coreExecutableNotFound =>
      'Eseguibile del core non trovato. Compilarlo con \"cd core && dotnet build\" oppure indicarne il percorso in POSTINOVIP_CORE.';

  @override
  String coreCannotStart(String path, String error) {
    return 'Impossibile avviare il core ($path): $error';
  }

  @override
  String coreExitedAtStart(String code) {
    return 'Il core è terminato durante l\'avvio (codice $code).';
  }

  @override
  String coreNoAnswerAtStart(String seconds) {
    return 'Il core non ha risposto entro $seconds s.';
  }

  @override
  String coreNotAnsweringCorrectly(String error) {
    return 'Il core non risponde correttamente: $error';
  }

  @override
  String get startingCore => 'Avvio del core…';

  @override
  String get coreLastLines => 'Ultime righe del core:';
}
