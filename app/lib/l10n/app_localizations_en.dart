// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String statusItems(int count) {
    return 'Items: $count';
  }

  @override
  String statusUnread(int count) {
    return 'Unread: $count';
  }

  @override
  String statusResults(int count) {
    return 'Results: $count';
  }

  @override
  String statusContacts(int count) {
    return 'Contacts: $count';
  }

  @override
  String statusFound(int count) {
    return 'Found: $count';
  }

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String statusDisconnectedAccounts(String accounts) {
    return 'Disconnected: $accounts';
  }

  @override
  String get optionsTitle => 'Options';

  @override
  String get optionsClose => 'Close';

  @override
  String get optionsPageGeneral => 'General';

  @override
  String get optionsPageMail => 'Mail';

  @override
  String get optionsPageNotifications => 'Notifications';

  @override
  String get optionsPageCalendar => 'Calendar';

  @override
  String get optionsAccountSection => 'Accounts';

  @override
  String get optionsAccountNotConfigured => '(not configured)';

  @override
  String get optionsAccountFromUserSecrets =>
      'Data from user-secrets (development)';

  @override
  String optionsAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String get optionsAccountManage => 'Manage…';

  @override
  String get optionsLookSection => 'Appearance';

  @override
  String get optionsTheme => 'Theme';

  @override
  String get optionsThemeHelper =>
      'Message text stays on a white background even with dark themes';

  @override
  String get themeSystem => 'Use system setting';

  @override
  String get themeColorful => 'Colorful';

  @override
  String get themeWhite => 'White';

  @override
  String get themeDarkGray => 'Dark Gray';

  @override
  String get themeBlack => 'Black';

  @override
  String get optionsModuleBar => 'Navigation bar (Mail, Calendar, People)';

  @override
  String get moduleBarLeft => 'On the left';

  @override
  String get moduleBarBottom => 'At the bottom of the folder pane';

  @override
  String get optionsLanguageSection => 'Language';

  @override
  String get optionsLanguage => 'Display language';

  @override
  String get optionsLanguageHelper =>
      'Translation in progress: some parts of the app are still in Italian only';

  @override
  String get languageSystem => 'Same as the system';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSendReceive => 'Send / Receive';

  @override
  String get tabFolder => 'Folder';

  @override
  String get tabView => 'View';

  @override
  String get groupLayout => 'Layout';

  @override
  String get ribbonCollapse => 'Collapse the Ribbon';

  @override
  String get ribbonCollapseTooltip => 'Show only the tab names (Ctrl+F1)';

  @override
  String get groupSendReceive => 'Send & Receive';

  @override
  String get sendReceiveAll => 'Send/Receive All Folders';

  @override
  String get sendReceiveAllTooltip =>
      'Update folders and messages of all accounts (F9)';

  @override
  String get readingPane => 'Reading Pane';

  @override
  String get messagePreview => 'Message Preview';

  @override
  String get messagePreviewOff => 'Off';

  @override
  String messagePreviewLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lines',
      one: '1 Line',
    );
    return '$_temp0';
  }

  @override
  String get groupMessages => 'Messages';

  @override
  String get showAsConversations => 'Show as Conversations';

  @override
  String get showAsConversationsOnTooltip =>
      'On in this folder: click to go back to the simple list';

  @override
  String get showAsConversationsOffTooltip =>
      'Groups the messages of the same conversation in one row';

  @override
  String get specialFolderHint =>
      'Inbox, Sent Items, Deleted Items and the other special folders cannot be renamed or deleted';

  @override
  String get groupNew => 'New';

  @override
  String get newFolder => 'New Folder';

  @override
  String get newFolderTooltip => 'Create a subfolder of the selected folder';

  @override
  String get groupActions => 'Actions';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get renameFolderTooltip =>
      'Change the name of the selected folder (F2)';

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String get deletePermanentlyTooltip =>
      'Delete from the server, with no way to recover it';

  @override
  String get deleteFolderTooltip =>
      'Move the folder, with its contents, to Deleted Items';

  @override
  String get emptyFolder => 'Empty Folder';

  @override
  String get emptyFolderTooltip =>
      'Delete all the messages in the folder from the server, with no way to recover them';

  @override
  String get emptyFolderOnlyTooltip => 'Only for Deleted Items and Junk Email';

  @override
  String get groupArchive => 'Archive';

  @override
  String get setArchiveFolder => 'Set Archive Folder';

  @override
  String get setArchiveFolderTooltip =>
      'Choose or create the folder where Archive moves the messages of this account';

  @override
  String get newMessage => 'New Email';

  @override
  String get newMessageTooltip => 'Write a new message';

  @override
  String get delete => 'Delete';

  @override
  String get deletePermanently => 'Permanently Delete';

  @override
  String get moveToDeletedTooltip => 'Move to Deleted Items';

  @override
  String get archive => 'Archive';

  @override
  String get cleanUp => 'Clean Up';

  @override
  String get cleanUpTooltip =>
      'Move redundant messages to Deleted Items: those quoted in full by a reply';

  @override
  String get junk => 'Junk';

  @override
  String get junkTooltip => 'Block Sender, Never Block, Junk Email Options';

  @override
  String get groupRespond => 'Respond';

  @override
  String get move => 'Move';

  @override
  String get moveTooltip => 'Move to another folder';

  @override
  String get moveOtherFolder => 'Other Folder… (Ctrl+Shift+V)';

  @override
  String get rules => 'Rules';

  @override
  String get rulesTooltip => 'Sort incoming mail automatically';

  @override
  String get createRule => 'Create Rule…';

  @override
  String get manageRulesEllipsis => 'Manage Rules & Alerts…';

  @override
  String get groupTags => 'Tags';

  @override
  String get markUnread => 'Mark as Unread';

  @override
  String get markRead => 'Mark as Read';

  @override
  String get categorize => 'Categorize';

  @override
  String get categorizeTooltip => 'Assign a color category';

  @override
  String get followUp => 'Follow Up';

  @override
  String get followUpTooltip => 'Flag for follow-up, with a due date';

  @override
  String get groupFind => 'Find';

  @override
  String get search => 'Search';

  @override
  String get searchTooltip => 'Search mail';

  @override
  String get fileTab => 'File';

  @override
  String get openEml => 'Open .eml File…';

  @override
  String get saveAs => 'Save As… (F12)';

  @override
  String get printMessage => 'Print… (Ctrl+P)';

  @override
  String get saveAsPdf => 'Save as PDF…';

  @override
  String get automaticReplies => 'Automatic Replies';

  @override
  String get manageRules => 'Manage Rules & Alerts';

  @override
  String get aboutApp => 'About PostinoVip';

  @override
  String get ribbonShowAlways => 'Always Show Ribbon';

  @override
  String get ribbonTabsOnly => 'Show Tabs Only (Ctrl+F1)';

  @override
  String get ribbonDisplayOptions => 'Ribbon Display Options';

  @override
  String get readingPaneRight => 'Right';

  @override
  String get readingPaneBottom => 'Bottom';

  @override
  String get readingPaneOff => 'Off';

  @override
  String get ribbonClassic => 'Classic Ribbon';

  @override
  String get ribbonSimplified => 'Simplified Ribbon';

  @override
  String get reply => 'Reply';

  @override
  String get replyAll => 'Reply All';

  @override
  String get forward => 'Forward';

  @override
  String get sendReceiveAllF9 => 'Send/Receive All Folders (F9)';

  @override
  String get searchHelp =>
      'Words (also beginnings: \"inv\" finds \"invoice\"), \"exact phrase\"\nfrom:anna   to:mario   subject:meeting\nattachment:pdf   hasattachments:yes   hasattachments:no';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchScopeFolder => 'Current Folder';

  @override
  String get searchScopeAccount => 'Current Mailbox';

  @override
  String get searchScopeAllAccounts => 'All Mailboxes';

  @override
  String get moduleMail => 'Mail (Ctrl+1)';

  @override
  String get moduleCalendar => 'Calendar (Ctrl+2)';

  @override
  String get modulePeople => 'People (Ctrl+3)';

  @override
  String get zoomOut => 'Zoom Out (Ctrl+-)';

  @override
  String get zoomIn => 'Zoom In (Ctrl++)';

  @override
  String get zoomReset =>
      'Reading pane zoom: click to go back to 100% (Ctrl+0)';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get noFolderSelected => 'No folder selected';

  @override
  String searchWhereFolder(String folder) {
    return 'in $folder';
  }

  @override
  String searchWhereAccount(String account) {
    return 'in all folders of $account';
  }

  @override
  String get searchWhereAllFolders => 'in all folders';

  @override
  String get searchWhereAllAccounts => 'in all accounts';

  @override
  String searchInProgress(String where) {
    return 'Searching $where…';
  }

  @override
  String searchResultsTitle(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0 $where';
  }

  @override
  String get listNoUnread => 'No unread messages';

  @override
  String get listEmptyFolder => 'This folder is empty';

  @override
  String get unknownSender => '(unknown sender)';

  @override
  String get noSubject => '(no subject)';

  @override
  String get searchNoLocalResults => 'No results in the local cache';

  @override
  String get offlineStrip =>
      'Not connected: showing the copy on this computer. Moving, deleting, marking as read and sending come back by themselves when the server responds.';

  @override
  String get theProvider => 'the provider';

  @override
  String loginExpired(String provider) {
    return 'Sign-in to $provider expired: this account won\'t receive or send mail until you sign in again.';
  }

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get autoReplyStrip =>
      'Automatic replies are turned on for this account.';

  @override
  String get editEllipsis => 'Edit…';

  @override
  String get autoReplyTurnedOff => 'Automatic replies turned off.';

  @override
  String autoReplyNotTurnedOff(String error) {
    return 'Not turned off: $error';
  }

  @override
  String get turnOff => 'Turn off';

  @override
  String get serverSearching => 'Searching the server…';

  @override
  String serverSearchFailed(String error) {
    return 'Server search failed: $error';
  }

  @override
  String get serverFoundNone => 'The server found no other messages.';

  @override
  String serverFoundMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The server found $count more messages',
      one: 'The server found 1 more message',
    );
    return '$_temp0 (with the cloud icon).';
  }

  @override
  String serverTruncated(int count) {
    return ' Showing the $count most recent.';
  }

  @override
  String get searchServerToo => 'Search the server too';

  @override
  String get searchServerHint =>
      'For messages older than the cache limit and for Deleted Items and Junk Email,\nwhose headers only were searched here.';

  @override
  String get conversationCollapse => 'Collapse the conversation';

  @override
  String get conversationExpand => 'Show all messages in the conversation';

  @override
  String get sortDateNewest => 'By date: newest on top';

  @override
  String get sortDateOldest => 'By date: oldest on top';

  @override
  String get sortFromAZ => 'By sender: A → Z';

  @override
  String get sortFromZA => 'By sender: Z → A';

  @override
  String get sortSubjectAZ => 'By subject: A → Z';

  @override
  String get sortSubjectZA => 'By subject: Z → A';

  @override
  String get sortSizeLargest => 'By size: largest on top';

  @override
  String get sortSizeSmallest => 'By size: smallest on top';

  @override
  String get sortByDate => 'By Date';

  @override
  String get sortByFrom => 'By Sender';

  @override
  String get sortBySubject => 'By Subject';

  @override
  String get sortBySize => 'By Size';

  @override
  String get filterAll => 'All';

  @override
  String get filterUnread => 'Unread';

  @override
  String get sortTooltip => 'Sort by';

  @override
  String get conversationBadgeTooltip =>
      'Conversation view is on in this folder: click to change it';

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
    return '$_temp0 in the conversation';
  }

  @override
  String get hasAttachments => 'Has attachments';

  @override
  String get flaggedClickToComplete => 'Flagged: click to mark complete';

  @override
  String dueByClickToComplete(String date) {
    return 'Due by $date: click to mark complete';
  }

  @override
  String get completedClickToFlag => 'Completed: click to flag again';

  @override
  String get flagToday => 'Flag for today';

  @override
  String get foundOnServer => 'Found on the server';

  @override
  String sortByColumn(String column) {
    return 'Sort by $column';
  }

  @override
  String get columnFrom => 'From';

  @override
  String get columnSubject => 'Subject';

  @override
  String get columnReceived => 'Received';

  @override
  String get columnSize => 'Size';

  @override
  String get columnCategories => 'Categories';

  @override
  String selectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items selected',
      one: '1 item selected',
    );
    return '$_temp0';
  }

  @override
  String get selectMessage => 'Select an item to read';

  @override
  String get messageUnavailable => 'Message not available';

  @override
  String receiptRequested(String sender) {
    return '$sender requested a read receipt.';
  }

  @override
  String get receiptDecline => 'Don\'t Send';

  @override
  String get receiptSend => 'Send';

  @override
  String get draftBanner => 'Draft: not sent yet.';

  @override
  String get editDraft => 'Edit Draft';

  @override
  String get headerTo => 'To';

  @override
  String get headerCc => 'Cc';

  @override
  String openAttachment(String name) {
    return 'Open \"$name\"';
  }

  @override
  String saveAttachment(String name) {
    return 'Save \"$name\"…';
  }

  @override
  String get importanceHighBanner =>
      'This message was sent with High importance.';

  @override
  String get importanceLowBanner =>
      'This message was sent with Low importance.';

  @override
  String get junkBanner =>
      'This message is in Junk Email: for safety, links are disabled and remote images are blocked. If it is a trusted message, move it back to the Inbox.';

  @override
  String get notJunk => 'Not Junk';

  @override
  String get remoteImagesBlocked =>
      'Remote images blocked to protect your privacy.';

  @override
  String get showImages => 'Show images';

  @override
  String get htmlOnlyAsText => 'HTML-only message: shown as simplified text.';

  @override
  String get bodyText => 'Text';

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String attachmentNotDownloaded(String error) {
    return 'Attachment not downloaded: $error';
  }

  @override
  String fileNotWritten(String message, String path) {
    return 'File not written: $message ($path)';
  }

  @override
  String attachedMailNotOpened(String error) {
    return 'Attached message not opened: $error';
  }

  @override
  String get messageWithoutText => '(message without text)';

  @override
  String get completed => 'Completed';

  @override
  String get flaggedForFollowUp => 'Flagged for follow-up';

  @override
  String dueBy(String date) {
    return 'Due by $date';
  }

  @override
  String get overdueSuffix => ' (overdue)';

  @override
  String get addSenderToContacts => 'Add Sender to Contacts';

  @override
  String get stopIgnoringConversation => 'Stop Ignoring Conversation';

  @override
  String get ignoreConversation => 'Ignore Conversation';

  @override
  String get cleanUpConversation => 'Clean Up Conversation';

  @override
  String draftNotAvailable(String error) {
    return 'Draft not available: $error';
  }

  @override
  String get draftTitle => 'Draft';

  @override
  String get deletePermanentlyQuestion => 'Permanently delete?';

  @override
  String deletePermanentlyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected messages in Deleted Items will be deleted',
      one: '1 selected message in Deleted Items will be deleted',
    );
    return '$_temp0 from the server.\nThis cannot be undone.';
  }

  @override
  String deletePermanentlyOne(String subject) {
    return '\"$subject\" will be deleted from the server.\nThis cannot be undone.';
  }

  @override
  String get dontShowAsConversations => 'Don\'t Show as Conversations';

  @override
  String conversationsOnQuestion(String folder) {
    return 'Messages of the same conversation will be grouped in one row, with the replies kept in other folders.\n\nApply to \"$folder\" or to all folders?';
  }

  @override
  String conversationsApplyQuestion(String folder) {
    return 'Apply to \"$folder\" or to all folders?';
  }

  @override
  String get allFolders => 'All Folders';

  @override
  String get thisFolder => 'This Folder';

  @override
  String get importanceHigh => 'High Importance';

  @override
  String get importanceLow => 'Low Importance';

  @override
  String get folderInbox => 'Inbox';

  @override
  String get favorites => 'Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get showInFavorites => 'Show in Favorites';

  @override
  String get cleanUpFolder => 'Clean Up Folder';

  @override
  String get outbox => 'Outbox';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String noAutoUpdate(String address) {
    return 'Automatic update is off for $address: new messages appear only with \"Send/Receive\"';
  }

  @override
  String get emptyFolderAllMails => 'All the messages';

  @override
  String get emptyFolderOnlyMail => 'The only message';

  @override
  String emptyFolderNMails(int count) {
    return 'All $count messages';
  }

  @override
  String get emptyFolderOneSubfolder =>
      ' and the subfolder, with its messages,';

  @override
  String emptyFolderNSubfolders(int count) {
    return ' and the $count subfolders, with their messages,';
  }

  @override
  String emptyFolderQuestion(String folder) {
    return 'Empty \"$folder\"?';
  }

  @override
  String emptyFolderContent(String mails, String folder, String also) {
    return '$mails in \"$folder\"$also will be deleted from the server.\nThis cannot be undone.';
  }

  @override
  String get deleteFolderPermanentlyQuestion =>
      'Permanently delete the folder?';

  @override
  String get deleteFolderQuestion => 'Delete the folder?';

  @override
  String deleteFolderPermanentlyContent(String folder) {
    return 'The folder \"$folder\", with all its messages and subfolders, will be deleted from the server.\nThis cannot be undone.';
  }

  @override
  String deleteFolderContent(String folder) {
    return 'The folder \"$folder\", with all its messages and subfolders, will be moved to Deleted Items.';
  }

  @override
  String get messageTab => 'Message';

  @override
  String get windowDeletePermanentlyTooltip =>
      'Delete from the server, with no way to recover it (then the next message)';

  @override
  String get windowDeleteTooltip =>
      'Move to Deleted Items and open the next message (Del)';

  @override
  String get windowArchiveTooltip =>
      'Move to the archive folder and open the next message';

  @override
  String get windowMoveTooltip =>
      'Move to another folder and open the next message';

  @override
  String get markUnreadWindow => 'Mark as Unread';

  @override
  String get groupZoom => 'Zoom';

  @override
  String zoomPercent(int percent) {
    return 'Zoom ($percent%)';
  }

  @override
  String get zoomTooltip =>
      'Zoom the message text in or out (Ctrl+wheel, Ctrl++, Ctrl+-, Ctrl+0)';

  @override
  String get previousItem => 'Previous Item (Ctrl+,)';

  @override
  String get nextItem => 'Next Item (Ctrl+.)';

  @override
  String get closeEsc => 'Close (Esc)';

  @override
  String messageNotSaved(String error) {
    return 'Message not saved: $error';
  }

  @override
  String get emlFilesLabel => 'Mail messages';

  @override
  String fileNotOpened(String name, String reason) {
    return '$name not opened: $reason';
  }

  @override
  String get readOnly => 'Read-only';

  @override
  String get saveAsShort => 'Save As…';

  @override
  String get moveItems => 'Move Items';

  @override
  String moveItemsTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move the $count selected items to the folder:',
      one: 'Move the selected item to the folder:',
    );
    return '$_temp0';
  }

  @override
  String get searchFolder => 'Search for a folder';

  @override
  String get noFolderWithName => 'No folder with this name';

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
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String reminderNotification(String title) {
    return 'Reminder: $title';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reminders',
      one: '1 Reminder',
    );
    return '$_temp0';
  }

  @override
  String get reminderAllDayToday => 'All day, today';

  @override
  String get reminderAllDayTomorrow => 'All day, tomorrow';

  @override
  String reminderAllDayIn(int count) {
    return 'All day, in $count days';
  }

  @override
  String reminderAllDayStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All day, started $count days ago',
      one: 'All day, started 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get reminderNow => 'Now';

  @override
  String reminderStartedAgo(String span) {
    return '$span overdue';
  }

  @override
  String reminderIn(String span) {
    return 'In $span';
  }

  @override
  String reminderStart(String when) {
    return 'Start time: $when';
  }

  @override
  String reminderLocation(String location) {
    return '    Location: $location';
  }

  @override
  String get dismissAll => 'Dismiss All';

  @override
  String get openItem => 'Open Item';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get snoozeHint => 'Click Snooze to be reminded again in:';

  @override
  String get snooze => 'Snooze';

  @override
  String newMailFrom(String sender, String suffix) {
    return 'New message from $sender$suffix';
  }

  @override
  String newMailMore(int count) {
    return '\n…and $count more';
  }

  @override
  String newMailCount(int count, String suffix) {
    return '$count new messages$suffix';
  }

  @override
  String get openMailAction => 'Open message';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWorkWeek => 'Work Week';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorGold => 'Gold';

  @override
  String get colorGray => 'Gray';

  @override
  String get deleteRecurringTitle => 'Delete a Recurring Appointment';

  @override
  String get openRecurringTitle => 'Open a Recurring Appointment';

  @override
  String get deleteRecurringQuestion =>
      'Delete only this occurrence or the entire series?';

  @override
  String get openRecurringQuestion =>
      'This is a recurring appointment. Open only this occurrence or the entire series?';

  @override
  String get entireSeries => 'The Entire Series';

  @override
  String get justThisOne => 'Just This One';

  @override
  String appointmentNotAvailable(String error) {
    return 'Appointment not available: $error';
  }

  @override
  String get deleteAppointmentQuestion => 'Delete the appointment?';

  @override
  String deleteAppointmentContent(String title) {
    return '\"$title\" will be deleted, and with synchronization also from the server. It cannot be recovered.';
  }

  @override
  String appointmentNotDeleted(String error) {
    return 'Appointment not deleted: $error';
  }

  @override
  String get uploadAppointmentsQuestion =>
      'Upload the appointments to the server?';

  @override
  String uploadAppointmentsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count appointments are only on this computer. They will be added',
      one: 'One appointment is only on this computer. It will be added',
    );
    return '$_temp0 to the server calendar and synchronized from then on.\n\nThe appointments already on the server are not changed.';
  }

  @override
  String get uploadToServer => 'Upload to Server';

  @override
  String appointmentsNotUploaded(String error) {
    return 'Appointments not uploaded: $error';
  }

  @override
  String get newAppointment => 'New Appointment';

  @override
  String get newAppointmentTooltip => 'New Appointment (Ctrl+N)';

  @override
  String get deleteSelectedAppointmentTooltip =>
      'Delete the selected appointment (Del)';

  @override
  String get groupGoTo => 'Go To';

  @override
  String get today => 'Today';

  @override
  String get todayTooltip => 'Go back to today';

  @override
  String get next7Days => 'Next 7 Days';

  @override
  String get next7DaysTooltip => 'Seven days starting today';

  @override
  String get groupArrange => 'Arrange';

  @override
  String get groupSync => 'Synchronization';

  @override
  String get sync => 'Sync';

  @override
  String get syncCalendarsTooltip =>
      'Sync the calendars with the server now (F9)';

  @override
  String appointmentsNotAvailable(String error) {
    return 'Appointments not available: $error';
  }

  @override
  String uploadStrip(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appointments are',
      one: 'one appointment is',
    );
    return '$name: $_temp0 only on this computer, not yet on the server.';
  }

  @override
  String get uploadToServerEllipsis => 'Upload to Server…';

  @override
  String get calendarEmpty => 'No appointments in this period. ';

  @override
  String get calendarEmptySyncHint =>
      'To see the server ones, turn on \"Sync the calendar with the server (CalDAV)\" in File → Options → Accounts → Edit. ';

  @override
  String get calendarEmptyCreate =>
      'To create one: \"New Appointment\" (Ctrl+N) or double-click an empty slot.';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get myCalendars => 'My Calendars';

  @override
  String get localOnlyTooltip =>
      'To see the server appointments: File → Options → Accounts → Edit → \"Sync the calendar with the server (CalDAV)\"';

  @override
  String get localOnly => 'Only on this computer';

  @override
  String get color => 'Color';

  @override
  String get calendarReadOnlyTooltip =>
      'Read-only: appointments can be viewed but not changed';

  @override
  String get syncedWithServer => 'Synced with the server';

  @override
  String get previousMonth => 'Previous Month';

  @override
  String get nextMonth => 'Next Month';

  @override
  String nowAt(String time) {
    return 'Now ($time)';
  }

  @override
  String moreItems(int count) {
    return '+$count more';
  }

  @override
  String get syncing => 'Syncing…';

  @override
  String get synced => 'Synced';

  @override
  String syncedAt(String time) {
    return 'Synced at $time';
  }

  @override
  String syncedOnAt(String date, String time) {
    return 'Synced on $date at $time';
  }

  @override
  String get syncServerUnreachable => 'Server not reachable';

  @override
  String get syncUnavailable => 'Sync not available';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get endBeforeStart => 'The end is before the start.';

  @override
  String get deleteOccurrenceQuestion => 'Delete this occurrence?';

  @override
  String get deleteOccurrenceContent =>
      'Only this occurrence is removed from the series; the others stay. It cannot be recovered.';

  @override
  String get deleteSeriesContent =>
      'The appointment (with all its occurrences, if it is recurring) will be deleted, and with synchronization also from the server. It cannot be recovered.';

  @override
  String get saveChangesQuestion => 'Save changes?';

  @override
  String get appointmentNotSavedContent =>
      'The changes to the appointment have not been saved.';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get untitled => 'Untitled';

  @override
  String get occurrence => 'Occurrence';

  @override
  String get appointment => 'Appointment';

  @override
  String get saveAndClose => 'Save & Close';

  @override
  String get saveAndCloseTooltip => 'Save & Close (Ctrl+S)';

  @override
  String get deleteOnlyOccurrenceTooltip => 'Delete only this occurrence';

  @override
  String get deleteAppointmentTooltip => 'Delete the appointment';

  @override
  String get groupOptions => 'Options';

  @override
  String get recurrence => 'Recurrence';

  @override
  String get recurrenceTooltip => 'Make it recurring or change the recurrence';

  @override
  String get reminder => 'Reminder';

  @override
  String reminderValue(String value) {
    return 'Reminder: $value';
  }

  @override
  String get reminderNone => 'None';

  @override
  String get reminderAtStart => 'At start time';

  @override
  String customRecurrence(String rule) {
    return 'Custom recurrence ($rule): kept as is when saving';
  }

  @override
  String calendarReadOnly(String calendar) {
    return 'The calendar \"$calendar\" is read-only: the appointment can be viewed but not changed.';
  }

  @override
  String get location => 'Location';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get allDayEvent => 'All day event';

  @override
  String recurrenceValue(String text) {
    return 'Recurrence: $text';
  }

  @override
  String get onlyThisOccurrenceHint =>
      'Only this occurrence of the series: the others don\'t change.';

  @override
  String get notes => 'Notes';

  @override
  String get weekFirst => 'first';

  @override
  String get weekSecond => 'second';

  @override
  String get weekThird => 'third';

  @override
  String get weekFourth => 'fourth';

  @override
  String get weekLast => 'last';

  @override
  String get recurrenceBadInterval => 'Invalid repetition (every 1–999).';

  @override
  String get recurrenceBadCount => 'Invalid number of occurrences (1–999).';

  @override
  String get recurrenceNoDays => 'Choose at least one day of the week.';

  @override
  String get recurEveryNDays => 'Every [n] day(s)';

  @override
  String get recurEveryWeekday => 'Every weekday';

  @override
  String get recurEveryNWeeksOn => 'Recur every [n] week(s) on:';

  @override
  String get recurMonthlyDay => 'Day [day] of every [n] month(s)';

  @override
  String get recurMonthlyWeekday => 'The [week] [weekday] of every month';

  @override
  String get recurYearlyDay => 'Every [month] [day]';

  @override
  String get recurYearlyWeekday => 'The [week] [weekday] of [month]';

  @override
  String get appointmentRecurrence => 'Appointment Recurrence';

  @override
  String get recurrencePattern => 'Recurrence pattern';

  @override
  String get recurDaily => 'Daily';

  @override
  String get recurWeekly => 'Weekly';

  @override
  String get recurMonthly => 'Monthly';

  @override
  String get recurYearly => 'Yearly';

  @override
  String get recurrenceRange => 'Range of recurrence';

  @override
  String get recurNoEnd => 'No end date';

  @override
  String get recurEndAfter => 'End after [n] occurrences';

  @override
  String get recurEndBy => 'End by [date]';

  @override
  String get removeRecurrence => 'Remove Recurrence';

  @override
  String queuedSendAfter(String when) {
    return 'Message in the Outbox: it will be sent after $when (with the app open).';
  }

  @override
  String get queuedOffline =>
      'No connection: the message is in the Outbox and will be sent by itself as soon as the server responds.';

  @override
  String get sentCopyNotSavedTitle => 'Message sent, copy not saved';

  @override
  String sentCopyNotSaved(String error) {
    return 'The message was sent, but the copy in Sent Items was not saved:\n$error\n\nDon\'t send it again: the recipients have already received it.';
  }

  @override
  String sentSavedIn(String folder) {
    return ' and saved in \"$folder\"';
  }

  @override
  String messageSent(String where, String response) {
    return 'Message sent$where. Server: $response';
  }

  @override
  String get newMessageTitle => 'New Message';

  @override
  String get toPlainTextQuestion => 'Switch to plain text?';

  @override
  String get toPlainTextContent =>
      'Formatting and images in the text will be lost, even if you switch back to HTML. The quoted original message will be added as text.';

  @override
  String get continueButton => 'Continue';

  @override
  String get savingDraft => 'Saving draft…';

  @override
  String get tabInsert => 'Insert';

  @override
  String get tabFormatText => 'Format Text';

  @override
  String get attachFile => 'Attach File';

  @override
  String get attachFileTooltip => 'Attach one or more files from the computer';

  @override
  String get saveSentCopy => 'Save Copy in Sent Items';

  @override
  String get saveSentCopyOnTooltip =>
      'On: after sending a copy goes to Sent Items (click to not save it)';

  @override
  String get saveSentCopyOffTooltip =>
      'Off: no copy in Sent Items after sending (click to save it)';

  @override
  String get saveDraft => 'Save Draft';

  @override
  String get saveDraftTooltip =>
      'Save in Drafts (Ctrl+S); also by itself every 3 minutes';

  @override
  String get delayDelivery => 'Delay Delivery';

  @override
  String get delayDeliveryTooltip =>
      'Do not send before a date and time (it stays in the Outbox)';

  @override
  String delayDeliveryActiveTooltip(String when) {
    return 'Sending after $when: click to change';
  }

  @override
  String get importanceHighTooltip =>
      'Mark the message as important (click again to remove)';

  @override
  String get importanceLowTooltip =>
      'Mark the message as low importance (click again to remove)';

  @override
  String get groupInclude => 'Include';

  @override
  String get groupSave => 'Save';

  @override
  String get groupShowFields => 'Show Fields';

  @override
  String get bcc => 'Bcc';

  @override
  String get bccTooltip =>
      'Blind carbon copy: Bcc recipients don\'t see each other and aren\'t seen by the others';

  @override
  String get groupTracking => 'Tracking';

  @override
  String get requestReadReceipt => 'Request a Read Receipt';

  @override
  String get requestReadReceiptOnTooltip =>
      'On: the recipient can send you a receipt when they read the message (click to remove)';

  @override
  String get requestReadReceiptOffTooltip =>
      'Ask the recipient for a receipt when they read the message (they can refuse)';

  @override
  String get groupMoreOptions => 'More Options';

  @override
  String get groupFormat => 'Format';

  @override
  String get formatHtmlTooltip => 'Formatted text, with images and links';

  @override
  String get plainText => 'Plain Text';

  @override
  String get plainTextTooltip =>
      'Text only, without formatting: every mail program can read it';

  @override
  String get signaturesEllipsis => 'Signatures…';

  @override
  String get signature => 'Signature';

  @override
  String get signatureTooltip =>
      'Insert a signature, or create and edit signatures';

  @override
  String get attachments => 'Attachments';

  @override
  String get originalAttachment => 'Attachment of the original message';

  @override
  String get remove => 'Remove';

  @override
  String attachmentsTooLarge(String size, String max) {
    return 'Attachments too large: $size, maximum $max.';
  }

  @override
  String get messageBody => 'Message text';

  @override
  String get addressesHint => 'addresses separated by commas';

  @override
  String get accountUnavailable => '(account not available)';

  @override
  String get originalMessageQuote =>
      'Original message (added at the end, as it is)';

  @override
  String get removeQuote => 'Remove Quote';

  @override
  String get offlineSendMessage =>
      'Not connected to the server and the original message (quote or attachments) is not on this computer: the message was not sent and stays here. Try again when the connection is back.';

  @override
  String sendFailed(String error) {
    return 'Sending failed: $error';
  }

  @override
  String draftTooLarge(String max) {
    return 'Draft not saved: attachments over $max.';
  }

  @override
  String draftSavedLocally(String time) {
    return 'Draft saved on this computer at $time: it will go to Drafts when the server responds';
  }

  @override
  String draftSavedAt(String time) {
    return 'Draft saved at $time';
  }

  @override
  String get draftNotSaved => 'Draft not saved';

  @override
  String draftNotSavedError(String error) {
    return 'Draft not saved: $error';
  }

  @override
  String get sendQuestion => 'Send the message?';

  @override
  String sendSummaryCopy(String value) {
    return 'Copy in Sent Items: $value';
  }

  @override
  String sendSummaryDelivery(String when) {
    return 'Delivery: not before $when';
  }

  @override
  String get emptySubjectWarning => 'Warning: the subject is empty.';

  @override
  String get attachmentsNone => 'none';

  @override
  String attachmentsFromDisk(String size) {
    return ', files from disk $size';
  }

  @override
  String get composeSaveNew =>
      'The message has not been sent. Save it in Drafts to finish it later?';

  @override
  String get composeSaveExisting =>
      'The message has not been sent. Save the latest changes to the draft?';

  @override
  String get sending => 'Sending…';

  @override
  String get doNotDeliverBefore => 'Do not deliver before:';

  @override
  String get delayDeliveryHint =>
      'After \"Send\" the message stays in the Outbox and goes out by itself at that time, if the app is open.';

  @override
  String get chooseFutureTime => 'Choose a time in the future.';

  @override
  String get noDelay => 'No Delay';

  @override
  String get recipientRequired => 'Enter at least one recipient';

  @override
  String invalidAddress(String address) {
    return 'Invalid address: $address';
  }

  @override
  String get dontSuggestAddress => 'Don\'t suggest this address anymore';

  @override
  String get noMoreSuggestions => 'No more suggestions';

  @override
  String get outboxHint =>
      'Outbox: messages on this computer that go out by themselves when it is time and the server responds, with the app open.';

  @override
  String get outboxEmpty => 'No messages waiting to be sent';

  @override
  String get deleteOutboxQuestion => 'Delete the message?';

  @override
  String deleteOutboxContent(String subject) {
    return '\"$subject\" will not be sent.';
  }

  @override
  String outboxNotSent(String error) {
    return 'Not sent: $error';
  }

  @override
  String outboxSendAfter(String when) {
    return 'Sending after $when';
  }

  @override
  String get outboxWaiting => 'Waiting for connection';

  @override
  String get noRecipients => '(no recipients)';

  @override
  String get sendNow => 'Send Now';

  @override
  String get moveToDrafts => 'Move to Drafts (to edit it)';

  @override
  String get deleteOutboxTooltip => 'Delete (it won\'t be sent)';

  @override
  String get yesValue => 'yes';

  @override
  String get noValue => 'no';

  @override
  String get fontColorAutomatic => 'Automatic';

  @override
  String get fontColorDarkRed => 'Dark Red';

  @override
  String get fontColorRed => 'Red';

  @override
  String get fontColorOrange => 'Orange';

  @override
  String get fontColorYellow => 'Yellow';

  @override
  String get fontColorLightGreen => 'Light Green';

  @override
  String get fontColorGreen => 'Green';

  @override
  String get fontColorLightBlue => 'Light Blue';

  @override
  String get fontColorBlue => 'Blue';

  @override
  String get fontColorDarkBlue => 'Dark Blue';

  @override
  String get fontColorPurple => 'Purple';

  @override
  String get remoteImagePlaceholder => '[image from the internet]';

  @override
  String get groupBasicText => 'Basic Text';

  @override
  String get groupFont => 'Font';

  @override
  String get groupParagraph => 'Paragraph';

  @override
  String get linkTooltip => 'Link (Ctrl+K)';

  @override
  String get imageFromFile => 'Image from file (e.g. a logo)';

  @override
  String get defaultFont => 'Calibri (default)';

  @override
  String get fontSize => 'Font Size';

  @override
  String get bold => 'Bold (Ctrl+B)';

  @override
  String get italic => 'Italic (Ctrl+I)';

  @override
  String get underline => 'Underline (Ctrl+U)';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get fontColor => 'Font Color';

  @override
  String get highlightColor => 'Text Highlight Color';

  @override
  String get noColor => 'No Color';

  @override
  String get clearFormatting => 'Clear All Formatting';

  @override
  String get bullets => 'Bullets';

  @override
  String get numbering => 'Numbering';

  @override
  String get decreaseIndent => 'Decrease Indent';

  @override
  String get increaseIndent => 'Increase Indent';

  @override
  String get alignLeft => 'Align Left';

  @override
  String get center => 'Center';

  @override
  String get alignRight => 'Align Right';

  @override
  String get justify => 'Justify';

  @override
  String get link => 'Link';

  @override
  String get linkButtonTooltip => 'Insert or edit a link (Ctrl+K)';

  @override
  String get linkInvalid =>
      'Invalid address: only http, https and mailto are allowed.';

  @override
  String get insertLink => 'Insert Hyperlink';

  @override
  String get linkAddress => 'Address';

  @override
  String get linkAddressHint => 'https://… or an email address';

  @override
  String get removeLink => 'Remove Link';

  @override
  String signatureTooLarge(String size, String max) {
    return 'Signature too large: $size of images, maximum $max.';
  }

  @override
  String get newSignature => 'New Signature';

  @override
  String get renameSignature => 'Rename Signature';

  @override
  String get deleteSignatureQuestion => 'Delete the signature?';

  @override
  String deleteSignatureContent(String name) {
    return '\"$name\" will be deleted from this computer.';
  }

  @override
  String get notAnImage =>
      'The chosen file is not an image (PNG, JPEG, GIF, BMP or WebP).';

  @override
  String get signaturesAndStationery => 'Signatures and Stationery';

  @override
  String get selectSignatureToEdit => 'Select signature to edit';

  @override
  String get newButton => 'New';

  @override
  String get rename => 'Rename';

  @override
  String get editSignature => 'Edit signature';

  @override
  String get noSignatures =>
      'No signatures: create the first one with \"New\".';

  @override
  String get signatureText => 'Signature text';

  @override
  String get noneFeminine => '(none)';

  @override
  String get chooseDefaultSignature => 'Choose default signature';

  @override
  String get account => 'Email account';

  @override
  String get newMessages => 'New messages';

  @override
  String get repliesForwards => 'Replies/forwards';

  @override
  String get writeAName => 'Enter a name.';

  @override
  String get signatureNameTaken =>
      'There is already a signature with this name.';

  @override
  String get signatureName => 'Signature name';

  @override
  String get contacts => 'Contacts';

  @override
  String get addressBook => 'Address Book';

  @override
  String get addressBookSearch => 'Search by name, address or company';

  @override
  String get allAddressBooks => 'All address books';

  @override
  String contactsNotAvailable(String error) {
    return 'Contacts not available: $error';
  }

  @override
  String get noContactsWithAddress => 'No contacts with an address.';

  @override
  String get noContactsFound => 'No contacts found.';

  @override
  String get takeOut => 'Remove';

  @override
  String get labelWork => 'Work';

  @override
  String get labelHome => 'Home';

  @override
  String get labelOther => 'Other';

  @override
  String get labelMobile => 'Mobile';

  @override
  String get labelOffice => 'Business';

  @override
  String get deleteContactQuestion => 'Delete the contact?';

  @override
  String deleteContactContent(String name) {
    return '\"$name\" is only on this computer: once deleted, it cannot be recovered.';
  }

  @override
  String contactNotDeleted(String error) {
    return 'Contact not deleted: $error';
  }

  @override
  String get contactFilesLabel => 'Contacts (vCard, CSV)';

  @override
  String get importDone => 'Import complete';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts added',
      one: '1 contact added',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    return '$count already present (not added again)';
  }

  @override
  String importInvalid(int count) {
    return '$count discarded (no name or address, or not valid)';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get exportContacts => 'Export Contacts';

  @override
  String get exportVcfHint => 'For Thunderbird, phones, Apple, Google';

  @override
  String get exportCsvHint => 'Outlook columns: for Outlook, Gmail, Excel';

  @override
  String exportDone(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts exported',
      one: '1 contact exported',
    );
    return '$_temp0 to $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String contactSavedIn(String name, String book) {
    return '\"$name\" saved in $book';
  }

  @override
  String get uploadContactsQuestion => 'Upload the contacts to the server?';

  @override
  String uploadContactsContent(int count, String book, String serverBook) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts of the address book \"$book\" are only on this computer. They will be added',
      one:
          'One contact of the address book \"$book\" is only on this computer. It will be added',
    );
    return '$_temp0 to the address book \"$serverBook\" of the contacts server and synchronized from then on.\n\nThe contacts already on the server are not changed.';
  }

  @override
  String contactsNotUploaded(String error) {
    return 'Contacts not uploaded: $error';
  }

  @override
  String get newContact => 'New Contact';

  @override
  String get newContactTooltip =>
      'New contact in the open address book (Ctrl+N)';

  @override
  String get deleteContactTooltip => 'Delete the selected contact (Del)';

  @override
  String get groupCommunicate => 'Communicate';

  @override
  String get emailMessage => 'Email';

  @override
  String get emailMessageTooltip => 'New message to the selected contact';

  @override
  String get edit => 'Edit';

  @override
  String get editContactTooltip =>
      'Open the selected contact (Enter or double-click)';

  @override
  String get syncContactsTooltip =>
      'Sync the address book with the contacts server now (F9)';

  @override
  String get syncContactsOffTooltip =>
      'Contact sync is off: turn it on in the account settings';

  @override
  String get groupImportExport => 'Import/Export';

  @override
  String get importEllipsis => 'Import…';

  @override
  String get importTooltip =>
      'Add contacts from a vCard (.vcf) or Outlook or Gmail CSV file';

  @override
  String get exportEllipsis => 'Export…';

  @override
  String get exportTooltip =>
      'Save the whole address book to a vCard or CSV file';

  @override
  String get searchContacts => 'Search Contacts';

  @override
  String get searchContactsTooltip =>
      'Search by name, address, company or phone (Ctrl+E)';

  @override
  String get myContacts => 'My Contacts';

  @override
  String get reloginCalendar =>
      'The calendar isn\'t syncing: you need to sign in to Google again and allow access to the calendar.';

  @override
  String get reloginContacts =>
      'Contacts aren\'t syncing: you need to sign in to Google again and allow access to contacts.';

  @override
  String contactsUploadStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts are only on this computer: they are not yet on the contacts server.',
      one: 'One contact is only on this computer: it is not yet on the contacts server.',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noContactsHint =>
      'No contacts. Use \"New Contact\" or \"Import…\".';

  @override
  String get selectContact => 'Select a contact';

  @override
  String get emailSection => 'Email';

  @override
  String get phoneSection => 'Phone';

  @override
  String get contact => 'Contact';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get displayAs => 'Display as (if different from first and last name)';

  @override
  String get company => 'Company';

  @override
  String get addAddress => 'Add address';

  @override
  String get phoneNumber => 'Number';

  @override
  String get addPhone => 'Add phone';

  @override
  String get securityNone => 'None';

  @override
  String get bodyMonthsAll => 'All';

  @override
  String bodyMonthsLast(int months) {
    return 'Last $months months';
  }

  @override
  String noAccountsSaved(String address) {
    return 'No accounts saved in the app. During development the core uses the user-secrets$address.\nOnce you add an account here, only the accounts saved here will be used: to keep seeing the current one, add it too.';
  }

  @override
  String accountSignedInWith(String provider) {
    return 'signed in with $provider';
  }

  @override
  String accountDownloadedMail(String months) {
    return 'Downloaded mail: $months';
  }

  @override
  String get accountContactsSynced => 'contacts synchronized (CardDAV)';

  @override
  String get accountCalendarSynced => 'calendar synchronized (CalDAV)';

  @override
  String get rebuildCache => 'Rebuild cache';

  @override
  String get removeFromApp => 'Remove from the app';

  @override
  String get addAccount => 'Add account';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get pendingChangesOk =>
      'Changes not saved yet: they apply when you click OK.';

  @override
  String accountsNotSaved(String error) {
    return 'Accounts not saved: $error';
  }

  @override
  String get pop3RemovedAfterDownload =>
      'removed from the server after downloading';

  @override
  String pop3CopyForDays(int days) {
    return 'copy on the server for $days days';
  }

  @override
  String get pop3CopyLeft => 'copy left on the server';

  @override
  String pop3Summary(String copy, int minutes) {
    return 'Mail on this computer, $copy · checked every $minutes minutes';
  }

  @override
  String get removedAccountsData => 'Data from removed accounts';

  @override
  String get removedAccountsDataInfo =>
      'Downloaded mail and search index of accounts removed from the app. They stay on this computer until you delete them.';

  @override
  String get orphanPop3Only => 'POP3 mail: this is the only copy';

  @override
  String orphanContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
    );
    return '$_temp0, only on this computer';
  }

  @override
  String get deleteLocalData => 'Delete local data';

  @override
  String get rebuildQuestion => 'Rebuild the local copy?';

  @override
  String rebuildContent(String name) {
    return 'The copy of \"$name\" on this computer (downloaded mail and search index) is deleted and downloaded again from the server in the background: it may take a few minutes and use the network.\n\nNothing is changed on the server.';
  }

  @override
  String get rebuild => 'Rebuild';

  @override
  String rebuildStarted(String name) {
    return 'Rebuilding the local copy of \"$name\" started.';
  }

  @override
  String rebuildFailed(String error) {
    return 'Local copy not rebuilt: $error';
  }

  @override
  String get deleteLocalDataQuestion => 'Delete the local data?';

  @override
  String deleteLocalDataContent(String name, String size, String contacts) {
    return 'The downloaded mail and the search index of \"$name\" ($size), an account no longer in the app, are deleted from this computer.\n\n${contacts}Nothing is changed on the server. This cannot be undone: if you add the account again, the mail will be downloaded again.';
  }

  @override
  String deleteLocalDataContacts(int count) {
    return 'Its $count contacts are lost too: they are only on this computer. To keep them, add the account again and export them from People.';
  }

  @override
  String localDataDeleted(String name) {
    return 'Local data of \"$name\" deleted.';
  }

  @override
  String localDataNotDeleted(String error) {
    return 'Local data not deleted: $error';
  }

  @override
  String get removeAccountQuestion => 'Remove the account from the app?';

  @override
  String removeAccountContent(String name, String email, String note) {
    return '\"$name\" ($email) will be removed from PostinoVip, together with the password saved in the keyring.\n\n$note Its contacts (People) also stay on this computer.\n\nThe removal applies when you click OK in the Accounts window.';
  }

  @override
  String get removeAccountPop3Note =>
      'Nothing is changed on the server. The mail downloaded with POP3 stays on this computer (for some it is the only copy): you find it in \"Data from removed accounts\" and it shows again if you add the account again.';

  @override
  String get removeAccountImapNote =>
      'Nothing is changed on the server: the mail stays where it is and you can add the account again at any time. The mail already downloaded stays on this computer: you can delete it later from \"Data from removed accounts\".';

  @override
  String get deleteForeverQuestion => 'Delete the mail forever?';

  @override
  String deleteForeverContent(String name, String size, String expected) {
    return '\"$name\" was a POP3 account: its mail ($size) was downloaded to this computer and this is the only copy. The mail already removed from the server can no longer be recovered.\n\nTo confirm, type: $expected';
  }

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get browserNotOpened => 'The browser did not open.';

  @override
  String signInNotStarted(String error) {
    return 'Sign-in not started: $error';
  }

  @override
  String get signInExpired => 'Sign-in expired: try again.';

  @override
  String signInFailedError(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get signInFailed => 'Sign-in failed.';

  @override
  String get signInWithoutContacts =>
      'Signed in, but without permission for contacts: contact synchronization stays off. To turn it on, check the box again and allow access.';

  @override
  String get signInWithoutCalendar =>
      'Signed in, but without permission for the calendar: calendar synchronization stays off. To turn it on, check the box again and allow access.';

  @override
  String get signInWithoutContactsCalendar =>
      'Signed in, but without permission for contacts and calendar: contact and calendar synchronization stays off. To turn it on, check the box again and allow access.';

  @override
  String waitingSignIn(String company) {
    return 'Waiting for sign-in on the $company page, in the browser…';
  }

  @override
  String signedInWith(String company) {
    return 'Signed in with $company: no password to save.';
  }

  @override
  String noPasswordSignIn(String company) {
    return 'No password: you sign in on the $company page, in the browser. When you come back, address and servers are filled in automatically.';
  }

  @override
  String serviceUnavailable(String service) {
    return '$service is not available: the core does not have the app ID.';
  }

  @override
  String signInWith(String company) {
    return 'Sign in with $company';
  }

  @override
  String get welcomeTitle => 'Welcome to PostinoVip';

  @override
  String get newAccount => 'New Account';

  @override
  String get editAccount => 'Change Account';

  @override
  String get firstRunIntro =>
      'Enter your mailbox details. The password is kept in the system keyring.';

  @override
  String get accountType => 'Account type';

  @override
  String get accountTypeHelp =>
      'IMAP: mail stays on the server and can be seen from all devices (recommended).\nPOP3: mail is downloaded to this computer. It cannot be changed later.';

  @override
  String accountTypeServices(String services) {
    return '$services: sign in with the browser, no password.';
  }

  @override
  String accountTypeValue(String type) {
    return 'Account type: $type';
  }

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get nameOptionalHint => 'e.g. Work; if empty, the address is shown';

  @override
  String get emailAddressUser => 'Email address (also the user name)';

  @override
  String get invalidAddressShort => 'Invalid address';

  @override
  String get accountAlreadyPresent => 'This account already exists';

  @override
  String get password => 'Password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get passwordRequired => 'Password required';

  @override
  String sameMailboxOtherType(String type, String name) {
    return 'This mailbox is already set up as $type (\"$name\"). It can be used both ways, but when POP3 removes mail from the server, it will disappear from the IMAP account too.';
  }

  @override
  String incomingServer(String type) {
    return '$type (incoming mail)';
  }

  @override
  String get outgoingServer => 'SMTP (outgoing mail)';

  @override
  String get smtpAuthTitle =>
      'My outgoing server (SMTP) requires authentication';

  @override
  String get smtpAuthSubtitle =>
      'With the mailbox address and password. Uncheck it only for a server that accepts mail without login (e.g. on port 25 of a company network).';

  @override
  String get downloadedMail => 'Mail downloaded to this computer';

  @override
  String get downloadedMailHelp =>
      'The most recent are downloaded in the background and open at once; the others when you open them.\nDeleted Items and Junk Email: only the list.';

  @override
  String get recommendedSuffix => ' (recommended)';

  @override
  String get syncContactsGoogle => 'Synchronize contacts with Google (CardDAV)';

  @override
  String get syncContactsServer =>
      'Synchronize contacts with the server (CardDAV)';

  @override
  String get notYetForMicrosoft => 'Not available yet for Microsoft accounts.';

  @override
  String get signInWithGoogleFirst => 'First click \"Sign in with Google\".';

  @override
  String get syncContactsGoogleHelp =>
      'This account\'s address book becomes your Google contacts. Checking the box opens the browser to allow PostinoVip to access your contacts.';

  @override
  String get syncContactsServerHelp =>
      'This account\'s address book becomes the one on the contacts server, with the same credentials. The first time, contacts that are only on this computer go to the server only after you confirm.';

  @override
  String get contactsSignInWaiting =>
      'Signing in with Google in the browser: allow access to contacts.';

  @override
  String get contactsServerUrl => 'Contacts server address (optional)';

  @override
  String get emptyFoundOnIncoming =>
      'Empty: found automatically on the incoming server';

  @override
  String emptyFoundOn(String host) {
    return 'Empty: found automatically on $host';
  }

  @override
  String get httpsRequired => 'An https:// address is required';

  @override
  String get testAddressBook => 'Test address book';

  @override
  String addressBookFound(String name) {
    return 'Found: \"$name\"';
  }

  @override
  String get addressBookNotFound => 'Address book not found.';

  @override
  String get calendarSection => 'Calendar';

  @override
  String get syncCalendarGoogle =>
      'Synchronize the calendar with Google (CalDAV)';

  @override
  String get syncCalendarServer =>
      'Synchronize the calendar with the server (CalDAV)';

  @override
  String get syncCalendarGoogleHelp =>
      'Your Google calendars become this account\'s calendars; read-only ones (e.g. holidays) can be seen but not changed. Checking the box opens the browser to allow PostinoVip to access your calendar.';

  @override
  String get syncCalendarServerHelp =>
      'The server calendars that accept appointments become this account\'s calendars. The first time, appointments that are only on this computer go to the server only after you confirm.';

  @override
  String get calendarSignInWaiting =>
      'Signing in with Google in the browser: allow access to the calendar.';

  @override
  String get calendarServerUrl => 'Calendar server address (optional)';

  @override
  String get testCalendar => 'Test calendar';

  @override
  String calendarsFound(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found',
    );
    return '$_temp0: $names';
  }

  @override
  String quoted(String text) {
    return '\"$text\"';
  }

  @override
  String get calendarNotFound => 'Calendar not found.';

  @override
  String get enterAddressPasswordFirst => 'Enter address and password first.';

  @override
  String get enterServerOrCalendarUrl =>
      'Enter the incoming server or the calendar server address.';

  @override
  String get enterServerOrContactsUrl =>
      'Enter the incoming server or the contacts server address.';

  @override
  String get deliverySection => 'Delivery';

  @override
  String get leaveCopyOnServer => 'Leave a copy of messages on the server';

  @override
  String get removeFromServerAfter => 'Remove from server after';

  @override
  String get days => 'days';

  @override
  String get removeWhenDeleted =>
      'Remove from server when deleted from \"Deleted Items\"';

  @override
  String get pop3NoCopyWarning =>
      'Each message will be removed from the server right after downloading it: it will stay only on this computer.';

  @override
  String get checkMailEvery => 'Check for new mail every';

  @override
  String get checkMailEveryHelp =>
      'Also with Send/Receive (F9). The mail is only on this computer: it is a good idea to back it up.';

  @override
  String minutesCount(int count) {
    return '$count minutes';
  }

  @override
  String get server => 'Server';

  @override
  String get serverHint => 'e.g. mail.domain.com';

  @override
  String get serverRequired => 'Server required';

  @override
  String get port => 'Port';

  @override
  String get encryption => 'Encryption';

  @override
  String get unencryptedWarning =>
      'Without encryption, password and mail travel in clear text: anyone on the network can read them. Use it only on a network you trust.';

  @override
  String get certificateTrustedByYou =>
      'Server certificate accepted by you (not signed by a recognized authority).';

  @override
  String get stopTrusting => 'Stop trusting';

  @override
  String testFailed(String error) {
    return 'Test failed: $error';
  }

  @override
  String get trustCertificateQuestion => 'Trust this certificate?';

  @override
  String invalidCertificatePresented(String server, String address) {
    return 'The $server server $address presented an invalid certificate:';
  }

  @override
  String get certificateIssuedTo => 'Issued to';

  @override
  String get certificateIssuedBy => 'Issued by';

  @override
  String get certificateValid => 'Valid';

  @override
  String certificateValidRange(String from, String to) {
    return 'from $from to $to';
  }

  @override
  String get certificateFingerprint => 'SHA-256 fingerprint';

  @override
  String get certificateAdvice =>
      'Accept it only if you know that this server uses its own certificate (e.g. a company or home server); if possible, compare the fingerprint with the one your administrator gives you. An unexpected certificate may mean that someone is trying to intercept your password.\n\nIf you accept, PostinoVip will trust only this certificate: if the server presents a different one, it will ask you again.';

  @override
  String get trustCertificate => 'Trust the certificate';

  @override
  String get testConnection => 'Test Account Settings';

  @override
  String get save => 'Save';

  @override
  String get saveAfterTest =>
      '\"Save\" becomes available after a successful test.';

  @override
  String accountNotSaved(String error) {
    return 'Account not saved: $error';
  }

  @override
  String unencryptedIncoming(String address) {
    return 'incoming ($address)';
  }

  @override
  String unencryptedOutgoing(String address) {
    return 'outgoing ($address)';
  }

  @override
  String get unencryptedTitle => 'Connection without encryption';

  @override
  String unencryptedContent(String servers) {
    return 'For $servers you chose \"None\" encryption: the password and mail travel in clear text and anyone on the same network (public Wi-Fi, company network, provider) can read or change them.\n\nSave anyway?';
  }

  @override
  String get andSeparator => ' and ';

  @override
  String get saveUnencrypted => 'Save without encryption';

  @override
  String get runFilterAll => 'All messages';

  @override
  String get runFilterRead => 'Read messages';

  @override
  String get runFilterUnread => 'Unread messages';

  @override
  String ruleNameFrom(String sender) {
    return 'From $sender';
  }

  @override
  String ruleCreated(String name) {
    return 'Rule \"$name\" created: it applies to mail that arrives from now on.';
  }

  @override
  String ruleNotSaved(String error) {
    return 'Rule not saved: $error';
  }

  @override
  String get orSeparator => ' or ';

  @override
  String ruleDescFrom(String words) {
    return 'from $words';
  }

  @override
  String ruleDescToOrCc(String words) {
    return 'To or Cc contains $words';
  }

  @override
  String get ruleDescSentOnlyToMe => 'sent only to me';

  @override
  String get ruleDescMeInTo => 'me in To';

  @override
  String get ruleDescMeInCc => 'me in Cc';

  @override
  String ruleDescSubject(String words) {
    return 'subject contains $words';
  }

  @override
  String ruleDescSubjectOrBody(String words) {
    return 'subject or body contains $words';
  }

  @override
  String get ruleDescAttachments => 'with attachments';

  @override
  String ruleDescSize(int kb) {
    return 'larger than $kb KB';
  }

  @override
  String ruleDescMove(String folder) {
    return 'move to $folder';
  }

  @override
  String ruleDescCopy(String folder) {
    return 'copy to $folder';
  }

  @override
  String get ruleDescDelete => 'delete';

  @override
  String get ruleDescMarkRead => 'mark as read';

  @override
  String get ruleDescFlag => 'flag';

  @override
  String ruleDescCategory(String name) {
    return 'category $name';
  }

  @override
  String get ruleDescStop => 'stop processing more rules';

  @override
  String get ruleDescAllMail => 'All mail';

  @override
  String ruleDescIf(String conditions) {
    return 'If $conditions';
  }

  @override
  String ruleDescExcept(String exceptions) {
    return ', except if $exceptions';
  }

  @override
  String rulesNotRead(String error) {
    return 'Rules not read: $error';
  }

  @override
  String get deleteRuleQuestion => 'Delete the rule?';

  @override
  String deleteRuleContent(String name) {
    return 'The rule \"$name\" will no longer be applied. Mail already sorted stays where it is.';
  }

  @override
  String rulesNotSaved(String error) {
    return 'Rules not saved: $error';
  }

  @override
  String get rulesAndAlerts => 'Rules and Alerts';

  @override
  String get applyChangesToFolder => 'Apply changes to this folder';

  @override
  String get newRuleEllipsis => 'New Rule…';

  @override
  String get runRulesNowEllipsis => 'Run Rules Now…';

  @override
  String get noRules =>
      'No rules. With \"New Rule…\" incoming mail is sorted automatically.';

  @override
  String get rulesInfo =>
      'Rules apply in list order to mail arriving in the Inbox while PostinoVip is open; mail that arrived while the app was closed is sorted when it reopens.';

  @override
  String get chooseFolderColon => 'Choose the folder:';

  @override
  String get ruleNameRequired => 'Enter the rule name.';

  @override
  String get ruleFolderRequired => 'Choose the folder to move or copy to.';

  @override
  String get ruleActionRequired =>
      'Choose at least one action in the \"Actions\" tab.';

  @override
  String get ruleSizeRequired => 'Enter the size in KB.';

  @override
  String get ruleForAllMail => 'Rule for all mail';

  @override
  String get ruleForAllMailContent =>
      'Without conditions, the rule will apply to all mail you receive. Is this correct?';

  @override
  String get newRule => 'New Rule';

  @override
  String get editRule => 'Change Rule';

  @override
  String get ruleName => 'Rule name';

  @override
  String get ruleConditions => 'Conditions';

  @override
  String get ruleActions => 'Actions';

  @override
  String get ruleExceptions => 'Exceptions';

  @override
  String get ruleConditionsIntro =>
      'Apply the rule to mail that meets all the selected conditions:';

  @override
  String get ruleExceptionsIntro => 'Except if at least one of these is true:';

  @override
  String get ruleFrom => 'from';

  @override
  String get ruleFromHint => 'e.g. anna@example.com; example.com';

  @override
  String get ruleToOrCc => 'To or Cc contains';

  @override
  String get ruleToOrCcHint => 'names or addresses, separated by ;';

  @override
  String get ruleMeInTo => 'my address is in the To box';

  @override
  String get ruleMeInCc => 'my address is in the Cc box';

  @override
  String get ruleSubjectContains => 'the subject contains';

  @override
  String get ruleSubjectOrBodyContains => 'the subject or body contains';

  @override
  String get ruleWordsHint => 'words separated by ;';

  @override
  String get ruleLargerThan => 'larger than';

  @override
  String get chooseFolderEllipsis => 'Choose the folder…';

  @override
  String get ruleActionsIntro =>
      'What to do with mail that meets the conditions:';

  @override
  String get ruleMoveTo => 'move it to the folder';

  @override
  String get ruleMoveToTitle => 'Move to folder';

  @override
  String get ruleCopyTo => 'copy it to the folder';

  @override
  String get ruleCopyToTitle => 'Copy to folder';

  @override
  String get ruleDeleteAction => 'delete it (to Deleted Items)';

  @override
  String get ruleFlagAction => 'flag it for follow up';

  @override
  String get ruleCategoryAction => 'assign it to the category';

  @override
  String get ruleStopAction => 'stop processing more rules';

  @override
  String rulesNotRun(String error) {
    return 'Rules not run: $error';
  }

  @override
  String progressUnavailable(String error) {
    return 'Progress not available: $error';
  }

  @override
  String get runInFolder => 'Run in folder';

  @override
  String runStoppedError(String error) {
    return 'Stopped because of an error: $error';
  }

  @override
  String runStoppedChecked(int checked, int total) {
    return 'Stopped: $checked of $total messages checked';
  }

  @override
  String runDoneChecked(int checked) {
    return 'Done: $checked messages checked';
  }

  @override
  String runOutcome(String head, int applied) {
    return '$head, $applied moved or changed';
  }

  @override
  String runFailedActions(int count) {
    return ', $count actions failed (details in the core log)';
  }

  @override
  String get runRulesNow => 'Run Rules Now';

  @override
  String get rulesToRun => 'Select rules to run:';

  @override
  String get ruleDisabledSuffix => ' (disabled)';

  @override
  String get runInFolderLabel => 'Run in folder: ';

  @override
  String get includeSubfolders => 'Include subfolders';

  @override
  String get applyRulesTo => 'Apply rules to';

  @override
  String get preparing => 'Preparing…';

  @override
  String runProgress(int checked, int total) {
    return '$checked of $total messages checked';
  }

  @override
  String get stopping => 'stopping…';

  @override
  String get stop => 'Stop';

  @override
  String get runNow => 'Run Now';

  @override
  String settingsNotRead(String error) {
    return 'Settings not read: $error';
  }

  @override
  String get autoReplyTextRequired => 'Write the automatic reply message.';

  @override
  String get endAfterStart => 'The end time must be after the start time.';

  @override
  String get turnOnAutoRepliesQuestion => 'Turn on automatic replies?';

  @override
  String get turnOnAutoRepliesContent =>
      'From now on PostinoVip will reply automatically, once per sender, to mail arriving in the Inbox where you are in To or Cc, as long as it stays open. Replies are sent without asking you.';

  @override
  String get turnOn => 'Turn on';

  @override
  String notSavedPlural(String error) {
    return 'Not saved: $error';
  }

  @override
  String get dontSendAutoReplies => 'Do not send automatic replies';

  @override
  String get sendAutoReplies => 'Send automatic replies';

  @override
  String get onlyDuringRange => 'Only send during this time range';

  @override
  String get startTimeColon => 'Start time:';

  @override
  String get endTimeColon => 'End time:';

  @override
  String get autoRepliesInfo =>
      'Replies are sent from this computer while PostinoVip is open (mail that arrived while the app was closed gets the reply when it reopens): only one per sender, only if you are in To or Cc, never to mailing lists, other automatic replies or senders like \"noreply\". They are not saved in Sent Items.';

  @override
  String get autoReplyPlaceholder =>
      'e.g. I am out of the office until Monday, November 16 and will reply when I return.';

  @override
  String get junkLevelNone => 'No Automatic Filtering';

  @override
  String get junkLevelNoneInfo =>
      'Mail from blocked senders is still moved to the Junk Email folder.';

  @override
  String get junkLevelLow => 'Low';

  @override
  String get junkLevelLowInfo =>
      'Move the most obvious junk email: the mail the server marked as spam.';

  @override
  String get junkLevelHigh => 'High';

  @override
  String get junkLevelHighInfo =>
      'Also move mail with a score close to the server threshold: some regular mail may be caught as well, so check your Junk Email folder often.';

  @override
  String get junkLevelSafeOnly => 'Safe Lists Only';

  @override
  String get junkLevelSafeOnlyInfo =>
      'Only mail from people or domains on your Safe Senders List, or sent to your Safe Recipients List, stays in the Inbox.';

  @override
  String get safeSenders => 'Safe Senders';

  @override
  String get safeSendersInfo =>
      'Mail from these addresses or domains will never be treated as junk email.';

  @override
  String get safeRecipients => 'Safe Recipients';

  @override
  String get safeRecipientsInfo =>
      'Mail sent to these addresses or domains (for example a mailing list) will never be treated as junk email.';

  @override
  String get blockedSenders => 'Blocked Senders';

  @override
  String get blockedSendersInfo =>
      'Mail from these addresses or domains will always be moved to the Junk Email folder.';

  @override
  String get neverBlockSender => 'Never Block Sender';

  @override
  String get neverBlockDomain => 'Never Block Sender\'s Domain';

  @override
  String get neverBlockGroup => 'Never Block this Group or Mailing List';

  @override
  String get neverBlockGroups => 'Never Block these Groups or Mailing Lists';

  @override
  String get blockSender => 'Block Sender';

  @override
  String get junkOptionsEllipsis => 'Junk Email Options…';

  @override
  String get noJunkFolder => 'No Junk Email folder';

  @override
  String noJunkFolderContent(String name) {
    return 'The account \"$name\" has no Junk Email folder: choose one in \"Junk Email Options\". The sender was not blocked.';
  }

  @override
  String get markAsNotJunk => 'Mark as Not Junk';

  @override
  String notJunkMoveBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'These $count messages will be moved back into the Inbox folder.',
      one: 'This message will be moved back into the Inbox folder.',
    );
    return '$_temp0';
  }

  @override
  String alwaysTrustSender(String sender) {
    return 'Always trust email from \"$sender\"';
  }

  @override
  String get alwaysTrustSenders => 'Always trust email from these senders';

  @override
  String optionsNotRead(String error) {
    return 'Options not read: $error';
  }

  @override
  String optionsNotSaved(String error) {
    return 'Options not saved: $error';
  }

  @override
  String get invalidValue => 'invalid value';

  @override
  String get junkOptions => 'Junk Email Options';

  @override
  String get junkOptionsIntro =>
      'New Inbox mail that appears to be junk email is moved to a special folder while PostinoVip is open. The judgment is the one of the mail server. Choose the level of protection:';

  @override
  String get junkFolder => 'Junk Email folder';

  @override
  String junkFolderAutomatic(String folder) {
    return 'Automatic: \"$folder\"';
  }

  @override
  String get junkFolderAutomaticNone => 'Automatic (no folder found)';

  @override
  String get junkFolderInfo =>
      'Automatic: the one indicated by the server, or one with \"spam\", \"junk\" or \"indesiderata\" in its name. For a new folder: Folder tab → New Folder, then choose it here.';

  @override
  String get junkNoFolderWarning =>
      'Without a folder the filter does not move any mail.';

  @override
  String get noEntries => 'No entries';

  @override
  String get addEllipsis => 'Add…';

  @override
  String get trustContacts => 'Also trust email from my Contacts';

  @override
  String get junkEntryInvalid =>
      'Enter an address (anna@example.com) or a domain (@example.com).';

  @override
  String get addAddressOrDomain => 'Add address or domain';

  @override
  String get editAddressOrDomain => 'Edit address or domain';

  @override
  String get junkEntryLabel => 'Enter an email address or Internet domain name';

  @override
  String get junkEntryHint => 'e.g. anna@example.com or @example.com';

  @override
  String get alreadyInArchive => 'The message is already in the archive folder';

  @override
  String get archiveTooltip => 'Move to the archive folder (Backspace)';

  @override
  String get mailsAlreadyInArchive =>
      'The messages are already in the archive folder';

  @override
  String get archiveFolderName => 'Archive';

  @override
  String get offlineUnavailable =>
      'Not available without a connection to the server.';

  @override
  String archiveFirstTime(String name) {
    return 'The account \"$name\" does not have an archive folder yet. Choose it: Archive will move mail there, without deleting it.';
  }

  @override
  String archiveInfo(String name) {
    return 'Archive moves mail of \"$name\" to this folder, without deleting it.';
  }

  @override
  String get useExistingFolder => 'Use an existing folder';

  @override
  String get chooseAFolder => 'Choose a folder';

  @override
  String get createTopFolder => 'Create a new folder at the top of the account';

  @override
  String get okAndArchive => 'OK and archive';

  @override
  String get stopIgnore => 'Stop Ignoring';

  @override
  String get ignore => 'Ignore';

  @override
  String get stopIgnoreTooltip =>
      'The conversation goes back to the Inbox and new mail no longer goes to Deleted Items';

  @override
  String get ignoreTooltip =>
      'Move the conversation and future messages to Deleted Items';

  @override
  String cleanUpFolderContent(String name) {
    return 'Redundant messages in the folder \"$name\" (those quoted in full by a reply) will be moved to Deleted Items. Unread, flagged, categorized or signed messages stay where they are.';
  }

  @override
  String get stopIgnoreContent =>
      'The selected conversation will no longer be ignored and its messages in Deleted Items will be moved to the Inbox.';

  @override
  String get ignoreContent =>
      'The messages of the selected conversation in this folder and all future messages will be moved to Deleted Items.';

  @override
  String get dontShowAgain => 'Don\'t show this message again';

  @override
  String get notifyAlways => 'Always';

  @override
  String get notifyUnfocused => 'Only when the window is not in the foreground';

  @override
  String get notifyNever => 'Never';

  @override
  String get readImmediately => 'As soon as it is opened';

  @override
  String get readAfterDelay => 'After it has been viewed for a few seconds';

  @override
  String get readManual => 'Never automatically (only with the button)';

  @override
  String get receiptAsk => 'Ask each time whether to send a read receipt';

  @override
  String get receiptAlways => 'Always send a read receipt';

  @override
  String get receiptNever => 'Never send a read receipt';

  @override
  String get categoryRed => 'Red category';

  @override
  String get categoryOrange => 'Orange category';

  @override
  String get categoryYellow => 'Yellow category';

  @override
  String get categoryGreen => 'Green category';

  @override
  String get categoryBlue => 'Blue category';

  @override
  String get categoryPurple => 'Purple category';

  @override
  String get followUpTomorrow => 'Tomorrow';

  @override
  String get followUpThisWeek => 'This Week';

  @override
  String get followUpNextWeek => 'Next Week';

  @override
  String get followUpNoDate => 'No Date';

  @override
  String get clearAllCategories => 'Clear All Categories';

  @override
  String get allCategoriesEllipsis => 'All Categories…';

  @override
  String get customDateEllipsis => 'Custom…';

  @override
  String get markComplete => 'Mark Complete';

  @override
  String get clearFlag => 'Clear Flag';

  @override
  String get dueByTitle => 'Due date';

  @override
  String get categoriesTitle => 'Color Categories';

  @override
  String get categoriesInfo =>
      'Names apply only on this computer; on the server each category is saved with its color.';

  @override
  String get defaultNames => 'Default names';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Desktop email client: interface in Flutter, core in C# with MailKit.';

  @override
  String aboutLegal(String license) {
    return 'This program is free software: you can redistribute it and/or modify it under the terms of the $license, published by the Free Software Foundation.\n\nIt is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. The full text of the license is in \"View licenses\" → PostinoVip.';
  }

  @override
  String coreVersionUnavailable(String error) {
    return 'Core: version not available ($error)';
  }

  @override
  String coreVersion(String version) {
    return 'Core: version $version';
  }

  @override
  String get coreVersionMismatch =>
      'Warning: app and core have different versions (rebuild the core).';

  @override
  String get composeMessages => 'Compose messages';

  @override
  String get composeInFormat => 'Compose messages in this format';

  @override
  String get composeInFormatHelp =>
      'For new messages; replies and forwards use the format of the original message';

  @override
  String get signaturesSection => 'Signatures';

  @override
  String signatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signatures',
      one: '1 signature',
      zero: 'No signatures',
    );
    return '$_temp0';
  }

  @override
  String get signaturesInfo =>
      'Added automatically to new messages and replies, per account';

  @override
  String get markAsReadSection => 'Mark as read';

  @override
  String get readReceiptsSection => 'Read receipts';

  @override
  String get alwaysRequestReceipt =>
      'Always request a read receipt for new messages';

  @override
  String get receiptForReceived =>
      'For any message received that includes a read receipt request:';

  @override
  String get confirmBeforeIgnore => 'Ask before Ignore Conversation';

  @override
  String get confirmBeforeStopIgnoring =>
      'Ask before Stop Ignoring Conversation';

  @override
  String get newMailNotifications => 'New mail notifications';

  @override
  String get notificationsUnavailable =>
      'System notifications not available: the reason is in the terminal (\"[notifiche]\").';

  @override
  String get testNotification => 'Test notification';

  @override
  String get testNotificationText =>
      'Test notification: if you see it, notifications work.';

  @override
  String get firstDayOfWeek => 'First day of week';

  @override
  String get workDays => 'Work days (Work Week)';

  @override
  String get workStart => 'Work hours start';

  @override
  String get workEnd => 'Work hours end';

  @override
  String receiptNotSent(String error) {
    return 'Read receipt not sent: $error';
  }

  @override
  String receiptNotRecorded(String error) {
    return 'Read receipt not recorded: $error';
  }

  @override
  String operationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get outboxSending =>
      'Sending: the message leaves as soon as the server answers.';

  @override
  String get outboxDeleted =>
      'Message deleted from the Outbox: it will not be sent.';

  @override
  String get outboxMovedToDrafts =>
      'Message moved to Drafts: open it from there to edit it.';

  @override
  String folderNotListed(String folder) {
    return 'The server confirmed the folder \"$folder\", but does not show it in the folder list.';
  }

  @override
  String get anotherOperation => 'Another operation is in progress';

  @override
  String folderDeletedPermanently(String folder) {
    return 'Folder \"$folder\" permanently deleted';
  }

  @override
  String folderMovedToTrash(String folder) {
    return 'Folder \"$folder\" moved to Deleted Items';
  }

  @override
  String folderNotDeleted(String error) {
    return 'Folder not deleted: $error';
  }

  @override
  String folderEmptied(String folder, String mails, String folders) {
    return '\"$folder\" emptied: $mails$folders permanently deleted';
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
      other: ' and $count folders',
      one: ' and 1 folder',
    );
    return '$_temp0';
  }

  @override
  String folderNotEmptied(String error) {
    return 'Folder not emptied: $error';
  }

  @override
  String folderMovedToTop(String folder) {
    return 'Folder \"$folder\" moved to the top of the account';
  }

  @override
  String folderMovedInto(String folder, String parent) {
    return 'Folder \"$folder\" moved to \"$parent\"';
  }

  @override
  String folderNotMoved(String error) {
    return 'Folder not moved: $error';
  }

  @override
  String get mailNotDownloadedOffline =>
      'Message not available offline: it has not been downloaded to this computer yet.';

  @override
  String readStateNotUpdated(String error) {
    return 'Read/unread state not updated: $error';
  }

  @override
  String tagsNotUpdated(String error) {
    return 'Flag or categories not updated: $error';
  }

  @override
  String movedTo(String folder) {
    return 'Moved to \"$folder\"';
  }

  @override
  String get deletedPermanently => 'Permanently deleted';

  @override
  String markedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 marked as read';
  }

  @override
  String markedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 marked as unread';
  }

  @override
  String othersFailed(String text, String error) {
    return '$text; the others failed: $error';
  }

  @override
  String readNotUpdated(String error) {
    return 'Read state not updated: $error';
  }

  @override
  String mailsMovedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 moved to \"$folder\"';
  }

  @override
  String mailsDeletedPermanently(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 permanently deleted';
  }

  @override
  String mailsMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 moved to Deleted Items';
  }

  @override
  String mailsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages archived',
      one: '1 message archived',
    );
    return '$_temp0';
  }

  @override
  String get conversationIgnored =>
      'Conversation ignored: future messages will go to Deleted Items';

  @override
  String conversationIgnoredMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 moved to Deleted Items; future messages will go there too';
  }

  @override
  String get conversationNotIgnored => 'The conversation is no longer ignored';

  @override
  String mailsBackToInbox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 moved back to the Inbox';
  }

  @override
  String cleanUpDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redundant messages moved to Deleted Items',
      one: '1 redundant message moved to Deleted Items',
      zero: 'No redundant messages to move',
    );
    return '$_temp0';
  }

  @override
  String get noMailMoved => 'No messages moved';

  @override
  String mailsMovedToJunk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 moved to Junk Email';
  }

  @override
  String senderBlocked(String sender) {
    return '$sender blocked';
  }

  @override
  String sendersBlocked(int count, String senders) {
    return '$count senders blocked ($senders)';
  }

  @override
  String senderTrusted(String sender) {
    return '$sender trusted';
  }

  @override
  String sendersTrusted(int count, String senders) {
    return '$count senders trusted ($senders)';
  }

  @override
  String addedToSafeSenders(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries added',
    );
    return '$_temp0 to Safe Senders';
  }

  @override
  String addedToSafeRecipients(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries added',
    );
    return '$_temp0 to Safe Recipients';
  }

  @override
  String listsNotUpdated(String error) {
    return 'Lists not updated: $error';
  }

  @override
  String mailsCopiedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0 copied to \"$folder\"';
  }

  @override
  String mailsNotCopied(String error) {
    return 'Messages not copied: $error';
  }

  @override
  String get fmtTime => 'h:mm a';

  @override
  String get fmtDayMonth => 'M/d';

  @override
  String get fmtDate => 'M/d/yyyy';

  @override
  String get fmtWeekdayDate => 'EEE M/d/yyyy';

  @override
  String get fmtWeekdayDateTime => 'EEE M/d/yyyy h:mm a';

  @override
  String get fmtWeekdayTime => 'EEE h:mm a';

  @override
  String get fmtLongDateTime => 'EEEE, MMMM d, y h:mm a';

  @override
  String get groupNoDate => 'No Date';

  @override
  String get groupYesterday => 'Yesterday';

  @override
  String get groupLastWeek => 'Last Week';

  @override
  String get groupTwoWeeksAgo => 'Two Weeks Ago';

  @override
  String get groupThreeWeeksAgo => 'Three Weeks Ago';

  @override
  String get groupEarlierThisMonth => 'Earlier this Month';

  @override
  String get groupLastMonth => 'Last Month';

  @override
  String get groupOlder => 'Older';

  @override
  String get sizeTiny => 'Tiny (< 10 KB)';

  @override
  String get sizeSmall => 'Small (10 - 25 KB)';

  @override
  String get sizeMedium => 'Medium (25 - 100 KB)';

  @override
  String get sizeLarge => 'Large (100 - 500 KB)';

  @override
  String get sizeVeryLarge => 'Very Large (500 KB - 1 MB)';

  @override
  String get sizeHuge => 'Huge (1 - 5 MB)';

  @override
  String get sizeEnormous => 'Enormous (> 5 MB)';

  @override
  String sizeBytes(int count) {
    return '$count bytes';
  }

  @override
  String get fmtMonthYear => 'MMMM y';

  @override
  String get fmtFullDate => 'EEEE, MMMM d, y';

  @override
  String get fmtHour => 'h a';

  @override
  String get fmtRangeSameMonthStart => 'MMMM d';

  @override
  String get fmtRangeSameMonthEnd => 'd, y';

  @override
  String get fmtRangeOtherMonthStart => 'MMMM d';

  @override
  String get fmtRangeOtherMonthEnd => 'MMMM d, y';

  @override
  String get fmtRangeOtherYearStart => 'MMMM d, y';

  @override
  String get fmtRangeOtherYearEnd => 'MMMM d, y';

  @override
  String get recurOrdinalFirst => 'on the first';

  @override
  String get recurOrdinalSecond => 'on the second';

  @override
  String get recurOrdinalThird => 'on the third';

  @override
  String get recurOrdinalFourth => 'on the fourth';

  @override
  String get recurOrdinalLast => 'on the last';

  @override
  String recurDescDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeeklyOn(String every, String days) {
    return '$every on $days';
  }

  @override
  String recurDescMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String recurDescMonthlyDay(String every, int day) {
    return '$every on day $day';
  }

  @override
  String recurDescMonthlyWhich(String every, String which) {
    return '$every $which';
  }

  @override
  String recurDescYearlyWhich(String which, String month) {
    return 'Every year $which of $month';
  }

  @override
  String recurDescYearlyDay(String day, String month) {
    return 'Every year on $month $day';
  }

  @override
  String get recurDescRecurring => 'Recurring';

  @override
  String recurDescTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count times',
      one: ', 1 time',
    );
    return '$_temp0';
  }

  @override
  String recurDescUntil(String date) {
    return ', until $date';
  }

  @override
  String whenAllDay(String date) {
    return '$date (all day)';
  }

  @override
  String whenAllDayRange(String start, String end) {
    return 'From $start to $end (all day)';
  }

  @override
  String get coreKindInvalidRequest => 'Invalid request';

  @override
  String get coreKindNotFound => 'Not found';

  @override
  String get coreKindOffline => 'Not connected';

  @override
  String get coreKindServer => 'Mail server error';

  @override
  String get coreKindConflict => 'Operation not allowed';

  @override
  String get coreKindNotSupported => 'Not supported by the server';

  @override
  String get coreKindCertificate => 'Invalid server certificate';

  @override
  String get coreKindOAuth => 'Account sign-in failed';

  @override
  String get coreKindAuth => 'Authentication with the mail server failed';

  @override
  String get coreKindConfig => 'Invalid configuration';

  @override
  String get coreKindInternal => 'Internal error';

  @override
  String certNameMismatch(String host) {
    return 'issued to a name other than $host';
  }

  @override
  String get certUntrustedRoot =>
      'not signed by a recognized authority (e.g. self-signed)';

  @override
  String get certNotTimeValid => 'expired or not yet valid';

  @override
  String get certRevoked => 'revoked';

  @override
  String get certChainInvalid => 'invalid certificate chain';

  @override
  String get certNoCertificate => 'no certificate';

  @override
  String get coreTimeout =>
      'The server is not responding: the operation may not have been carried out.';

  @override
  String get coreAuthCheckCredentials => 'Check user name and password.';

  @override
  String get coreInternalUnexpected => 'Unexpected error, see the core log.';

  @override
  String coreCertificateChanged(String address, String problems) {
    return 'Invalid certificate for $address ($problems). Open the account settings and repeat \"Test Account Settings\".';
  }

  @override
  String coreTestCertificateInvalid(String address, String problems) {
    return 'The certificate of the server $address is not valid: $problems.';
  }

  @override
  String coreTestNoStartTls(String address) {
    return 'The server $address does not offer STARTTLS: choose another encryption or another port.';
  }

  @override
  String get coreTestAuthRejected =>
      'Authentication rejected: check address and password.';

  @override
  String coreTestTlsFailed(String address) {
    return 'Encrypted connection to $address failed: does the port really use this encryption?';
  }

  @override
  String coreTestUnreachable(String address) {
    return 'Server $address not reachable.';
  }

  @override
  String coreTestNoAnswer(String address, String seconds) {
    return 'No answer from $address within $seconds s: wrong server, port or encryption?';
  }

  @override
  String coreTestUnexpectedAnswer(String address) {
    return 'Unexpected answer from $address: wrong port or protocol?';
  }

  @override
  String corePop3NoUidl(String address) {
    return 'The POP3 server $address does not support UIDL: it is needed to avoid downloading mail twice.';
  }

  @override
  String coreOAuthServerUnreachable(String provider) {
    return '$provider sign-in server not reachable.';
  }

  @override
  String coreOAuthInvalidResponse(String provider, String status) {
    return 'Invalid response from the $provider sign-in server (HTTP $status).';
  }

  @override
  String coreOAuthExpired(String provider) {
    return 'Sign-in to $provider expired or revoked: repeat \"Sign in with $provider\".';
  }

  @override
  String coreOAuthClientInvalid(String provider) {
    return 'PostinoVip is not registered correctly with $provider (client ID).';
  }

  @override
  String coreOAuthFailed(String provider, String error) {
    return 'Sign-in to $provider failed ($error).';
  }

  @override
  String get coreOAuthCancelled => 'Sign-in cancelled.';

  @override
  String get coreOAuthNoCode => 'Sign-in failed (no code).';

  @override
  String coreOAuthFlowFailed(String error) {
    return 'Sign-in failed ($error).';
  }

  @override
  String get coreOAuthNoRefreshToken =>
      'The provider did not give a refresh token (offline_access missing?).';

  @override
  String coreServerUnreachable(String reason) {
    return 'Server not reachable ($reason).';
  }

  @override
  String corePop3NoAnswer(String address) {
    return 'POP3 server $address not reachable (no answer).';
  }

  @override
  String corePop3Unreachable(String address, String reason) {
    return 'POP3 server $address not reachable ($reason).';
  }

  @override
  String coreSmtpNoAnswer(String seconds) {
    return 'Outgoing server not reachable (no answer in $seconds s): message not sent.';
  }

  @override
  String coreSmtpUnreachable(String reason) {
    return 'Outgoing server not reachable ($reason): message not sent.';
  }

  @override
  String get coreContactsServerUnreachable => 'Contacts server not reachable.';

  @override
  String get coreCalendarServerUnreachable => 'Calendar server not reachable.';

  @override
  String get coreContactsServerNoAnswer =>
      'The contacts server is not responding.';

  @override
  String get coreCalendarServerNoAnswer =>
      'The calendar server is not responding.';

  @override
  String coreDavSignInRejectedContacts(String provider) {
    return '$provider refused access to the contacts server: repeat \"Sign in with $provider\" allowing access to contacts.';
  }

  @override
  String coreDavSignInRejectedCalendar(String provider) {
    return '$provider refused access to the calendar server: repeat \"Sign in with $provider\" allowing access to the calendar.';
  }

  @override
  String coreDavScopeMissingContacts(String provider) {
    return 'The sign-in with $provider does not include permission for contacts: repeat \"Sign in with $provider\".';
  }

  @override
  String coreDavScopeMissingCalendar(String provider) {
    return 'The sign-in with $provider does not include permission for the calendar: repeat \"Sign in with $provider\".';
  }

  @override
  String coreAccountScopeMissingContacts(String provider) {
    return 'The sign-in with $provider does not include contacts: in the account window use \"Sign in again\" and allow access to contacts.';
  }

  @override
  String coreAccountScopeMissingCalendar(String provider) {
    return 'The sign-in with $provider does not include the calendar: in the account window use \"Sign in again\" and allow access to the calendar.';
  }

  @override
  String get coreNotConnected => 'not connected';

  @override
  String coreUnreachableApp(String address, String error) {
    return 'PostinoVip core not reachable at $address: $error';
  }

  @override
  String get coreUnexpectedResponse => 'Unexpected response from the core';

  @override
  String get coreUnexpectedResponseVersions =>
      'Unexpected response from the core (different app and core versions?)';

  @override
  String get coreEventsUnavailable => 'Events not available';

  @override
  String coreUnexpectedFormat(String path, String error) {
    return 'Core response in an unexpected format ($path): $error. Is the core updated and restarted?';
  }

  @override
  String get imagePlaceholder => 'image';

  @override
  String get coreErrScrivereIlNomeDellaCartella => 'Enter the folder name.';

  @override
  String coreErrIlNomePuoAvereAl(String maxLength) {
    return 'The name can have at most $maxLength characters.';
  }

  @override
  String get coreErrIlNomeContieneCaratteriNon =>
      'The name contains invalid characters.';

  @override
  String coreErrIlNomeNonPuoContenere(String separator) {
    return 'The name cannot contain the character \"$separator\".';
  }

  @override
  String get coreErrInboxIlNomeRiservatoDella =>
      '\"INBOX\" is the reserved name of the Inbox.';

  @override
  String get coreErrIlMessaggioOriginaleDisponibileSolo =>
      'The original message is available only with the local copy.';

  @override
  String get coreErrCartellaNonValida => 'Invalid folder.';

  @override
  String get coreErrLaMailNonChiedeUna =>
      'The message does not request a read receipt to this address.';

  @override
  String get coreErrLivelloDelFiltroNonValido => 'Invalid filter level.';

  @override
  String get coreErrNessunaCartellaDellaPostaIndesiderata =>
      'No Junk Email folder: choose it in \"Junk Email Options\".';

  @override
  String get coreErrNessunMittenteDaBloccareLe =>
      'No sender to block (the messages were sent from this account or have no sender).';

  @override
  String get coreErrNonPostaIndesiderataValeSolo =>
      '\"Not Junk\" applies only to messages in the Junk Email folder.';

  @override
  String coreErrNessunaDelleMailIndicateIn(String folder) {
    return 'None of the given messages is in \'$folder\'.';
  }

  @override
  String get coreErrIlServerPop3NonSupporta =>
      'The POP3 server does not support UIDL: without it, there is no way to know which messages were already downloaded.';

  @override
  String get coreErrIdNonValido => 'Invalid id.';

  @override
  String get coreErrHostSmtpNonConfigurato => 'SMTP host not configured.';

  @override
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2) {
    return 'Attachments too large: $value MB, maximum $value2 MB.';
  }

  @override
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel) {
    return 'The $serverLabel refused the request (403).';
  }

  @override
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  ) {
    return 'Address of the $value not allowed: https is required ($scheme://$host).';
  }

  @override
  String get coreErrNessunCalendarioTrovatoSulServer =>
      'No calendar found on the calendar server.';

  @override
  String get coreErrNessunaRubricaTrovataSulServer =>
      'No address book found on the contacts server.';

  @override
  String coreErrIlHaCreatoElementoSenza(String serverLabel) {
    return 'The $serverLabel created the item without saying where (Location missing).';
  }

  @override
  String coreErrIlHaCreatoElementoFuori(String serverLabel) {
    return 'The $serverLabel created the item outside the collection.';
  }

  @override
  String coreErrTroppiReindirizzamentiDal(String serverLabel) {
    return 'Too many redirects from the $serverLabel.';
  }

  @override
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel) {
    return 'The $serverLabel rejected the user name or password.';
  }

  @override
  String coreErrCertificatoDelNonValido(String serverLabel) {
    return 'Invalid certificate of the $serverLabel.';
  }

  @override
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  ) {
    return 'The $serverLabel answered $code $reasonPhrase.';
  }

  @override
  String coreErrRispostaDelNonLeggibile(String serverLabel) {
    return 'Unreadable response from the $serverLabel.';
  }

  @override
  String get coreErrIlFileNonUnaMail =>
      'The file is not a readable message (.eml).';

  @override
  String get coreErrIlFileNonUnaMail2 =>
      'The file is not a message (.eml): sender, date, subject and recipients are missing.';

  @override
  String get coreErrIlFileEmlNonPiu =>
      'The .eml file is no longer open: open it again.';

  @override
  String coreErrAccountNonTrovato(String id) {
    return 'Account \'$id\' not found.';
  }

  @override
  String coreErrAccountUnAccountPop3Richiede(String id) {
    return 'Account \'$id\': a POP3 account requires the local copy (Cache:Enabled=false is not possible).';
  }

  @override
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider) {
    return 'Account \'$id\': unknown OAuth provider \'$provider\'.';
  }

  @override
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  ) {
    return 'Account \'$id\': the $displayName client ID is missing (section OAuth:$id2).';
  }

  @override
  String get coreErrNessunAccountConfigurato => 'No account configured.';

  @override
  String coreErrIdAccountNonValidoAmmessi(String id) {
    return 'Invalid account id: \'$id\' (letters, digits, \'-\' and \'_\' allowed, at most 64).';
  }

  @override
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths) {
    return 'Account \'$id\': invalid cache limit ($bodyMonths months; 0 = all).';
  }

  @override
  String coreErrAccountIndirizzoNonValido(String id, String name) {
    return 'Account \'$id\': invalid $name address.';
  }

  @override
  String coreErrAccount(String id, String message) {
    return 'Account \'$id\': $message';
  }

  @override
  String coreErrIdAccountRipetuto(String key) {
    return 'Repeated account id: \'$key\'.';
  }

  @override
  String coreErrCartellaNonTrovata(String fullName) {
    return 'Folder \'$fullName\' not found.';
  }

  @override
  String coreErrLaCartellaEsisteGia(String fullName) {
    return 'The folder \'$fullName\' already exists.';
  }

  @override
  String coreErrCartellaNonTrovata2(String parent) {
    return 'Folder \'$parent\' not found.';
  }

  @override
  String coreErrCartellaNonTrovata3(String folder) {
    return 'Folder \'$folder\' not found.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn(String uid, String folder) {
    return 'Message $uid not found in \'$folder\'.';
  }

  @override
  String coreErrLaCartellaEsisteGia2(String newFullName) {
    return 'The folder \'$newFullName\' already exists.';
  }

  @override
  String get coreErrCartellaNonIndicata => 'Folder not specified.';

  @override
  String coreErrCartellaNonValida2(String fullName) {
    return 'Invalid folder \'$fullName\'.';
  }

  @override
  String coreErrCartellaAssenteDallIndiceDopo(String folder) {
    return 'Folder \'$folder\' missing from the index after synchronization.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid) {
    return 'Attachment $index not found in message $uid.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid) {
    return 'Attachment $i not found in message $uid.';
  }

  @override
  String get coreErrCartellaDiOrigineDestinazioneCoincidono =>
      'Source and destination folders are the same.';

  @override
  String get coreErrIlMessaggioGiaInPosta =>
      'The message is already in Deleted Items: use permanent deletion.';

  @override
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn =>
      'Permanent deletion is allowed only in Deleted Items.';

  @override
  String coreErrNonPuoAndareDentroSe(String folder) {
    return '\'$folder\' cannot go inside itself or one of its subfolders.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special) {
    return '\'$folder\' contains the special folder \'$special\': it is not emptied.';
  }

  @override
  String coreErrNessunaCartellaLocaleConRuolo(String role) {
    return 'No local folder with role $role.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName) {
    return 'Message $uid not found in \'$fullName\'.';
  }

  @override
  String coreErrNessunaRispostaIn(String totalSeconds) {
    return 'no answer in $totalSeconds s';
  }

  @override
  String get coreErrHostImapNonConfigurato => 'IMAP host not configured.';

  @override
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName) {
    return 'Message $uid not found in \'$folderName\'.';
  }

  @override
  String coreErrIlServerNonPermetteDi(String value, String folderName) {
    return 'The server does not allow saving the keywords $value in \'$folderName\'.';
  }

  @override
  String get coreErrIlServerNonDichiaraUna =>
      'The server does not declare a \\Sent folder (Sent Items): copy not saved.';

  @override
  String get coreErrIlServerNonDichiaraUna2 =>
      'The server does not declare a \\Drafts folder (Drafts): draft not saved.';

  @override
  String get coreErrIlServerNonDichiaraUna3 =>
      'The server does not declare a \\Drafts folder (Drafts).';

  @override
  String get coreErrIlServerNonDichiaraUna4 =>
      'The server does not declare a \\Trash folder (Deleted Items).';

  @override
  String get coreErrIlServerNonSupportaMove =>
      'The server supports neither MOVE nor UIDPLUS: operation refused so as not to delete other messages.';

  @override
  String coreErrLaCartellaNonPuoContenere(String fullName) {
    return 'The folder \'$fullName\' cannot contain subfolders.';
  }

  @override
  String coreErrIlServerNonHaCreato(String clean) {
    return 'The server did not create the folder \'$clean\'.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  ) {
    return '\'$fullName\' contains the special folder \'$fullName2\': it is not emptied.';
  }

  @override
  String coreErrNonPuoAndareDentroSe2(String fullName) {
    return '\'$fullName\' cannot go inside itself or one of its subfolders.';
  }

  @override
  String coreErrUnaCartellaSpecialeNonSi(String fullName) {
    return '\'$fullName\' is a special folder: it cannot be renamed, moved or deleted.';
  }

  @override
  String coreErrCartellaNonTrovata4(String folderName) {
    return 'Folder \'$folderName\' not found.';
  }

  @override
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  ) {
    return 'unreadable structure (BODYSTRUCTURE) in a group of $count messages of $fullName: skipped, the faulty message will be searched in the background ($message)';
  }

  @override
  String get coreErrFiltroDaLeggereOrdineDal =>
      'The \"Unread\" filter and oldest-first order require the local cache (Cache:Enabled=false).';

  @override
  String get coreErrLeConversazioniRichiedonoLaCache =>
      'Conversations require the local cache (Cache:Enabled=false).';

  @override
  String get coreErrLaRicercaRichiedeLaCache =>
      'Search requires the local cache (Cache:Enabled=false).';

  @override
  String coreErrCorpoAppenaSalvatoNonRileggibile(
    String folderName,
    String uid,
  ) {
    return 'Body $folderName/$uid just saved and not readable.';
  }

  @override
  String coreErrCartellaAssenteDallaCacheDopo(String fullName) {
    return 'Folder \'$fullName\' missing from the cache after synchronization.';
  }

  @override
  String get coreErrImprontaSha256NonValida => 'Invalid SHA-256 fingerprint.';

  @override
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id) {
    return 'The account \'$id\' is still configured: to clear its cache use \"Rebuild cache\".';
  }

  @override
  String coreErrNessunDatoLocalePerAccount(String id) {
    return 'No local data for the account \'$id\'.';
  }

  @override
  String get coreErrIgnoraPulisciRichiedonoLaCopia =>
      'Ignore and Clean Up require the local copy (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaPostaEliminataIn =>
      'No Deleted Items folder in this account.';

  @override
  String get coreErrLaConversazioneNonIgnorata =>
      'The conversation is not ignored.';

  @override
  String get coreErrPulisciNonValePerPosta =>
      'Clean Up does not apply to Deleted Items and Junk Email.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia =>
      'Rules require the local copy.';

  @override
  String coreErrAlMassimoRegolePerAccount(String maxRules) {
    return 'At most $maxRules rules per account.';
  }

  @override
  String get coreErrOgniRegolaDeveAvereUn => 'Every rule must have a name.';

  @override
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength) {
    return '\"$name…\": the name can have at most $maxNameLength characters.';
  }

  @override
  String coreErrEliminaSpostaInsiemeNonHanno(String name) {
    return '\"$name\": \"Delete\" and \"Move\" together make no sense, choose one.';
  }

  @override
  String coreErrCategoriaNonValida(String name) {
    return '\"$name\": invalid category.';
  }

  @override
  String coreErrDimensioneNonValida(String rule) {
    return '\"$rule\": invalid size.';
  }

  @override
  String coreErrTroppeParoleParoleTroppoLunghe(String rule) {
    return '\"$rule\": too many words or words too long.';
  }

  @override
  String get coreErrScrivereIlMessaggioDellaRisposta =>
      'Write the automatic reply message.';

  @override
  String get coreErrLaFineDeveVenireDopo =>
      'The end must come after the start.';

  @override
  String get coreErrIlMessaggioTroppoLungo => 'The message is too long.';

  @override
  String get coreErrContattoNonTrovato => 'Contact not found.';

  @override
  String coreErrLaRubricaHaGiaContatti(String maxContacts) {
    return 'The address book already has $maxContacts contacts.';
  }

  @override
  String get coreErrFormatoNonRiconosciutoUsareVcf =>
      'Format not recognized: use vcf or csv.';

  @override
  String coreErrIndirizzoNonValido(String address) {
    return 'Invalid address: $address';
  }

  @override
  String get coreErrScrivereAlmenoUnNomeLa =>
      'Enter at least a name, the company or an address.';

  @override
  String get coreErrCalendarioNonTrovato => 'Calendar not found.';

  @override
  String get coreErrAppuntamentoNonValido => 'Invalid appointment.';

  @override
  String get coreErrAppuntamentoNonTrovato => 'Appointment not found.';

  @override
  String get coreErrEsisteGiaUnAppuntamentoCon =>
      'An appointment with the same UID already exists.';

  @override
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems) {
    return 'The calendar already has $maxItems appointments.';
  }

  @override
  String coreErrPeriodoNonValidoAlMassimo(String maxDays) {
    return 'Invalid period: at most $maxDays days, with the end after the start.';
  }

  @override
  String get coreErrAppuntamentoNonLeggibile => 'Unreadable appointment.';

  @override
  String get coreErrOccorrenzaNonValida => 'Invalid occurrence.';

  @override
  String get coreErrSerieNonTrovata => 'Series not found.';

  @override
  String get coreErrAppuntamentoNonRicorrenteSiModifica =>
      'The appointment is not recurring: the whole of it is changed.';

  @override
  String get coreErrAlMassimo20000Caratteri => 'At most 20000 characters.';

  @override
  String get coreErrPromemoriaNonValidoDaMinuti =>
      'Invalid reminder (from 0 minutes to 4 weeks before).';

  @override
  String get coreErrLaFinePrimaDellInizio => 'The end is before the start.';

  @override
  String get coreErrSerializzazioneNonRiuscita => 'Serialization failed.';

  @override
  String coreErrMancaIlClientIdDi(String displayName, String id) {
    return 'The $displayName client ID is missing: the app must be registered and the ID written in oauth-clients.json (section OAuth:$id).';
  }

  @override
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName) {
    return 'Contact synchronization is not available with $displayName.';
  }

  @override
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName) {
    return 'Calendar synchronization is not available with $displayName.';
  }

  @override
  String coreErrAllegatoNonTrovato(String i) {
    return 'Attachment $i not found.';
  }

  @override
  String get coreErrIndicareLaCartellaDelMessaggio =>
      'Specify the folder of the original message.';

  @override
  String coreErrModalitaNonValidaReplyReplyall(String mode) {
    return 'Invalid mode: $mode (reply, replyAll, forward).';
  }

  @override
  String coreErrMancantePiuCortoDiCaratteri(
    String configKey,
    String minLength,
  ) {
    return '$configKey missing or shorter than $minLength characters.';
  }

  @override
  String get coreErrCartellaDeiDatiDellUtente =>
      'The user\'s data folder cannot be determined (HOME not set?): use Cache:Directory.';

  @override
  String get coreErrIndicareAlmenoUnaMail => 'Specify at least one message.';

  @override
  String coreErrAlMassimoMailPerVolta(String maxBatch) {
    return 'At most $maxBatch messages at a time.';
  }

  @override
  String coreErrAllegatoNonTrovato2(String index) {
    return 'Attachment $index not found.';
  }

  @override
  String get coreErrUnaCategoriaNonPuoEssere =>
      'A category cannot be added and removed at the same time.';

  @override
  String get coreErrIndicareLaCartellaDiDestinazione =>
      'Specify the destination folder.';

  @override
  String get coreErrLaScadenzaValeSoloCon =>
      'The due date applies only with followUp \"flagged\".';

  @override
  String get coreErrLeRisposteAutomaticheRichiedonoLa =>
      'Automatic replies require the local copy.';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa =>
      'Junk Email requires the local copy (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa2 =>
      'Junk Email requires the local copy.';

  @override
  String get coreErrLaCartellaSceltaNonEsiste =>
      'The chosen folder does not exist.';

  @override
  String get coreErrScegliereUnaCartellaDiversaDa =>
      'Choose a folder other than Inbox, Sent Items, Drafts and Deleted Items.';

  @override
  String get coreErrLaCartellaDiArchiviazioneSceglierne =>
      'It is the archive folder: choose another one.';

  @override
  String coreErrCartellaNonTrovata5(String name) {
    return 'Folder \'$name\' not found.';
  }

  @override
  String get coreErrArchiviaRichiedeLaCopiaLocale =>
      'Archive requires the local copy (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla =>
      'No archive folder: choose it with \"Set Archive Folder\".';

  @override
  String get coreErrLeMailSonoGiaNella =>
      'The messages are already in the archive folder.';

  @override
  String get coreErrContattiRichiedonoLaCopiaLocale =>
      'Contacts require the local copy (Cache:Enabled=false).';

  @override
  String get coreErrContenutoDelFileNonValido => 'Invalid file content.';

  @override
  String get coreErrFileTroppoGrandeAlMassimo =>
      'File too large (at most 10 MB).';

  @override
  String get coreErrLaSincronizzazioneDeiContattiNon2 =>
      'Contact synchronization is not active for this account.';

  @override
  String get coreErrDa50 => 'From 1 to 50.';

  @override
  String get coreErrIndirizzoMancante => 'Address missing.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia2 =>
      'Rules require the local copy (Cache:Enabled=false).';

  @override
  String get coreErrScegliereAlmenoUnaRegolaSalvata =>
      'Choose at least one saved rule.';

  @override
  String get coreErrAccountPop3LeMailSono =>
      'POP3 account: the mail is only on this computer, there is no copy to rebuild from the server.';

  @override
  String get coreErrCalendariRichiedonoLaCopiaLocale =>
      'Calendars require the local copy (Cache:Enabled=false).';

  @override
  String coreErrIlCalendarioDiSolaLettura(String name) {
    return 'The calendar \"$name\" is read-only: appointments cannot be created, changed or deleted.';
  }

  @override
  String get coreErrLaSincronizzazioneDelCalendarioNon2 =>
      'Calendar synchronization is not active for this account.';

  @override
  String get coreErrRitardaRecapitoRichiedeLaCache =>
      'Delay Delivery requires the local cache (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaInUscitaRichiede =>
      'The Outbox requires the local cache (Cache:Enabled=false).';

  @override
  String get coreErrMailNonTrovataNellaPosta =>
      'Message not found in the Outbox.';

  @override
  String get coreErrNessunaConfermaDiLetturaPer =>
      'No read receipts for messages in Junk Email, Sent Items and Drafts.';

  @override
  String get coreErrAllaRichiestaDiConfermaDi =>
      'The read receipt request has already been answered.';

  @override
  String get coreErrLaMailNonChiedeUna2 =>
      'The message does not request a read receipt to its sender.';

  @override
  String get davContactsServerLabel => 'contacts server';

  @override
  String get davCalendarServerLabel => 'calendar server';

  @override
  String get printPreviewOpened =>
      'Preview opened in the PDF viewer: print from there.';

  @override
  String printNoPdfViewer(String path) {
    return 'No program to open PDF files. File in $path';
  }

  @override
  String printNotPrepared(String message, String path) {
    return 'Printing not prepared: $message ($path)';
  }

  @override
  String get defaultMessageFileName => 'message';

  @override
  String get preparingPdf => 'Preparing the PDF…';

  @override
  String pdfNotCreated(String error) {
    return 'PDF not created: $error';
  }

  @override
  String get printFrom => 'From:';

  @override
  String get printSent => 'Sent:';

  @override
  String get printTo => 'To:';

  @override
  String get printCc => 'Cc:';

  @override
  String get printSubject => 'Subject:';

  @override
  String get printImportance => 'Importance:';

  @override
  String get printHigh => 'High';

  @override
  String get printLow => 'Low';

  @override
  String get printAttachments => 'Attachments:';

  @override
  String get defaultAttachmentFileName => 'attachment';

  @override
  String get coreExecutableNotFound =>
      'Core executable not found. Build it with \"cd core && dotnet build\" or set its path in POSTINOVIP_CORE.';

  @override
  String coreCannotStart(String path, String error) {
    return 'Cannot start the core ($path): $error';
  }

  @override
  String coreExitedAtStart(String code) {
    return 'The core stopped during startup (code $code).';
  }

  @override
  String coreNoAnswerAtStart(String seconds) {
    return 'The core did not answer within $seconds s.';
  }

  @override
  String coreNotAnsweringCorrectly(String error) {
    return 'The core is not answering correctly: $error';
  }

  @override
  String get startingCore => 'Starting the core…';

  @override
  String get coreLastLines => 'Last lines from the core:';
}
