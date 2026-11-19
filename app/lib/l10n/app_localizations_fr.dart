// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String statusItems(int count) {
    return 'Éléments : $count';
  }

  @override
  String statusUnread(int count) {
    return 'Non lus : $count';
  }

  @override
  String statusResults(int count) {
    return 'Résultats : $count';
  }

  @override
  String statusContacts(int count) {
    return 'Contacts : $count';
  }

  @override
  String statusFound(int count) {
    return 'Trouvés : $count';
  }

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusDisconnected => 'Déconnecté';

  @override
  String statusDisconnectedAccounts(String accounts) {
    return 'Déconnecté : $accounts';
  }

  @override
  String get optionsTitle => 'Options';

  @override
  String get optionsClose => 'Fermer';

  @override
  String get optionsPageGeneral => 'Général';

  @override
  String get optionsPageMail => 'Courrier';

  @override
  String get optionsPageNotifications => 'Notifications';

  @override
  String get optionsPageCalendar => 'Calendrier';

  @override
  String get optionsAccountSection => 'Comptes';

  @override
  String get optionsAccountNotConfigured => '(non configuré)';

  @override
  String get optionsAccountFromUserSecrets =>
      'Données de user-secrets (développement)';

  @override
  String optionsAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comptes',
      one: '1 compte',
    );
    return '$_temp0';
  }

  @override
  String get optionsAccountManage => 'Gérer…';

  @override
  String get optionsLookSection => 'Apparence';

  @override
  String get optionsTheme => 'Thème';

  @override
  String get optionsThemeHelper =>
      'Le texte des messages reste sur fond blanc, même avec les thèmes sombres';

  @override
  String get themeSystem => 'Utiliser le paramètre système';

  @override
  String get themeColorful => 'Multicolore';

  @override
  String get themeWhite => 'Blanc';

  @override
  String get themeDarkGray => 'Gris foncé';

  @override
  String get themeBlack => 'Noir';

  @override
  String get optionsModuleBar =>
      'Barre de navigation (Courrier, Calendrier, Contacts)';

  @override
  String get moduleBarLeft => 'À gauche';

  @override
  String get moduleBarBottom => 'En bas du volet des dossiers';

  @override
  String get optionsLanguageSection => 'Langue';

  @override
  String get optionsLanguage => 'Langue d\'affichage';

  @override
  String get optionsLanguageHelper =>
      'Utilisée aussi pour les textes que l\'application écrit dans les messages (en-têtes des réponses, confirmations de lecture)';

  @override
  String get languageSystem => 'Comme le système';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabSendReceive => 'Envoi/réception';

  @override
  String get tabFolder => 'Dossier';

  @override
  String get tabView => 'Affichage';

  @override
  String get groupLayout => 'Disposition';

  @override
  String get ribbonCollapse => 'Réduire le ruban';

  @override
  String get ribbonCollapseTooltip =>
      'Afficher uniquement les noms des onglets (Ctrl+F1)';

  @override
  String get groupSendReceive => 'Envoyer et recevoir';

  @override
  String get sendReceiveAll => 'Envoyer/recevoir tous les dossiers';

  @override
  String get sendReceiveAllTooltip =>
      'Mettre à jour les dossiers et les messages de tous les comptes (F9)';

  @override
  String get readingPane => 'Volet de lecture';

  @override
  String get messagePreview => 'Aperçu des messages';

  @override
  String get messagePreviewOff => 'Désactivé';

  @override
  String messagePreviewLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '1 ligne',
    );
    return '$_temp0';
  }

  @override
  String get groupMessages => 'Messages';

  @override
  String get showAsConversations => 'Afficher sous forme de conversations';

  @override
  String get showAsConversationsOnTooltip =>
      'Activé dans ce dossier : cliquez pour revenir à la liste simple';

  @override
  String get showAsConversationsOffTooltip =>
      'Regroupe sur une ligne les messages d\'une même conversation';

  @override
  String get specialFolderHint =>
      'Boîte de réception, Éléments envoyés, Éléments supprimés et les autres dossiers spéciaux ne peuvent être ni renommés ni supprimés';

  @override
  String get groupNew => 'Nouveau';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get newFolderTooltip => 'Créer un sous-dossier du dossier sélectionné';

  @override
  String get groupActions => 'Actions';

  @override
  String get renameFolder => 'Renommer le dossier';

  @override
  String get renameFolderTooltip =>
      'Modifier le nom du dossier sélectionné (F2)';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String get deletePermanentlyTooltip =>
      'Supprimer du serveur, sans possibilité de récupération';

  @override
  String get deleteFolderTooltip =>
      'Déplacer le dossier, avec son contenu, vers Éléments supprimés';

  @override
  String get emptyFolder => 'Vider le dossier';

  @override
  String get emptyFolderTooltip =>
      'Supprimer du serveur tous les messages du dossier, sans possibilité de les récupérer';

  @override
  String get emptyFolderOnlyTooltip =>
      'Uniquement pour Éléments supprimés et Courrier indésirable';

  @override
  String get groupArchive => 'Archive';

  @override
  String get setArchiveFolder => 'Définir le dossier d\'archivage';

  @override
  String get setArchiveFolderTooltip =>
      'Choisir ou créer le dossier dans lequel Archiver déplace les messages de ce compte';

  @override
  String get newMessage => 'Nouveau courrier';

  @override
  String get newMessageTooltip => 'Écrire un nouveau message';

  @override
  String get delete => 'Supprimer';

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get moveToDeletedTooltip => 'Déplacer vers Éléments supprimés';

  @override
  String get archive => 'Archiver';

  @override
  String get cleanUp => 'Nettoyer';

  @override
  String get cleanUpTooltip =>
      'Déplacer vers Éléments supprimés les messages redondants : ceux cités intégralement dans une réponse';

  @override
  String get junk => 'Courrier indésirable';

  @override
  String get junkTooltip =>
      'Bloquer l\'expéditeur, Ne jamais bloquer, Options du courrier indésirable';

  @override
  String get groupRespond => 'Répondre';

  @override
  String get move => 'Déplacer';

  @override
  String get moveTooltip => 'Déplacer vers un autre dossier';

  @override
  String get moveOtherFolder => 'Autre dossier… (Ctrl+Maj+V)';

  @override
  String get rules => 'Règles';

  @override
  String get rulesTooltip => 'Trier automatiquement le courrier entrant';

  @override
  String get createRule => 'Créer une règle…';

  @override
  String get manageRulesEllipsis => 'Gérer les règles et les alertes…';

  @override
  String get groupTags => 'Indicateurs';

  @override
  String get markUnread => 'Marquer comme non lu';

  @override
  String get markRead => 'Marquer comme lu';

  @override
  String get categorize => 'Classer';

  @override
  String get categorizeTooltip => 'Attribuer une catégorie de couleur';

  @override
  String get followUp => 'Assurer un suivi';

  @override
  String get followUpTooltip => 'Marquer pour suivi, avec une échéance';

  @override
  String get groupFind => 'Rechercher';

  @override
  String get search => 'Rechercher';

  @override
  String get searchTooltip => 'Rechercher dans le courrier';

  @override
  String get fileTab => 'Fichier';

  @override
  String get openEml => 'Ouvrir un fichier .eml…';

  @override
  String get saveAs => 'Enregistrer sous… (F12)';

  @override
  String get printMessage => 'Imprimer… (Ctrl+P)';

  @override
  String get saveAsPdf => 'Enregistrer en PDF…';

  @override
  String get automaticReplies => 'Réponses automatiques';

  @override
  String get manageRules => 'Gérer les règles et les alertes';

  @override
  String get aboutApp => 'À propos de PostinoVip';

  @override
  String get ribbonShowAlways => 'Toujours afficher le ruban';

  @override
  String get ribbonTabsOnly => 'Afficher uniquement les onglets (Ctrl+F1)';

  @override
  String get ribbonDisplayOptions => 'Options d\'affichage du ruban';

  @override
  String get readingPaneRight => 'À droite';

  @override
  String get readingPaneBottom => 'En bas';

  @override
  String get readingPaneOff => 'Désactivé';

  @override
  String get ribbonClassic => 'Ruban classique';

  @override
  String get ribbonSimplified => 'Ruban simplifié';

  @override
  String get reply => 'Répondre';

  @override
  String get replyAll => 'Répondre à tous';

  @override
  String get forward => 'Transférer';

  @override
  String get sendReceiveAllF9 => 'Envoyer/recevoir tous les dossiers (F9)';

  @override
  String get searchHelp =>
      'Mots (aussi les débuts : \"fact\" trouve \"facture\"), \"expression exacte\"\nde:anne   à:mario   objet:réunion\npiècejointe:pdf   piècesjointes:oui   piècesjointes:non';

  @override
  String get searchClose => 'Fermer la recherche';

  @override
  String get searchScopeFolder => 'Dossier actif';

  @override
  String get searchScopeAccount => 'Boîte aux lettres active';

  @override
  String get searchScopeAllAccounts => 'Toutes les boîtes aux lettres';

  @override
  String get moduleMail => 'Courrier (Ctrl+1)';

  @override
  String get moduleCalendar => 'Calendrier (Ctrl+2)';

  @override
  String get modulePeople => 'Contacts (Ctrl+3)';

  @override
  String get zoomOut => 'Zoom arrière (Ctrl+-)';

  @override
  String get zoomIn => 'Zoom avant (Ctrl++)';

  @override
  String get zoomReset =>
      'Zoom du volet de lecture : cliquez pour revenir à 100 % (Ctrl+0)';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get retry => 'Réessayer';

  @override
  String get noFolderSelected => 'Aucun dossier sélectionné';

  @override
  String searchWhereFolder(String folder) {
    return 'dans $folder';
  }

  @override
  String searchWhereAccount(String account) {
    return 'dans tous les dossiers de $account';
  }

  @override
  String get searchWhereAllFolders => 'dans tous les dossiers';

  @override
  String get searchWhereAllAccounts => 'dans tous les comptes';

  @override
  String searchInProgress(String where) {
    return 'Recherche $where…';
  }

  @override
  String searchResultsTitle(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
    );
    return '$_temp0 $where';
  }

  @override
  String get listNoUnread => 'Aucun message non lu';

  @override
  String get listEmptyFolder => 'Ce dossier est vide';

  @override
  String get unknownSender => '(expéditeur inconnu)';

  @override
  String get noSubject => '(sans objet)';

  @override
  String get searchNoLocalResults => 'Aucun résultat dans la copie locale';

  @override
  String get offlineStrip =>
      'Non connecté : affichage de la copie de cet ordinateur. Les déplacements, suppressions, marquages comme lu et envois reprennent d\'eux-mêmes quand le serveur répond.';

  @override
  String get theProvider => 'le fournisseur';

  @override
  String loginExpired(String provider) {
    return 'La connexion à $provider a expiré : ce compte ne recevra ni n\'enverra de courrier tant que vous ne vous serez pas reconnecté.';
  }

  @override
  String get signInAgain => 'Se reconnecter';

  @override
  String get autoReplyStrip =>
      'Les réponses automatiques sont activées pour ce compte.';

  @override
  String get editEllipsis => 'Modifier…';

  @override
  String get autoReplyTurnedOff => 'Réponses automatiques désactivées.';

  @override
  String autoReplyNotTurnedOff(String error) {
    return 'Non désactivées : $error';
  }

  @override
  String get turnOff => 'Désactiver';

  @override
  String get serverSearching => 'Recherche sur le serveur…';

  @override
  String serverSearchFailed(String error) {
    return 'La recherche sur le serveur a échoué : $error';
  }

  @override
  String get serverFoundNone => 'Le serveur n\'a trouvé aucun autre message.';

  @override
  String serverFoundMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le serveur a trouvé $count messages de plus',
      one: 'Le serveur a trouvé 1 message de plus',
    );
    return '$_temp0 (avec l\'icône du nuage).';
  }

  @override
  String serverTruncated(int count) {
    return ' Affichage des $count plus récents.';
  }

  @override
  String get searchServerToo => 'Rechercher aussi sur le serveur';

  @override
  String get searchServerHint =>
      'Pour les messages plus anciens que la limite de la copie locale et pour Éléments supprimés et Courrier indésirable,\ndont seuls les en-têtes ont été recherchés ici.';

  @override
  String get conversationCollapse => 'Réduire la conversation';

  @override
  String get conversationExpand =>
      'Afficher tous les messages de la conversation';

  @override
  String get sortDateNewest => 'Par date : les plus récents en haut';

  @override
  String get sortDateOldest => 'Par date : les plus anciens en haut';

  @override
  String get sortFromAZ => 'Par expéditeur : A → Z';

  @override
  String get sortFromZA => 'Par expéditeur : Z → A';

  @override
  String get sortSubjectAZ => 'Par objet : A → Z';

  @override
  String get sortSubjectZA => 'Par objet : Z → A';

  @override
  String get sortSizeLargest => 'Par taille : les plus volumineux en haut';

  @override
  String get sortSizeSmallest => 'Par taille : les plus petits en haut';

  @override
  String get sortByDate => 'Par date';

  @override
  String get sortByFrom => 'Par expéditeur';

  @override
  String get sortBySubject => 'Par objet';

  @override
  String get sortBySize => 'Par taille';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterUnread => 'Non lus';

  @override
  String get sortTooltip => 'Trier par';

  @override
  String get conversationBadgeTooltip =>
      'L\'affichage en conversations est activé dans ce dossier : cliquez pour le modifier';

  @override
  String get conversations => 'Conversations';

  @override
  String conversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 dans la conversation';
  }

  @override
  String get hasAttachments => 'Contient des pièces jointes';

  @override
  String get flaggedClickToComplete =>
      'Indicateur : cliquez pour marquer comme terminé';

  @override
  String dueByClickToComplete(String date) {
    return 'Échéance le $date : cliquez pour marquer comme terminé';
  }

  @override
  String get completedClickToFlag => 'Terminé : cliquez pour marquer à nouveau';

  @override
  String get flagToday => 'Marquer pour aujourd\'hui';

  @override
  String get foundOnServer => 'Trouvé sur le serveur';

  @override
  String sortByColumn(String column) {
    return 'Trier par $column';
  }

  @override
  String get columnFrom => 'De';

  @override
  String get columnSubject => 'Objet';

  @override
  String get columnReceived => 'Reçu';

  @override
  String get columnSize => 'Taille';

  @override
  String get columnCategories => 'Catégories';

  @override
  String selectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments sélectionnés',
      one: '1 élément sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get selectMessage => 'Sélectionnez un élément à lire';

  @override
  String get messageUnavailable => 'Message non disponible';

  @override
  String receiptRequested(String sender) {
    return '$sender a demandé une confirmation de lecture.';
  }

  @override
  String get receiptDecline => 'Ne pas envoyer';

  @override
  String get receiptSend => 'Envoyer';

  @override
  String get draftBanner => 'Brouillon : pas encore envoyé.';

  @override
  String get editDraft => 'Modifier le brouillon';

  @override
  String get headerTo => 'À';

  @override
  String get headerCc => 'Cc';

  @override
  String openAttachment(String name) {
    return 'Ouvrir « $name »';
  }

  @override
  String saveAttachment(String name) {
    return 'Enregistrer « $name »…';
  }

  @override
  String get importanceHighBanner =>
      'Ce message a été envoyé avec une importance haute.';

  @override
  String get importanceLowBanner =>
      'Ce message a été envoyé avec une importance faible.';

  @override
  String get junkBanner =>
      'Ce message se trouve dans Courrier indésirable : par sécurité, les liens sont désactivés et les images distantes bloquées. S\'il s\'agit d\'un message fiable, replacez-le dans la Boîte de réception.';

  @override
  String get notJunk => 'Courrier légitime';

  @override
  String get remoteImagesBlocked =>
      'Images distantes bloquées pour protéger votre vie privée.';

  @override
  String get showImages => 'Afficher les images';

  @override
  String get htmlOnlyAsText =>
      'Message uniquement en HTML : affiché en texte simplifié.';

  @override
  String get bodyText => 'Texte';

  @override
  String savedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String attachmentNotDownloaded(String error) {
    return 'Pièce jointe non téléchargée : $error';
  }

  @override
  String fileNotWritten(String message, String path) {
    return 'Fichier non écrit : $message ($path)';
  }

  @override
  String attachedMailNotOpened(String error) {
    return 'Message joint non ouvert : $error';
  }

  @override
  String get messageWithoutText => '(message sans texte)';

  @override
  String get completed => 'Terminé';

  @override
  String get flaggedForFollowUp => 'Marqué pour suivi';

  @override
  String dueBy(String date) {
    return 'Échéance le $date';
  }

  @override
  String get overdueSuffix => ' (en retard)';

  @override
  String get addSenderToContacts => 'Ajouter l\'expéditeur aux contacts';

  @override
  String get stopIgnoringConversation => 'Ne plus ignorer la conversation';

  @override
  String get ignoreConversation => 'Ignorer la conversation';

  @override
  String get cleanUpConversation => 'Nettoyer la conversation';

  @override
  String draftNotAvailable(String error) {
    return 'Brouillon non disponible : $error';
  }

  @override
  String get draftTitle => 'Brouillon';

  @override
  String get deletePermanentlyQuestion => 'Supprimer définitivement ?';

  @override
  String deletePermanentlyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count messages sélectionnés dans Éléments supprimés seront supprimés',
      one: '1 message sélectionné dans Éléments supprimés sera supprimé',
    );
    return '$_temp0 du serveur.\nCette action est irréversible.';
  }

  @override
  String deletePermanentlyOne(String subject) {
    return '« $subject » sera supprimé du serveur.\nCette action est irréversible.';
  }

  @override
  String get dontShowAsConversations =>
      'Ne pas afficher sous forme de conversations';

  @override
  String conversationsOnQuestion(String folder) {
    return 'Les messages d\'une même conversation seront regroupés sur une ligne, avec les réponses classées dans d\'autres dossiers.\n\nAppliquer à « $folder » ou à tous les dossiers ?';
  }

  @override
  String conversationsApplyQuestion(String folder) {
    return 'Appliquer à « $folder » ou à tous les dossiers ?';
  }

  @override
  String get allFolders => 'Tous les dossiers';

  @override
  String get thisFolder => 'Ce dossier';

  @override
  String get importanceHigh => 'Importance haute';

  @override
  String get importanceLow => 'Importance faible';

  @override
  String get folderInbox => 'Boîte de réception';

  @override
  String get favorites => 'Favoris';

  @override
  String get removeFromFavorites => 'Supprimer des favoris';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get showInFavorites => 'Afficher dans les favoris';

  @override
  String get cleanUpFolder => 'Nettoyer le dossier';

  @override
  String get outbox => 'Boîte d\'envoi';

  @override
  String get folderNameHint => 'Nom du dossier';

  @override
  String noAutoUpdate(String address) {
    return 'La mise à jour automatique est désactivée pour $address : les nouveaux messages n\'apparaissent qu\'avec « Envoyer/recevoir »';
  }

  @override
  String get emptyFolderAllMails => 'Tous les messages';

  @override
  String get emptyFolderOnlyMail => 'Le seul message';

  @override
  String emptyFolderNMails(int count) {
    return 'Les $count messages';
  }

  @override
  String get emptyFolderOneSubfolder =>
      ' et le sous-dossier, avec ses messages';

  @override
  String emptyFolderNSubfolders(int count) {
    return ' et les $count sous-dossiers, avec leurs messages';
  }

  @override
  String emptyFolderQuestion(String folder) {
    return 'Vider « $folder » ?';
  }

  @override
  String emptyFolderContent(String mails, String folder, String also) {
    return 'Sera supprimé du serveur : $mails de « $folder »$also.\nCette action est irréversible.';
  }

  @override
  String get deleteFolderPermanentlyQuestion =>
      'Supprimer définitivement le dossier ?';

  @override
  String get deleteFolderQuestion => 'Supprimer le dossier ?';

  @override
  String deleteFolderPermanentlyContent(String folder) {
    return 'Le dossier « $folder », avec tous ses messages et sous-dossiers, sera supprimé du serveur.\nCette action est irréversible.';
  }

  @override
  String deleteFolderContent(String folder) {
    return 'Le dossier « $folder », avec tous ses messages et sous-dossiers, sera déplacé vers Éléments supprimés.';
  }

  @override
  String get messageTab => 'Message';

  @override
  String get windowDeletePermanentlyTooltip =>
      'Supprimer du serveur, sans possibilité de récupération (puis le message suivant)';

  @override
  String get windowDeleteTooltip =>
      'Déplacer vers Éléments supprimés et ouvrir le message suivant (Suppr)';

  @override
  String get windowArchiveTooltip =>
      'Déplacer vers le dossier d\'archivage et ouvrir le message suivant';

  @override
  String get windowMoveTooltip =>
      'Déplacer vers un autre dossier et ouvrir le message suivant';

  @override
  String get markUnreadWindow => 'Marquer comme non lu';

  @override
  String get groupZoom => 'Zoom';

  @override
  String zoomPercent(int percent) {
    return 'Zoom ($percent %)';
  }

  @override
  String get zoomTooltip =>
      'Agrandir ou réduire le texte du message (Ctrl+molette, Ctrl++, Ctrl+-, Ctrl+0)';

  @override
  String get previousItem => 'Élément précédent (Ctrl+,)';

  @override
  String get nextItem => 'Élément suivant (Ctrl+.)';

  @override
  String get closeEsc => 'Fermer (Échap)';

  @override
  String messageNotSaved(String error) {
    return 'Message non enregistré : $error';
  }

  @override
  String get emlFilesLabel => 'Messages électroniques';

  @override
  String fileNotOpened(String name, String reason) {
    return '$name non ouvert : $reason';
  }

  @override
  String get readOnly => 'Lecture seule';

  @override
  String get saveAsShort => 'Enregistrer sous…';

  @override
  String get moveItems => 'Déplacer des éléments';

  @override
  String moveItemsTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Déplacer les $count éléments sélectionnés vers le dossier :',
      one: 'Déplacer l\'élément sélectionné vers le dossier :',
    );
    return '$_temp0';
  }

  @override
  String get searchFolder => 'Rechercher un dossier';

  @override
  String get noFolderWithName => 'Aucun dossier portant ce nom';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String reminderNotification(String title) {
    return 'Rappel : $title';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rappels',
      one: '1 rappel',
    );
    return '$_temp0';
  }

  @override
  String get reminderAllDayToday => 'Toute la journée, aujourd\'hui';

  @override
  String get reminderAllDayTomorrow => 'Toute la journée, demain';

  @override
  String reminderAllDayIn(int count) {
    return 'Toute la journée, dans $count jours';
  }

  @override
  String reminderAllDayStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toute la journée, commencé il y a $count jours',
      one: 'Toute la journée, commencé il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get reminderNow => 'Maintenant';

  @override
  String reminderStartedAgo(String span) {
    return 'En retard de $span';
  }

  @override
  String reminderIn(String span) {
    return 'Dans $span';
  }

  @override
  String reminderStart(String when) {
    return 'Heure de début : $when';
  }

  @override
  String reminderLocation(String location) {
    return '    Emplacement : $location';
  }

  @override
  String get dismissAll => 'Tout ignorer';

  @override
  String get openItem => 'Ouvrir l\'élément';

  @override
  String get dismiss => 'Ignorer';

  @override
  String get snoozeHint => 'Cliquez sur Répéter pour être rappelé dans :';

  @override
  String get snooze => 'Répéter';

  @override
  String newMailFrom(String sender, String suffix) {
    return 'Nouveau message de $sender$suffix';
  }

  @override
  String newMailMore(int count) {
    return '\n…et $count autres';
  }

  @override
  String newMailCount(int count, String suffix) {
    return '$count nouveaux messages$suffix';
  }

  @override
  String get openMailAction => 'Ouvrir le message';

  @override
  String get viewDay => 'Jour';

  @override
  String get viewWorkWeek => 'Semaine de travail';

  @override
  String get viewWeek => 'Semaine';

  @override
  String get viewMonth => 'Mois';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPurple => 'Violet';

  @override
  String get colorTeal => 'Bleu-vert';

  @override
  String get colorPink => 'Rose';

  @override
  String get colorGold => 'Or';

  @override
  String get colorGray => 'Gris';

  @override
  String get deleteRecurringTitle => 'Supprimer un rendez-vous périodique';

  @override
  String get openRecurringTitle => 'Ouvrir un rendez-vous périodique';

  @override
  String get deleteRecurringQuestion =>
      'Supprimer uniquement cette occurrence ou toute la série ?';

  @override
  String get openRecurringQuestion =>
      'Il s\'agit d\'un rendez-vous périodique. Ouvrir uniquement cette occurrence ou toute la série ?';

  @override
  String get entireSeries => 'Toute la série';

  @override
  String get justThisOne => 'Celle-ci uniquement';

  @override
  String appointmentNotAvailable(String error) {
    return 'Rendez-vous non disponible : $error';
  }

  @override
  String get deleteAppointmentQuestion => 'Supprimer le rendez-vous ?';

  @override
  String deleteAppointmentContent(String title) {
    return '« $title » sera supprimé, et avec la synchronisation également du serveur. Il ne pourra pas être récupéré.';
  }

  @override
  String appointmentNotDeleted(String error) {
    return 'Rendez-vous non supprimé : $error';
  }

  @override
  String get uploadAppointmentsQuestion =>
      'Envoyer les rendez-vous sur le serveur ?';

  @override
  String uploadAppointmentsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rendez-vous n\'existent que sur cet ordinateur. Ils seront ajoutés',
      one: 'Un rendez-vous n\'existe que sur cet ordinateur. Il sera ajouté',
    );
    return '$_temp0 au calendrier du serveur et synchronisés ensuite.\n\nLes rendez-vous déjà présents sur le serveur ne sont pas modifiés.';
  }

  @override
  String get uploadToServer => 'Envoyer sur le serveur';

  @override
  String appointmentsNotUploaded(String error) {
    return 'Rendez-vous non envoyés : $error';
  }

  @override
  String get newAppointment => 'Nouveau rendez-vous';

  @override
  String get newAppointmentTooltip => 'Nouveau rendez-vous (Ctrl+N)';

  @override
  String get deleteSelectedAppointmentTooltip =>
      'Supprimer le rendez-vous sélectionné (Suppr)';

  @override
  String get groupGoTo => 'Atteindre';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get todayTooltip => 'Revenir à aujourd\'hui';

  @override
  String get next7Days => '7 prochains jours';

  @override
  String get next7DaysTooltip => 'Sept jours à partir d\'aujourd\'hui';

  @override
  String get groupArrange => 'Organiser';

  @override
  String get groupSync => 'Synchronisation';

  @override
  String get sync => 'Synchroniser';

  @override
  String get syncCalendarsTooltip =>
      'Synchroniser maintenant les calendriers avec le serveur (F9)';

  @override
  String appointmentsNotAvailable(String error) {
    return 'Rendez-vous non disponibles : $error';
  }

  @override
  String uploadStrip(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rendez-vous n\'existent',
      one: 'un rendez-vous n\'existe',
    );
    return '$name : $_temp0 que sur cet ordinateur, pas encore sur le serveur.';
  }

  @override
  String get uploadToServerEllipsis => 'Envoyer sur le serveur…';

  @override
  String get calendarEmpty => 'Aucun rendez-vous sur cette période. ';

  @override
  String get calendarEmptySyncHint =>
      'Pour voir ceux du serveur, activez « Synchroniser le calendrier avec le serveur (CalDAV) » dans Fichier → Options → Comptes → Modifier. ';

  @override
  String get calendarEmptyCreate =>
      'Pour en créer un : « Nouveau rendez-vous » (Ctrl+N) ou double-clic sur une plage libre.';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get myCalendars => 'Mes calendriers';

  @override
  String get localOnlyTooltip =>
      'Pour voir les rendez-vous du serveur : Fichier → Options → Comptes → Modifier → « Synchroniser le calendrier avec le serveur (CalDAV) »';

  @override
  String get localOnly => 'Uniquement sur cet ordinateur';

  @override
  String get color => 'Couleur';

  @override
  String get calendarReadOnlyTooltip =>
      'Lecture seule : les rendez-vous peuvent être consultés mais pas modifiés';

  @override
  String get syncedWithServer => 'Synchronisé avec le serveur';

  @override
  String get previousMonth => 'Mois précédent';

  @override
  String get nextMonth => 'Mois suivant';

  @override
  String nowAt(String time) {
    return 'Maintenant ($time)';
  }

  @override
  String moreItems(int count) {
    return '+$count de plus';
  }

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get synced => 'Synchronisé';

  @override
  String syncedAt(String time) {
    return 'Synchronisé à $time';
  }

  @override
  String syncedOnAt(String date, String time) {
    return 'Synchronisé le $date à $time';
  }

  @override
  String get syncServerUnreachable => 'Serveur inaccessible';

  @override
  String get syncUnavailable => 'Synchronisation non disponible';

  @override
  String get syncFailed => 'Échec de la synchronisation';

  @override
  String get endBeforeStart => 'La fin est antérieure au début.';

  @override
  String get deleteOccurrenceQuestion => 'Supprimer cette occurrence ?';

  @override
  String get deleteOccurrenceContent =>
      'Seule cette occurrence est retirée de la série ; les autres restent. Elle ne pourra pas être récupérée.';

  @override
  String get deleteSeriesContent =>
      'Le rendez-vous (avec toutes ses occurrences, s\'il est périodique) sera supprimé, et avec la synchronisation également du serveur. Il ne pourra pas être récupéré.';

  @override
  String get saveChangesQuestion => 'Enregistrer les modifications ?';

  @override
  String get appointmentNotSavedContent =>
      'Les modifications du rendez-vous n\'ont pas été enregistrées.';

  @override
  String get no => 'Non';

  @override
  String get yes => 'Oui';

  @override
  String get untitled => 'Sans titre';

  @override
  String get occurrence => 'Occurrence';

  @override
  String get appointment => 'Rendez-vous';

  @override
  String get saveAndClose => 'Enregistrer et fermer';

  @override
  String get saveAndCloseTooltip => 'Enregistrer et fermer (Ctrl+S)';

  @override
  String get deleteOnlyOccurrenceTooltip =>
      'Supprimer uniquement cette occurrence';

  @override
  String get deleteAppointmentTooltip => 'Supprimer le rendez-vous';

  @override
  String get groupOptions => 'Options';

  @override
  String get recurrence => 'Périodicité';

  @override
  String get recurrenceTooltip =>
      'Rendre périodique ou modifier la périodicité';

  @override
  String get reminder => 'Rappel';

  @override
  String reminderValue(String value) {
    return 'Rappel : $value';
  }

  @override
  String get reminderNone => 'Aucun';

  @override
  String get reminderAtStart => 'À l\'heure de début';

  @override
  String customRecurrence(String rule) {
    return 'Périodicité personnalisée ($rule) : conservée telle quelle à l\'enregistrement';
  }

  @override
  String calendarReadOnly(String calendar) {
    return 'Le calendrier « $calendar » est en lecture seule : le rendez-vous peut être consulté mais pas modifié.';
  }

  @override
  String get location => 'Emplacement';

  @override
  String get startTime => 'Heure de début';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get allDayEvent => 'Toute la journée';

  @override
  String recurrenceValue(String text) {
    return 'Périodicité : $text';
  }

  @override
  String get onlyThisOccurrenceHint =>
      'Uniquement cette occurrence de la série : les autres ne changent pas.';

  @override
  String get notes => 'Notes';

  @override
  String get weekFirst => 'premier';

  @override
  String get weekSecond => 'deuxième';

  @override
  String get weekThird => 'troisième';

  @override
  String get weekFourth => 'quatrième';

  @override
  String get weekLast => 'dernier';

  @override
  String get recurrenceBadInterval =>
      'Répétition non valide (tous les 1 à 999).';

  @override
  String get recurrenceBadCount =>
      'Nombre d\'occurrences non valide (1 à 999).';

  @override
  String get recurrenceNoDays => 'Choisissez au moins un jour de la semaine.';

  @override
  String get recurEveryNDays => 'Tous les [n] jour(s)';

  @override
  String get recurEveryWeekday => 'Tous les jours ouvrables';

  @override
  String get recurEveryNWeeksOn => 'Toutes les [n] semaine(s) le :';

  @override
  String get recurMonthlyDay => 'Le [day] tous les [n] mois';

  @override
  String get recurMonthlyWeekday => 'Le [week] [weekday] de chaque mois';

  @override
  String get recurYearlyDay => 'Chaque [day] [month]';

  @override
  String get recurYearlyWeekday => 'Le [week] [weekday] de [month]';

  @override
  String get appointmentRecurrence => 'Périodicité du rendez-vous';

  @override
  String get recurrencePattern => 'Modèle de périodicité';

  @override
  String get recurDaily => 'Quotidienne';

  @override
  String get recurWeekly => 'Hebdomadaire';

  @override
  String get recurMonthly => 'Mensuelle';

  @override
  String get recurYearly => 'Annuelle';

  @override
  String get recurrenceRange => 'Plage de périodicité';

  @override
  String get recurNoEnd => 'Pas de date de fin';

  @override
  String get recurEndAfter => 'Fin après [n] occurrences';

  @override
  String get recurEndBy => 'Fin le [date]';

  @override
  String get removeRecurrence => 'Supprimer la périodicité';

  @override
  String queuedSendAfter(String when) {
    return 'Message dans la Boîte d\'envoi : il sera envoyé après $when (application ouverte).';
  }

  @override
  String get queuedOffline =>
      'Pas de connexion : le message est dans la Boîte d\'envoi et sera envoyé automatiquement dès que le serveur répondra.';

  @override
  String get sentCopyNotSavedTitle => 'Message envoyé, copie non enregistrée';

  @override
  String sentCopyNotSaved(String error) {
    return 'Le message a été envoyé, mais la copie dans Éléments envoyés n\'a pas été enregistrée :\n$error\n\nNe le renvoyez pas : les destinataires l\'ont déjà reçu.';
  }

  @override
  String sentSavedIn(String folder) {
    return ' et enregistré dans « $folder »';
  }

  @override
  String messageSent(String where, String response) {
    return 'Message envoyé$where. Serveur : $response';
  }

  @override
  String get newMessageTitle => 'Nouveau message';

  @override
  String get toPlainTextQuestion => 'Passer en texte brut ?';

  @override
  String get toPlainTextContent =>
      'La mise en forme et les images du texte seront perdues, même si vous revenez au HTML. Le message d\'origine cité sera ajouté sous forme de texte.';

  @override
  String get continueButton => 'Continuer';

  @override
  String get savingDraft => 'Enregistrement du brouillon…';

  @override
  String get tabInsert => 'Insertion';

  @override
  String get tabFormatText => 'Format du texte';

  @override
  String get attachFile => 'Joindre un fichier';

  @override
  String get attachFileTooltip =>
      'Joindre un ou plusieurs fichiers de l\'ordinateur';

  @override
  String get saveSentCopy => 'Garder une copie';

  @override
  String get saveSentCopyOnTooltip =>
      'Activé : après l\'envoi, une copie va dans Éléments envoyés (cliquez pour ne pas l\'enregistrer)';

  @override
  String get saveSentCopyOffTooltip =>
      'Désactivé : aucune copie dans Éléments envoyés après l\'envoi (cliquez pour l\'enregistrer)';

  @override
  String get saveDraft => 'Enregistrer le brouillon';

  @override
  String get saveDraftTooltip =>
      'Enregistrer dans Brouillons (Ctrl+S) ; aussi automatiquement toutes les 3 minutes';

  @override
  String get delayDelivery => 'Différer la remise';

  @override
  String get delayDeliveryTooltip =>
      'Ne pas envoyer avant une date et une heure (il reste dans la Boîte d\'envoi)';

  @override
  String delayDeliveryActiveTooltip(String when) {
    return 'Envoi après $when : cliquez pour modifier';
  }

  @override
  String get importanceHighTooltip =>
      'Marquer le message comme important (cliquez à nouveau pour retirer)';

  @override
  String get importanceLowTooltip =>
      'Marquer le message comme peu important (cliquez à nouveau pour retirer)';

  @override
  String get groupInclude => 'Inclure';

  @override
  String get groupSave => 'Enregistrer';

  @override
  String get groupShowFields => 'Afficher les champs';

  @override
  String get bcc => 'Cci';

  @override
  String get bccTooltip =>
      'Copie cachée : les destinataires en Cci ne se voient pas entre eux et ne sont pas vus par les autres';

  @override
  String get groupTracking => 'Suivi';

  @override
  String get requestReadReceipt => 'Demander une confirmation de lecture';

  @override
  String get requestReadReceiptOnTooltip =>
      'Activé : le destinataire peut vous envoyer une confirmation quand il lit le message (cliquez pour retirer)';

  @override
  String get requestReadReceiptOffTooltip =>
      'Demander au destinataire une confirmation quand il lit le message (il peut refuser)';

  @override
  String get groupMoreOptions => 'Autres options';

  @override
  String get groupFormat => 'Format';

  @override
  String get formatHtmlTooltip => 'Texte mis en forme, avec images et liens';

  @override
  String get plainText => 'Texte brut';

  @override
  String get plainTextTooltip =>
      'Texte seul, sans mise en forme : tous les programmes de messagerie peuvent le lire';

  @override
  String get signaturesEllipsis => 'Signatures…';

  @override
  String get signature => 'Signature';

  @override
  String get signatureTooltip =>
      'Insérer une signature, ou créer et modifier des signatures';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get originalAttachment => 'Pièce jointe du message d\'origine';

  @override
  String get remove => 'Supprimer';

  @override
  String attachmentsTooLarge(String size, String max) {
    return 'Pièces jointes trop volumineuses : $size, maximum $max.';
  }

  @override
  String get messageBody => 'Texte du message';

  @override
  String get addressesHint => 'adresses séparées par des virgules';

  @override
  String get accountUnavailable => '(compte non disponible)';

  @override
  String get originalMessageQuote =>
      'Message d\'origine (ajouté à la fin, tel quel)';

  @override
  String get removeQuote => 'Supprimer la citation';

  @override
  String get offlineSendMessage =>
      'Pas de connexion au serveur et le message d\'origine (citation ou pièces jointes) n\'est pas sur cet ordinateur : le message n\'a pas été envoyé et reste ici. Réessayez quand la connexion sera rétablie.';

  @override
  String sendFailed(String error) {
    return 'Échec de l\'envoi : $error';
  }

  @override
  String draftTooLarge(String max) {
    return 'Brouillon non enregistré : pièces jointes de plus de $max.';
  }

  @override
  String draftSavedLocally(String time) {
    return 'Brouillon enregistré sur cet ordinateur à $time : il ira dans Brouillons quand le serveur répondra';
  }

  @override
  String draftSavedAt(String time) {
    return 'Brouillon enregistré à $time';
  }

  @override
  String get draftNotSaved => 'Brouillon non enregistré';

  @override
  String draftNotSavedError(String error) {
    return 'Brouillon non enregistré : $error';
  }

  @override
  String get sendQuestion => 'Envoyer le message ?';

  @override
  String sendSummaryCopy(String value) {
    return 'Copie dans Éléments envoyés : $value';
  }

  @override
  String sendSummaryDelivery(String when) {
    return 'Remise : pas avant $when';
  }

  @override
  String get emptySubjectWarning => 'Attention : l\'objet est vide.';

  @override
  String get attachmentsNone => 'aucune';

  @override
  String attachmentsFromDisk(String size) {
    return ', fichiers du disque $size';
  }

  @override
  String get composeSaveNew =>
      'Le message n\'a pas été envoyé. L\'enregistrer dans Brouillons pour le terminer plus tard ?';

  @override
  String get composeSaveExisting =>
      'Le message n\'a pas été envoyé. Enregistrer les dernières modifications dans le brouillon ?';

  @override
  String get sending => 'Envoi…';

  @override
  String get doNotDeliverBefore => 'Ne pas remettre avant :';

  @override
  String get delayDeliveryHint =>
      'Après « Envoyer », le message reste dans la Boîte d\'envoi et part automatiquement à cette heure, si l\'application est ouverte.';

  @override
  String get chooseFutureTime => 'Choisissez une heure dans le futur.';

  @override
  String get noDelay => 'Aucun délai';

  @override
  String get recipientRequired => 'Indiquez au moins un destinataire';

  @override
  String invalidAddress(String address) {
    return 'Adresse non valide : $address';
  }

  @override
  String get dontSuggestAddress => 'Ne plus suggérer cette adresse';

  @override
  String get noMoreSuggestions => 'Plus de suggestions';

  @override
  String get outboxHint =>
      'Boîte d\'envoi : messages de cet ordinateur qui partent automatiquement à l\'heure prévue quand le serveur répond, application ouverte.';

  @override
  String get outboxEmpty => 'Aucun message en attente d\'envoi';

  @override
  String get deleteOutboxQuestion => 'Supprimer le message ?';

  @override
  String deleteOutboxContent(String subject) {
    return '« $subject » ne sera pas envoyé.';
  }

  @override
  String outboxNotSent(String error) {
    return 'Non envoyé : $error';
  }

  @override
  String outboxSendAfter(String when) {
    return 'Envoi après $when';
  }

  @override
  String get outboxWaiting => 'En attente de connexion';

  @override
  String get noRecipients => '(aucun destinataire)';

  @override
  String get sendNow => 'Envoyer maintenant';

  @override
  String get moveToDrafts => 'Déplacer vers Brouillons (pour le modifier)';

  @override
  String get deleteOutboxTooltip => 'Supprimer (il ne sera pas envoyé)';

  @override
  String get yesValue => 'oui';

  @override
  String get noValue => 'non';

  @override
  String get fontColorAutomatic => 'Automatique';

  @override
  String get fontColorDarkRed => 'Rouge foncé';

  @override
  String get fontColorRed => 'Rouge';

  @override
  String get fontColorOrange => 'Orange';

  @override
  String get fontColorYellow => 'Jaune';

  @override
  String get fontColorLightGreen => 'Vert clair';

  @override
  String get fontColorGreen => 'Vert';

  @override
  String get fontColorLightBlue => 'Bleu clair';

  @override
  String get fontColorBlue => 'Bleu';

  @override
  String get fontColorDarkBlue => 'Bleu foncé';

  @override
  String get fontColorPurple => 'Violet';

  @override
  String get remoteImagePlaceholder => '[image d\'internet]';

  @override
  String get groupBasicText => 'Texte simple';

  @override
  String get groupFont => 'Police';

  @override
  String get groupParagraph => 'Paragraphe';

  @override
  String get linkTooltip => 'Lien (Ctrl+K)';

  @override
  String get imageFromFile => 'Image à partir d\'un fichier (par ex. un logo)';

  @override
  String get defaultFont => 'Calibri (par défaut)';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get bold => 'Gras (Ctrl+B)';

  @override
  String get italic => 'Italique (Ctrl+I)';

  @override
  String get underline => 'Souligné (Ctrl+U)';

  @override
  String get strikethrough => 'Barré';

  @override
  String get fontColor => 'Couleur de police';

  @override
  String get highlightColor => 'Couleur de surbrillance du texte';

  @override
  String get noColor => 'Aucune couleur';

  @override
  String get clearFormatting => 'Effacer toute la mise en forme';

  @override
  String get bullets => 'Puces';

  @override
  String get numbering => 'Numérotation';

  @override
  String get decreaseIndent => 'Diminuer le retrait';

  @override
  String get increaseIndent => 'Augmenter le retrait';

  @override
  String get alignLeft => 'Aligner à gauche';

  @override
  String get center => 'Centrer';

  @override
  String get alignRight => 'Aligner à droite';

  @override
  String get justify => 'Justifier';

  @override
  String get link => 'Lien';

  @override
  String get linkButtonTooltip => 'Insérer ou modifier un lien (Ctrl+K)';

  @override
  String get linkInvalid =>
      'Adresse non valide : seuls http, https et mailto sont autorisés.';

  @override
  String get insertLink => 'Insérer un lien hypertexte';

  @override
  String get linkAddress => 'Adresse';

  @override
  String get linkAddressHint => 'https://… ou une adresse e-mail';

  @override
  String get removeLink => 'Supprimer le lien';

  @override
  String signatureTooLarge(String size, String max) {
    return 'Signature trop volumineuse : $size d\'images, maximum $max.';
  }

  @override
  String get newSignature => 'Nouvelle signature';

  @override
  String get renameSignature => 'Renommer la signature';

  @override
  String get deleteSignatureQuestion => 'Supprimer la signature ?';

  @override
  String deleteSignatureContent(String name) {
    return '« $name » sera supprimée de cet ordinateur.';
  }

  @override
  String get notAnImage =>
      'Le fichier choisi n\'est pas une image (PNG, JPEG, GIF, BMP ou WebP).';

  @override
  String get signaturesAndStationery => 'Signatures et thème';

  @override
  String get selectSignatureToEdit => 'Sélectionner la signature à modifier';

  @override
  String get newButton => 'Nouveau';

  @override
  String get rename => 'Renommer';

  @override
  String get editSignature => 'Modifier la signature';

  @override
  String get noSignatures =>
      'Aucune signature : créez la première avec « Nouveau ».';

  @override
  String get signatureText => 'Texte de la signature';

  @override
  String get noneFeminine => '(aucune)';

  @override
  String get chooseDefaultSignature => 'Choisir la signature par défaut';

  @override
  String get account => 'Compte de messagerie';

  @override
  String get newMessages => 'Nouveaux messages';

  @override
  String get repliesForwards => 'Réponses/transferts';

  @override
  String get writeAName => 'Indiquez un nom.';

  @override
  String get signatureNameTaken => 'Une signature porte déjà ce nom.';

  @override
  String get signatureName => 'Nom de la signature';

  @override
  String get contacts => 'Contacts';

  @override
  String get addressBook => 'Carnet d\'adresses';

  @override
  String get addressBookSearch => 'Rechercher par nom, adresse ou société';

  @override
  String get allAddressBooks => 'Tous les carnets d\'adresses';

  @override
  String contactsNotAvailable(String error) {
    return 'Contacts non disponibles : $error';
  }

  @override
  String get noContactsWithAddress => 'Aucun contact avec une adresse.';

  @override
  String get noContactsFound => 'Aucun contact trouvé.';

  @override
  String get takeOut => 'Retirer';

  @override
  String get labelWork => 'Travail';

  @override
  String get labelHome => 'Domicile';

  @override
  String get labelOther => 'Autre';

  @override
  String get labelMobile => 'Mobile';

  @override
  String get labelOffice => 'Bureau';

  @override
  String get deleteContactQuestion => 'Supprimer le contact ?';

  @override
  String deleteContactContent(String name) {
    return '« $name » n\'existe que sur cet ordinateur : une fois supprimé, il ne pourra pas être récupéré.';
  }

  @override
  String contactNotDeleted(String error) {
    return 'Contact non supprimé : $error';
  }

  @override
  String get contactFilesLabel => 'Contacts (vCard, CSV)';

  @override
  String get importDone => 'Importation terminée';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts ajoutés',
      one: '1 contact ajouté',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    return '$count déjà présents (non ajoutés à nouveau)';
  }

  @override
  String importInvalid(int count) {
    return '$count ignorés (sans nom ni adresse, ou non valides)';
  }

  @override
  String importFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get exportContacts => 'Exporter les contacts';

  @override
  String get exportVcfHint => 'Pour Thunderbird, téléphones, Apple, Google';

  @override
  String get exportCsvHint =>
      'Colonnes d\'Outlook : pour Outlook, Gmail, Excel';

  @override
  String exportDone(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts exportés',
      one: '1 contact exporté',
    );
    return '$_temp0 vers $path';
  }

  @override
  String exportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String contactSavedIn(String name, String book) {
    return '« $name » enregistré dans $book';
  }

  @override
  String get uploadContactsQuestion => 'Envoyer les contacts sur le serveur ?';

  @override
  String uploadContactsContent(int count, String book, String serverBook) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts du carnet « $book » n\'existent que sur cet ordinateur. Ils seront ajoutés',
      one:
          'Un contact du carnet « $book » n\'existe que sur cet ordinateur. Il sera ajouté',
    );
    return '$_temp0 au carnet « $serverBook » du serveur de contacts et synchronisés ensuite.\n\nLes contacts déjà présents sur le serveur ne sont pas modifiés.';
  }

  @override
  String contactsNotUploaded(String error) {
    return 'Contacts non envoyés : $error';
  }

  @override
  String get newContact => 'Nouveau contact';

  @override
  String get newContactTooltip =>
      'Nouveau contact dans le carnet ouvert (Ctrl+N)';

  @override
  String get deleteContactTooltip => 'Supprimer le contact sélectionné (Suppr)';

  @override
  String get groupCommunicate => 'Communiquer';

  @override
  String get emailMessage => 'Courrier';

  @override
  String get emailMessageTooltip => 'Nouveau message au contact sélectionné';

  @override
  String get edit => 'Modifier';

  @override
  String get editContactTooltip =>
      'Ouvrir le contact sélectionné (Entrée ou double-clic)';

  @override
  String get syncContactsTooltip =>
      'Synchroniser maintenant le carnet avec le serveur de contacts (F9)';

  @override
  String get syncContactsOffTooltip =>
      'La synchronisation des contacts est désactivée : activez-la dans les paramètres du compte';

  @override
  String get groupImportExport => 'Importer/Exporter';

  @override
  String get importEllipsis => 'Importer…';

  @override
  String get importTooltip =>
      'Ajouter des contacts à partir d\'un fichier vCard (.vcf) ou CSV d\'Outlook ou de Gmail';

  @override
  String get exportEllipsis => 'Exporter…';

  @override
  String get exportTooltip =>
      'Enregistrer tout le carnet dans un fichier vCard ou CSV';

  @override
  String get searchContacts => 'Rechercher des contacts';

  @override
  String get searchContactsTooltip =>
      'Rechercher par nom, adresse, société ou téléphone (Ctrl+E)';

  @override
  String get myContacts => 'Mes contacts';

  @override
  String get reloginCalendar =>
      'Le calendrier ne se synchronise pas : vous devez vous reconnecter à Google et autoriser l\'accès au calendrier.';

  @override
  String get reloginContacts =>
      'Les contacts ne se synchronisent pas : vous devez vous reconnecter à Google et autoriser l\'accès aux contacts.';

  @override
  String contactsUploadStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts n\'existent que sur cet ordinateur : ils ne sont pas encore sur le serveur de contacts.',
      one: 'Un contact n\'existe que sur cet ordinateur : il n\'est pas encore sur le serveur de contacts.',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get noContactsHint =>
      'Aucun contact. Utilisez « Nouveau contact » ou « Importer… ».';

  @override
  String get selectContact => 'Sélectionnez un contact';

  @override
  String get emailSection => 'Adresse e-mail';

  @override
  String get phoneSection => 'Téléphone';

  @override
  String get contact => 'Contact';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get displayAs => 'Afficher sous (si différent du prénom et du nom)';

  @override
  String get company => 'Société';

  @override
  String get addAddress => 'Ajouter une adresse';

  @override
  String get phoneNumber => 'Numéro';

  @override
  String get addPhone => 'Ajouter un téléphone';

  @override
  String get securityNone => 'Aucun';

  @override
  String get bodyMonthsAll => 'Tout';

  @override
  String bodyMonthsLast(int months) {
    return '$months derniers mois';
  }

  @override
  String noAccountsSaved(String address) {
    return 'Aucun compte enregistré dans l\'application. Pendant le développement, le core utilise user-secrets$address.\nDès que vous ajoutez un compte ici, seuls les comptes enregistrés ici seront utilisés : pour continuer à voir le compte actuel, ajoutez-le aussi.';
  }

  @override
  String accountSignedInWith(String provider) {
    return 'connecté avec $provider';
  }

  @override
  String accountDownloadedMail(String months) {
    return 'Courrier téléchargé : $months';
  }

  @override
  String get accountContactsSynced => 'contacts synchronisés (CardDAV)';

  @override
  String get accountCalendarSynced => 'calendrier synchronisé (CalDAV)';

  @override
  String get rebuildCache => 'Reconstruire la copie locale';

  @override
  String get removeFromApp => 'Retirer de l\'application';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get pendingChangesOk =>
      'Modifications pas encore enregistrées : elles s\'appliquent quand vous cliquez sur OK.';

  @override
  String accountsNotSaved(String error) {
    return 'Comptes non enregistrés : $error';
  }

  @override
  String get pop3RemovedAfterDownload =>
      'supprimé du serveur après téléchargement';

  @override
  String pop3CopyForDays(int days) {
    return 'copie sur le serveur pendant $days jours';
  }

  @override
  String get pop3CopyLeft => 'copie laissée sur le serveur';

  @override
  String pop3Summary(String copy, int minutes) {
    return 'Courrier sur cet ordinateur, $copy · vérifié toutes les $minutes minutes';
  }

  @override
  String get removedAccountsData => 'Données des comptes retirés';

  @override
  String get removedAccountsDataInfo =>
      'Courrier téléchargé et index de recherche des comptes retirés de l\'application. Ils restent sur cet ordinateur jusqu\'à ce que vous les supprimiez.';

  @override
  String get orphanPop3Only => 'Courrier POP3 : c\'est la seule copie';

  @override
  String orphanContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
    );
    return '$_temp0, uniquement sur cet ordinateur';
  }

  @override
  String get deleteLocalData => 'Supprimer les données locales';

  @override
  String get rebuildQuestion => 'Reconstruire la copie locale ?';

  @override
  String rebuildContent(String name) {
    return 'La copie de « $name » sur cet ordinateur (courrier téléchargé et index de recherche) est supprimée puis téléchargée à nouveau depuis le serveur en arrière-plan : cela peut prendre quelques minutes et utiliser le réseau.\n\nRien n\'est modifié sur le serveur.';
  }

  @override
  String get rebuild => 'Reconstruire';

  @override
  String rebuildStarted(String name) {
    return 'La reconstruction de la copie locale de « $name » a commencé.';
  }

  @override
  String rebuildFailed(String error) {
    return 'Copie locale non reconstruite : $error';
  }

  @override
  String get deleteLocalDataQuestion => 'Supprimer les données locales ?';

  @override
  String deleteLocalDataContent(String name, String size, String contacts) {
    return 'Le courrier téléchargé et l\'index de recherche de « $name » ($size), un compte qui n\'est plus dans l\'application, sont supprimés de cet ordinateur.\n\n${contacts}Rien n\'est modifié sur le serveur. Cette action est irréversible : si vous ajoutez à nouveau le compte, le courrier sera de nouveau téléchargé.';
  }

  @override
  String deleteLocalDataContacts(int count) {
    return 'Ses $count contacts sont également perdus : ils n\'existent que sur cet ordinateur. Pour les conserver, ajoutez à nouveau le compte et exportez-les depuis Contacts.';
  }

  @override
  String localDataDeleted(String name) {
    return 'Données locales de « $name » supprimées.';
  }

  @override
  String localDataNotDeleted(String error) {
    return 'Données locales non supprimées : $error';
  }

  @override
  String get removeAccountQuestion => 'Retirer le compte de l\'application ?';

  @override
  String removeAccountContent(String name, String email, String note) {
    return '« $name » ($email) sera retiré de PostinoVip, avec le mot de passe enregistré dans le trousseau.\n\n$note Ses contacts (Contacts) restent aussi sur cet ordinateur.\n\nLe retrait s\'applique quand vous cliquez sur OK dans la fenêtre Comptes.';
  }

  @override
  String get removeAccountPop3Note =>
      'Rien n\'est modifié sur le serveur. Le courrier téléchargé en POP3 reste sur cet ordinateur (pour une partie, c\'est la seule copie) : vous le trouverez dans « Données des comptes retirés » et il réapparaît si vous ajoutez à nouveau le compte.';

  @override
  String get removeAccountImapNote =>
      'Rien n\'est modifié sur le serveur : le courrier reste où il est et vous pouvez ajouter à nouveau le compte à tout moment. Le courrier déjà téléchargé reste sur cet ordinateur : vous pourrez le supprimer plus tard depuis « Données des comptes retirés ».';

  @override
  String get deleteForeverQuestion => 'Supprimer le courrier définitivement ?';

  @override
  String deleteForeverContent(String name, String size, String expected) {
    return '« $name » était un compte POP3 : son courrier ($size) a été téléchargé sur cet ordinateur et c\'est la seule copie. Le courrier déjà supprimé du serveur ne pourra plus être récupéré.\n\nPour confirmer, tapez : $expected';
  }

  @override
  String get deleteForever => 'Supprimer définitivement';

  @override
  String get browserNotOpened => 'Le navigateur ne s\'est pas ouvert.';

  @override
  String signInNotStarted(String error) {
    return 'Connexion non démarrée : $error';
  }

  @override
  String get signInExpired => 'La connexion a expiré : réessayez.';

  @override
  String signInFailedError(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get signInFailed => 'Échec de la connexion.';

  @override
  String get signInWithoutContacts =>
      'Connecté, mais sans autorisation pour les contacts : la synchronisation des contacts reste désactivée. Pour l\'activer, cochez à nouveau la case et autorisez l\'accès.';

  @override
  String get signInWithoutCalendar =>
      'Connecté, mais sans autorisation pour le calendrier : la synchronisation du calendrier reste désactivée. Pour l\'activer, cochez à nouveau la case et autorisez l\'accès.';

  @override
  String get signInWithoutContactsCalendar =>
      'Connecté, mais sans autorisation pour les contacts et le calendrier : leur synchronisation reste désactivée. Pour l\'activer, cochez à nouveau la case et autorisez l\'accès.';

  @override
  String waitingSignIn(String company) {
    return 'En attente de la connexion sur la page de $company, dans le navigateur…';
  }

  @override
  String signedInWith(String company) {
    return 'Connecté avec $company : aucun mot de passe à enregistrer.';
  }

  @override
  String noPasswordSignIn(String company) {
    return 'Pas de mot de passe : vous vous connectez sur la page de $company, dans le navigateur. À votre retour, l\'adresse et les serveurs sont remplis automatiquement.';
  }

  @override
  String serviceUnavailable(String service) {
    return '$service n\'est pas disponible : le core n\'a pas l\'ID de l\'application.';
  }

  @override
  String signInWith(String company) {
    return 'Se connecter avec $company';
  }

  @override
  String get welcomeTitle => 'Bienvenue dans PostinoVip';

  @override
  String get newAccount => 'Nouveau compte';

  @override
  String get editAccount => 'Modifier le compte';

  @override
  String get firstRunIntro =>
      'Saisissez les informations de votre boîte aux lettres. Le mot de passe est conservé dans le trousseau du système.';

  @override
  String get accountType => 'Type de compte';

  @override
  String get accountTypeHelp =>
      'IMAP : le courrier reste sur le serveur et est visible depuis tous les appareils (recommandé).\nPOP3 : le courrier est téléchargé sur cet ordinateur. Ce choix ne peut pas être modifié ensuite.';

  @override
  String accountTypeServices(String services) {
    return '$services : connexion avec le navigateur, sans mot de passe.';
  }

  @override
  String accountTypeValue(String type) {
    return 'Type de compte : $type';
  }

  @override
  String get nameOptional => 'Nom (facultatif)';

  @override
  String get nameOptionalHint =>
      'par ex. Travail ; si vide, l\'adresse est affichée';

  @override
  String get emailAddressUser => 'Adresse e-mail (aussi le nom d\'utilisateur)';

  @override
  String get invalidAddressShort => 'Adresse non valide';

  @override
  String get accountAlreadyPresent => 'Ce compte existe déjà';

  @override
  String get password => 'Mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get passwordRequired => 'Mot de passe obligatoire';

  @override
  String sameMailboxOtherType(String type, String name) {
    return 'Cette boîte aux lettres est déjà configurée en $type (« $name »). Elle peut être utilisée des deux façons, mais quand POP3 supprime le courrier du serveur, il disparaît aussi du compte IMAP.';
  }

  @override
  String incomingServer(String type) {
    return '$type (courrier entrant)';
  }

  @override
  String get outgoingServer => 'SMTP (courrier sortant)';

  @override
  String get smtpAuthTitle =>
      'Mon serveur sortant (SMTP) requiert une authentification';

  @override
  String get smtpAuthSubtitle =>
      'Avec l\'adresse et le mot de passe de la boîte aux lettres. Décochez-la uniquement pour un serveur qui accepte le courrier sans connexion (par ex. sur le port 25 d\'un réseau d\'entreprise).';

  @override
  String get downloadedMail => 'Courrier téléchargé sur cet ordinateur';

  @override
  String get downloadedMailHelp =>
      'Les plus récents sont téléchargés en arrière-plan et s\'ouvrent immédiatement ; les autres quand vous les ouvrez.\nÉléments supprimés et Courrier indésirable : uniquement la liste.';

  @override
  String get recommendedSuffix => ' (recommandé)';

  @override
  String get syncContactsGoogle =>
      'Synchroniser les contacts avec Google (CardDAV)';

  @override
  String get syncContactsServer =>
      'Synchroniser les contacts avec le serveur (CardDAV)';

  @override
  String get notYetForMicrosoft =>
      'Pas encore disponible pour les comptes Microsoft.';

  @override
  String get signInWithGoogleFirst =>
      'Cliquez d\'abord sur « Se connecter avec Google ».';

  @override
  String get syncContactsGoogleHelp =>
      'Le carnet d\'adresses de ce compte devient celui de vos contacts Google. Cocher la case ouvre le navigateur pour autoriser PostinoVip à accéder à vos contacts.';

  @override
  String get syncContactsServerHelp =>
      'Le carnet d\'adresses de ce compte devient celui du serveur de contacts, avec les mêmes identifiants. La première fois, les contacts qui n\'existent que sur cet ordinateur ne sont envoyés au serveur qu\'après votre confirmation.';

  @override
  String get contactsSignInWaiting =>
      'Connexion à Google dans le navigateur : autorisez l\'accès aux contacts.';

  @override
  String get contactsServerUrl => 'Adresse du serveur de contacts (facultatif)';

  @override
  String get emptyFoundOnIncoming =>
      'Vide : trouvé automatiquement sur le serveur entrant';

  @override
  String emptyFoundOn(String host) {
    return 'Vide : trouvé automatiquement sur $host';
  }

  @override
  String get httpsRequired => 'Une adresse https:// est obligatoire';

  @override
  String get testAddressBook => 'Tester le carnet d\'adresses';

  @override
  String addressBookFound(String name) {
    return 'Trouvé : « $name »';
  }

  @override
  String get addressBookNotFound => 'Carnet d\'adresses introuvable.';

  @override
  String get calendarSection => 'Calendrier';

  @override
  String get syncCalendarGoogle =>
      'Synchroniser le calendrier avec Google (CalDAV)';

  @override
  String get syncCalendarServer =>
      'Synchroniser le calendrier avec le serveur (CalDAV)';

  @override
  String get syncCalendarGoogleHelp =>
      'Vos calendriers Google deviennent les calendriers de ce compte ; ceux en lecture seule (par ex. jours fériés) sont visibles mais non modifiables. Cocher la case ouvre le navigateur pour autoriser PostinoVip à accéder à votre calendrier.';

  @override
  String get syncCalendarServerHelp =>
      'Les calendriers du serveur qui acceptent des rendez-vous deviennent les calendriers de ce compte. La première fois, les rendez-vous qui n\'existent que sur cet ordinateur ne sont envoyés au serveur qu\'après votre confirmation.';

  @override
  String get calendarSignInWaiting =>
      'Connexion à Google dans le navigateur : autorisez l\'accès au calendrier.';

  @override
  String get calendarServerUrl =>
      'Adresse du serveur de calendrier (facultatif)';

  @override
  String get testCalendar => 'Tester le calendrier';

  @override
  String calendarsFound(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trouvés',
      one: 'Trouvé',
    );
    return '$_temp0 : $names';
  }

  @override
  String quoted(String text) {
    return '« $text »';
  }

  @override
  String get calendarNotFound => 'Calendrier introuvable.';

  @override
  String get enterAddressPasswordFirst =>
      'Saisissez d\'abord l\'adresse et le mot de passe.';

  @override
  String get enterServerOrCalendarUrl =>
      'Saisissez le serveur entrant ou l\'adresse du serveur de calendrier.';

  @override
  String get enterServerOrContactsUrl =>
      'Saisissez le serveur entrant ou l\'adresse du serveur de contacts.';

  @override
  String get deliverySection => 'Remise';

  @override
  String get leaveCopyOnServer =>
      'Laisser une copie des messages sur le serveur';

  @override
  String get removeFromServerAfter => 'Supprimer du serveur après';

  @override
  String get days => 'jours';

  @override
  String get removeWhenDeleted =>
      'Supprimer du serveur lors de la suppression dans « Éléments supprimés »';

  @override
  String get pop3NoCopyWarning =>
      'Chaque message sera supprimé du serveur juste après son téléchargement : il ne restera que sur cet ordinateur.';

  @override
  String get checkMailEvery => 'Vérifier les nouveaux messages toutes les';

  @override
  String get checkMailEveryHelp =>
      'Aussi avec Envoyer/recevoir (F9). Le courrier n\'existe que sur cet ordinateur : pensez à le sauvegarder.';

  @override
  String minutesCount(int count) {
    return '$count minutes';
  }

  @override
  String get server => 'Serveur';

  @override
  String get serverHint => 'par ex. mail.domaine.com';

  @override
  String get serverRequired => 'Serveur obligatoire';

  @override
  String get port => 'Port';

  @override
  String get encryption => 'Chiffrement';

  @override
  String get unencryptedWarning =>
      'Sans chiffrement, le mot de passe et le courrier circulent en clair : n\'importe qui sur le réseau peut les lire. À utiliser uniquement sur un réseau de confiance.';

  @override
  String get certificateTrustedByYou =>
      'Certificat du serveur accepté par vous (non signé par une autorité reconnue).';

  @override
  String get stopTrusting => 'Ne plus faire confiance';

  @override
  String testFailed(String error) {
    return 'Échec du test : $error';
  }

  @override
  String get trustCertificateQuestion => 'Faire confiance à ce certificat ?';

  @override
  String invalidCertificatePresented(String server, String address) {
    return 'Le serveur $server $address a présenté un certificat non valide :';
  }

  @override
  String get certificateIssuedTo => 'Délivré à';

  @override
  String get certificateIssuedBy => 'Délivré par';

  @override
  String get certificateValid => 'Valide';

  @override
  String certificateValidRange(String from, String to) {
    return 'du $from au $to';
  }

  @override
  String get certificateFingerprint => 'Empreinte SHA-256';

  @override
  String get certificateAdvice =>
      'Acceptez-le uniquement si vous savez que ce serveur utilise son propre certificat (par ex. un serveur d\'entreprise ou personnel) ; si possible, comparez l\'empreinte avec celle fournie par votre administrateur. Un certificat inattendu peut signifier que quelqu\'un tente d\'intercepter votre mot de passe.\n\nSi vous l\'acceptez, PostinoVip ne fera confiance qu\'à ce certificat : si le serveur en présente un autre, la question vous sera reposée.';

  @override
  String get trustCertificate => 'Faire confiance au certificat';

  @override
  String get testConnection => 'Tester les paramètres du compte';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveAfterTest =>
      '« Enregistrer » devient disponible après un test réussi.';

  @override
  String accountNotSaved(String error) {
    return 'Compte non enregistré : $error';
  }

  @override
  String unencryptedIncoming(String address) {
    return 'entrant ($address)';
  }

  @override
  String unencryptedOutgoing(String address) {
    return 'sortant ($address)';
  }

  @override
  String get unencryptedTitle => 'Connexion sans chiffrement';

  @override
  String unencryptedContent(String servers) {
    return 'Pour $servers vous avez choisi le chiffrement « Aucun » : le mot de passe et le courrier circulent en clair et n\'importe qui sur le même réseau (Wi-Fi public, réseau d\'entreprise, fournisseur) peut les lire ou les modifier.\n\nEnregistrer quand même ?';
  }

  @override
  String get andSeparator => ' et ';

  @override
  String get saveUnencrypted => 'Enregistrer sans chiffrement';

  @override
  String get runFilterAll => 'Tous les messages';

  @override
  String get runFilterRead => 'Messages lus';

  @override
  String get runFilterUnread => 'Messages non lus';

  @override
  String ruleNameFrom(String sender) {
    return 'De $sender';
  }

  @override
  String ruleCreated(String name) {
    return 'Règle « $name » créée : elle s\'applique au courrier qui arrive à partir de maintenant.';
  }

  @override
  String ruleNotSaved(String error) {
    return 'Règle non enregistrée : $error';
  }

  @override
  String get orSeparator => ' ou ';

  @override
  String ruleDescFrom(String words) {
    return 'de $words';
  }

  @override
  String ruleDescToOrCc(String words) {
    return 'À ou Cc contient $words';
  }

  @override
  String get ruleDescSentOnlyToMe => 'envoyé uniquement à moi';

  @override
  String get ruleDescMeInTo => 'moi dans À';

  @override
  String get ruleDescMeInCc => 'moi dans Cc';

  @override
  String ruleDescSubject(String words) {
    return 'l\'objet contient $words';
  }

  @override
  String ruleDescSubjectOrBody(String words) {
    return 'l\'objet ou le corps contient $words';
  }

  @override
  String get ruleDescAttachments => 'avec pièces jointes';

  @override
  String ruleDescSize(int kb) {
    return 'de plus de $kb Ko';
  }

  @override
  String ruleDescMove(String folder) {
    return 'déplacer vers $folder';
  }

  @override
  String ruleDescCopy(String folder) {
    return 'copier vers $folder';
  }

  @override
  String get ruleDescDelete => 'supprimer';

  @override
  String get ruleDescMarkRead => 'marquer comme lu';

  @override
  String get ruleDescFlag => 'marquer pour suivi';

  @override
  String ruleDescCategory(String name) {
    return 'catégorie $name';
  }

  @override
  String get ruleDescStop => 'arrêter le traitement des autres règles';

  @override
  String get ruleDescAllMail => 'Tout le courrier';

  @override
  String ruleDescIf(String conditions) {
    return 'Si $conditions';
  }

  @override
  String ruleDescExcept(String exceptions) {
    return ', sauf si $exceptions';
  }

  @override
  String rulesNotRead(String error) {
    return 'Règles non lues : $error';
  }

  @override
  String get deleteRuleQuestion => 'Supprimer la règle ?';

  @override
  String deleteRuleContent(String name) {
    return 'La règle « $name » ne sera plus appliquée. Le courrier déjà trié reste où il est.';
  }

  @override
  String rulesNotSaved(String error) {
    return 'Règles non enregistrées : $error';
  }

  @override
  String get rulesAndAlerts => 'Règles et alertes';

  @override
  String get applyChangesToFolder => 'Appliquer les modifications à ce dossier';

  @override
  String get newRuleEllipsis => 'Nouvelle règle…';

  @override
  String get runRulesNowEllipsis => 'Exécuter les règles maintenant…';

  @override
  String get noRules =>
      'Aucune règle. Avec « Nouvelle règle… », le courrier entrant est trié automatiquement.';

  @override
  String get rulesInfo =>
      'Les règles s\'appliquent dans l\'ordre de la liste au courrier qui arrive dans la Boîte de réception pendant que PostinoVip est ouvert ; le courrier arrivé application fermée est trié à sa réouverture.';

  @override
  String get chooseFolderColon => 'Choisissez le dossier :';

  @override
  String get ruleNameRequired => 'Indiquez le nom de la règle.';

  @override
  String get ruleFolderRequired => 'Choisissez le dossier de destination.';

  @override
  String get ruleActionRequired =>
      'Choisissez au moins une action dans l\'onglet « Actions ».';

  @override
  String get ruleSizeRequired => 'Indiquez la taille en Ko.';

  @override
  String get ruleForAllMail => 'Règle pour tout le courrier';

  @override
  String get ruleForAllMailContent =>
      'Sans conditions, la règle s\'appliquera à tout le courrier que vous recevez. Est-ce correct ?';

  @override
  String get newRule => 'Nouvelle règle';

  @override
  String get editRule => 'Modifier la règle';

  @override
  String get ruleName => 'Nom de la règle';

  @override
  String get ruleConditions => 'Conditions';

  @override
  String get ruleActions => 'Actions';

  @override
  String get ruleExceptions => 'Exceptions';

  @override
  String get ruleConditionsIntro =>
      'Appliquer la règle au courrier qui remplit toutes les conditions sélectionnées :';

  @override
  String get ruleExceptionsIntro =>
      'Sauf si au moins l\'une de ces conditions est remplie :';

  @override
  String get ruleFrom => 'de';

  @override
  String get ruleFromHint => 'par ex. anne@example.com ; example.com';

  @override
  String get ruleToOrCc => 'À ou Cc contient';

  @override
  String get ruleToOrCcHint => 'noms ou adresses, séparés par ;';

  @override
  String get ruleMeInTo => 'mon adresse figure dans la zone À';

  @override
  String get ruleMeInCc => 'mon adresse figure dans la zone Cc';

  @override
  String get ruleSubjectContains => 'l\'objet contient';

  @override
  String get ruleSubjectOrBodyContains => 'l\'objet ou le corps contient';

  @override
  String get ruleWordsHint => 'mots séparés par ;';

  @override
  String get ruleLargerThan => 'de plus de';

  @override
  String get chooseFolderEllipsis => 'Choisir le dossier…';

  @override
  String get ruleActionsIntro =>
      'Que faire du courrier qui remplit les conditions :';

  @override
  String get ruleMoveTo => 'le déplacer vers le dossier';

  @override
  String get ruleMoveToTitle => 'Déplacer vers le dossier';

  @override
  String get ruleCopyTo => 'le copier dans le dossier';

  @override
  String get ruleCopyToTitle => 'Copier dans le dossier';

  @override
  String get ruleDeleteAction => 'le supprimer (vers Éléments supprimés)';

  @override
  String get ruleFlagAction => 'le marquer pour suivi';

  @override
  String get ruleCategoryAction => 'lui attribuer la catégorie';

  @override
  String get ruleStopAction => 'arrêter le traitement des autres règles';

  @override
  String rulesNotRun(String error) {
    return 'Règles non exécutées : $error';
  }

  @override
  String progressUnavailable(String error) {
    return 'Progression non disponible : $error';
  }

  @override
  String get runInFolder => 'Exécuter dans le dossier';

  @override
  String runStoppedError(String error) {
    return 'Arrêté à cause d\'une erreur : $error';
  }

  @override
  String runStoppedChecked(int checked, int total) {
    return 'Arrêté : $checked messages vérifiés sur $total';
  }

  @override
  String runDoneChecked(int checked) {
    return 'Terminé : $checked messages vérifiés';
  }

  @override
  String runOutcome(String head, int applied) {
    return '$head, $applied déplacés ou modifiés';
  }

  @override
  String runFailedActions(int count) {
    return ', $count actions en échec (détails dans le journal du core)';
  }

  @override
  String get runRulesNow => 'Exécuter les règles maintenant';

  @override
  String get rulesToRun => 'Sélectionnez les règles à exécuter :';

  @override
  String get ruleDisabledSuffix => ' (désactivée)';

  @override
  String get runInFolderLabel => 'Exécuter dans le dossier : ';

  @override
  String get includeSubfolders => 'Inclure les sous-dossiers';

  @override
  String get applyRulesTo => 'Appliquer les règles à';

  @override
  String get preparing => 'Préparation…';

  @override
  String runProgress(int checked, int total) {
    return '$checked messages vérifiés sur $total';
  }

  @override
  String get stopping => 'arrêt en cours…';

  @override
  String get stop => 'Arrêter';

  @override
  String get runNow => 'Exécuter maintenant';

  @override
  String settingsNotRead(String error) {
    return 'Paramètres non lus : $error';
  }

  @override
  String get autoReplyTextRequired =>
      'Rédigez le message de réponse automatique.';

  @override
  String get endAfterStart =>
      'L\'heure de fin doit être postérieure à l\'heure de début.';

  @override
  String get turnOnAutoRepliesQuestion => 'Activer les réponses automatiques ?';

  @override
  String get turnOnAutoRepliesContent =>
      'À partir de maintenant, PostinoVip répondra automatiquement, une fois par expéditeur, au courrier arrivant dans la Boîte de réception où vous figurez en À ou Cc, tant qu\'il reste ouvert. Les réponses sont envoyées sans vous le demander.';

  @override
  String get turnOn => 'Activer';

  @override
  String notSavedPlural(String error) {
    return 'Non enregistrées : $error';
  }

  @override
  String get dontSendAutoReplies => 'Ne pas envoyer de réponses automatiques';

  @override
  String get sendAutoReplies => 'Envoyer des réponses automatiques';

  @override
  String get onlyDuringRange => 'Envoyer uniquement pendant cette période';

  @override
  String get startTimeColon => 'Heure de début :';

  @override
  String get endTimeColon => 'Heure de fin :';

  @override
  String get autoRepliesInfo =>
      'Les réponses sont envoyées depuis cet ordinateur pendant que PostinoVip est ouvert (le courrier arrivé application fermée reçoit la réponse à sa réouverture) : une seule par expéditeur, uniquement si vous figurez en À ou Cc, jamais aux listes de diffusion, aux autres réponses automatiques ni aux expéditeurs comme « noreply ». Elles ne sont pas enregistrées dans Éléments envoyés.';

  @override
  String get autoReplyPlaceholder =>
      'par ex. Je suis absent du bureau jusqu\'au lundi 16 novembre et je vous répondrai à mon retour.';

  @override
  String get junkLevelNone => 'Pas de filtrage automatique';

  @override
  String get junkLevelNoneInfo =>
      'Le courrier des expéditeurs bloqués est toujours déplacé vers le dossier Courrier indésirable.';

  @override
  String get junkLevelLow => 'Faible';

  @override
  String get junkLevelLowInfo =>
      'Déplacer le courrier indésirable le plus évident : celui que le serveur a marqué comme spam.';

  @override
  String get junkLevelHigh => 'Élevé';

  @override
  String get junkLevelHighInfo =>
      'Déplacer aussi le courrier dont le score est proche du seuil du serveur : du courrier normal peut aussi être intercepté, vérifiez donc souvent le dossier Courrier indésirable.';

  @override
  String get junkLevelSafeOnly => 'Listes approuvées uniquement';

  @override
  String get junkLevelSafeOnlyInfo =>
      'Seul le courrier provenant de personnes ou de domaines de votre liste d\'expéditeurs approuvés, ou envoyé à votre liste de destinataires approuvés, reste dans la Boîte de réception.';

  @override
  String get safeSenders => 'Expéditeurs approuvés';

  @override
  String get safeSendersInfo =>
      'Le courrier provenant de ces adresses ou domaines ne sera jamais traité comme indésirable.';

  @override
  String get safeRecipients => 'Destinataires approuvés';

  @override
  String get safeRecipientsInfo =>
      'Le courrier envoyé à ces adresses ou domaines (par exemple une liste de diffusion) ne sera jamais traité comme indésirable.';

  @override
  String get blockedSenders => 'Expéditeurs bloqués';

  @override
  String get blockedSendersInfo =>
      'Le courrier provenant de ces adresses ou domaines sera toujours déplacé vers le dossier Courrier indésirable.';

  @override
  String get neverBlockSender => 'Ne jamais bloquer l\'expéditeur';

  @override
  String get neverBlockDomain =>
      'Ne jamais bloquer le domaine de l\'expéditeur';

  @override
  String get neverBlockGroup =>
      'Ne jamais bloquer ce groupe ou cette liste de diffusion';

  @override
  String get neverBlockGroups =>
      'Ne jamais bloquer ces groupes ou listes de diffusion';

  @override
  String get blockSender => 'Bloquer l\'expéditeur';

  @override
  String get junkOptionsEllipsis => 'Options du courrier indésirable…';

  @override
  String get noJunkFolder => 'Aucun dossier Courrier indésirable';

  @override
  String noJunkFolderContent(String name) {
    return 'Le compte « $name » n\'a pas de dossier Courrier indésirable : choisissez-en un dans « Options du courrier indésirable ». L\'expéditeur n\'a pas été bloqué.';
  }

  @override
  String get markAsNotJunk => 'Marquer comme courrier légitime';

  @override
  String notJunkMoveBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ces $count messages seront replacés dans le dossier Boîte de réception.',
      one: 'Ce message sera replacé dans le dossier Boîte de réception.',
    );
    return '$_temp0';
  }

  @override
  String alwaysTrustSender(String sender) {
    return 'Toujours faire confiance au courrier de « $sender »';
  }

  @override
  String get alwaysTrustSenders =>
      'Toujours faire confiance au courrier de ces expéditeurs';

  @override
  String optionsNotRead(String error) {
    return 'Options non lues : $error';
  }

  @override
  String optionsNotSaved(String error) {
    return 'Options non enregistrées : $error';
  }

  @override
  String get invalidValue => 'valeur non valide';

  @override
  String get junkOptions => 'Options du courrier indésirable';

  @override
  String get junkOptionsIntro =>
      'Le nouveau courrier de la Boîte de réception qui semble indésirable est déplacé vers un dossier spécial pendant que PostinoVip est ouvert. Le jugement est celui du serveur de messagerie. Choisissez le niveau de protection :';

  @override
  String get junkFolder => 'Dossier Courrier indésirable';

  @override
  String junkFolderAutomatic(String folder) {
    return 'Automatique : « $folder »';
  }

  @override
  String get junkFolderAutomaticNone => 'Automatique (aucun dossier trouvé)';

  @override
  String get junkFolderInfo =>
      'Automatique : celui indiqué par le serveur, ou un dossier dont le nom contient « spam », « junk » ou « indesiderata ». Pour un nouveau dossier : onglet Dossier → Nouveau dossier, puis choisissez-le ici.';

  @override
  String get junkNoFolderWarning =>
      'Sans dossier, le filtre ne déplace aucun courrier.';

  @override
  String get noEntries => 'Aucune entrée';

  @override
  String get addEllipsis => 'Ajouter…';

  @override
  String get trustContacts =>
      'Faire aussi confiance au courrier de mes contacts';

  @override
  String get junkEntryInvalid =>
      'Saisissez une adresse (anne@example.com) ou un domaine (@example.com).';

  @override
  String get addAddressOrDomain => 'Ajouter une adresse ou un domaine';

  @override
  String get editAddressOrDomain => 'Modifier l\'adresse ou le domaine';

  @override
  String get junkEntryLabel =>
      'Saisissez une adresse e-mail ou un nom de domaine Internet';

  @override
  String get junkEntryHint => 'par ex. anne@example.com ou @example.com';

  @override
  String get alreadyInArchive =>
      'Le message est déjà dans le dossier d\'archivage';

  @override
  String get archiveTooltip =>
      'Déplacer vers le dossier d\'archivage (Retour arrière)';

  @override
  String get mailsAlreadyInArchive =>
      'Les messages sont déjà dans le dossier d\'archivage';

  @override
  String get archiveFolderName => 'Archives';

  @override
  String get offlineUnavailable => 'Non disponible sans connexion au serveur.';

  @override
  String archiveFirstTime(String name) {
    return 'Le compte « $name » n\'a pas encore de dossier d\'archivage. Choisissez-le : Archiver y déplacera le courrier, sans le supprimer.';
  }

  @override
  String archiveInfo(String name) {
    return 'Archiver déplace le courrier de « $name » vers ce dossier, sans le supprimer.';
  }

  @override
  String get useExistingFolder => 'Utiliser un dossier existant';

  @override
  String get chooseAFolder => 'Choisissez un dossier';

  @override
  String get createTopFolder =>
      'Créer un nouveau dossier au niveau supérieur du compte';

  @override
  String get okAndArchive => 'OK et archiver';

  @override
  String get stopIgnore => 'Ne plus ignorer';

  @override
  String get ignore => 'Ignorer';

  @override
  String get stopIgnoreTooltip =>
      'La conversation revient dans la Boîte de réception et le nouveau courrier ne va plus dans Éléments supprimés';

  @override
  String get ignoreTooltip =>
      'Déplacer la conversation et les futurs messages vers Éléments supprimés';

  @override
  String cleanUpFolderContent(String name) {
    return 'Les messages redondants du dossier « $name » (ceux cités intégralement dans une réponse) seront déplacés vers Éléments supprimés. Les messages non lus, marqués, classés ou signés restent où ils sont.';
  }

  @override
  String get stopIgnoreContent =>
      'La conversation sélectionnée ne sera plus ignorée et ses messages dans Éléments supprimés seront déplacés vers la Boîte de réception.';

  @override
  String get ignoreContent =>
      'Les messages de la conversation sélectionnée dans ce dossier et tous les futurs messages seront déplacés vers Éléments supprimés.';

  @override
  String get dontShowAgain => 'Ne plus afficher ce message';

  @override
  String get notifyAlways => 'Toujours';

  @override
  String get notifyUnfocused =>
      'Uniquement quand la fenêtre n\'est pas au premier plan';

  @override
  String get notifyNever => 'Jamais';

  @override
  String get readImmediately => 'Dès son ouverture';

  @override
  String get readAfterDelay => 'Après quelques secondes d\'affichage';

  @override
  String get readManual => 'Jamais automatiquement (uniquement avec le bouton)';

  @override
  String get receiptAsk =>
      'Toujours demander avant d\'envoyer une confirmation de lecture';

  @override
  String get receiptAlways => 'Toujours envoyer une confirmation de lecture';

  @override
  String get receiptNever => 'Ne jamais envoyer de confirmation de lecture';

  @override
  String get categoryRed => 'Catégorie rouge';

  @override
  String get categoryOrange => 'Catégorie orange';

  @override
  String get categoryYellow => 'Catégorie jaune';

  @override
  String get categoryGreen => 'Catégorie verte';

  @override
  String get categoryBlue => 'Catégorie bleue';

  @override
  String get categoryPurple => 'Catégorie violette';

  @override
  String get followUpTomorrow => 'Demain';

  @override
  String get followUpThisWeek => 'Cette semaine';

  @override
  String get followUpNextWeek => 'La semaine prochaine';

  @override
  String get followUpNoDate => 'Pas de date';

  @override
  String get clearAllCategories => 'Effacer toutes les catégories';

  @override
  String get allCategoriesEllipsis => 'Toutes les catégories…';

  @override
  String get customDateEllipsis => 'Personnalisé…';

  @override
  String get markComplete => 'Marquer comme terminé';

  @override
  String get clearFlag => 'Effacer l\'indicateur';

  @override
  String get dueByTitle => 'Date d\'échéance';

  @override
  String get categoriesTitle => 'Catégories de couleurs';

  @override
  String get categoriesInfo =>
      'Les noms ne s\'appliquent que sur cet ordinateur ; sur le serveur, chaque catégorie est enregistrée avec sa couleur.';

  @override
  String get defaultNames => 'Noms par défaut';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Client de messagerie de bureau : interface en Flutter, core en C# avec MailKit.';

  @override
  String aboutLegal(String license) {
    return 'Ce programme est un logiciel libre : vous pouvez le redistribuer et/ou le modifier selon les termes de la $license, publiée par la Free Software Foundation.\n\nIl est distribué dans l\'espoir qu\'il sera utile, mais SANS AUCUNE GARANTIE ; sans même la garantie implicite de QUALITÉ MARCHANDE ou d\'ADÉQUATION À UN USAGE PARTICULIER. Le texte complet de la licence se trouve dans « Afficher les licences » → PostinoVip.';
  }

  @override
  String coreVersionUnavailable(String error) {
    return 'Core : version non disponible ($error)';
  }

  @override
  String coreVersion(String version) {
    return 'Core : version $version';
  }

  @override
  String get coreVersionMismatch =>
      'Attention : l\'application et le core ont des versions différentes (recompilez le core).';

  @override
  String get composeMessages => 'Composer des messages';

  @override
  String get composeInFormat => 'Composer les messages dans ce format';

  @override
  String get composeInFormatHelp =>
      'Pour les nouveaux messages ; les réponses et transferts utilisent le format du message d\'origine';

  @override
  String get signaturesSection => 'Signatures';

  @override
  String signatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signatures',
      one: '1 signature',
      zero: 'Aucune signature',
    );
    return '$_temp0';
  }

  @override
  String get signaturesInfo =>
      'Ajoutées automatiquement aux nouveaux messages et aux réponses, par compte';

  @override
  String get markAsReadSection => 'Marquer comme lu';

  @override
  String get readReceiptsSection => 'Confirmations de lecture';

  @override
  String get alwaysRequestReceipt =>
      'Toujours demander une confirmation de lecture pour les nouveaux messages';

  @override
  String get receiptForReceived =>
      'Pour tout message reçu contenant une demande de confirmation de lecture :';

  @override
  String get confirmBeforeIgnore => 'Demander avant Ignorer la conversation';

  @override
  String get confirmBeforeStopIgnoring =>
      'Demander avant Ne plus ignorer la conversation';

  @override
  String get newMailNotifications => 'Notifications de nouveau courrier';

  @override
  String get notificationsUnavailable =>
      'Notifications système non disponibles : la raison se trouve dans le terminal (« [notifiche] »).';

  @override
  String get testNotification => 'Notification de test';

  @override
  String get testNotificationText =>
      'Notification de test : si vous la voyez, les notifications fonctionnent.';

  @override
  String get firstDayOfWeek => 'Premier jour de la semaine';

  @override
  String get workDays => 'Jours ouvrables (Semaine de travail)';

  @override
  String get workStart => 'Début des heures de travail';

  @override
  String get workEnd => 'Fin des heures de travail';

  @override
  String receiptNotSent(String error) {
    return 'Confirmation de lecture non envoyée : $error';
  }

  @override
  String receiptNotRecorded(String error) {
    return 'Confirmation de lecture non enregistrée : $error';
  }

  @override
  String operationFailed(String error) {
    return 'Échec de l\'opération : $error';
  }

  @override
  String get outboxSending =>
      'Envoi : le message part dès que le serveur répond.';

  @override
  String get outboxDeleted =>
      'Message supprimé de la Boîte d\'envoi : il ne sera pas envoyé.';

  @override
  String get outboxMovedToDrafts =>
      'Message déplacé vers Brouillons : ouvrez-le depuis là pour le modifier.';

  @override
  String folderNotListed(String folder) {
    return 'Le serveur a confirmé le dossier « $folder », mais ne l\'affiche pas dans la liste des dossiers.';
  }

  @override
  String get anotherOperation => 'Une autre opération est en cours';

  @override
  String folderDeletedPermanently(String folder) {
    return 'Dossier « $folder » supprimé définitivement';
  }

  @override
  String folderMovedToTrash(String folder) {
    return 'Dossier « $folder » déplacé vers Éléments supprimés';
  }

  @override
  String folderNotDeleted(String error) {
    return 'Dossier non supprimé : $error';
  }

  @override
  String folderEmptied(String folder, String mails, String folders) {
    return '« $folder » vidé : $mails$folders supprimés définitivement';
  }

  @override
  String emptiedMails(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String emptiedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' et $count dossiers',
      one: ' et 1 dossier',
    );
    return '$_temp0';
  }

  @override
  String folderNotEmptied(String error) {
    return 'Dossier non vidé : $error';
  }

  @override
  String folderMovedToTop(String folder) {
    return 'Dossier « $folder » déplacé au niveau supérieur du compte';
  }

  @override
  String folderMovedInto(String folder, String parent) {
    return 'Dossier « $folder » déplacé dans « $parent »';
  }

  @override
  String folderNotMoved(String error) {
    return 'Dossier non déplacé : $error';
  }

  @override
  String get mailNotDownloadedOffline =>
      'Message non disponible hors connexion : il n\'a pas encore été téléchargé sur cet ordinateur.';

  @override
  String readStateNotUpdated(String error) {
    return 'État lu/non lu non mis à jour : $error';
  }

  @override
  String tagsNotUpdated(String error) {
    return 'Indicateur ou catégories non mis à jour : $error';
  }

  @override
  String movedTo(String folder) {
    return 'Déplacé vers « $folder »';
  }

  @override
  String get deletedPermanently => 'Supprimé définitivement';

  @override
  String markedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages marqués comme lus',
      one: '1 message marqué comme lu',
    );
    return '$_temp0';
  }

  @override
  String markedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages marqués comme non lus',
      one: '1 message marqué comme non lu',
    );
    return '$_temp0';
  }

  @override
  String othersFailed(String text, String error) {
    return '$text ; les autres ont échoué : $error';
  }

  @override
  String readNotUpdated(String error) {
    return 'État de lecture non mis à jour : $error';
  }

  @override
  String mailsMovedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages déplacés',
      one: '1 message déplacé',
    );
    return '$_temp0 vers « $folder »';
  }

  @override
  String mailsDeletedPermanently(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages supprimés',
      one: '1 message supprimé',
    );
    return '$_temp0 définitivement';
  }

  @override
  String mailsMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages déplacés',
      one: '1 message déplacé',
    );
    return '$_temp0 vers Éléments supprimés';
  }

  @override
  String mailsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages archivés',
      one: '1 message archivé',
    );
    return '$_temp0';
  }

  @override
  String get conversationIgnored =>
      'Conversation ignorée : les futurs messages iront dans Éléments supprimés';

  @override
  String conversationIgnoredMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages déplacés',
      one: '1 message déplacé',
    );
    return '$_temp0 vers Éléments supprimés ; les futurs messages iront aussi là';
  }

  @override
  String get conversationNotIgnored => 'La conversation n\'est plus ignorée';

  @override
  String mailsBackToInbox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages replacés',
      one: '1 message replacé',
    );
    return '$_temp0 dans la Boîte de réception';
  }

  @override
  String cleanUpDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages redondants déplacés vers Éléments supprimés',
      one: '1 message redondant déplacé vers Éléments supprimés',
      zero: 'Aucun message redondant à déplacer',
    );
    return '$_temp0';
  }

  @override
  String get noMailMoved => 'Aucun message déplacé';

  @override
  String mailsMovedToJunk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages déplacés',
      one: '1 message déplacé',
    );
    return '$_temp0 vers Courrier indésirable';
  }

  @override
  String senderBlocked(String sender) {
    return '$sender bloqué';
  }

  @override
  String sendersBlocked(int count, String senders) {
    return '$count expéditeurs bloqués ($senders)';
  }

  @override
  String senderTrusted(String sender) {
    return '$sender approuvé';
  }

  @override
  String sendersTrusted(int count, String senders) {
    return '$count expéditeurs approuvés ($senders)';
  }

  @override
  String addedToSafeSenders(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries ajoutés',
      one: '$entries ajouté',
    );
    return '$_temp0 aux expéditeurs approuvés';
  }

  @override
  String addedToSafeRecipients(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries ajoutés',
      one: '$entries ajouté',
    );
    return '$_temp0 aux destinataires approuvés';
  }

  @override
  String listsNotUpdated(String error) {
    return 'Listes non mises à jour : $error';
  }

  @override
  String mailsCopiedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages copiés',
      one: '1 message copié',
    );
    return '$_temp0 dans « $folder »';
  }

  @override
  String mailsNotCopied(String error) {
    return 'Messages non copiés : $error';
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
  String get groupNoDate => 'Aucune date';

  @override
  String get groupYesterday => 'Hier';

  @override
  String get groupLastWeek => 'La semaine dernière';

  @override
  String get groupTwoWeeksAgo => 'Il y a deux semaines';

  @override
  String get groupThreeWeeksAgo => 'Il y a trois semaines';

  @override
  String get groupEarlierThisMonth => 'Plus tôt ce mois-ci';

  @override
  String get groupLastMonth => 'Le mois dernier';

  @override
  String get groupOlder => 'Plus anciens';

  @override
  String get sizeTiny => 'Minuscule (< 10 Ko)';

  @override
  String get sizeSmall => 'Petit (10 - 25 Ko)';

  @override
  String get sizeMedium => 'Moyen (25 - 100 Ko)';

  @override
  String get sizeLarge => 'Grand (100 - 500 Ko)';

  @override
  String get sizeVeryLarge => 'Très grand (500 Ko - 1 Mo)';

  @override
  String get sizeHuge => 'Énorme (1 - 5 Mo)';

  @override
  String get sizeEnormous => 'Gigantesque (> 5 Mo)';

  @override
  String sizeBytes(int count) {
    return '$count octets';
  }

  @override
  String get fmtMonthYear => 'MMMM y';

  @override
  String get fmtFullDate => 'EEEE d MMMM y';

  @override
  String get fmtHour => 'HH:00';

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
  String get recurOrdinalFirst => 'le premier';

  @override
  String get recurOrdinalSecond => 'le deuxième';

  @override
  String get recurOrdinalThird => 'le troisième';

  @override
  String get recurOrdinalFourth => 'le quatrième';

  @override
  String get recurOrdinalLast => 'le dernier';

  @override
  String recurDescDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tous les $count jours',
      one: 'Tous les jours',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toutes les $count semaines',
      one: 'Toutes les semaines',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeeklyOn(String every, String days) {
    return '$every le $days';
  }

  @override
  String recurDescMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tous les $count mois',
      one: 'Tous les mois',
    );
    return '$_temp0';
  }

  @override
  String recurDescMonthlyDay(String every, int day) {
    return '$every le $day';
  }

  @override
  String recurDescMonthlyWhich(String every, String which) {
    return '$every $which';
  }

  @override
  String recurDescYearlyWhich(String which, String month) {
    return 'Chaque année $which de $month';
  }

  @override
  String recurDescYearlyDay(String day, String month) {
    return 'Chaque année le $day $month';
  }

  @override
  String get recurDescRecurring => 'Périodique';

  @override
  String recurDescTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count fois',
      one: ', 1 fois',
    );
    return '$_temp0';
  }

  @override
  String recurDescUntil(String date) {
    return ', jusqu\'au $date';
  }

  @override
  String whenAllDay(String date) {
    return '$date (toute la journée)';
  }

  @override
  String whenAllDayRange(String start, String end) {
    return 'Du $start au $end (toute la journée)';
  }

  @override
  String get coreKindInvalidRequest => 'Requête non valide';

  @override
  String get coreKindNotFound => 'Introuvable';

  @override
  String get coreKindOffline => 'Non connecté';

  @override
  String get coreKindServer => 'Erreur du serveur de messagerie';

  @override
  String get coreKindConflict => 'Opération non autorisée';

  @override
  String get coreKindNotSupported => 'Non pris en charge par le serveur';

  @override
  String get coreKindCertificate => 'Certificat du serveur non valide';

  @override
  String get coreKindOAuth => 'Échec de la connexion au compte';

  @override
  String get coreKindAuth =>
      'Échec de l\'authentification auprès du serveur de messagerie';

  @override
  String get coreKindConfig => 'Configuration non valide';

  @override
  String get coreKindInternal => 'Erreur interne';

  @override
  String certNameMismatch(String host) {
    return 'délivré à un nom autre que $host';
  }

  @override
  String get certUntrustedRoot =>
      'non signé par une autorité reconnue (par ex. auto-signé)';

  @override
  String get certNotTimeValid => 'expiré ou pas encore valide';

  @override
  String get certRevoked => 'révoqué';

  @override
  String get certChainInvalid => 'chaîne de certificats non valide';

  @override
  String get certNoCertificate => 'aucun certificat';

  @override
  String get coreTimeout =>
      'Le serveur ne répond pas : l\'opération n\'a peut-être pas été effectuée.';

  @override
  String get coreAuthCheckCredentials =>
      'Vérifiez le nom d\'utilisateur et le mot de passe.';

  @override
  String get coreInternalUnexpected =>
      'Erreur inattendue, consultez le journal du core.';

  @override
  String coreCertificateChanged(String address, String problems) {
    return 'Certificat non valide pour $address ($problems). Ouvrez les paramètres du compte et relancez « Tester les paramètres du compte ».';
  }

  @override
  String coreTestCertificateInvalid(String address, String problems) {
    return 'Le certificat du serveur $address n\'est pas valide : $problems.';
  }

  @override
  String coreTestNoStartTls(String address) {
    return 'Le serveur $address ne propose pas STARTTLS : choisissez un autre chiffrement ou un autre port.';
  }

  @override
  String get coreTestAuthRejected =>
      'Authentification refusée : vérifiez l\'adresse et le mot de passe.';

  @override
  String coreTestTlsFailed(String address) {
    return 'Échec de la connexion chiffrée à $address : le port utilise-t-il vraiment ce chiffrement ?';
  }

  @override
  String coreTestUnreachable(String address) {
    return 'Serveur $address inaccessible.';
  }

  @override
  String coreTestNoAnswer(String address, String seconds) {
    return 'Aucune réponse de $address en $seconds s : serveur, port ou chiffrement incorrect ?';
  }

  @override
  String coreTestUnexpectedAnswer(String address) {
    return 'Réponse inattendue de $address : port ou protocole incorrect ?';
  }

  @override
  String corePop3NoUidl(String address) {
    return 'Le serveur POP3 $address ne prend pas en charge UIDL : c\'est nécessaire pour ne pas télécharger le courrier deux fois.';
  }

  @override
  String coreOAuthServerUnreachable(String provider) {
    return 'Serveur de connexion de $provider inaccessible.';
  }

  @override
  String coreOAuthInvalidResponse(String provider, String status) {
    return 'Réponse non valide du serveur de connexion de $provider (HTTP $status).';
  }

  @override
  String coreOAuthExpired(String provider) {
    return 'Connexion à $provider expirée ou révoquée : relancez « Se connecter avec $provider ».';
  }

  @override
  String coreOAuthClientInvalid(String provider) {
    return 'PostinoVip n\'est pas correctement inscrit auprès de $provider (ID client).';
  }

  @override
  String coreOAuthFailed(String provider, String error) {
    return 'Échec de la connexion à $provider ($error).';
  }

  @override
  String get coreOAuthCancelled => 'Connexion annulée.';

  @override
  String get coreOAuthNoCode => 'Échec de la connexion (aucun code).';

  @override
  String coreOAuthFlowFailed(String error) {
    return 'Échec de la connexion ($error).';
  }

  @override
  String get coreOAuthNoRefreshToken =>
      'Le fournisseur n\'a pas fourni de jeton d\'actualisation (offline_access manquant ?).';

  @override
  String coreServerUnreachable(String reason) {
    return 'Serveur inaccessible ($reason).';
  }

  @override
  String corePop3NoAnswer(String address) {
    return 'Serveur POP3 $address inaccessible (aucune réponse).';
  }

  @override
  String corePop3Unreachable(String address, String reason) {
    return 'Serveur POP3 $address inaccessible ($reason).';
  }

  @override
  String coreSmtpNoAnswer(String seconds) {
    return 'Serveur sortant inaccessible (aucune réponse en $seconds s) : message non envoyé.';
  }

  @override
  String coreSmtpUnreachable(String reason) {
    return 'Serveur sortant inaccessible ($reason) : message non envoyé.';
  }

  @override
  String get coreContactsServerUnreachable =>
      'Serveur de contacts inaccessible.';

  @override
  String get coreCalendarServerUnreachable =>
      'Serveur de calendrier inaccessible.';

  @override
  String get coreContactsServerNoAnswer =>
      'Le serveur de contacts ne répond pas.';

  @override
  String get coreCalendarServerNoAnswer =>
      'Le serveur de calendrier ne répond pas.';

  @override
  String coreDavSignInRejectedContacts(String provider) {
    return '$provider a refusé l\'accès au serveur de contacts : relancez « Se connecter avec $provider » en autorisant l\'accès aux contacts.';
  }

  @override
  String coreDavSignInRejectedCalendar(String provider) {
    return '$provider a refusé l\'accès au serveur de calendrier : relancez « Se connecter avec $provider » en autorisant l\'accès au calendrier.';
  }

  @override
  String coreDavScopeMissingContacts(String provider) {
    return 'La connexion avec $provider n\'inclut pas l\'autorisation pour les contacts : relancez « Se connecter avec $provider ».';
  }

  @override
  String coreDavScopeMissingCalendar(String provider) {
    return 'La connexion avec $provider n\'inclut pas l\'autorisation pour le calendrier : relancez « Se connecter avec $provider ».';
  }

  @override
  String coreAccountScopeMissingContacts(String provider) {
    return 'La connexion avec $provider n\'inclut pas les contacts : dans la fenêtre du compte, utilisez « Se reconnecter » et autorisez l\'accès aux contacts.';
  }

  @override
  String coreAccountScopeMissingCalendar(String provider) {
    return 'La connexion avec $provider n\'inclut pas le calendrier : dans la fenêtre du compte, utilisez « Se reconnecter » et autorisez l\'accès au calendrier.';
  }

  @override
  String get coreNotConnected => 'non connecté';

  @override
  String coreUnreachableApp(String address, String error) {
    return 'Core de PostinoVip inaccessible à $address : $error';
  }

  @override
  String get coreUnexpectedResponse => 'Réponse inattendue du core';

  @override
  String get coreUnexpectedResponseVersions =>
      'Réponse inattendue du core (versions différentes de l\'application et du core ?)';

  @override
  String get coreEventsUnavailable => 'Événements non disponibles';

  @override
  String coreUnexpectedFormat(String path, String error) {
    return 'Réponse du core dans un format inattendu ($path) : $error. Le core est-il à jour et redémarré ?';
  }

  @override
  String get imagePlaceholder => 'image';

  @override
  String get coreErrScrivereIlNomeDellaCartella =>
      'Indiquez le nom du dossier.';

  @override
  String coreErrIlNomePuoAvereAl(String maxLength) {
    return 'Le nom peut comporter au maximum $maxLength caractères.';
  }

  @override
  String get coreErrIlNomeContieneCaratteriNon =>
      'Le nom contient des caractères non valides.';

  @override
  String coreErrIlNomeNonPuoContenere(String separator) {
    return 'Le nom ne peut pas contenir le caractère « $separator ».';
  }

  @override
  String get coreErrInboxIlNomeRiservatoDella =>
      '« INBOX » est le nom réservé de la Boîte de réception.';

  @override
  String get coreErrIlMessaggioOriginaleDisponibileSolo =>
      'Le message d\'origine n\'est disponible qu\'avec la copie locale.';

  @override
  String get coreErrCartellaNonValida => 'Dossier non valide.';

  @override
  String get coreErrLaMailNonChiedeUna =>
      'Le message ne demande pas de confirmation de lecture à cette adresse.';

  @override
  String get coreErrLivelloDelFiltroNonValido => 'Niveau de filtre non valide.';

  @override
  String get coreErrNessunaCartellaDellaPostaIndesiderata =>
      'Aucun dossier Courrier indésirable : choisissez-le dans « Options du courrier indésirable ».';

  @override
  String get coreErrNessunMittenteDaBloccareLe =>
      'Aucun expéditeur à bloquer (les messages ont été envoyés depuis ce compte ou n\'ont pas d\'expéditeur).';

  @override
  String get coreErrNonPostaIndesiderataValeSolo =>
      '« Courrier légitime » ne s\'applique qu\'aux messages du dossier Courrier indésirable.';

  @override
  String coreErrNessunaDelleMailIndicateIn(String folder) {
    return 'Aucun des messages indiqués ne se trouve dans \'$folder\'.';
  }

  @override
  String get coreErrIlServerPop3NonSupporta =>
      'Le serveur POP3 ne prend pas en charge UIDL : sans cela, impossible de savoir quels messages ont déjà été téléchargés.';

  @override
  String get coreErrIdNonValido => 'Id non valide.';

  @override
  String get coreErrHostSmtpNonConfigurato => 'Hôte SMTP non configuré.';

  @override
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2) {
    return 'Pièces jointes trop volumineuses : $value Mo, maximum $value2 Mo.';
  }

  @override
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel) {
    return 'Le $serverLabel a refusé la requête (403).';
  }

  @override
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  ) {
    return 'Adresse du $value non autorisée : https est obligatoire ($scheme://$host).';
  }

  @override
  String get coreErrNessunCalendarioTrovatoSulServer =>
      'Aucun calendrier trouvé sur le serveur de calendrier.';

  @override
  String get coreErrNessunaRubricaTrovataSulServer =>
      'Aucun carnet d\'adresses trouvé sur le serveur de contacts.';

  @override
  String coreErrIlHaCreatoElementoSenza(String serverLabel) {
    return 'Le $serverLabel a créé l\'élément sans indiquer où (Location manquant).';
  }

  @override
  String coreErrIlHaCreatoElementoFuori(String serverLabel) {
    return 'Le $serverLabel a créé l\'élément hors de la collection.';
  }

  @override
  String coreErrTroppiReindirizzamentiDal(String serverLabel) {
    return 'Trop de redirections du $serverLabel.';
  }

  @override
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel) {
    return 'Le $serverLabel a refusé le nom d\'utilisateur ou le mot de passe.';
  }

  @override
  String coreErrCertificatoDelNonValido(String serverLabel) {
    return 'Certificat du $serverLabel non valide.';
  }

  @override
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  ) {
    return 'Le $serverLabel a répondu $code $reasonPhrase.';
  }

  @override
  String coreErrRispostaDelNonLeggibile(String serverLabel) {
    return 'Réponse illisible du $serverLabel.';
  }

  @override
  String get coreErrIlFileNonUnaMail =>
      'Le fichier n\'est pas un message lisible (.eml).';

  @override
  String get coreErrIlFileNonUnaMail2 =>
      'Le fichier n\'est pas un message (.eml) : expéditeur, date, objet et destinataires manquent.';

  @override
  String get coreErrIlFileEmlNonPiu =>
      'Le fichier .eml n\'est plus ouvert : ouvrez-le à nouveau.';

  @override
  String coreErrAccountNonTrovato(String id) {
    return 'Compte \'$id\' introuvable.';
  }

  @override
  String coreErrAccountUnAccountPop3Richiede(String id) {
    return 'Compte \'$id\' : un compte POP3 nécessite la copie locale (Cache:Enabled=false n\'est pas possible).';
  }

  @override
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider) {
    return 'Compte \'$id\' : fournisseur OAuth inconnu \'$provider\'.';
  }

  @override
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  ) {
    return 'Compte \'$id\' : l\'ID client de $displayName manque (section OAuth:$id2).';
  }

  @override
  String get coreErrNessunAccountConfigurato => 'Aucun compte configuré.';

  @override
  String coreErrIdAccountNonValidoAmmessi(String id) {
    return 'Id de compte non valide : \'$id\' (lettres, chiffres, \'-\' et \'_\' autorisés, 64 au maximum).';
  }

  @override
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths) {
    return 'Compte \'$id\' : limite de la copie locale non valide ($bodyMonths mois ; 0 = tout).';
  }

  @override
  String coreErrAccountIndirizzoNonValido(String id, String name) {
    return 'Compte \'$id\' : adresse $name non valide.';
  }

  @override
  String coreErrAccount(String id, String message) {
    return 'Compte \'$id\' : $message';
  }

  @override
  String coreErrIdAccountRipetuto(String key) {
    return 'Id de compte en double : \'$key\'.';
  }

  @override
  String coreErrCartellaNonTrovata(String fullName) {
    return 'Dossier \'$fullName\' introuvable.';
  }

  @override
  String coreErrLaCartellaEsisteGia(String fullName) {
    return 'Le dossier \'$fullName\' existe déjà.';
  }

  @override
  String coreErrCartellaNonTrovata2(String parent) {
    return 'Dossier \'$parent\' introuvable.';
  }

  @override
  String coreErrCartellaNonTrovata3(String folder) {
    return 'Dossier \'$folder\' introuvable.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn(String uid, String folder) {
    return 'Message $uid introuvable dans \'$folder\'.';
  }

  @override
  String coreErrLaCartellaEsisteGia2(String newFullName) {
    return 'Le dossier \'$newFullName\' existe déjà.';
  }

  @override
  String get coreErrCartellaNonIndicata => 'Dossier non indiqué.';

  @override
  String coreErrCartellaNonValida2(String fullName) {
    return 'Dossier \'$fullName\' non valide.';
  }

  @override
  String coreErrCartellaAssenteDallIndiceDopo(String folder) {
    return 'Dossier \'$folder\' absent de l\'index après la synchronisation.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid) {
    return 'Pièce jointe $index introuvable dans le message $uid.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid) {
    return 'Pièce jointe $i introuvable dans le message $uid.';
  }

  @override
  String get coreErrCartellaDiOrigineDestinazioneCoincidono =>
      'Les dossiers d\'origine et de destination sont identiques.';

  @override
  String get coreErrIlMessaggioGiaInPosta =>
      'Le message est déjà dans Éléments supprimés : utilisez la suppression définitive.';

  @override
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn =>
      'La suppression définitive n\'est autorisée que dans Éléments supprimés.';

  @override
  String coreErrNonPuoAndareDentroSe(String folder) {
    return '\'$folder\' ne peut pas aller dans lui-même ni dans l\'un de ses sous-dossiers.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special) {
    return '\'$folder\' contient le dossier spécial \'$special\' : il n\'est pas vidé.';
  }

  @override
  String coreErrNessunaCartellaLocaleConRuolo(String role) {
    return 'Aucun dossier local avec le rôle $role.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName) {
    return 'Message $uid introuvable dans \'$fullName\'.';
  }

  @override
  String coreErrNessunaRispostaIn(String totalSeconds) {
    return 'aucune réponse en $totalSeconds s';
  }

  @override
  String get coreErrHostImapNonConfigurato => 'Hôte IMAP non configuré.';

  @override
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName) {
    return 'Message $uid introuvable dans \'$folderName\'.';
  }

  @override
  String coreErrIlServerNonPermetteDi(String value, String folderName) {
    return 'Le serveur ne permet pas d\'enregistrer les mots-clés $value dans \'$folderName\'.';
  }

  @override
  String get coreErrIlServerNonDichiaraUna =>
      'Le serveur ne déclare pas de dossier \\Sent (Éléments envoyés) : copie non enregistrée.';

  @override
  String get coreErrIlServerNonDichiaraUna2 =>
      'Le serveur ne déclare pas de dossier \\Drafts (Brouillons) : brouillon non enregistré.';

  @override
  String get coreErrIlServerNonDichiaraUna3 =>
      'Le serveur ne déclare pas de dossier \\Drafts (Brouillons).';

  @override
  String get coreErrIlServerNonDichiaraUna4 =>
      'Le serveur ne déclare pas de dossier \\Trash (Éléments supprimés).';

  @override
  String get coreErrIlServerNonSupportaMove =>
      'Le serveur ne prend en charge ni MOVE ni UIDPLUS : opération refusée pour ne pas supprimer d\'autres messages.';

  @override
  String coreErrLaCartellaNonPuoContenere(String fullName) {
    return 'Le dossier \'$fullName\' ne peut pas contenir de sous-dossiers.';
  }

  @override
  String coreErrIlServerNonHaCreato(String clean) {
    return 'Le serveur n\'a pas créé le dossier \'$clean\'.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  ) {
    return '\'$fullName\' contient le dossier spécial \'$fullName2\' : il n\'est pas vidé.';
  }

  @override
  String coreErrNonPuoAndareDentroSe2(String fullName) {
    return '\'$fullName\' ne peut pas aller dans lui-même ni dans l\'un de ses sous-dossiers.';
  }

  @override
  String coreErrUnaCartellaSpecialeNonSi(String fullName) {
    return '\'$fullName\' est un dossier spécial : il ne peut être ni renommé, ni déplacé, ni supprimé.';
  }

  @override
  String coreErrCartellaNonTrovata4(String folderName) {
    return 'Dossier \'$folderName\' introuvable.';
  }

  @override
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  ) {
    return 'structure (BODYSTRUCTURE) illisible dans un groupe de $count messages de $fullName : ignoré, le message défectueux sera recherché en arrière-plan ($message)';
  }

  @override
  String get coreErrFiltroDaLeggereOrdineDal =>
      'Le filtre « Non lus » et l\'ordre du plus ancien au plus récent nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrLeConversazioniRichiedonoLaCache =>
      'Les conversations nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrLaRicercaRichiedeLaCache =>
      'La recherche nécessite la copie locale (Cache:Enabled=false).';

  @override
  String coreErrCorpoAppenaSalvatoNonRileggibile(
    String folderName,
    String uid,
  ) {
    return 'Corps $folderName/$uid tout juste enregistré et illisible.';
  }

  @override
  String coreErrCartellaAssenteDallaCacheDopo(String fullName) {
    return 'Dossier \'$fullName\' absent de la copie locale après la synchronisation.';
  }

  @override
  String get coreErrImprontaSha256NonValida => 'Empreinte SHA-256 non valide.';

  @override
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id) {
    return 'Le compte \'$id\' est toujours configuré : pour vider sa copie locale, utilisez « Reconstruire la copie locale ».';
  }

  @override
  String coreErrNessunDatoLocalePerAccount(String id) {
    return 'Aucune donnée locale pour le compte \'$id\'.';
  }

  @override
  String get coreErrIgnoraPulisciRichiedonoLaCopia =>
      'Ignorer et Nettoyer nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaPostaEliminataIn =>
      'Aucun dossier Éléments supprimés dans ce compte.';

  @override
  String get coreErrLaConversazioneNonIgnorata =>
      'La conversation n\'est pas ignorée.';

  @override
  String get coreErrPulisciNonValePerPosta =>
      'Nettoyer ne s\'applique pas à Éléments supprimés ni à Courrier indésirable.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia =>
      'Les règles nécessitent la copie locale.';

  @override
  String coreErrAlMassimoRegolePerAccount(String maxRules) {
    return 'Au maximum $maxRules règles par compte.';
  }

  @override
  String get coreErrOgniRegolaDeveAvereUn => 'Chaque règle doit avoir un nom.';

  @override
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength) {
    return '« $name… » : le nom peut comporter au maximum $maxNameLength caractères.';
  }

  @override
  String coreErrEliminaSpostaInsiemeNonHanno(String name) {
    return '« $name » : « Supprimer » et « Déplacer » ensemble n\'ont pas de sens, choisissez-en un.';
  }

  @override
  String coreErrCategoriaNonValida(String name) {
    return '« $name » : catégorie non valide.';
  }

  @override
  String coreErrDimensioneNonValida(String rule) {
    return '« $rule » : taille non valide.';
  }

  @override
  String coreErrTroppeParoleParoleTroppoLunghe(String rule) {
    return '« $rule » : trop de mots ou mots trop longs.';
  }

  @override
  String get coreErrScrivereIlMessaggioDellaRisposta =>
      'Rédigez le message de réponse automatique.';

  @override
  String get coreErrLaFineDeveVenireDopo =>
      'La fin doit être postérieure au début.';

  @override
  String get coreErrIlMessaggioTroppoLungo => 'Le message est trop long.';

  @override
  String get coreErrContattoNonTrovato => 'Contact introuvable.';

  @override
  String coreErrLaRubricaHaGiaContatti(String maxContacts) {
    return 'Le carnet d\'adresses contient déjà $maxContacts contacts.';
  }

  @override
  String get coreErrFormatoNonRiconosciutoUsareVcf =>
      'Format non reconnu : utilisez vcf ou csv.';

  @override
  String coreErrIndirizzoNonValido(String address) {
    return 'Adresse non valide : $address';
  }

  @override
  String get coreErrScrivereAlmenoUnNomeLa =>
      'Indiquez au moins un nom, la société ou une adresse.';

  @override
  String get coreErrCalendarioNonTrovato => 'Calendrier introuvable.';

  @override
  String get coreErrAppuntamentoNonValido => 'Rendez-vous non valide.';

  @override
  String get coreErrAppuntamentoNonTrovato => 'Rendez-vous introuvable.';

  @override
  String get coreErrEsisteGiaUnAppuntamentoCon =>
      'Un rendez-vous avec le même UID existe déjà.';

  @override
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems) {
    return 'Le calendrier contient déjà $maxItems rendez-vous.';
  }

  @override
  String coreErrPeriodoNonValidoAlMassimo(String maxDays) {
    return 'Période non valide : au maximum $maxDays jours, avec la fin après le début.';
  }

  @override
  String get coreErrAppuntamentoNonLeggibile => 'Rendez-vous illisible.';

  @override
  String get coreErrOccorrenzaNonValida => 'Occurrence non valide.';

  @override
  String get coreErrSerieNonTrovata => 'Série introuvable.';

  @override
  String get coreErrAppuntamentoNonRicorrenteSiModifica =>
      'Le rendez-vous n\'est pas périodique : il est modifié en entier.';

  @override
  String get coreErrAlMassimo20000Caratteri => 'Au maximum 20000 caractères.';

  @override
  String get coreErrPromemoriaNonValidoDaMinuti =>
      'Rappel non valide (de 0 minute à 4 semaines avant).';

  @override
  String get coreErrLaFinePrimaDellInizio => 'La fin est antérieure au début.';

  @override
  String get coreErrSerializzazioneNonRiuscita => 'Échec de la sérialisation.';

  @override
  String coreErrMancaIlClientIdDi(String displayName, String id) {
    return 'L\'ID client de $displayName manque : l\'application doit être inscrite et l\'ID écrit dans oauth-clients.json (section OAuth:$id).';
  }

  @override
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName) {
    return 'La synchronisation des contacts n\'est pas disponible avec $displayName.';
  }

  @override
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName) {
    return 'La synchronisation du calendrier n\'est pas disponible avec $displayName.';
  }

  @override
  String coreErrAllegatoNonTrovato(String i) {
    return 'Pièce jointe $i introuvable.';
  }

  @override
  String get coreErrIndicareLaCartellaDelMessaggio =>
      'Indiquez le dossier du message d\'origine.';

  @override
  String coreErrModalitaNonValidaReplyReplyall(String mode) {
    return 'Mode non valide : $mode (reply, replyAll, forward).';
  }

  @override
  String coreErrMancantePiuCortoDiCaratteri(
    String configKey,
    String minLength,
  ) {
    return '$configKey manquant ou de moins de $minLength caractères.';
  }

  @override
  String get coreErrCartellaDeiDatiDellUtente =>
      'Impossible de déterminer le dossier de données de l\'utilisateur (HOME non défini ?) : utilisez Cache:Directory.';

  @override
  String get coreErrIndicareAlmenoUnaMail => 'Indiquez au moins un message.';

  @override
  String coreErrAlMassimoMailPerVolta(String maxBatch) {
    return 'Au maximum $maxBatch messages à la fois.';
  }

  @override
  String coreErrAllegatoNonTrovato2(String index) {
    return 'Pièce jointe $index introuvable.';
  }

  @override
  String get coreErrUnaCategoriaNonPuoEssere =>
      'Une catégorie ne peut pas être ajoutée et retirée en même temps.';

  @override
  String get coreErrIndicareLaCartellaDiDestinazione =>
      'Indiquez le dossier de destination.';

  @override
  String get coreErrLaScadenzaValeSoloCon =>
      'L\'échéance ne s\'applique qu\'avec followUp « flagged ».';

  @override
  String get coreErrLeRisposteAutomaticheRichiedonoLa =>
      'Les réponses automatiques nécessitent la copie locale.';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa =>
      'Le courrier indésirable nécessite la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa2 =>
      'Le courrier indésirable nécessite la copie locale.';

  @override
  String get coreErrLaCartellaSceltaNonEsiste =>
      'Le dossier choisi n\'existe pas.';

  @override
  String get coreErrScegliereUnaCartellaDiversaDa =>
      'Choisissez un dossier autre que Boîte de réception, Éléments envoyés, Brouillons et Éléments supprimés.';

  @override
  String get coreErrLaCartellaDiArchiviazioneSceglierne =>
      'C\'est le dossier d\'archivage : choisissez-en un autre.';

  @override
  String coreErrCartellaNonTrovata5(String name) {
    return 'Dossier \'$name\' introuvable.';
  }

  @override
  String get coreErrArchiviaRichiedeLaCopiaLocale =>
      'Archiver nécessite la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla =>
      'Aucun dossier d\'archivage : choisissez-le avec « Définir le dossier d\'archivage ».';

  @override
  String get coreErrLeMailSonoGiaNella =>
      'Les messages sont déjà dans le dossier d\'archivage.';

  @override
  String get coreErrContattiRichiedonoLaCopiaLocale =>
      'Les contacts nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrContenutoDelFileNonValido =>
      'Contenu du fichier non valide.';

  @override
  String get coreErrFileTroppoGrandeAlMassimo =>
      'Fichier trop volumineux (10 Mo au maximum).';

  @override
  String get coreErrLaSincronizzazioneDeiContattiNon2 =>
      'La synchronisation des contacts n\'est pas active pour ce compte.';

  @override
  String get coreErrDa50 => 'De 1 à 50.';

  @override
  String get coreErrIndirizzoMancante => 'Adresse manquante.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia2 =>
      'Les règles nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrScegliereAlmenoUnaRegolaSalvata =>
      'Choisissez au moins une règle enregistrée.';

  @override
  String get coreErrAccountPop3LeMailSono =>
      'Compte POP3 : le courrier n\'existe que sur cet ordinateur, il n\'y a aucune copie à reconstruire depuis le serveur.';

  @override
  String get coreErrCalendariRichiedonoLaCopiaLocale =>
      'Les calendriers nécessitent la copie locale (Cache:Enabled=false).';

  @override
  String coreErrIlCalendarioDiSolaLettura(String name) {
    return 'Le calendrier « $name » est en lecture seule : impossible de créer, modifier ou supprimer des rendez-vous.';
  }

  @override
  String get coreErrLaSincronizzazioneDelCalendarioNon2 =>
      'La synchronisation du calendrier n\'est pas active pour ce compte.';

  @override
  String get coreErrRitardaRecapitoRichiedeLaCache =>
      'Différer la remise nécessite la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaInUscitaRichiede =>
      'La Boîte d\'envoi nécessite la copie locale (Cache:Enabled=false).';

  @override
  String get coreErrMailNonTrovataNellaPosta =>
      'Message introuvable dans la Boîte d\'envoi.';

  @override
  String get coreErrNessunaConfermaDiLetturaPer =>
      'Aucune confirmation de lecture pour les messages de Courrier indésirable, Éléments envoyés et Brouillons.';

  @override
  String get coreErrAllaRichiestaDiConfermaDi =>
      'La demande de confirmation de lecture a déjà reçu une réponse.';

  @override
  String get coreErrLaMailNonChiedeUna2 =>
      'Le message ne demande pas de confirmation de lecture à son expéditeur.';

  @override
  String get davContactsServerLabel => 'serveur de contacts';

  @override
  String get davCalendarServerLabel => 'serveur de calendrier';

  @override
  String get printPreviewOpened =>
      'Aperçu ouvert dans la visionneuse PDF : imprimez depuis celle-ci.';

  @override
  String printNoPdfViewer(String path) {
    return 'Aucun programme pour ouvrir les fichiers PDF. Fichier dans $path';
  }

  @override
  String printNotPrepared(String message, String path) {
    return 'Impression non préparée : $message ($path)';
  }

  @override
  String get defaultMessageFileName => 'message';

  @override
  String get preparingPdf => 'Préparation du PDF…';

  @override
  String pdfNotCreated(String error) {
    return 'PDF non créé : $error';
  }

  @override
  String get printFrom => 'De :';

  @override
  String get printSent => 'Envoyé :';

  @override
  String get printTo => 'À :';

  @override
  String get printCc => 'Cc :';

  @override
  String get printSubject => 'Objet :';

  @override
  String get printImportance => 'Importance :';

  @override
  String get printHigh => 'Haute';

  @override
  String get printLow => 'Faible';

  @override
  String get printAttachments => 'Pièces jointes :';

  @override
  String get defaultAttachmentFileName => 'piece-jointe';

  @override
  String get coreExecutableNotFound =>
      'Exécutable du core introuvable. Compilez-le avec « cd core && dotnet build » ou indiquez son chemin dans POSTINOVIP_CORE.';

  @override
  String coreCannotStart(String path, String error) {
    return 'Impossible de démarrer le core ($path) : $error';
  }

  @override
  String coreExitedAtStart(String code) {
    return 'Le core s\'est arrêté pendant le démarrage (code $code).';
  }

  @override
  String coreNoAnswerAtStart(String seconds) {
    return 'Le core n\'a pas répondu en $seconds s.';
  }

  @override
  String coreNotAnsweringCorrectly(String error) {
    return 'Le core ne répond pas correctement : $error';
  }

  @override
  String get startingCore => 'Démarrage du core…';

  @override
  String get coreLastLines => 'Dernières lignes du core :';

  @override
  String get macMenuAbout => 'À propos de PostinoVip';

  @override
  String get macMenuOptions => 'Options…';

  @override
  String get macMenuServices => 'Services';

  @override
  String get macMenuHide => 'Masquer PostinoVip';

  @override
  String get macMenuHideOthers => 'Masquer les autres';

  @override
  String get macMenuShowAll => 'Tout afficher';

  @override
  String get macMenuQuit => 'Quitter PostinoVip';

  @override
  String get macMenuEdit => 'Édition';

  @override
  String get macMenuUndo => 'Annuler';

  @override
  String get macMenuRedo => 'Rétablir';

  @override
  String get macMenuCut => 'Couper';

  @override
  String get macMenuCopy => 'Copier';

  @override
  String get macMenuPaste => 'Coller';

  @override
  String get macMenuSelectAll => 'Tout sélectionner';

  @override
  String get macMenuWindow => 'Fenêtre';

  @override
  String get macMenuMinimize => 'Placer dans le Dock';

  @override
  String get macMenuZoom => 'Réduire/agrandir';

  @override
  String get macMenuFullScreen => 'Plein écran';

  @override
  String get macMenuBringAllToFront => 'Tout ramener au premier plan';

  @override
  String get macMenuShowRibbon => 'Ruban';

  @override
  String get macMenuZoomReset => 'Taille réelle';

  @override
  String get macMenuCloseWindow => 'Fermer la fenêtre';

  @override
  String get macMenuCalendarView => 'Affichage du calendrier';

  @override
  String get optionsShowRibbon => 'Afficher le ruban';

  @override
  String get optionsShowRibbonHelp =>
      'Dans la fenêtre principale. Les commandes restent dans la barre des menus en haut.';
}
