// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String statusItems(int count) {
    return 'Elementos: $count';
  }

  @override
  String statusUnread(int count) {
    return 'No leídos: $count';
  }

  @override
  String statusResults(int count) {
    return 'Resultados: $count';
  }

  @override
  String statusContacts(int count) {
    return 'Contactos: $count';
  }

  @override
  String statusFound(int count) {
    return 'Encontrados: $count';
  }

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusDisconnected => 'Desconectado';

  @override
  String statusDisconnectedAccounts(String accounts) {
    return 'Desconectado: $accounts';
  }

  @override
  String get optionsTitle => 'Opciones';

  @override
  String get optionsClose => 'Cerrar';

  @override
  String get optionsPageGeneral => 'General';

  @override
  String get optionsPageMail => 'Correo';

  @override
  String get optionsPageNotifications => 'Notificaciones';

  @override
  String get optionsPageCalendar => 'Calendario';

  @override
  String get optionsAccountSection => 'Cuentas';

  @override
  String get optionsAccountNotConfigured => '(no configurada)';

  @override
  String get optionsAccountFromUserSecrets =>
      'Datos de user-secrets (desarrollo)';

  @override
  String optionsAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return '$_temp0';
  }

  @override
  String get optionsAccountManage => 'Administrar…';

  @override
  String get optionsLookSection => 'Apariencia';

  @override
  String get optionsTheme => 'Tema';

  @override
  String get optionsThemeHelper =>
      'El texto de los mensajes sigue sobre fondo blanco incluso con los temas oscuros';

  @override
  String get themeSystem => 'Usar la configuración del sistema';

  @override
  String get themeColorful => 'Multicolor';

  @override
  String get themeWhite => 'Blanco';

  @override
  String get themeDarkGray => 'Gris oscuro';

  @override
  String get themeBlack => 'Negro';

  @override
  String get optionsModuleBar =>
      'Barra de navegación (Correo, Calendario, Personas)';

  @override
  String get moduleBarLeft => 'A la izquierda';

  @override
  String get moduleBarBottom => 'En la parte inferior del panel de carpetas';

  @override
  String get optionsLanguageSection => 'Idioma';

  @override
  String get optionsLanguage => 'Idioma para mostrar';

  @override
  String get optionsLanguageHelper =>
      'Se usa también para los textos que la aplicación escribe en los mensajes (encabezados de las respuestas, confirmaciones de lectura)';

  @override
  String get languageSystem => 'Igual que el sistema';

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabSendReceive => 'Enviar y recibir';

  @override
  String get tabFolder => 'Carpeta';

  @override
  String get tabView => 'Vista';

  @override
  String get groupLayout => 'Diseño';

  @override
  String get ribbonCollapse => 'Contraer la cinta de opciones';

  @override
  String get ribbonCollapseTooltip =>
      'Mostrar solo los nombres de las pestañas (Ctrl+F1)';

  @override
  String get groupSendReceive => 'Enviar y recibir';

  @override
  String get sendReceiveAll => 'Enviar y recibir todas las carpetas';

  @override
  String get sendReceiveAllTooltip =>
      'Actualizar las carpetas y los mensajes de todas las cuentas (F9)';

  @override
  String get readingPane => 'Panel de lectura';

  @override
  String get messagePreview => 'Vista previa de mensajes';

  @override
  String get messagePreviewOff => 'Desactivada';

  @override
  String messagePreviewLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '1 línea',
    );
    return '$_temp0';
  }

  @override
  String get groupMessages => 'Mensajes';

  @override
  String get showAsConversations => 'Mostrar como conversaciones';

  @override
  String get showAsConversationsOnTooltip =>
      'Activado en esta carpeta: haga clic para volver a la lista simple';

  @override
  String get showAsConversationsOffTooltip =>
      'Agrupa en una fila los mensajes de la misma conversación';

  @override
  String get specialFolderHint =>
      'Bandeja de entrada, Elementos enviados, Elementos eliminados y las demás carpetas especiales no se pueden cambiar de nombre ni eliminar';

  @override
  String get groupNew => 'Nuevo';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get newFolderTooltip =>
      'Crear una subcarpeta de la carpeta seleccionada';

  @override
  String get groupActions => 'Acciones';

  @override
  String get renameFolder => 'Cambiar nombre de carpeta';

  @override
  String get renameFolderTooltip =>
      'Cambiar el nombre de la carpeta seleccionada (F2)';

  @override
  String get deleteFolder => 'Eliminar carpeta';

  @override
  String get deletePermanentlyTooltip =>
      'Eliminar del servidor, sin posibilidad de recuperarlo';

  @override
  String get deleteFolderTooltip =>
      'Mover la carpeta, con su contenido, a Elementos eliminados';

  @override
  String get emptyFolder => 'Vaciar carpeta';

  @override
  String get emptyFolderTooltip =>
      'Eliminar del servidor todos los mensajes de la carpeta, sin posibilidad de recuperarlos';

  @override
  String get emptyFolderOnlyTooltip =>
      'Solo para Elementos eliminados y Correo no deseado';

  @override
  String get groupArchive => 'Archivo';

  @override
  String get setArchiveFolder => 'Establecer carpeta de archivo';

  @override
  String get setArchiveFolderTooltip =>
      'Elegir o crear la carpeta a la que Archivar mueve los mensajes de esta cuenta';

  @override
  String get newMessage => 'Nuevo correo electrónico';

  @override
  String get newMessageTooltip => 'Escribir un mensaje nuevo';

  @override
  String get delete => 'Eliminar';

  @override
  String get deletePermanently => 'Eliminar permanentemente';

  @override
  String get moveToDeletedTooltip => 'Mover a Elementos eliminados';

  @override
  String get archive => 'Archivar';

  @override
  String get cleanUp => 'Limpiar';

  @override
  String get cleanUpTooltip =>
      'Mover a Elementos eliminados los mensajes redundantes: los citados por completo en una respuesta';

  @override
  String get junk => 'Correo no deseado';

  @override
  String get junkTooltip =>
      'Bloquear remitente, No bloquear nunca, Opciones de correo no deseado';

  @override
  String get groupRespond => 'Responder';

  @override
  String get move => 'Mover';

  @override
  String get moveTooltip => 'Mover a otra carpeta';

  @override
  String get moveOtherFolder => 'Otra carpeta… (Ctrl+Mayús+V)';

  @override
  String get rules => 'Reglas';

  @override
  String get rulesTooltip => 'Ordenar automáticamente el correo entrante';

  @override
  String get createRule => 'Crear regla…';

  @override
  String get manageRulesEllipsis => 'Administrar reglas y alertas…';

  @override
  String get groupTags => 'Etiquetas';

  @override
  String get markUnread => 'Marcar como no leído';

  @override
  String get markRead => 'Marcar como leído';

  @override
  String get categorize => 'Categorizar';

  @override
  String get categorizeTooltip => 'Asignar una categoría de color';

  @override
  String get followUp => 'Seguimiento';

  @override
  String get followUpTooltip =>
      'Marcar para seguimiento, con una fecha de vencimiento';

  @override
  String get groupFind => 'Buscar';

  @override
  String get search => 'Buscar';

  @override
  String get searchTooltip => 'Buscar en el correo';

  @override
  String get fileTab => 'Archivo';

  @override
  String get openEml => 'Abrir archivo .eml…';

  @override
  String get saveAs => 'Guardar como… (F12)';

  @override
  String get printMessage => 'Imprimir… (Ctrl+P)';

  @override
  String get saveAsPdf => 'Guardar como PDF…';

  @override
  String get automaticReplies => 'Respuestas automáticas';

  @override
  String get manageRules => 'Administrar reglas y alertas';

  @override
  String get aboutApp => 'Acerca de PostinoVip';

  @override
  String get ribbonShowAlways => 'Mostrar siempre la cinta de opciones';

  @override
  String get ribbonTabsOnly => 'Mostrar solo las pestañas (Ctrl+F1)';

  @override
  String get ribbonDisplayOptions =>
      'Opciones de presentación de la cinta de opciones';

  @override
  String get readingPaneRight => 'Derecha';

  @override
  String get readingPaneBottom => 'Abajo';

  @override
  String get readingPaneOff => 'Desactivado';

  @override
  String get ribbonClassic => 'Cinta de opciones clásica';

  @override
  String get ribbonSimplified => 'Cinta de opciones simplificada';

  @override
  String get reply => 'Responder';

  @override
  String get replyAll => 'Responder a todos';

  @override
  String get forward => 'Reenviar';

  @override
  String get sendReceiveAllF9 => 'Enviar y recibir todas las carpetas (F9)';

  @override
  String get searchHelp =>
      'Palabras (también iniciales: \"fact\" encuentra \"factura\"), \"frase exacta\"\nde:ana   para:mario   asunto:reunión\nadjunto:pdf   adjuntos:sí   adjuntos:no';

  @override
  String get searchClose => 'Cerrar la búsqueda';

  @override
  String get searchScopeFolder => 'Carpeta actual';

  @override
  String get searchScopeAccount => 'Buzón actual';

  @override
  String get searchScopeAllAccounts => 'Todos los buzones';

  @override
  String get moduleMail => 'Correo (Ctrl+1)';

  @override
  String get moduleCalendar => 'Calendario (Ctrl+2)';

  @override
  String get modulePeople => 'Personas (Ctrl+3)';

  @override
  String get zoomOut => 'Alejar (Ctrl+-)';

  @override
  String get zoomIn => 'Acercar (Ctrl++)';

  @override
  String get zoomReset =>
      'Zoom del panel de lectura: haga clic para volver al 100% (Ctrl+0)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get retry => 'Reintentar';

  @override
  String get noFolderSelected => 'Ninguna carpeta seleccionada';

  @override
  String searchWhereFolder(String folder) {
    return 'en $folder';
  }

  @override
  String searchWhereAccount(String account) {
    return 'en todas las carpetas de $account';
  }

  @override
  String get searchWhereAllFolders => 'en todas las carpetas';

  @override
  String get searchWhereAllAccounts => 'en todas las cuentas';

  @override
  String searchInProgress(String where) {
    return 'Buscando $where…';
  }

  @override
  String searchResultsTitle(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0 $where';
  }

  @override
  String get listNoUnread => 'No hay mensajes no leídos';

  @override
  String get listEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get unknownSender => '(remitente desconocido)';

  @override
  String get noSubject => '(sin asunto)';

  @override
  String get searchNoLocalResults => 'No hay resultados en la copia local';

  @override
  String get offlineStrip =>
      'Sin conexión: se muestra la copia de este equipo. Mover, eliminar, marcar como leído y enviar se reanudan solos cuando el servidor responda.';

  @override
  String get theProvider => 'el proveedor';

  @override
  String loginExpired(String provider) {
    return 'El inicio de sesión en $provider ha caducado: esta cuenta no recibirá ni enviará correo hasta que vuelva a iniciar sesión.';
  }

  @override
  String get signInAgain => 'Volver a iniciar sesión';

  @override
  String get autoReplyStrip =>
      'Las respuestas automáticas están activadas para esta cuenta.';

  @override
  String get editEllipsis => 'Modificar…';

  @override
  String get autoReplyTurnedOff => 'Respuestas automáticas desactivadas.';

  @override
  String autoReplyNotTurnedOff(String error) {
    return 'No desactivadas: $error';
  }

  @override
  String get turnOff => 'Desactivar';

  @override
  String get serverSearching => 'Buscando en el servidor…';

  @override
  String serverSearchFailed(String error) {
    return 'La búsqueda en el servidor ha fallado: $error';
  }

  @override
  String get serverFoundNone => 'El servidor no ha encontrado otros mensajes.';

  @override
  String serverFoundMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'El servidor ha encontrado $count mensajes más',
      one: 'El servidor ha encontrado 1 mensaje más',
    );
    return '$_temp0 (con el icono de la nube).';
  }

  @override
  String serverTruncated(int count) {
    return ' Se muestran los $count más recientes.';
  }

  @override
  String get searchServerToo => 'Buscar también en el servidor';

  @override
  String get searchServerHint =>
      'Para los mensajes más antiguos que el límite de la copia local y para Elementos eliminados y Correo no deseado,\nde los que aquí solo se buscaron los encabezados.';

  @override
  String get conversationCollapse => 'Contraer la conversación';

  @override
  String get conversationExpand =>
      'Mostrar todos los mensajes de la conversación';

  @override
  String get sortDateNewest => 'Por fecha: los más recientes arriba';

  @override
  String get sortDateOldest => 'Por fecha: los más antiguos arriba';

  @override
  String get sortFromAZ => 'Por remitente: A → Z';

  @override
  String get sortFromZA => 'Por remitente: Z → A';

  @override
  String get sortSubjectAZ => 'Por asunto: A → Z';

  @override
  String get sortSubjectZA => 'Por asunto: Z → A';

  @override
  String get sortSizeLargest => 'Por tamaño: los más grandes arriba';

  @override
  String get sortSizeSmallest => 'Por tamaño: los más pequeños arriba';

  @override
  String get sortByDate => 'Por fecha';

  @override
  String get sortByFrom => 'Por remitente';

  @override
  String get sortBySubject => 'Por asunto';

  @override
  String get sortBySize => 'Por tamaño';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterUnread => 'No leídos';

  @override
  String get sortTooltip => 'Ordenar por';

  @override
  String get conversationBadgeTooltip =>
      'La vista de conversación está activada en esta carpeta: haga clic para cambiarla';

  @override
  String get conversations => 'Conversaciones';

  @override
  String conversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes',
      one: '1 mensaje',
    );
    return '$_temp0 en la conversación';
  }

  @override
  String get hasAttachments => 'Tiene datos adjuntos';

  @override
  String get flaggedClickToComplete =>
      'Marcado: haga clic para marcar como completado';

  @override
  String dueByClickToComplete(String date) {
    return 'Vence el $date: haga clic para marcar como completado';
  }

  @override
  String get completedClickToFlag =>
      'Completado: haga clic para volver a marcar';

  @override
  String get flagToday => 'Marcar para hoy';

  @override
  String get foundOnServer => 'Encontrado en el servidor';

  @override
  String sortByColumn(String column) {
    return 'Ordenar por $column';
  }

  @override
  String get columnFrom => 'De';

  @override
  String get columnSubject => 'Asunto';

  @override
  String get columnReceived => 'Recibido';

  @override
  String get columnSize => 'Tamaño';

  @override
  String get columnCategories => 'Categorías';

  @override
  String selectedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos seleccionados',
      one: '1 elemento seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get selectMessage => 'Seleccione un elemento para leerlo';

  @override
  String get messageUnavailable => 'Mensaje no disponible';

  @override
  String receiptRequested(String sender) {
    return '$sender ha solicitado una confirmación de lectura.';
  }

  @override
  String get receiptDecline => 'No enviar';

  @override
  String get receiptSend => 'Enviar';

  @override
  String get draftBanner => 'Borrador: aún no enviado.';

  @override
  String get editDraft => 'Modificar borrador';

  @override
  String get headerTo => 'Para';

  @override
  String get headerCc => 'CC';

  @override
  String openAttachment(String name) {
    return 'Abrir \"$name\"';
  }

  @override
  String saveAttachment(String name) {
    return 'Guardar \"$name\"…';
  }

  @override
  String get importanceHighBanner =>
      'Este mensaje se envió con importancia Alta.';

  @override
  String get importanceLowBanner =>
      'Este mensaje se envió con importancia Baja.';

  @override
  String get junkBanner =>
      'Este mensaje está en Correo no deseado: por seguridad, los vínculos están deshabilitados y las imágenes remotas bloqueadas. Si es un mensaje de confianza, vuelva a moverlo a la Bandeja de entrada.';

  @override
  String get notJunk => 'No es correo no deseado';

  @override
  String get remoteImagesBlocked =>
      'Imágenes remotas bloqueadas para proteger su privacidad.';

  @override
  String get showImages => 'Mostrar imágenes';

  @override
  String get htmlOnlyAsText =>
      'Mensaje solo en HTML: se muestra como texto simplificado.';

  @override
  String get bodyText => 'Texto';

  @override
  String savedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String attachmentNotDownloaded(String error) {
    return 'Datos adjuntos no descargados: $error';
  }

  @override
  String fileNotWritten(String message, String path) {
    return 'Archivo no escrito: $message ($path)';
  }

  @override
  String attachedMailNotOpened(String error) {
    return 'Mensaje adjunto no abierto: $error';
  }

  @override
  String get messageWithoutText => '(mensaje sin texto)';

  @override
  String get completed => 'Completado';

  @override
  String get flaggedForFollowUp => 'Marcado para seguimiento';

  @override
  String dueBy(String date) {
    return 'Vence el $date';
  }

  @override
  String get overdueSuffix => ' (vencido)';

  @override
  String get addSenderToContacts => 'Agregar remitente a Contactos';

  @override
  String get stopIgnoringConversation => 'Dejar de omitir la conversación';

  @override
  String get ignoreConversation => 'Omitir conversación';

  @override
  String get cleanUpConversation => 'Limpiar conversación';

  @override
  String draftNotAvailable(String error) {
    return 'Borrador no disponible: $error';
  }

  @override
  String get draftTitle => 'Borrador';

  @override
  String get deletePermanentlyQuestion => '¿Eliminar permanentemente?';

  @override
  String deletePermanentlyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se eliminarán del servidor $count mensajes seleccionados de Elementos eliminados',
      one: 'Se eliminará del servidor 1 mensaje seleccionado de Elementos eliminados',
    );
    return '$_temp0.\nEsta acción no se puede deshacer.';
  }

  @override
  String deletePermanentlyOne(String subject) {
    return '\"$subject\" se eliminará del servidor.\nEsta acción no se puede deshacer.';
  }

  @override
  String get dontShowAsConversations => 'No mostrar como conversaciones';

  @override
  String conversationsOnQuestion(String folder) {
    return 'Los mensajes de la misma conversación se agruparán en una fila, con las respuestas guardadas en otras carpetas.\n\n¿Aplicar a \"$folder\" o a todas las carpetas?';
  }

  @override
  String conversationsApplyQuestion(String folder) {
    return '¿Aplicar a \"$folder\" o a todas las carpetas?';
  }

  @override
  String get allFolders => 'Todas las carpetas';

  @override
  String get thisFolder => 'Esta carpeta';

  @override
  String get importanceHigh => 'Importancia alta';

  @override
  String get importanceLow => 'Importancia baja';

  @override
  String get folderInbox => 'Bandeja de entrada';

  @override
  String get favorites => 'Favoritos';

  @override
  String get removeFromFavorites => 'Quitar de Favoritos';

  @override
  String get moveUp => 'Subir';

  @override
  String get moveDown => 'Bajar';

  @override
  String get showInFavorites => 'Mostrar en Favoritos';

  @override
  String get cleanUpFolder => 'Limpiar carpeta';

  @override
  String get outbox => 'Bandeja de salida';

  @override
  String get folderNameHint => 'Nombre de la carpeta';

  @override
  String noAutoUpdate(String address) {
    return 'La actualización automática está desactivada para $address: los mensajes nuevos solo aparecen con \"Enviar y recibir\"';
  }

  @override
  String get emptyFolderAllMails => 'Todos los mensajes';

  @override
  String get emptyFolderOnlyMail => 'El único mensaje';

  @override
  String emptyFolderNMails(int count) {
    return 'Los $count mensajes';
  }

  @override
  String get emptyFolderOneSubfolder => ' y la subcarpeta, con sus mensajes';

  @override
  String emptyFolderNSubfolders(int count) {
    return ' y las $count subcarpetas, con sus mensajes';
  }

  @override
  String emptyFolderQuestion(String folder) {
    return '¿Vaciar \"$folder\"?';
  }

  @override
  String emptyFolderContent(String mails, String folder, String also) {
    return 'Se eliminará del servidor: $mails de \"$folder\"$also.\nEsta acción no se puede deshacer.';
  }

  @override
  String get deleteFolderPermanentlyQuestion =>
      '¿Eliminar permanentemente la carpeta?';

  @override
  String get deleteFolderQuestion => '¿Eliminar la carpeta?';

  @override
  String deleteFolderPermanentlyContent(String folder) {
    return 'La carpeta \"$folder\", con todos sus mensajes y subcarpetas, se eliminará del servidor.\nEsta acción no se puede deshacer.';
  }

  @override
  String deleteFolderContent(String folder) {
    return 'La carpeta \"$folder\", con todos sus mensajes y subcarpetas, se moverá a Elementos eliminados.';
  }

  @override
  String get messageTab => 'Mensaje';

  @override
  String get windowDeletePermanentlyTooltip =>
      'Eliminar del servidor, sin posibilidad de recuperarlo (luego el mensaje siguiente)';

  @override
  String get windowDeleteTooltip =>
      'Mover a Elementos eliminados y abrir el mensaje siguiente (Supr)';

  @override
  String get windowArchiveTooltip =>
      'Mover a la carpeta de archivo y abrir el mensaje siguiente';

  @override
  String get windowMoveTooltip =>
      'Mover a otra carpeta y abrir el mensaje siguiente';

  @override
  String get markUnreadWindow => 'Marcar como no leído';

  @override
  String get groupZoom => 'Zoom';

  @override
  String zoomPercent(int percent) {
    return 'Zoom ($percent%)';
  }

  @override
  String get zoomTooltip =>
      'Ampliar o reducir el texto del mensaje (Ctrl+rueda, Ctrl++, Ctrl+-, Ctrl+0)';

  @override
  String get previousItem => 'Elemento anterior (Ctrl+,)';

  @override
  String get nextItem => 'Elemento siguiente (Ctrl+.)';

  @override
  String get closeEsc => 'Cerrar (Esc)';

  @override
  String messageNotSaved(String error) {
    return 'Mensaje no guardado: $error';
  }

  @override
  String get emlFilesLabel => 'Mensajes de correo';

  @override
  String fileNotOpened(String name, String reason) {
    return '$name no abierto: $reason';
  }

  @override
  String get readOnly => 'Solo lectura';

  @override
  String get saveAsShort => 'Guardar como…';

  @override
  String get moveItems => 'Mover elementos';

  @override
  String moveItemsTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mover los $count elementos seleccionados a la carpeta:',
      one: 'Mover el elemento seleccionado a la carpeta:',
    );
    return '$_temp0';
  }

  @override
  String get searchFolder => 'Buscar una carpeta';

  @override
  String get noFolderWithName => 'No hay ninguna carpeta con este nombre';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: '1 semana',
    );
    return '$_temp0';
  }

  @override
  String reminderNotification(String title) {
    return 'Aviso: $title';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos',
      one: '1 aviso',
    );
    return '$_temp0';
  }

  @override
  String get reminderAllDayToday => 'Todo el día, hoy';

  @override
  String get reminderAllDayTomorrow => 'Todo el día, mañana';

  @override
  String reminderAllDayIn(int count) {
    return 'Todo el día, dentro de $count días';
  }

  @override
  String reminderAllDayStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Todo el día, empezó hace $count días',
      one: 'Todo el día, empezó hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get reminderNow => 'Ahora';

  @override
  String reminderStartedAgo(String span) {
    return 'Vencido hace $span';
  }

  @override
  String reminderIn(String span) {
    return 'Dentro de $span';
  }

  @override
  String reminderStart(String when) {
    return 'Hora de inicio: $when';
  }

  @override
  String reminderLocation(String location) {
    return '    Ubicación: $location';
  }

  @override
  String get dismissAll => 'Descartar todos';

  @override
  String get openItem => 'Abrir elemento';

  @override
  String get dismiss => 'Descartar';

  @override
  String get snoozeHint =>
      'Haga clic en Posponer para recibir un nuevo aviso en:';

  @override
  String get snooze => 'Posponer';

  @override
  String newMailFrom(String sender, String suffix) {
    return 'Nuevo mensaje de $sender$suffix';
  }

  @override
  String newMailMore(int count) {
    return '\n…y $count más';
  }

  @override
  String newMailCount(int count, String suffix) {
    return '$count mensajes nuevos$suffix';
  }

  @override
  String get openMailAction => 'Abrir mensaje';

  @override
  String get viewDay => 'Día';

  @override
  String get viewWorkWeek => 'Semana laboral';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewMonth => 'Mes';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorOrange => 'Naranja';

  @override
  String get colorPurple => 'Morado';

  @override
  String get colorTeal => 'Verde azulado';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorGold => 'Dorado';

  @override
  String get colorGray => 'Gris';

  @override
  String get deleteRecurringTitle => 'Eliminar una cita periódica';

  @override
  String get openRecurringTitle => 'Abrir una cita periódica';

  @override
  String get deleteRecurringQuestion =>
      '¿Eliminar solo esta repetición o toda la serie?';

  @override
  String get openRecurringQuestion =>
      'Es una cita periódica. ¿Abrir solo esta repetición o toda la serie?';

  @override
  String get entireSeries => 'Toda la serie';

  @override
  String get justThisOne => 'Solo esta';

  @override
  String appointmentNotAvailable(String error) {
    return 'Cita no disponible: $error';
  }

  @override
  String get deleteAppointmentQuestion => '¿Eliminar la cita?';

  @override
  String deleteAppointmentContent(String title) {
    return '\"$title\" se eliminará, y con la sincronización también del servidor. No se podrá recuperar.';
  }

  @override
  String appointmentNotDeleted(String error) {
    return 'Cita no eliminada: $error';
  }

  @override
  String get uploadAppointmentsQuestion => '¿Subir las citas al servidor?';

  @override
  String uploadAppointmentsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas solo están en este equipo. Se agregarán',
      one: 'Una cita solo está en este equipo. Se agregará',
    );
    return '$_temp0 al calendario del servidor y se sincronizarán a partir de entonces.\n\nLas citas que ya están en el servidor no se modifican.';
  }

  @override
  String get uploadToServer => 'Subir al servidor';

  @override
  String appointmentsNotUploaded(String error) {
    return 'Citas no subidas: $error';
  }

  @override
  String get newAppointment => 'Nueva cita';

  @override
  String get newAppointmentTooltip => 'Nueva cita (Ctrl+N)';

  @override
  String get deleteSelectedAppointmentTooltip =>
      'Eliminar la cita seleccionada (Supr)';

  @override
  String get groupGoTo => 'Ir a';

  @override
  String get today => 'Hoy';

  @override
  String get todayTooltip => 'Volver a hoy';

  @override
  String get next7Days => 'Próximos 7 días';

  @override
  String get next7DaysTooltip => 'Siete días a partir de hoy';

  @override
  String get groupArrange => 'Organizar';

  @override
  String get groupSync => 'Sincronización';

  @override
  String get sync => 'Sincronizar';

  @override
  String get syncCalendarsTooltip =>
      'Sincronizar ahora los calendarios con el servidor (F9)';

  @override
  String appointmentsNotAvailable(String error) {
    return 'Citas no disponibles: $error';
  }

  @override
  String uploadStrip(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas están',
      one: 'una cita está',
    );
    return '$name: $_temp0 solo en este equipo, todavía no en el servidor.';
  }

  @override
  String get uploadToServerEllipsis => 'Subir al servidor…';

  @override
  String get calendarEmpty => 'No hay citas en este período. ';

  @override
  String get calendarEmptySyncHint =>
      'Para ver las del servidor, active \"Sincronizar el calendario con el servidor (CalDAV)\" en Archivo → Opciones → Cuentas → Modificar. ';

  @override
  String get calendarEmptyCreate =>
      'Para crear una: \"Nueva cita\" (Ctrl+N) o doble clic en un espacio libre.';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Siguiente';

  @override
  String get myCalendars => 'Mis calendarios';

  @override
  String get localOnlyTooltip =>
      'Para ver las citas del servidor: Archivo → Opciones → Cuentas → Modificar → \"Sincronizar el calendario con el servidor (CalDAV)\"';

  @override
  String get localOnly => 'Solo en este equipo';

  @override
  String get color => 'Color';

  @override
  String get calendarReadOnlyTooltip =>
      'Solo lectura: las citas se pueden ver pero no modificar';

  @override
  String get syncedWithServer => 'Sincronizado con el servidor';

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String nowAt(String time) {
    return 'Ahora ($time)';
  }

  @override
  String moreItems(int count) {
    return '+$count más';
  }

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get synced => 'Sincronizado';

  @override
  String syncedAt(String time) {
    return 'Sincronizado a las $time';
  }

  @override
  String syncedOnAt(String date, String time) {
    return 'Sincronizado el $date a las $time';
  }

  @override
  String get syncServerUnreachable => 'Servidor no accesible';

  @override
  String get syncUnavailable => 'Sincronización no disponible';

  @override
  String get syncFailed => 'Error de sincronización';

  @override
  String get endBeforeStart => 'El fin es anterior al inicio.';

  @override
  String get deleteOccurrenceQuestion => '¿Eliminar esta repetición?';

  @override
  String get deleteOccurrenceContent =>
      'Solo se quita esta repetición de la serie; las demás se mantienen. No se podrá recuperar.';

  @override
  String get deleteSeriesContent =>
      'La cita (con todas sus repeticiones, si es periódica) se eliminará, y con la sincronización también del servidor. No se podrá recuperar.';

  @override
  String get saveChangesQuestion => '¿Guardar los cambios?';

  @override
  String get appointmentNotSavedContent =>
      'Los cambios en la cita no se han guardado.';

  @override
  String get no => 'No';

  @override
  String get yes => 'Sí';

  @override
  String get untitled => 'Sin título';

  @override
  String get occurrence => 'Repetición';

  @override
  String get appointment => 'Cita';

  @override
  String get saveAndClose => 'Guardar y cerrar';

  @override
  String get saveAndCloseTooltip => 'Guardar y cerrar (Ctrl+S)';

  @override
  String get deleteOnlyOccurrenceTooltip => 'Eliminar solo esta repetición';

  @override
  String get deleteAppointmentTooltip => 'Eliminar la cita';

  @override
  String get groupOptions => 'Opciones';

  @override
  String get recurrence => 'Periodicidad';

  @override
  String get recurrenceTooltip =>
      'Convertirla en periódica o cambiar la periodicidad';

  @override
  String get reminder => 'Aviso';

  @override
  String reminderValue(String value) {
    return 'Aviso: $value';
  }

  @override
  String get reminderNone => 'Ninguno';

  @override
  String get reminderAtStart => 'A la hora de inicio';

  @override
  String customRecurrence(String rule) {
    return 'Periodicidad personalizada ($rule): se conserva tal cual al guardar';
  }

  @override
  String calendarReadOnly(String calendar) {
    return 'El calendario \"$calendar\" es de solo lectura: la cita se puede ver pero no modificar.';
  }

  @override
  String get location => 'Ubicación';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get endTime => 'Hora de finalización';

  @override
  String get allDayEvent => 'Todo el día';

  @override
  String recurrenceValue(String text) {
    return 'Periodicidad: $text';
  }

  @override
  String get onlyThisOccurrenceHint =>
      'Solo esta repetición de la serie: las demás no cambian.';

  @override
  String get notes => 'Notas';

  @override
  String get weekFirst => 'primer';

  @override
  String get weekSecond => 'segundo';

  @override
  String get weekThird => 'tercer';

  @override
  String get weekFourth => 'cuarto';

  @override
  String get weekLast => 'último';

  @override
  String get recurrenceBadInterval => 'Repetición no válida (cada 1–999).';

  @override
  String get recurrenceBadCount => 'Número de repeticiones no válido (1–999).';

  @override
  String get recurrenceNoDays => 'Elija al menos un día de la semana.';

  @override
  String get recurEveryNDays => 'Cada [n] día(s)';

  @override
  String get recurEveryWeekday => 'Todos los días laborables';

  @override
  String get recurEveryNWeeksOn => 'Repetir cada [n] semana(s) el:';

  @override
  String get recurMonthlyDay => 'El día [day] de cada [n] mes(es)';

  @override
  String get recurMonthlyWeekday => 'El [week] [weekday] de cada mes';

  @override
  String get recurYearlyDay => 'Cada [day] de [month]';

  @override
  String get recurYearlyWeekday => 'El [week] [weekday] de [month]';

  @override
  String get appointmentRecurrence => 'Periodicidad de la cita';

  @override
  String get recurrencePattern => 'Patrón de periodicidad';

  @override
  String get recurDaily => 'Diaria';

  @override
  String get recurWeekly => 'Semanal';

  @override
  String get recurMonthly => 'Mensual';

  @override
  String get recurYearly => 'Anual';

  @override
  String get recurrenceRange => 'Intervalo de repetición';

  @override
  String get recurNoEnd => 'Sin fecha de finalización';

  @override
  String get recurEndAfter => 'Finalizar después de [n] repeticiones';

  @override
  String get recurEndBy => 'Finalizar el [date]';

  @override
  String get removeRecurrence => 'Quitar periodicidad';

  @override
  String queuedSendAfter(String when) {
    return 'Mensaje en la Bandeja de salida: se enviará después de $when (con la aplicación abierta).';
  }

  @override
  String get queuedOffline =>
      'Sin conexión: el mensaje está en la Bandeja de salida y se enviará solo en cuanto el servidor responda.';

  @override
  String get sentCopyNotSavedTitle => 'Mensaje enviado, copia no guardada';

  @override
  String sentCopyNotSaved(String error) {
    return 'El mensaje se envió, pero no se guardó la copia en Elementos enviados:\n$error\n\nNo lo vuelva a enviar: los destinatarios ya lo han recibido.';
  }

  @override
  String sentSavedIn(String folder) {
    return ' y guardado en \"$folder\"';
  }

  @override
  String messageSent(String where, String response) {
    return 'Mensaje enviado$where. Servidor: $response';
  }

  @override
  String get newMessageTitle => 'Mensaje nuevo';

  @override
  String get toPlainTextQuestion => '¿Cambiar a texto sin formato?';

  @override
  String get toPlainTextContent =>
      'El formato y las imágenes del texto se perderán, aunque vuelva a HTML. El mensaje original citado se agregará como texto.';

  @override
  String get continueButton => 'Continuar';

  @override
  String get savingDraft => 'Guardando el borrador…';

  @override
  String get tabInsert => 'Insertar';

  @override
  String get tabFormatText => 'Formato de texto';

  @override
  String get attachFile => 'Adjuntar archivo';

  @override
  String get attachFileTooltip => 'Adjuntar uno o varios archivos del equipo';

  @override
  String get saveSentCopy => 'Guardar copia';

  @override
  String get saveSentCopyOnTooltip =>
      'Activado: después del envío se guarda una copia en Elementos enviados (haga clic para no guardarla)';

  @override
  String get saveSentCopyOffTooltip =>
      'Desactivado: no hay copia en Elementos enviados después del envío (haga clic para guardarla)';

  @override
  String get saveDraft => 'Guardar borrador';

  @override
  String get saveDraftTooltip =>
      'Guardar en Borradores (Ctrl+S); también solo cada 3 minutos';

  @override
  String get delayDelivery => 'Retrasar entrega';

  @override
  String get delayDeliveryTooltip =>
      'No enviar antes de una fecha y hora (se queda en la Bandeja de salida)';

  @override
  String delayDeliveryActiveTooltip(String when) {
    return 'Envío después de $when: haga clic para cambiarlo';
  }

  @override
  String get importanceHighTooltip =>
      'Marcar el mensaje como importante (haga clic otra vez para quitarlo)';

  @override
  String get importanceLowTooltip =>
      'Marcar el mensaje como de importancia baja (haga clic otra vez para quitarlo)';

  @override
  String get groupInclude => 'Incluir';

  @override
  String get groupSave => 'Guardar';

  @override
  String get groupShowFields => 'Mostrar campos';

  @override
  String get bcc => 'CCO';

  @override
  String get bccTooltip =>
      'Copia oculta: los destinatarios en CCO no se ven entre sí ni los ven los demás';

  @override
  String get groupTracking => 'Seguimiento';

  @override
  String get requestReadReceipt => 'Solicitar confirmación de lectura';

  @override
  String get requestReadReceiptOnTooltip =>
      'Activado: el destinatario puede enviarle una confirmación cuando lea el mensaje (haga clic para quitarla)';

  @override
  String get requestReadReceiptOffTooltip =>
      'Pedir al destinatario una confirmación cuando lea el mensaje (puede rechazarla)';

  @override
  String get groupMoreOptions => 'Más opciones';

  @override
  String get groupFormat => 'Formato';

  @override
  String get formatHtmlTooltip => 'Texto con formato, con imágenes y vínculos';

  @override
  String get plainText => 'Texto sin formato';

  @override
  String get plainTextTooltip =>
      'Solo texto, sin formato: cualquier programa de correo puede leerlo';

  @override
  String get signaturesEllipsis => 'Firmas…';

  @override
  String get signature => 'Firma';

  @override
  String get signatureTooltip =>
      'Insertar una firma, o crear y modificar firmas';

  @override
  String get attachments => 'Datos adjuntos';

  @override
  String get originalAttachment => 'Dato adjunto del mensaje original';

  @override
  String get remove => 'Quitar';

  @override
  String attachmentsTooLarge(String size, String max) {
    return 'Datos adjuntos demasiado grandes: $size, máximo $max.';
  }

  @override
  String get messageBody => 'Texto del mensaje';

  @override
  String get addressesHint => 'direcciones separadas por comas';

  @override
  String get accountUnavailable => '(cuenta no disponible)';

  @override
  String get originalMessageQuote =>
      'Mensaje original (se agrega al final, tal cual)';

  @override
  String get removeQuote => 'Quitar cita';

  @override
  String get offlineSendMessage =>
      'Sin conexión con el servidor y el mensaje original (cita o datos adjuntos) no está en este equipo: el mensaje no se ha enviado y se queda aquí. Inténtelo de nuevo cuando vuelva la conexión.';

  @override
  String sendFailed(String error) {
    return 'Error al enviar: $error';
  }

  @override
  String draftTooLarge(String max) {
    return 'Borrador no guardado: datos adjuntos de más de $max.';
  }

  @override
  String draftSavedLocally(String time) {
    return 'Borrador guardado en este equipo a las $time: irá a Borradores cuando el servidor responda';
  }

  @override
  String draftSavedAt(String time) {
    return 'Borrador guardado a las $time';
  }

  @override
  String get draftNotSaved => 'Borrador no guardado';

  @override
  String draftNotSavedError(String error) {
    return 'Borrador no guardado: $error';
  }

  @override
  String get sendQuestion => '¿Enviar el mensaje?';

  @override
  String sendSummaryCopy(String value) {
    return 'Copia en Elementos enviados: $value';
  }

  @override
  String sendSummaryDelivery(String when) {
    return 'Entrega: no antes de $when';
  }

  @override
  String get emptySubjectWarning => 'Atención: el asunto está vacío.';

  @override
  String get attachmentsNone => 'ninguno';

  @override
  String attachmentsFromDisk(String size) {
    return ', archivos del disco $size';
  }

  @override
  String get composeSaveNew =>
      'El mensaje no se ha enviado. ¿Guardarlo en Borradores para terminarlo más tarde?';

  @override
  String get composeSaveExisting =>
      'El mensaje no se ha enviado. ¿Guardar los últimos cambios en el borrador?';

  @override
  String get sending => 'Enviando…';

  @override
  String get doNotDeliverBefore => 'No entregar antes de:';

  @override
  String get delayDeliveryHint =>
      'Después de \"Enviar\" el mensaje se queda en la Bandeja de salida y sale solo a esa hora, si la aplicación está abierta.';

  @override
  String get chooseFutureTime => 'Elija una hora en el futuro.';

  @override
  String get noDelay => 'Sin retraso';

  @override
  String get recipientRequired => 'Escriba al menos un destinatario';

  @override
  String invalidAddress(String address) {
    return 'Dirección no válida: $address';
  }

  @override
  String get dontSuggestAddress => 'No volver a sugerir esta dirección';

  @override
  String get noMoreSuggestions => 'No más sugerencias';

  @override
  String get outboxHint =>
      'Bandeja de salida: mensajes de este equipo que salen solos cuando llega la hora y el servidor responde, con la aplicación abierta.';

  @override
  String get outboxEmpty => 'No hay mensajes en espera de envío';

  @override
  String get deleteOutboxQuestion => '¿Eliminar el mensaje?';

  @override
  String deleteOutboxContent(String subject) {
    return '\"$subject\" no se enviará.';
  }

  @override
  String outboxNotSent(String error) {
    return 'No enviado: $error';
  }

  @override
  String outboxSendAfter(String when) {
    return 'Envío después de $when';
  }

  @override
  String get outboxWaiting => 'Esperando conexión';

  @override
  String get noRecipients => '(sin destinatarios)';

  @override
  String get sendNow => 'Enviar ahora';

  @override
  String get moveToDrafts => 'Mover a Borradores (para modificarlo)';

  @override
  String get deleteOutboxTooltip => 'Eliminar (no se enviará)';

  @override
  String get yesValue => 'sí';

  @override
  String get noValue => 'no';

  @override
  String get fontColorAutomatic => 'Automático';

  @override
  String get fontColorDarkRed => 'Rojo oscuro';

  @override
  String get fontColorRed => 'Rojo';

  @override
  String get fontColorOrange => 'Naranja';

  @override
  String get fontColorYellow => 'Amarillo';

  @override
  String get fontColorLightGreen => 'Verde claro';

  @override
  String get fontColorGreen => 'Verde';

  @override
  String get fontColorLightBlue => 'Azul claro';

  @override
  String get fontColorBlue => 'Azul';

  @override
  String get fontColorDarkBlue => 'Azul oscuro';

  @override
  String get fontColorPurple => 'Morado';

  @override
  String get remoteImagePlaceholder => '[imagen de internet]';

  @override
  String get groupBasicText => 'Texto básico';

  @override
  String get groupFont => 'Fuente';

  @override
  String get groupParagraph => 'Párrafo';

  @override
  String get linkTooltip => 'Vínculo (Ctrl+K)';

  @override
  String get imageFromFile => 'Imagen desde archivo (p. ej. un logotipo)';

  @override
  String get defaultFont => 'Calibri (predeterminada)';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get bold => 'Negrita (Ctrl+B)';

  @override
  String get italic => 'Cursiva (Ctrl+I)';

  @override
  String get underline => 'Subrayado (Ctrl+U)';

  @override
  String get strikethrough => 'Tachado';

  @override
  String get fontColor => 'Color de fuente';

  @override
  String get highlightColor => 'Color de resaltado de texto';

  @override
  String get noColor => 'Sin color';

  @override
  String get clearFormatting => 'Borrar todo el formato';

  @override
  String get bullets => 'Viñetas';

  @override
  String get numbering => 'Numeración';

  @override
  String get decreaseIndent => 'Disminuir sangría';

  @override
  String get increaseIndent => 'Aumentar sangría';

  @override
  String get alignLeft => 'Alinear a la izquierda';

  @override
  String get center => 'Centrar';

  @override
  String get alignRight => 'Alinear a la derecha';

  @override
  String get justify => 'Justificar';

  @override
  String get link => 'Vínculo';

  @override
  String get linkButtonTooltip => 'Insertar o modificar un vínculo (Ctrl+K)';

  @override
  String get linkInvalid =>
      'Dirección no válida: solo se permiten http, https y mailto.';

  @override
  String get insertLink => 'Insertar hipervínculo';

  @override
  String get linkAddress => 'Dirección';

  @override
  String get linkAddressHint =>
      'https://… o una dirección de correo electrónico';

  @override
  String get removeLink => 'Quitar vínculo';

  @override
  String signatureTooLarge(String size, String max) {
    return 'Firma demasiado grande: $size de imágenes, máximo $max.';
  }

  @override
  String get newSignature => 'Nueva firma';

  @override
  String get renameSignature => 'Cambiar nombre de la firma';

  @override
  String get deleteSignatureQuestion => '¿Eliminar la firma?';

  @override
  String deleteSignatureContent(String name) {
    return '\"$name\" se eliminará de este equipo.';
  }

  @override
  String get notAnImage =>
      'El archivo elegido no es una imagen (PNG, JPEG, GIF, BMP o WebP).';

  @override
  String get signaturesAndStationery => 'Firmas y plantillas';

  @override
  String get selectSignatureToEdit => 'Seleccione la firma que desea modificar';

  @override
  String get newButton => 'Nueva';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get editSignature => 'Modificar firma';

  @override
  String get noSignatures => 'No hay firmas: cree la primera con \"Nueva\".';

  @override
  String get signatureText => 'Texto de la firma';

  @override
  String get noneFeminine => '(ninguna)';

  @override
  String get chooseDefaultSignature => 'Elegir firma predeterminada';

  @override
  String get account => 'Cuenta de correo electrónico';

  @override
  String get newMessages => 'Mensajes nuevos';

  @override
  String get repliesForwards => 'Respuestas/reenvíos';

  @override
  String get writeAName => 'Escriba un nombre.';

  @override
  String get signatureNameTaken => 'Ya existe una firma con este nombre.';

  @override
  String get signatureName => 'Nombre de la firma';

  @override
  String get contacts => 'Contactos';

  @override
  String get addressBook => 'Libreta de direcciones';

  @override
  String get addressBookSearch => 'Buscar por nombre, dirección o empresa';

  @override
  String get allAddressBooks => 'Todas las libretas de direcciones';

  @override
  String contactsNotAvailable(String error) {
    return 'Contactos no disponibles: $error';
  }

  @override
  String get noContactsWithAddress => 'No hay contactos con dirección.';

  @override
  String get noContactsFound => 'No se han encontrado contactos.';

  @override
  String get takeOut => 'Quitar';

  @override
  String get labelWork => 'Trabajo';

  @override
  String get labelHome => 'Personal';

  @override
  String get labelOther => 'Otro';

  @override
  String get labelMobile => 'Móvil';

  @override
  String get labelOffice => 'Trabajo';

  @override
  String get deleteContactQuestion => '¿Eliminar el contacto?';

  @override
  String deleteContactContent(String name) {
    return '\"$name\" solo está en este equipo: una vez eliminado, no se podrá recuperar.';
  }

  @override
  String contactNotDeleted(String error) {
    return 'Contacto no eliminado: $error';
  }

  @override
  String get contactFilesLabel => 'Contactos (vCard, CSV)';

  @override
  String get importDone => 'Importación completada';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contactos agregados',
      one: '1 contacto agregado',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    return '$count ya presentes (no se agregan de nuevo)';
  }

  @override
  String importInvalid(int count) {
    return '$count descartados (sin nombre ni dirección, o no válidos)';
  }

  @override
  String importFailed(String error) {
    return 'Error en la importación: $error';
  }

  @override
  String get exportContacts => 'Exportar contactos';

  @override
  String get exportVcfHint => 'Para Thunderbird, teléfonos, Apple, Google';

  @override
  String get exportCsvHint => 'Columnas de Outlook: para Outlook, Gmail, Excel';

  @override
  String exportDone(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contactos exportados',
      one: '1 contacto exportado',
    );
    return '$_temp0 a $path';
  }

  @override
  String exportFailed(String error) {
    return 'Error en la exportación: $error';
  }

  @override
  String contactSavedIn(String name, String book) {
    return '\"$name\" guardado en $book';
  }

  @override
  String get uploadContactsQuestion => '¿Subir los contactos al servidor?';

  @override
  String uploadContactsContent(int count, String book, String serverBook) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contactos de la libreta \"$book\" solo están en este equipo. Se agregarán',
      one:
          'Un contacto de la libreta \"$book\" solo está en este equipo. Se agregará',
    );
    return '$_temp0 a la libreta \"$serverBook\" del servidor de contactos y se sincronizarán a partir de entonces.\n\nLos contactos que ya están en el servidor no se modifican.';
  }

  @override
  String contactsNotUploaded(String error) {
    return 'Contactos no subidos: $error';
  }

  @override
  String get newContact => 'Nuevo contacto';

  @override
  String get newContactTooltip =>
      'Nuevo contacto en la libreta abierta (Ctrl+N)';

  @override
  String get deleteContactTooltip => 'Eliminar el contacto seleccionado (Supr)';

  @override
  String get groupCommunicate => 'Comunicarse';

  @override
  String get emailMessage => 'Correo electrónico';

  @override
  String get emailMessageTooltip => 'Mensaje nuevo al contacto seleccionado';

  @override
  String get edit => 'Modificar';

  @override
  String get editContactTooltip =>
      'Abrir el contacto seleccionado (Entrar o doble clic)';

  @override
  String get syncContactsTooltip =>
      'Sincronizar ahora la libreta con el servidor de contactos (F9)';

  @override
  String get syncContactsOffTooltip =>
      'La sincronización de contactos está desactivada: actívela en la configuración de la cuenta';

  @override
  String get groupImportExport => 'Importar/Exportar';

  @override
  String get importEllipsis => 'Importar…';

  @override
  String get importTooltip =>
      'Agregar contactos desde un archivo vCard (.vcf) o CSV de Outlook o Gmail';

  @override
  String get exportEllipsis => 'Exportar…';

  @override
  String get exportTooltip =>
      'Guardar toda la libreta en un archivo vCard o CSV';

  @override
  String get searchContacts => 'Buscar contactos';

  @override
  String get searchContactsTooltip =>
      'Buscar por nombre, dirección, empresa o teléfono (Ctrl+E)';

  @override
  String get myContacts => 'Mis contactos';

  @override
  String get reloginCalendar =>
      'El calendario no se sincroniza: debe volver a iniciar sesión en Google y permitir el acceso al calendario.';

  @override
  String get reloginContacts =>
      'Los contactos no se sincronizan: debe volver a iniciar sesión en Google y permitir el acceso a los contactos.';

  @override
  String contactsUploadStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contactos solo están en este equipo: todavía no están en el servidor de contactos.',
      one: 'Un contacto solo está en este equipo: todavía no está en el servidor de contactos.',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get noContactsHint =>
      'No hay contactos. Use \"Nuevo contacto\" o \"Importar…\".';

  @override
  String get selectContact => 'Seleccione un contacto';

  @override
  String get emailSection => 'Correo electrónico';

  @override
  String get phoneSection => 'Teléfono';

  @override
  String get contact => 'Contacto';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellidos';

  @override
  String get displayAs =>
      'Mostrar como (si es distinto del nombre y apellidos)';

  @override
  String get company => 'Empresa';

  @override
  String get addAddress => 'Agregar dirección';

  @override
  String get phoneNumber => 'Número';

  @override
  String get addPhone => 'Agregar teléfono';

  @override
  String get securityNone => 'Ninguno';

  @override
  String get bodyMonthsAll => 'Todo';

  @override
  String bodyMonthsLast(int months) {
    return 'Últimos $months meses';
  }

  @override
  String noAccountsSaved(String address) {
    return 'No hay cuentas guardadas en la aplicación. Durante el desarrollo el core usa user-secrets$address.\nEn cuanto agregue una cuenta aquí, solo se usarán las cuentas guardadas aquí: para seguir viendo la actual, agréguela también.';
  }

  @override
  String accountSignedInWith(String provider) {
    return 'sesión iniciada con $provider';
  }

  @override
  String accountDownloadedMail(String months) {
    return 'Correo descargado: $months';
  }

  @override
  String get accountContactsSynced => 'contactos sincronizados (CardDAV)';

  @override
  String get accountCalendarSynced => 'calendario sincronizado (CalDAV)';

  @override
  String get rebuildCache => 'Reconstruir copia local';

  @override
  String get removeFromApp => 'Quitar de la aplicación';

  @override
  String get addAccount => 'Agregar cuenta';

  @override
  String get accountsTitle => 'Cuentas';

  @override
  String get pendingChangesOk =>
      'Cambios aún no guardados: se aplican al hacer clic en Aceptar.';

  @override
  String accountsNotSaved(String error) {
    return 'Cuentas no guardadas: $error';
  }

  @override
  String get pop3RemovedAfterDownload =>
      'se quita del servidor después de descargarlo';

  @override
  String pop3CopyForDays(int days) {
    return 'copia en el servidor durante $days días';
  }

  @override
  String get pop3CopyLeft => 'copia en el servidor';

  @override
  String pop3Summary(String copy, int minutes) {
    return 'Correo en este equipo, $copy · comprobado cada $minutes minutos';
  }

  @override
  String get removedAccountsData => 'Datos de cuentas quitadas';

  @override
  String get removedAccountsDataInfo =>
      'Correo descargado e índice de búsqueda de cuentas quitadas de la aplicación. Permanecen en este equipo hasta que los elimine.';

  @override
  String get orphanPop3Only => 'Correo POP3: es la única copia';

  @override
  String orphanContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contactos',
      one: '1 contacto',
    );
    return '$_temp0, solo en este equipo';
  }

  @override
  String get deleteLocalData => 'Eliminar datos locales';

  @override
  String get rebuildQuestion => '¿Reconstruir la copia local?';

  @override
  String rebuildContent(String name) {
    return 'La copia de \"$name\" en este equipo (correo descargado e índice de búsqueda) se elimina y se vuelve a descargar del servidor en segundo plano: puede tardar unos minutos y usar la red.\n\nNo se modifica nada en el servidor.';
  }

  @override
  String get rebuild => 'Reconstruir';

  @override
  String rebuildStarted(String name) {
    return 'Se ha iniciado la reconstrucción de la copia local de \"$name\".';
  }

  @override
  String rebuildFailed(String error) {
    return 'Copia local no reconstruida: $error';
  }

  @override
  String get deleteLocalDataQuestion => '¿Eliminar los datos locales?';

  @override
  String deleteLocalDataContent(String name, String size, String contacts) {
    return 'El correo descargado y el índice de búsqueda de \"$name\" ($size), una cuenta que ya no está en la aplicación, se eliminan de este equipo.\n\n${contacts}No se modifica nada en el servidor. Esta acción no se puede deshacer: si vuelve a agregar la cuenta, el correo se descargará de nuevo.';
  }

  @override
  String deleteLocalDataContacts(int count) {
    return 'También se pierden sus $count contactos: solo están en este equipo. Para conservarlos, vuelva a agregar la cuenta y expórtelos desde Personas.';
  }

  @override
  String localDataDeleted(String name) {
    return 'Datos locales de \"$name\" eliminados.';
  }

  @override
  String localDataNotDeleted(String error) {
    return 'Datos locales no eliminados: $error';
  }

  @override
  String get removeAccountQuestion => '¿Quitar la cuenta de la aplicación?';

  @override
  String removeAccountContent(String name, String email, String note) {
    return '\"$name\" ($email) se quitará de PostinoVip, junto con la contraseña guardada en el llavero.\n\n$note Sus contactos (Personas) también permanecen en este equipo.\n\nLa eliminación se aplica al hacer clic en Aceptar en la ventana Cuentas.';
  }

  @override
  String get removeAccountPop3Note =>
      'No se modifica nada en el servidor. El correo descargado con POP3 permanece en este equipo (para parte de él es la única copia): lo encontrará en \"Datos de cuentas quitadas\" y vuelve a aparecer si agrega de nuevo la cuenta.';

  @override
  String get removeAccountImapNote =>
      'No se modifica nada en el servidor: el correo se queda donde está y puede volver a agregar la cuenta en cualquier momento. El correo ya descargado permanece en este equipo: puede eliminarlo más tarde desde \"Datos de cuentas quitadas\".';

  @override
  String get deleteForeverQuestion => '¿Eliminar el correo para siempre?';

  @override
  String deleteForeverContent(String name, String size, String expected) {
    return '\"$name\" era una cuenta POP3: su correo ($size) se descargó en este equipo y esta es la única copia. El correo ya quitado del servidor no se podrá recuperar.\n\nPara confirmar, escriba: $expected';
  }

  @override
  String get deleteForever => 'Eliminar para siempre';

  @override
  String get browserNotOpened => 'El navegador no se ha abierto.';

  @override
  String signInNotStarted(String error) {
    return 'Inicio de sesión no iniciado: $error';
  }

  @override
  String get signInExpired =>
      'El inicio de sesión ha caducado: inténtelo de nuevo.';

  @override
  String signInFailedError(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get signInFailed => 'Error al iniciar sesión.';

  @override
  String get signInWithoutContacts =>
      'Sesión iniciada, pero sin permiso para los contactos: la sincronización de contactos sigue desactivada. Para activarla, vuelva a marcar la casilla y permita el acceso.';

  @override
  String get signInWithoutCalendar =>
      'Sesión iniciada, pero sin permiso para el calendario: la sincronización del calendario sigue desactivada. Para activarla, vuelva a marcar la casilla y permita el acceso.';

  @override
  String get signInWithoutContactsCalendar =>
      'Sesión iniciada, pero sin permiso para contactos y calendario: la sincronización de contactos y calendario sigue desactivada. Para activarla, vuelva a marcar la casilla y permita el acceso.';

  @override
  String waitingSignIn(String company) {
    return 'Esperando el inicio de sesión en la página de $company, en el navegador…';
  }

  @override
  String signedInWith(String company) {
    return 'Sesión iniciada con $company: no hay contraseña que guardar.';
  }

  @override
  String noPasswordSignIn(String company) {
    return 'Sin contraseña: inicia sesión en la página de $company, en el navegador. Al volver, la dirección y los servidores se rellenan solos.';
  }

  @override
  String serviceUnavailable(String service) {
    return '$service no está disponible: el core no tiene el ID de la aplicación.';
  }

  @override
  String signInWith(String company) {
    return 'Iniciar sesión con $company';
  }

  @override
  String get welcomeTitle => 'Le damos la bienvenida a PostinoVip';

  @override
  String get newAccount => 'Nueva cuenta';

  @override
  String get editAccount => 'Cambiar cuenta';

  @override
  String get firstRunIntro =>
      'Escriba los datos de su buzón. La contraseña se guarda en el llavero del sistema.';

  @override
  String get accountType => 'Tipo de cuenta';

  @override
  String get accountTypeHelp =>
      'IMAP: el correo se queda en el servidor y se ve desde todos los dispositivos (recomendado).\nPOP3: el correo se descarga en este equipo. No se puede cambiar más adelante.';

  @override
  String accountTypeServices(String services) {
    return '$services: inicio de sesión con el navegador, sin contraseña.';
  }

  @override
  String accountTypeValue(String type) {
    return 'Tipo de cuenta: $type';
  }

  @override
  String get nameOptional => 'Nombre (opcional)';

  @override
  String get nameOptionalHint =>
      'p. ej. Trabajo; si está vacío, se muestra la dirección';

  @override
  String get emailAddressUser =>
      'Dirección de correo electrónico (también el nombre de usuario)';

  @override
  String get invalidAddressShort => 'Dirección no válida';

  @override
  String get accountAlreadyPresent => 'Esta cuenta ya existe';

  @override
  String get password => 'Contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get passwordRequired => 'Se requiere la contraseña';

  @override
  String sameMailboxOtherType(String type, String name) {
    return 'Este buzón ya está configurado como $type (\"$name\"). Se puede usar de las dos formas, pero cuando POP3 quite el correo del servidor, desaparecerá también de la cuenta IMAP.';
  }

  @override
  String incomingServer(String type) {
    return '$type (correo entrante)';
  }

  @override
  String get outgoingServer => 'SMTP (correo saliente)';

  @override
  String get smtpAuthTitle =>
      'Mi servidor de salida (SMTP) requiere autenticación';

  @override
  String get smtpAuthSubtitle =>
      'Con la dirección y la contraseña del buzón. Desmárquelo solo para un servidor que acepte correo sin inicio de sesión (p. ej. en el puerto 25 de una red de empresa).';

  @override
  String get downloadedMail => 'Correo descargado en este equipo';

  @override
  String get downloadedMailHelp =>
      'Los más recientes se descargan en segundo plano y se abren al instante; los demás, cuando los abra.\nElementos eliminados y Correo no deseado: solo la lista.';

  @override
  String get recommendedSuffix => ' (recomendado)';

  @override
  String get syncContactsGoogle =>
      'Sincronizar los contactos con Google (CardDAV)';

  @override
  String get syncContactsServer =>
      'Sincronizar los contactos con el servidor (CardDAV)';

  @override
  String get notYetForMicrosoft =>
      'Aún no disponible para las cuentas de Microsoft.';

  @override
  String get signInWithGoogleFirst =>
      'Primero haga clic en \"Iniciar sesión con Google\".';

  @override
  String get syncContactsGoogleHelp =>
      'La libreta de direcciones de esta cuenta pasa a ser la de sus contactos de Google. Al marcar la casilla se abre el navegador para permitir que PostinoVip acceda a sus contactos.';

  @override
  String get syncContactsServerHelp =>
      'La libreta de direcciones de esta cuenta pasa a ser la del servidor de contactos, con las mismas credenciales. La primera vez, los contactos que solo están en este equipo van al servidor solo después de que lo confirme.';

  @override
  String get contactsSignInWaiting =>
      'Iniciando sesión con Google en el navegador: permita el acceso a los contactos.';

  @override
  String get contactsServerUrl =>
      'Dirección del servidor de contactos (opcional)';

  @override
  String get emptyFoundOnIncoming =>
      'Vacío: se busca automáticamente en el servidor de entrada';

  @override
  String emptyFoundOn(String host) {
    return 'Vacío: se busca automáticamente en $host';
  }

  @override
  String get httpsRequired => 'Se requiere una dirección https://';

  @override
  String get testAddressBook => 'Probar libreta de direcciones';

  @override
  String addressBookFound(String name) {
    return 'Encontrada: \"$name\"';
  }

  @override
  String get addressBookNotFound => 'Libreta de direcciones no encontrada.';

  @override
  String get calendarSection => 'Calendario';

  @override
  String get syncCalendarGoogle =>
      'Sincronizar el calendario con Google (CalDAV)';

  @override
  String get syncCalendarServer =>
      'Sincronizar el calendario con el servidor (CalDAV)';

  @override
  String get syncCalendarGoogleHelp =>
      'Sus calendarios de Google pasan a ser los calendarios de esta cuenta; los de solo lectura (p. ej. festivos) se ven pero no se modifican. Al marcar la casilla se abre el navegador para permitir que PostinoVip acceda a su calendario.';

  @override
  String get syncCalendarServerHelp =>
      'Los calendarios del servidor que aceptan citas pasan a ser los calendarios de esta cuenta. La primera vez, las citas que solo están en este equipo van al servidor solo después de que lo confirme.';

  @override
  String get calendarSignInWaiting =>
      'Iniciando sesión con Google en el navegador: permita el acceso al calendario.';

  @override
  String get calendarServerUrl =>
      'Dirección del servidor de calendario (opcional)';

  @override
  String get testCalendar => 'Probar calendario';

  @override
  String calendarsFound(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encontrados',
      one: 'Encontrado',
    );
    return '$_temp0: $names';
  }

  @override
  String quoted(String text) {
    return '\"$text\"';
  }

  @override
  String get calendarNotFound => 'Calendario no encontrado.';

  @override
  String get enterAddressPasswordFirst =>
      'Escriba primero la dirección y la contraseña.';

  @override
  String get enterServerOrCalendarUrl =>
      'Escriba el servidor de entrada o la dirección del servidor de calendario.';

  @override
  String get enterServerOrContactsUrl =>
      'Escriba el servidor de entrada o la dirección del servidor de contactos.';

  @override
  String get deliverySection => 'Entrega';

  @override
  String get leaveCopyOnServer =>
      'Dejar una copia de los mensajes en el servidor';

  @override
  String get removeFromServerAfter => 'Quitar del servidor después de';

  @override
  String get days => 'días';

  @override
  String get removeWhenDeleted =>
      'Quitar del servidor al eliminar de \"Elementos eliminados\"';

  @override
  String get pop3NoCopyWarning =>
      'Cada mensaje se quitará del servidor justo después de descargarlo: solo quedará en este equipo.';

  @override
  String get checkMailEvery => 'Comprobar si hay correo nuevo cada';

  @override
  String get checkMailEveryHelp =>
      'También con Enviar y recibir (F9). El correo solo está en este equipo: conviene hacer copias de seguridad.';

  @override
  String minutesCount(int count) {
    return '$count minutos';
  }

  @override
  String get server => 'Servidor';

  @override
  String get serverHint => 'p. ej. mail.dominio.com';

  @override
  String get serverRequired => 'Se requiere el servidor';

  @override
  String get port => 'Puerto';

  @override
  String get encryption => 'Cifrado';

  @override
  String get unencryptedWarning =>
      'Sin cifrado, la contraseña y el correo viajan en texto claro: cualquiera en la red puede leerlos. Úselo solo en una red de confianza.';

  @override
  String get certificateTrustedByYou =>
      'Certificado del servidor aceptado por usted (no firmado por una entidad reconocida).';

  @override
  String get stopTrusting => 'Dejar de confiar';

  @override
  String testFailed(String error) {
    return 'Prueba fallida: $error';
  }

  @override
  String get trustCertificateQuestion => '¿Confiar en este certificado?';

  @override
  String invalidCertificatePresented(String server, String address) {
    return 'El servidor $server $address ha presentado un certificado no válido:';
  }

  @override
  String get certificateIssuedTo => 'Emitido para';

  @override
  String get certificateIssuedBy => 'Emitido por';

  @override
  String get certificateValid => 'Válido';

  @override
  String certificateValidRange(String from, String to) {
    return 'del $from al $to';
  }

  @override
  String get certificateFingerprint => 'Huella digital SHA-256';

  @override
  String get certificateAdvice =>
      'Acéptelo solo si sabe que este servidor usa un certificado propio (p. ej. un servidor de empresa o doméstico); si es posible, compare la huella digital con la que le dé su administrador. Un certificado inesperado puede significar que alguien intenta interceptar su contraseña.\n\nSi lo acepta, PostinoVip confiará solo en este certificado: si el servidor presenta otro distinto, se lo volverá a preguntar.';

  @override
  String get trustCertificate => 'Confiar en el certificado';

  @override
  String get testConnection => 'Probar configuración de la cuenta';

  @override
  String get save => 'Guardar';

  @override
  String get saveAfterTest =>
      '\"Guardar\" estará disponible después de una prueba correcta.';

  @override
  String accountNotSaved(String error) {
    return 'Cuenta no guardada: $error';
  }

  @override
  String unencryptedIncoming(String address) {
    return 'entrante ($address)';
  }

  @override
  String unencryptedOutgoing(String address) {
    return 'saliente ($address)';
  }

  @override
  String get unencryptedTitle => 'Conexión sin cifrado';

  @override
  String unencryptedContent(String servers) {
    return 'Para $servers ha elegido el cifrado \"Ninguno\": la contraseña y el correo viajan en texto claro y cualquiera en la misma red (wifi pública, red de empresa, proveedor) puede leerlos o modificarlos.\n\n¿Guardar de todos modos?';
  }

  @override
  String get andSeparator => ' y ';

  @override
  String get saveUnencrypted => 'Guardar sin cifrado';

  @override
  String get runFilterAll => 'Todos los mensajes';

  @override
  String get runFilterRead => 'Mensajes leídos';

  @override
  String get runFilterUnread => 'Mensajes no leídos';

  @override
  String ruleNameFrom(String sender) {
    return 'De $sender';
  }

  @override
  String ruleCreated(String name) {
    return 'Regla \"$name\" creada: se aplica al correo que llegue a partir de ahora.';
  }

  @override
  String ruleNotSaved(String error) {
    return 'Regla no guardada: $error';
  }

  @override
  String get orSeparator => ' o ';

  @override
  String ruleDescFrom(String words) {
    return 'de $words';
  }

  @override
  String ruleDescToOrCc(String words) {
    return 'Para o CC contiene $words';
  }

  @override
  String get ruleDescSentOnlyToMe => 'enviado solo a mí';

  @override
  String get ruleDescMeInTo => 'yo en Para';

  @override
  String get ruleDescMeInCc => 'yo en CC';

  @override
  String ruleDescSubject(String words) {
    return 'el asunto contiene $words';
  }

  @override
  String ruleDescSubjectOrBody(String words) {
    return 'el asunto o el cuerpo contiene $words';
  }

  @override
  String get ruleDescAttachments => 'con datos adjuntos';

  @override
  String ruleDescSize(int kb) {
    return 'de más de $kb KB';
  }

  @override
  String ruleDescMove(String folder) {
    return 'mover a $folder';
  }

  @override
  String ruleDescCopy(String folder) {
    return 'copiar a $folder';
  }

  @override
  String get ruleDescDelete => 'eliminar';

  @override
  String get ruleDescMarkRead => 'marcar como leído';

  @override
  String get ruleDescFlag => 'marcar para seguimiento';

  @override
  String ruleDescCategory(String name) {
    return 'categoría $name';
  }

  @override
  String get ruleDescStop => 'no procesar más reglas';

  @override
  String get ruleDescAllMail => 'Todo el correo';

  @override
  String ruleDescIf(String conditions) {
    return 'Si $conditions';
  }

  @override
  String ruleDescExcept(String exceptions) {
    return ', excepto si $exceptions';
  }

  @override
  String rulesNotRead(String error) {
    return 'Reglas no leídas: $error';
  }

  @override
  String get deleteRuleQuestion => '¿Eliminar la regla?';

  @override
  String deleteRuleContent(String name) {
    return 'La regla \"$name\" dejará de aplicarse. El correo ya ordenado se queda donde está.';
  }

  @override
  String rulesNotSaved(String error) {
    return 'Reglas no guardadas: $error';
  }

  @override
  String get rulesAndAlerts => 'Reglas y alertas';

  @override
  String get applyChangesToFolder => 'Aplicar cambios a esta carpeta';

  @override
  String get newRuleEllipsis => 'Nueva regla…';

  @override
  String get runRulesNowEllipsis => 'Ejecutar reglas ahora…';

  @override
  String get noRules =>
      'No hay reglas. Con \"Nueva regla…\" el correo entrante se ordena automáticamente.';

  @override
  String get rulesInfo =>
      'Las reglas se aplican en el orden de la lista al correo que llega a la Bandeja de entrada mientras PostinoVip está abierto; el correo llegado con la aplicación cerrada se ordena al volver a abrirla.';

  @override
  String get chooseFolderColon => 'Elija la carpeta:';

  @override
  String get ruleNameRequired => 'Escriba el nombre de la regla.';

  @override
  String get ruleFolderRequired => 'Elija la carpeta a la que mover o copiar.';

  @override
  String get ruleActionRequired =>
      'Elija al menos una acción en la pestaña \"Acciones\".';

  @override
  String get ruleSizeRequired => 'Escriba el tamaño en KB.';

  @override
  String get ruleForAllMail => 'Regla para todo el correo';

  @override
  String get ruleForAllMailContent =>
      'Sin condiciones, la regla se aplicará a todo el correo que reciba. ¿Es correcto?';

  @override
  String get newRule => 'Nueva regla';

  @override
  String get editRule => 'Cambiar regla';

  @override
  String get ruleName => 'Nombre de la regla';

  @override
  String get ruleConditions => 'Condiciones';

  @override
  String get ruleActions => 'Acciones';

  @override
  String get ruleExceptions => 'Excepciones';

  @override
  String get ruleConditionsIntro =>
      'Aplicar la regla al correo que cumpla todas las condiciones seleccionadas:';

  @override
  String get ruleExceptionsIntro =>
      'Excepto si se cumple al menos una de estas:';

  @override
  String get ruleFrom => 'de';

  @override
  String get ruleFromHint => 'p. ej. ana@example.com; example.com';

  @override
  String get ruleToOrCc => 'Para o CC contiene';

  @override
  String get ruleToOrCcHint => 'nombres o direcciones, separados por ;';

  @override
  String get ruleMeInTo => 'mi dirección está en el cuadro Para';

  @override
  String get ruleMeInCc => 'mi dirección está en el cuadro CC';

  @override
  String get ruleSubjectContains => 'el asunto contiene';

  @override
  String get ruleSubjectOrBodyContains => 'el asunto o el cuerpo contiene';

  @override
  String get ruleWordsHint => 'palabras separadas por ;';

  @override
  String get ruleLargerThan => 'de más de';

  @override
  String get chooseFolderEllipsis => 'Elegir la carpeta…';

  @override
  String get ruleActionsIntro =>
      'Qué hacer con el correo que cumpla las condiciones:';

  @override
  String get ruleMoveTo => 'moverlo a la carpeta';

  @override
  String get ruleMoveToTitle => 'Mover a la carpeta';

  @override
  String get ruleCopyTo => 'copiarlo a la carpeta';

  @override
  String get ruleCopyToTitle => 'Copiar a la carpeta';

  @override
  String get ruleDeleteAction => 'eliminarlo (a Elementos eliminados)';

  @override
  String get ruleFlagAction => 'marcarlo para seguimiento';

  @override
  String get ruleCategoryAction => 'asignarle la categoría';

  @override
  String get ruleStopAction => 'no procesar más reglas';

  @override
  String rulesNotRun(String error) {
    return 'Reglas no ejecutadas: $error';
  }

  @override
  String progressUnavailable(String error) {
    return 'Progreso no disponible: $error';
  }

  @override
  String get runInFolder => 'Ejecutar en la carpeta';

  @override
  String runStoppedError(String error) {
    return 'Detenido por un error: $error';
  }

  @override
  String runStoppedChecked(int checked, int total) {
    return 'Detenido: $checked de $total mensajes comprobados';
  }

  @override
  String runDoneChecked(int checked) {
    return 'Terminado: $checked mensajes comprobados';
  }

  @override
  String runOutcome(String head, int applied) {
    return '$head, $applied movidos o modificados';
  }

  @override
  String runFailedActions(int count) {
    return ', $count acciones fallidas (detalles en el registro del core)';
  }

  @override
  String get runRulesNow => 'Ejecutar reglas ahora';

  @override
  String get rulesToRun => 'Seleccione las reglas que desea ejecutar:';

  @override
  String get ruleDisabledSuffix => ' (deshabilitada)';

  @override
  String get runInFolderLabel => 'Ejecutar en la carpeta: ';

  @override
  String get includeSubfolders => 'Incluir subcarpetas';

  @override
  String get applyRulesTo => 'Aplicar reglas a';

  @override
  String get preparing => 'Preparando…';

  @override
  String runProgress(int checked, int total) {
    return '$checked de $total mensajes comprobados';
  }

  @override
  String get stopping => 'deteniendo…';

  @override
  String get stop => 'Detener';

  @override
  String get runNow => 'Ejecutar ahora';

  @override
  String settingsNotRead(String error) {
    return 'Configuración no leída: $error';
  }

  @override
  String get autoReplyTextRequired =>
      'Escriba el mensaje de respuesta automática.';

  @override
  String get endAfterStart =>
      'La hora de finalización debe ser posterior a la de inicio.';

  @override
  String get turnOnAutoRepliesQuestion =>
      '¿Activar las respuestas automáticas?';

  @override
  String get turnOnAutoRepliesContent =>
      'A partir de ahora PostinoVip responderá automáticamente, una vez por remitente, al correo que llegue a la Bandeja de entrada en el que usted esté en Para o CC, mientras siga abierto. Las respuestas se envían sin preguntarle.';

  @override
  String get turnOn => 'Activar';

  @override
  String notSavedPlural(String error) {
    return 'No guardadas: $error';
  }

  @override
  String get dontSendAutoReplies => 'No enviar respuestas automáticas';

  @override
  String get sendAutoReplies => 'Enviar respuestas automáticas';

  @override
  String get onlyDuringRange => 'Enviar solo durante este intervalo de tiempo';

  @override
  String get startTimeColon => 'Hora de inicio:';

  @override
  String get endTimeColon => 'Hora de finalización:';

  @override
  String get autoRepliesInfo =>
      'Las respuestas se envían desde este equipo mientras PostinoVip está abierto (el correo llegado con la aplicación cerrada recibe la respuesta al volver a abrirla): solo una por remitente, solo si usted está en Para o CC, nunca a listas de correo, a otras respuestas automáticas ni a remitentes como \"noreply\". No se guardan en Elementos enviados.';

  @override
  String get autoReplyPlaceholder =>
      'p. ej. Estoy fuera de la oficina hasta el lunes 16 de noviembre y responderé a mi regreso.';

  @override
  String get junkLevelNone => 'Sin filtrado automático';

  @override
  String get junkLevelNoneInfo =>
      'El correo de los remitentes bloqueados se sigue moviendo a la carpeta Correo no deseado.';

  @override
  String get junkLevelLow => 'Bajo';

  @override
  String get junkLevelLowInfo =>
      'Mover el correo no deseado más evidente: el que el servidor marcó como spam.';

  @override
  String get junkLevelHigh => 'Alto';

  @override
  String get junkLevelHighInfo =>
      'Mover también el correo con una puntuación cercana al umbral del servidor: puede atrapar también algún correo normal, así que revise a menudo la carpeta Correo no deseado.';

  @override
  String get junkLevelSafeOnly => 'Solo listas seguras';

  @override
  String get junkLevelSafeOnlyInfo =>
      'Solo el correo de personas o dominios de su lista de remitentes seguros, o enviado a su lista de destinatarios seguros, se queda en la Bandeja de entrada.';

  @override
  String get safeSenders => 'Remitentes seguros';

  @override
  String get safeSendersInfo =>
      'El correo de estas direcciones o dominios nunca se tratará como correo no deseado.';

  @override
  String get safeRecipients => 'Destinatarios seguros';

  @override
  String get safeRecipientsInfo =>
      'El correo enviado a estas direcciones o dominios (por ejemplo, una lista de correo) nunca se tratará como correo no deseado.';

  @override
  String get blockedSenders => 'Remitentes bloqueados';

  @override
  String get blockedSendersInfo =>
      'El correo de estas direcciones o dominios se moverá siempre a la carpeta Correo no deseado.';

  @override
  String get neverBlockSender => 'No bloquear nunca al remitente';

  @override
  String get neverBlockDomain => 'No bloquear nunca el dominio del remitente';

  @override
  String get neverBlockGroup =>
      'No bloquear nunca este grupo o lista de correo';

  @override
  String get neverBlockGroups =>
      'No bloquear nunca estos grupos o listas de correo';

  @override
  String get blockSender => 'Bloquear remitente';

  @override
  String get junkOptionsEllipsis => 'Opciones para el correo no deseado…';

  @override
  String get noJunkFolder => 'No hay carpeta Correo no deseado';

  @override
  String noJunkFolderContent(String name) {
    return 'La cuenta \"$name\" no tiene carpeta Correo no deseado: elija una en \"Opciones para el correo no deseado\". El remitente no se ha bloqueado.';
  }

  @override
  String get markAsNotJunk => 'Marcar como correo deseado';

  @override
  String notJunkMoveBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Estos $count mensajes se volverán a mover a la carpeta Bandeja de entrada.',
      one: 'Este mensaje se volverá a mover a la carpeta Bandeja de entrada.',
    );
    return '$_temp0';
  }

  @override
  String alwaysTrustSender(String sender) {
    return 'Confiar siempre en el correo de \"$sender\"';
  }

  @override
  String get alwaysTrustSenders =>
      'Confiar siempre en el correo de estos remitentes';

  @override
  String optionsNotRead(String error) {
    return 'Opciones no leídas: $error';
  }

  @override
  String optionsNotSaved(String error) {
    return 'Opciones no guardadas: $error';
  }

  @override
  String get invalidValue => 'valor no válido';

  @override
  String get junkOptions => 'Opciones para el correo no deseado';

  @override
  String get junkOptionsIntro =>
      'El correo nuevo de la Bandeja de entrada que parezca no deseado se mueve a una carpeta especial mientras PostinoVip está abierto. El juicio es el del servidor de correo. Elija el nivel de protección:';

  @override
  String get junkFolder => 'Carpeta Correo no deseado';

  @override
  String junkFolderAutomatic(String folder) {
    return 'Automática: \"$folder\"';
  }

  @override
  String get junkFolderAutomaticNone =>
      'Automática (no se ha encontrado ninguna carpeta)';

  @override
  String get junkFolderInfo =>
      'Automática: la que indica el servidor, o una con \"spam\", \"junk\" o \"indesiderata\" en el nombre. Para una carpeta nueva: pestaña Carpeta → Nueva carpeta, y luego elíjala aquí.';

  @override
  String get junkNoFolderWarning =>
      'Sin carpeta, el filtro no mueve ningún correo.';

  @override
  String get noEntries => 'No hay entradas';

  @override
  String get addEllipsis => 'Agregar…';

  @override
  String get trustContacts => 'Confiar también en el correo de mis Contactos';

  @override
  String get junkEntryInvalid =>
      'Escriba una dirección (ana@example.com) o un dominio (@example.com).';

  @override
  String get addAddressOrDomain => 'Agregar dirección o dominio';

  @override
  String get editAddressOrDomain => 'Modificar dirección o dominio';

  @override
  String get junkEntryLabel =>
      'Escriba una dirección de correo electrónico o un nombre de dominio de Internet';

  @override
  String get junkEntryHint => 'p. ej. ana@example.com o @example.com';

  @override
  String get alreadyInArchive => 'El mensaje ya está en la carpeta de archivo';

  @override
  String get archiveTooltip => 'Mover a la carpeta de archivo (Retroceso)';

  @override
  String get mailsAlreadyInArchive =>
      'Los mensajes ya están en la carpeta de archivo';

  @override
  String get archiveFolderName => 'Archivo';

  @override
  String get offlineUnavailable =>
      'No disponible sin conexión con el servidor.';

  @override
  String archiveFirstTime(String name) {
    return 'La cuenta \"$name\" aún no tiene carpeta de archivo. Elíjala: Archivar moverá allí el correo, sin eliminarlo.';
  }

  @override
  String archiveInfo(String name) {
    return 'Archivar mueve el correo de \"$name\" a esta carpeta, sin eliminarlo.';
  }

  @override
  String get useExistingFolder => 'Usar una carpeta existente';

  @override
  String get chooseAFolder => 'Elija una carpeta';

  @override
  String get createTopFolder =>
      'Crear una carpeta nueva en el nivel superior de la cuenta';

  @override
  String get okAndArchive => 'Aceptar y archivar';

  @override
  String get stopIgnore => 'Dejar de omitir';

  @override
  String get ignore => 'Omitir';

  @override
  String get stopIgnoreTooltip =>
      'La conversación vuelve a la Bandeja de entrada y el correo nuevo ya no va a Elementos eliminados';

  @override
  String get ignoreTooltip =>
      'Mover la conversación y los mensajes futuros a Elementos eliminados';

  @override
  String cleanUpFolderContent(String name) {
    return 'Los mensajes redundantes de la carpeta \"$name\" (los citados por completo en una respuesta) se moverán a Elementos eliminados. Los mensajes no leídos, marcados, categorizados o firmados se quedan donde están.';
  }

  @override
  String get stopIgnoreContent =>
      'La conversación seleccionada dejará de omitirse y sus mensajes de Elementos eliminados se moverán a la Bandeja de entrada.';

  @override
  String get ignoreContent =>
      'Los mensajes de la conversación seleccionada en esta carpeta y todos los mensajes futuros se moverán a Elementos eliminados.';

  @override
  String get dontShowAgain => 'No volver a mostrar este mensaje';

  @override
  String get notifyAlways => 'Siempre';

  @override
  String get notifyUnfocused =>
      'Solo cuando la ventana no está en primer plano';

  @override
  String get notifyNever => 'Nunca';

  @override
  String get readImmediately => 'En cuanto se abre';

  @override
  String get readAfterDelay => 'Después de verlo durante unos segundos';

  @override
  String get readManual => 'Nunca automáticamente (solo con el botón)';

  @override
  String get receiptAsk =>
      'Preguntar cada vez si se envía una confirmación de lectura';

  @override
  String get receiptAlways => 'Enviar siempre una confirmación de lectura';

  @override
  String get receiptNever => 'No enviar nunca una confirmación de lectura';

  @override
  String get categoryRed => 'Categoría roja';

  @override
  String get categoryOrange => 'Categoría naranja';

  @override
  String get categoryYellow => 'Categoría amarilla';

  @override
  String get categoryGreen => 'Categoría verde';

  @override
  String get categoryBlue => 'Categoría azul';

  @override
  String get categoryPurple => 'Categoría morada';

  @override
  String get followUpTomorrow => 'Mañana';

  @override
  String get followUpThisWeek => 'Esta semana';

  @override
  String get followUpNextWeek => 'La próxima semana';

  @override
  String get followUpNoDate => 'Sin fecha';

  @override
  String get clearAllCategories => 'Borrar todas las categorías';

  @override
  String get allCategoriesEllipsis => 'Todas las categorías…';

  @override
  String get customDateEllipsis => 'Personalizado…';

  @override
  String get markComplete => 'Marcar como completado';

  @override
  String get clearFlag => 'Borrar marca';

  @override
  String get dueByTitle => 'Fecha de vencimiento';

  @override
  String get categoriesTitle => 'Categorías de colores';

  @override
  String get categoriesInfo =>
      'Los nombres solo se aplican en este equipo; en el servidor cada categoría se guarda con su color.';

  @override
  String get defaultNames => 'Nombres predeterminados';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutDescription =>
      'Cliente de correo de escritorio: interfaz en Flutter, core en C# con MailKit.';

  @override
  String aboutLegal(String license) {
    return 'Este programa es software libre: puede redistribuirlo y/o modificarlo según los términos de la $license, publicada por la Free Software Foundation.\n\nSe distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA; ni siquiera la garantía implícita de COMERCIABILIDAD o IDONEIDAD PARA UN PROPÓSITO PARTICULAR. El texto completo de la licencia está en \"Ver licencias\" → PostinoVip.';
  }

  @override
  String coreVersionUnavailable(String error) {
    return 'Core: versión no disponible ($error)';
  }

  @override
  String coreVersion(String version) {
    return 'Core: versión $version';
  }

  @override
  String get coreVersionMismatch =>
      'Atención: la aplicación y el core tienen versiones distintas (vuelva a compilar el core).';

  @override
  String get composeMessages => 'Redactar mensajes';

  @override
  String get composeInFormat => 'Redactar mensajes en este formato';

  @override
  String get composeInFormatHelp =>
      'Para los mensajes nuevos; las respuestas y los reenvíos usan el formato del mensaje original';

  @override
  String get signaturesSection => 'Firmas';

  @override
  String signatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count firmas',
      one: '1 firma',
      zero: 'Sin firmas',
    );
    return '$_temp0';
  }

  @override
  String get signaturesInfo =>
      'Se agregan automáticamente a los mensajes nuevos y a las respuestas, por cuenta';

  @override
  String get markAsReadSection => 'Marcar como leído';

  @override
  String get readReceiptsSection => 'Confirmaciones de lectura';

  @override
  String get alwaysRequestReceipt =>
      'Solicitar siempre una confirmación de lectura para los mensajes nuevos';

  @override
  String get receiptForReceived =>
      'Para cualquier mensaje recibido que incluya una solicitud de confirmación de lectura:';

  @override
  String get confirmBeforeIgnore => 'Preguntar antes de Omitir conversación';

  @override
  String get confirmBeforeStopIgnoring =>
      'Preguntar antes de Dejar de omitir la conversación';

  @override
  String get newMailNotifications => 'Notificaciones de correo nuevo';

  @override
  String get notificationsUnavailable =>
      'Notificaciones del sistema no disponibles: el motivo está en el terminal (\"[notifiche]\").';

  @override
  String get testNotification => 'Notificación de prueba';

  @override
  String get testNotificationText =>
      'Notificación de prueba: si la ve, las notificaciones funcionan.';

  @override
  String get firstDayOfWeek => 'Primer día de la semana';

  @override
  String get workDays => 'Días laborables (Semana laboral)';

  @override
  String get workStart => 'Inicio del horario laboral';

  @override
  String get workEnd => 'Fin del horario laboral';

  @override
  String receiptNotSent(String error) {
    return 'Confirmación de lectura no enviada: $error';
  }

  @override
  String receiptNotRecorded(String error) {
    return 'Confirmación de lectura no registrada: $error';
  }

  @override
  String operationFailed(String error) {
    return 'Error en la operación: $error';
  }

  @override
  String get outboxSending =>
      'Enviando: el mensaje sale en cuanto el servidor responda.';

  @override
  String get outboxDeleted =>
      'Mensaje eliminado de la Bandeja de salida: no se enviará.';

  @override
  String get outboxMovedToDrafts =>
      'Mensaje movido a Borradores: ábralo desde allí para modificarlo.';

  @override
  String folderNotListed(String folder) {
    return 'El servidor ha confirmado la carpeta \"$folder\", pero no la muestra en la lista de carpetas.';
  }

  @override
  String get anotherOperation => 'Hay otra operación en curso';

  @override
  String folderDeletedPermanently(String folder) {
    return 'Carpeta \"$folder\" eliminada permanentemente';
  }

  @override
  String folderMovedToTrash(String folder) {
    return 'Carpeta \"$folder\" movida a Elementos eliminados';
  }

  @override
  String folderNotDeleted(String error) {
    return 'Carpeta no eliminada: $error';
  }

  @override
  String folderEmptied(String folder, String mails, String folders) {
    return '\"$folder\" vaciada: $mails$folders eliminados permanentemente';
  }

  @override
  String emptiedMails(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes',
      one: '1 mensaje',
    );
    return '$_temp0';
  }

  @override
  String emptiedFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' y $count carpetas',
      one: ' y 1 carpeta',
    );
    return '$_temp0';
  }

  @override
  String folderNotEmptied(String error) {
    return 'Carpeta no vaciada: $error';
  }

  @override
  String folderMovedToTop(String folder) {
    return 'Carpeta \"$folder\" movida al nivel superior de la cuenta';
  }

  @override
  String folderMovedInto(String folder, String parent) {
    return 'Carpeta \"$folder\" movida a \"$parent\"';
  }

  @override
  String folderNotMoved(String error) {
    return 'Carpeta no movida: $error';
  }

  @override
  String get mailNotDownloadedOffline =>
      'Mensaje no disponible sin conexión: todavía no se ha descargado en este equipo.';

  @override
  String readStateNotUpdated(String error) {
    return 'Estado leído/no leído no actualizado: $error';
  }

  @override
  String tagsNotUpdated(String error) {
    return 'Marca o categorías no actualizadas: $error';
  }

  @override
  String movedTo(String folder) {
    return 'Movido a \"$folder\"';
  }

  @override
  String get deletedPermanently => 'Eliminado permanentemente';

  @override
  String markedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes marcados como leídos',
      one: '1 mensaje marcado como leído',
    );
    return '$_temp0';
  }

  @override
  String markedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes marcados como no leídos',
      one: '1 mensaje marcado como no leído',
    );
    return '$_temp0';
  }

  @override
  String othersFailed(String text, String error) {
    return '$text; los demás han fallado: $error';
  }

  @override
  String readNotUpdated(String error) {
    return 'Estado de lectura no actualizado: $error';
  }

  @override
  String mailsMovedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes movidos',
      one: '1 mensaje movido',
    );
    return '$_temp0 a \"$folder\"';
  }

  @override
  String mailsDeletedPermanently(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes eliminados',
      one: '1 mensaje eliminado',
    );
    return '$_temp0 permanentemente';
  }

  @override
  String mailsMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes movidos',
      one: '1 mensaje movido',
    );
    return '$_temp0 a Elementos eliminados';
  }

  @override
  String mailsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes archivados',
      one: '1 mensaje archivado',
    );
    return '$_temp0';
  }

  @override
  String get conversationIgnored =>
      'Conversación omitida: los mensajes futuros irán a Elementos eliminados';

  @override
  String conversationIgnoredMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes movidos',
      one: '1 mensaje movido',
    );
    return '$_temp0 a Elementos eliminados; los mensajes futuros también irán allí';
  }

  @override
  String get conversationNotIgnored => 'La conversación ya no se omite';

  @override
  String mailsBackToInbox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes devueltos',
      one: '1 mensaje devuelto',
    );
    return '$_temp0 a la Bandeja de entrada';
  }

  @override
  String cleanUpDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes redundantes movidos a Elementos eliminados',
      one: '1 mensaje redundante movido a Elementos eliminados',
      zero: 'No hay mensajes redundantes que mover',
    );
    return '$_temp0';
  }

  @override
  String get noMailMoved => 'Ningún mensaje movido';

  @override
  String mailsMovedToJunk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes movidos',
      one: '1 mensaje movido',
    );
    return '$_temp0 a Correo no deseado';
  }

  @override
  String senderBlocked(String sender) {
    return '$sender bloqueado';
  }

  @override
  String sendersBlocked(int count, String senders) {
    return '$count remitentes bloqueados ($senders)';
  }

  @override
  String senderTrusted(String sender) {
    return '$sender es de confianza';
  }

  @override
  String sendersTrusted(int count, String senders) {
    return '$count remitentes de confianza ($senders)';
  }

  @override
  String addedToSafeSenders(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries agregados',
      one: '$entries agregado',
    );
    return '$_temp0 a Remitentes seguros';
  }

  @override
  String addedToSafeRecipients(int count, String entries) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$entries agregados',
      one: '$entries agregado',
    );
    return '$_temp0 a Destinatarios seguros';
  }

  @override
  String listsNotUpdated(String error) {
    return 'Listas no actualizadas: $error';
  }

  @override
  String mailsCopiedTo(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes copiados',
      one: '1 mensaje copiado',
    );
    return '$_temp0 a \"$folder\"';
  }

  @override
  String mailsNotCopied(String error) {
    return 'Mensajes no copiados: $error';
  }

  @override
  String get fmtTime => 'H:mm';

  @override
  String get fmtDayMonth => 'dd/MM';

  @override
  String get fmtDate => 'dd/MM/yyyy';

  @override
  String get fmtWeekdayDate => 'EEE dd/MM/yyyy';

  @override
  String get fmtWeekdayDateTime => 'EEE dd/MM/yyyy H:mm';

  @override
  String get fmtWeekdayTime => 'EEE H:mm';

  @override
  String get fmtLongDateTime => 'EEEE, d \'de\' MMMM \'de\' y H:mm';

  @override
  String get groupNoDate => 'Sin fecha';

  @override
  String get groupYesterday => 'Ayer';

  @override
  String get groupLastWeek => 'La semana pasada';

  @override
  String get groupTwoWeeksAgo => 'Hace dos semanas';

  @override
  String get groupThreeWeeksAgo => 'Hace tres semanas';

  @override
  String get groupEarlierThisMonth => 'A principios de este mes';

  @override
  String get groupLastMonth => 'El mes pasado';

  @override
  String get groupOlder => 'Más antiguos';

  @override
  String get sizeTiny => 'Diminuto (< 10 KB)';

  @override
  String get sizeSmall => 'Pequeño (10 - 25 KB)';

  @override
  String get sizeMedium => 'Mediano (25 - 100 KB)';

  @override
  String get sizeLarge => 'Grande (100 - 500 KB)';

  @override
  String get sizeVeryLarge => 'Muy grande (500 KB - 1 MB)';

  @override
  String get sizeHuge => 'Enorme (1 - 5 MB)';

  @override
  String get sizeEnormous => 'Gigantesco (> 5 MB)';

  @override
  String sizeBytes(int count) {
    return '$count bytes';
  }

  @override
  String get fmtMonthYear => 'MMMM \'de\' y';

  @override
  String get fmtFullDate => 'EEEE, d \'de\' MMMM \'de\' y';

  @override
  String get fmtHour => 'H:00';

  @override
  String get fmtRangeSameMonthStart => 'd';

  @override
  String get fmtRangeSameMonthEnd => 'd \'de\' MMMM \'de\' y';

  @override
  String get fmtRangeOtherMonthStart => 'd \'de\' MMMM';

  @override
  String get fmtRangeOtherMonthEnd => 'd \'de\' MMMM \'de\' y';

  @override
  String get fmtRangeOtherYearStart => 'd \'de\' MMMM \'de\' y';

  @override
  String get fmtRangeOtherYearEnd => 'd \'de\' MMMM \'de\' y';

  @override
  String get recurOrdinalFirst => 'el primer';

  @override
  String get recurOrdinalSecond => 'el segundo';

  @override
  String get recurOrdinalThird => 'el tercer';

  @override
  String get recurOrdinalFourth => 'el cuarto';

  @override
  String get recurOrdinalLast => 'el último';

  @override
  String recurDescDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count días',
      one: 'Cada día',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count semanas',
      one: 'Cada semana',
    );
    return '$_temp0';
  }

  @override
  String recurDescWeeklyOn(String every, String days) {
    return '$every el $days';
  }

  @override
  String recurDescMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count meses',
      one: 'Cada mes',
    );
    return '$_temp0';
  }

  @override
  String recurDescMonthlyDay(String every, int day) {
    return '$every el día $day';
  }

  @override
  String recurDescMonthlyWhich(String every, String which) {
    return '$every $which';
  }

  @override
  String recurDescYearlyWhich(String which, String month) {
    return 'Cada año $which de $month';
  }

  @override
  String recurDescYearlyDay(String day, String month) {
    return 'Cada año el $day de $month';
  }

  @override
  String get recurDescRecurring => 'Periódica';

  @override
  String recurDescTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count veces',
      one: ', 1 vez',
    );
    return '$_temp0';
  }

  @override
  String recurDescUntil(String date) {
    return ', hasta el $date';
  }

  @override
  String whenAllDay(String date) {
    return '$date (todo el día)';
  }

  @override
  String whenAllDayRange(String start, String end) {
    return 'Del $start al $end (todo el día)';
  }

  @override
  String get coreKindInvalidRequest => 'Solicitud no válida';

  @override
  String get coreKindNotFound => 'No encontrado';

  @override
  String get coreKindOffline => 'Sin conexión';

  @override
  String get coreKindServer => 'Error del servidor de correo';

  @override
  String get coreKindConflict => 'Operación no permitida';

  @override
  String get coreKindNotSupported => 'No admitido por el servidor';

  @override
  String get coreKindCertificate => 'Certificado del servidor no válido';

  @override
  String get coreKindOAuth => 'Error al iniciar sesión en la cuenta';

  @override
  String get coreKindAuth => 'Error de autenticación con el servidor de correo';

  @override
  String get coreKindConfig => 'Configuración no válida';

  @override
  String get coreKindInternal => 'Error interno';

  @override
  String certNameMismatch(String host) {
    return 'emitido para un nombre distinto de $host';
  }

  @override
  String get certUntrustedRoot =>
      'no firmado por una entidad reconocida (p. ej. autofirmado)';

  @override
  String get certNotTimeValid => 'caducado o aún no válido';

  @override
  String get certRevoked => 'revocado';

  @override
  String get certChainInvalid => 'cadena de certificados no válida';

  @override
  String get certNoCertificate => 'sin certificado';

  @override
  String get coreTimeout =>
      'El servidor no responde: puede que la operación no se haya realizado.';

  @override
  String get coreAuthCheckCredentials =>
      'Compruebe el nombre de usuario y la contraseña.';

  @override
  String get coreInternalUnexpected =>
      'Error inesperado, consulte el registro del core.';

  @override
  String coreCertificateChanged(String address, String problems) {
    return 'Certificado no válido para $address ($problems). Abra la configuración de la cuenta y repita \"Probar configuración de la cuenta\".';
  }

  @override
  String coreTestCertificateInvalid(String address, String problems) {
    return 'El certificado del servidor $address no es válido: $problems.';
  }

  @override
  String coreTestNoStartTls(String address) {
    return 'El servidor $address no ofrece STARTTLS: elija otro cifrado u otro puerto.';
  }

  @override
  String get coreTestAuthRejected =>
      'Autenticación rechazada: compruebe la dirección y la contraseña.';

  @override
  String coreTestTlsFailed(String address) {
    return 'Error en la conexión cifrada con $address: ¿el puerto usa realmente este cifrado?';
  }

  @override
  String coreTestUnreachable(String address) {
    return 'Servidor $address no accesible.';
  }

  @override
  String coreTestNoAnswer(String address, String seconds) {
    return 'Sin respuesta de $address en $seconds s: ¿servidor, puerto o cifrado incorrectos?';
  }

  @override
  String coreTestUnexpectedAnswer(String address) {
    return 'Respuesta inesperada de $address: ¿puerto o protocolo incorrectos?';
  }

  @override
  String corePop3NoUidl(String address) {
    return 'El servidor POP3 $address no admite UIDL: es necesario para no descargar el correo dos veces.';
  }

  @override
  String coreOAuthServerUnreachable(String provider) {
    return 'Servidor de inicio de sesión de $provider no accesible.';
  }

  @override
  String coreOAuthInvalidResponse(String provider, String status) {
    return 'Respuesta no válida del servidor de inicio de sesión de $provider (HTTP $status).';
  }

  @override
  String coreOAuthExpired(String provider) {
    return 'Inicio de sesión en $provider caducado o revocado: repita \"Iniciar sesión con $provider\".';
  }

  @override
  String coreOAuthClientInvalid(String provider) {
    return 'PostinoVip no está registrado correctamente en $provider (ID de cliente).';
  }

  @override
  String coreOAuthFailed(String provider, String error) {
    return 'Error al iniciar sesión en $provider ($error).';
  }

  @override
  String get coreOAuthCancelled => 'Inicio de sesión cancelado.';

  @override
  String get coreOAuthNoCode => 'Error al iniciar sesión (sin código).';

  @override
  String coreOAuthFlowFailed(String error) {
    return 'Error al iniciar sesión ($error).';
  }

  @override
  String get coreOAuthNoRefreshToken =>
      'El proveedor no ha dado un token de actualización (¿falta offline_access?).';

  @override
  String coreServerUnreachable(String reason) {
    return 'Servidor no accesible ($reason).';
  }

  @override
  String corePop3NoAnswer(String address) {
    return 'Servidor POP3 $address no accesible (sin respuesta).';
  }

  @override
  String corePop3Unreachable(String address, String reason) {
    return 'Servidor POP3 $address no accesible ($reason).';
  }

  @override
  String coreSmtpNoAnswer(String seconds) {
    return 'Servidor de salida no accesible (sin respuesta en $seconds s): mensaje no enviado.';
  }

  @override
  String coreSmtpUnreachable(String reason) {
    return 'Servidor de salida no accesible ($reason): mensaje no enviado.';
  }

  @override
  String get coreContactsServerUnreachable =>
      'Servidor de contactos no accesible.';

  @override
  String get coreCalendarServerUnreachable =>
      'Servidor de calendario no accesible.';

  @override
  String get coreContactsServerNoAnswer =>
      'El servidor de contactos no responde.';

  @override
  String get coreCalendarServerNoAnswer =>
      'El servidor de calendario no responde.';

  @override
  String coreDavSignInRejectedContacts(String provider) {
    return '$provider ha rechazado el acceso al servidor de contactos: repita \"Iniciar sesión con $provider\" permitiendo el acceso a los contactos.';
  }

  @override
  String coreDavSignInRejectedCalendar(String provider) {
    return '$provider ha rechazado el acceso al servidor de calendario: repita \"Iniciar sesión con $provider\" permitiendo el acceso al calendario.';
  }

  @override
  String coreDavScopeMissingContacts(String provider) {
    return 'El inicio de sesión con $provider no incluye permiso para los contactos: repita \"Iniciar sesión con $provider\".';
  }

  @override
  String coreDavScopeMissingCalendar(String provider) {
    return 'El inicio de sesión con $provider no incluye permiso para el calendario: repita \"Iniciar sesión con $provider\".';
  }

  @override
  String coreAccountScopeMissingContacts(String provider) {
    return 'El inicio de sesión con $provider no incluye los contactos: en la ventana de la cuenta use \"Volver a iniciar sesión\" y permita el acceso a los contactos.';
  }

  @override
  String coreAccountScopeMissingCalendar(String provider) {
    return 'El inicio de sesión con $provider no incluye el calendario: en la ventana de la cuenta use \"Volver a iniciar sesión\" y permita el acceso al calendario.';
  }

  @override
  String get coreNotConnected => 'sin conexión';

  @override
  String coreUnreachableApp(String address, String error) {
    return 'Core de PostinoVip no accesible en $address: $error';
  }

  @override
  String get coreUnexpectedResponse => 'Respuesta inesperada del core';

  @override
  String get coreUnexpectedResponseVersions =>
      'Respuesta inesperada del core (¿versiones distintas de la aplicación y del core?)';

  @override
  String get coreEventsUnavailable => 'Eventos no disponibles';

  @override
  String coreUnexpectedFormat(String path, String error) {
    return 'Respuesta del core en un formato inesperado ($path): $error. ¿Está el core actualizado y reiniciado?';
  }

  @override
  String get imagePlaceholder => 'imagen';

  @override
  String get coreErrScrivereIlNomeDellaCartella =>
      'Escriba el nombre de la carpeta.';

  @override
  String coreErrIlNomePuoAvereAl(String maxLength) {
    return 'El nombre puede tener como máximo $maxLength caracteres.';
  }

  @override
  String get coreErrIlNomeContieneCaratteriNon =>
      'El nombre contiene caracteres no válidos.';

  @override
  String coreErrIlNomeNonPuoContenere(String separator) {
    return 'El nombre no puede contener el carácter \"$separator\".';
  }

  @override
  String get coreErrInboxIlNomeRiservatoDella =>
      '\"INBOX\" es el nombre reservado de la Bandeja de entrada.';

  @override
  String get coreErrIlMessaggioOriginaleDisponibileSolo =>
      'El mensaje original solo está disponible con la copia local.';

  @override
  String get coreErrCartellaNonValida => 'Carpeta no válida.';

  @override
  String get coreErrLaMailNonChiedeUna =>
      'El mensaje no solicita una confirmación de lectura a esta dirección.';

  @override
  String get coreErrLivelloDelFiltroNonValido => 'Nivel de filtro no válido.';

  @override
  String get coreErrNessunaCartellaDellaPostaIndesiderata =>
      'No hay carpeta Correo no deseado: elíjala en \"Opciones para el correo no deseado\".';

  @override
  String get coreErrNessunMittenteDaBloccareLe =>
      'No hay remitente que bloquear (los mensajes se enviaron desde esta cuenta o no tienen remitente).';

  @override
  String get coreErrNonPostaIndesiderataValeSolo =>
      '\"No es correo no deseado\" solo se aplica a los mensajes de la carpeta Correo no deseado.';

  @override
  String coreErrNessunaDelleMailIndicateIn(String folder) {
    return 'Ninguno de los mensajes indicados está en \'$folder\'.';
  }

  @override
  String get coreErrIlServerPop3NonSupporta =>
      'El servidor POP3 no admite UIDL: sin él no hay forma de saber qué mensajes ya se descargaron.';

  @override
  String get coreErrIdNonValido => 'Id no válido.';

  @override
  String get coreErrHostSmtpNonConfigurato => 'Host SMTP no configurado.';

  @override
  String coreErrAllegatiTroppoGrandiMbMassimo(String value, String value2) {
    return 'Datos adjuntos demasiado grandes: $value MB, máximo $value2 MB.';
  }

  @override
  String coreErrIlHaRifiutatoLaRichiesta(String serverLabel) {
    return 'El $serverLabel ha rechazado la solicitud (403).';
  }

  @override
  String coreErrIndirizzoDelNonAmmessoServe(
    String value,
    String scheme,
    String host,
  ) {
    return 'Dirección del $value no permitida: se requiere https ($scheme://$host).';
  }

  @override
  String get coreErrNessunCalendarioTrovatoSulServer =>
      'No se ha encontrado ningún calendario en el servidor de calendario.';

  @override
  String get coreErrNessunaRubricaTrovataSulServer =>
      'No se ha encontrado ninguna libreta de direcciones en el servidor de contactos.';

  @override
  String coreErrIlHaCreatoElementoSenza(String serverLabel) {
    return 'El $serverLabel ha creado el elemento sin indicar dónde (falta Location).';
  }

  @override
  String coreErrIlHaCreatoElementoFuori(String serverLabel) {
    return 'El $serverLabel ha creado el elemento fuera de la colección.';
  }

  @override
  String coreErrTroppiReindirizzamentiDal(String serverLabel) {
    return 'Demasiadas redirecciones del $serverLabel.';
  }

  @override
  String coreErrIlHaRifiutatoNomeUtente(String serverLabel) {
    return 'El $serverLabel ha rechazado el nombre de usuario o la contraseña.';
  }

  @override
  String coreErrCertificatoDelNonValido(String serverLabel) {
    return 'Certificado del $serverLabel no válido.';
  }

  @override
  String coreErrIlHaRisposto(
    String serverLabel,
    String code,
    String reasonPhrase,
  ) {
    return 'El $serverLabel ha respondido $code $reasonPhrase.';
  }

  @override
  String coreErrRispostaDelNonLeggibile(String serverLabel) {
    return 'Respuesta ilegible del $serverLabel.';
  }

  @override
  String get coreErrIlFileNonUnaMail =>
      'El archivo no es un mensaje legible (.eml).';

  @override
  String get coreErrIlFileNonUnaMail2 =>
      'El archivo no es un mensaje (.eml): faltan remitente, fecha, asunto y destinatarios.';

  @override
  String get coreErrIlFileEmlNonPiu =>
      'El archivo .eml ya no está abierto: vuelva a abrirlo.';

  @override
  String coreErrAccountNonTrovato(String id) {
    return 'Cuenta \'$id\' no encontrada.';
  }

  @override
  String coreErrAccountUnAccountPop3Richiede(String id) {
    return 'Cuenta \'$id\': una cuenta POP3 requiere la copia local (Cache:Enabled=false no es posible).';
  }

  @override
  String coreErrAccountFornitoreOauthSconosciuto(String id, String provider) {
    return 'Cuenta \'$id\': proveedor OAuth desconocido \'$provider\'.';
  }

  @override
  String coreErrAccountMancaIlClientId(
    String id,
    String displayName,
    String id2,
  ) {
    return 'Cuenta \'$id\': falta el ID de cliente de $displayName (sección OAuth:$id2).';
  }

  @override
  String get coreErrNessunAccountConfigurato =>
      'No hay ninguna cuenta configurada.';

  @override
  String coreErrIdAccountNonValidoAmmessi(String id) {
    return 'Id de cuenta no válido: \'$id\' (se permiten letras, números, \'-\' y \'_\', como máximo 64).';
  }

  @override
  String coreErrAccountLimiteDellaCacheNon(String id, String bodyMonths) {
    return 'Cuenta \'$id\': límite de la copia local no válido ($bodyMonths meses; 0 = todo).';
  }

  @override
  String coreErrAccountIndirizzoNonValido(String id, String name) {
    return 'Cuenta \'$id\': dirección $name no válida.';
  }

  @override
  String coreErrAccount(String id, String message) {
    return 'Cuenta \'$id\': $message';
  }

  @override
  String coreErrIdAccountRipetuto(String key) {
    return 'Id de cuenta repetido: \'$key\'.';
  }

  @override
  String coreErrCartellaNonTrovata(String fullName) {
    return 'Carpeta \'$fullName\' no encontrada.';
  }

  @override
  String coreErrLaCartellaEsisteGia(String fullName) {
    return 'La carpeta \'$fullName\' ya existe.';
  }

  @override
  String coreErrCartellaNonTrovata2(String parent) {
    return 'Carpeta \'$parent\' no encontrada.';
  }

  @override
  String coreErrCartellaNonTrovata3(String folder) {
    return 'Carpeta \'$folder\' no encontrada.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn(String uid, String folder) {
    return 'Mensaje $uid no encontrado en \'$folder\'.';
  }

  @override
  String coreErrLaCartellaEsisteGia2(String newFullName) {
    return 'La carpeta \'$newFullName\' ya existe.';
  }

  @override
  String get coreErrCartellaNonIndicata => 'Carpeta no indicada.';

  @override
  String coreErrCartellaNonValida2(String fullName) {
    return 'Carpeta \'$fullName\' no válida.';
  }

  @override
  String coreErrCartellaAssenteDallIndiceDopo(String folder) {
    return 'Carpeta \'$folder\' ausente del índice después de la sincronización.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio(String index, String uid) {
    return 'Dato adjunto $index no encontrado en el mensaje $uid.';
  }

  @override
  String coreErrAllegatoNonTrovatoNelMessaggio2(String i, String uid) {
    return 'Dato adjunto $i no encontrado en el mensaje $uid.';
  }

  @override
  String get coreErrCartellaDiOrigineDestinazioneCoincidono =>
      'Las carpetas de origen y de destino coinciden.';

  @override
  String get coreErrIlMessaggioGiaInPosta =>
      'El mensaje ya está en Elementos eliminados: use la eliminación permanente.';

  @override
  String get coreErrEliminazioneDefinitivaConsentitaSoloIn =>
      'La eliminación permanente solo se permite en Elementos eliminados.';

  @override
  String coreErrNonPuoAndareDentroSe(String folder) {
    return '\'$folder\' no puede ir dentro de sí misma ni de una de sus subcarpetas.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon(String folder, String special) {
    return '\'$folder\' contiene la carpeta especial \'$special\': no se vacía.';
  }

  @override
  String coreErrNessunaCartellaLocaleConRuolo(String role) {
    return 'No hay ninguna carpeta local con el rol $role.';
  }

  @override
  String coreErrMessaggioNonTrovatoIn2(String uid, String fullName) {
    return 'Mensaje $uid no encontrado en \'$fullName\'.';
  }

  @override
  String coreErrNessunaRispostaIn(String totalSeconds) {
    return 'sin respuesta en $totalSeconds s';
  }

  @override
  String get coreErrHostImapNonConfigurato => 'Host IMAP no configurado.';

  @override
  String coreErrMessaggioNonTrovatoIn3(String uid, String folderName) {
    return 'Mensaje $uid no encontrado en \'$folderName\'.';
  }

  @override
  String coreErrIlServerNonPermetteDi(String value, String folderName) {
    return 'El servidor no permite guardar las palabras clave $value en \'$folderName\'.';
  }

  @override
  String get coreErrIlServerNonDichiaraUna =>
      'El servidor no declara una carpeta \\Sent (Elementos enviados): copia no guardada.';

  @override
  String get coreErrIlServerNonDichiaraUna2 =>
      'El servidor no declara una carpeta \\Drafts (Borradores): borrador no guardado.';

  @override
  String get coreErrIlServerNonDichiaraUna3 =>
      'El servidor no declara una carpeta \\Drafts (Borradores).';

  @override
  String get coreErrIlServerNonDichiaraUna4 =>
      'El servidor no declara una carpeta \\Trash (Elementos eliminados).';

  @override
  String get coreErrIlServerNonSupportaMove =>
      'El servidor no admite ni MOVE ni UIDPLUS: operación rechazada para no eliminar otros mensajes.';

  @override
  String coreErrLaCartellaNonPuoContenere(String fullName) {
    return 'La carpeta \'$fullName\' no puede contener subcarpetas.';
  }

  @override
  String coreErrIlServerNonHaCreato(String clean) {
    return 'El servidor no ha creado la carpeta \'$clean\'.';
  }

  @override
  String coreErrContieneLaCartellaSpecialeNon2(
    String fullName,
    String fullName2,
  ) {
    return '\'$fullName\' contiene la carpeta especial \'$fullName2\': no se vacía.';
  }

  @override
  String coreErrNonPuoAndareDentroSe2(String fullName) {
    return '\'$fullName\' no puede ir dentro de sí misma ni de una de sus subcarpetas.';
  }

  @override
  String coreErrUnaCartellaSpecialeNonSi(String fullName) {
    return '\'$fullName\' es una carpeta especial: no se puede cambiar de nombre, mover ni eliminar.';
  }

  @override
  String coreErrCartellaNonTrovata4(String folderName) {
    return 'Carpeta \'$folderName\' no encontrada.';
  }

  @override
  String coreErrStrutturaBodystructureIlleggibileInUn(
    String count,
    String fullName,
    String message,
  ) {
    return 'estructura (BODYSTRUCTURE) ilegible en un grupo de $count mensajes de $fullName: omitido, el mensaje defectuoso se buscará en segundo plano ($message)';
  }

  @override
  String get coreErrFiltroDaLeggereOrdineDal =>
      'El filtro \"No leídos\" y el orden de más antiguo a más reciente requieren la copia local (Cache:Enabled=false).';

  @override
  String get coreErrLeConversazioniRichiedonoLaCache =>
      'Las conversaciones requieren la copia local (Cache:Enabled=false).';

  @override
  String get coreErrLaRicercaRichiedeLaCache =>
      'La búsqueda requiere la copia local (Cache:Enabled=false).';

  @override
  String coreErrCorpoAppenaSalvatoNonRileggibile(
    String folderName,
    String uid,
  ) {
    return 'Cuerpo $folderName/$uid recién guardado y no legible.';
  }

  @override
  String coreErrCartellaAssenteDallaCacheDopo(String fullName) {
    return 'Carpeta \'$fullName\' ausente de la copia local después de la sincronización.';
  }

  @override
  String get coreErrImprontaSha256NonValida =>
      'Huella digital SHA-256 no válida.';

  @override
  String coreErrAccountAncoraConfiguratoPerSvuotarne(String id) {
    return 'La cuenta \'$id\' sigue configurada: para vaciar su copia local use \"Reconstruir copia local\".';
  }

  @override
  String coreErrNessunDatoLocalePerAccount(String id) {
    return 'No hay datos locales para la cuenta \'$id\'.';
  }

  @override
  String get coreErrIgnoraPulisciRichiedonoLaCopia =>
      'Omitir y Limpiar requieren la copia local (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaPostaEliminataIn =>
      'No hay carpeta Elementos eliminados en esta cuenta.';

  @override
  String get coreErrLaConversazioneNonIgnorata =>
      'La conversación no está omitida.';

  @override
  String get coreErrPulisciNonValePerPosta =>
      'Limpiar no se aplica a Elementos eliminados ni a Correo no deseado.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia =>
      'Las reglas requieren la copia local.';

  @override
  String coreErrAlMassimoRegolePerAccount(String maxRules) {
    return 'Como máximo $maxRules reglas por cuenta.';
  }

  @override
  String get coreErrOgniRegolaDeveAvereUn => 'Cada regla debe tener un nombre.';

  @override
  String coreErrIlNomePuoAvereAl2(String name, String maxNameLength) {
    return '\"$name…\": el nombre puede tener como máximo $maxNameLength caracteres.';
  }

  @override
  String coreErrEliminaSpostaInsiemeNonHanno(String name) {
    return '\"$name\": \"Eliminar\" y \"Mover\" juntos no tienen sentido, elija uno.';
  }

  @override
  String coreErrCategoriaNonValida(String name) {
    return '\"$name\": categoría no válida.';
  }

  @override
  String coreErrDimensioneNonValida(String rule) {
    return '\"$rule\": tamaño no válido.';
  }

  @override
  String coreErrTroppeParoleParoleTroppoLunghe(String rule) {
    return '\"$rule\": demasiadas palabras o palabras demasiado largas.';
  }

  @override
  String get coreErrScrivereIlMessaggioDellaRisposta =>
      'Escriba el mensaje de respuesta automática.';

  @override
  String get coreErrLaFineDeveVenireDopo =>
      'El fin debe ser posterior al inicio.';

  @override
  String get coreErrIlMessaggioTroppoLungo => 'El mensaje es demasiado largo.';

  @override
  String get coreErrContattoNonTrovato => 'Contacto no encontrado.';

  @override
  String coreErrLaRubricaHaGiaContatti(String maxContacts) {
    return 'La libreta de direcciones ya tiene $maxContacts contactos.';
  }

  @override
  String get coreErrFormatoNonRiconosciutoUsareVcf =>
      'Formato no reconocido: use vcf o csv.';

  @override
  String coreErrIndirizzoNonValido(String address) {
    return 'Dirección no válida: $address';
  }

  @override
  String get coreErrScrivereAlmenoUnNomeLa =>
      'Escriba al menos un nombre, la empresa o una dirección.';

  @override
  String get coreErrCalendarioNonTrovato => 'Calendario no encontrado.';

  @override
  String get coreErrAppuntamentoNonValido => 'Cita no válida.';

  @override
  String get coreErrAppuntamentoNonTrovato => 'Cita no encontrada.';

  @override
  String get coreErrEsisteGiaUnAppuntamentoCon =>
      'Ya existe una cita con el mismo UID.';

  @override
  String coreErrIlCalendarioHaGiaAppuntamenti(String maxItems) {
    return 'El calendario ya tiene $maxItems citas.';
  }

  @override
  String coreErrPeriodoNonValidoAlMassimo(String maxDays) {
    return 'Período no válido: como máximo $maxDays días, con el fin posterior al inicio.';
  }

  @override
  String get coreErrAppuntamentoNonLeggibile => 'Cita ilegible.';

  @override
  String get coreErrOccorrenzaNonValida => 'Repetición no válida.';

  @override
  String get coreErrSerieNonTrovata => 'Serie no encontrada.';

  @override
  String get coreErrAppuntamentoNonRicorrenteSiModifica =>
      'La cita no es periódica: se modifica entera.';

  @override
  String get coreErrAlMassimo20000Caratteri => 'Como máximo 20000 caracteres.';

  @override
  String get coreErrPromemoriaNonValidoDaMinuti =>
      'Aviso no válido (de 0 minutos a 4 semanas antes).';

  @override
  String get coreErrLaFinePrimaDellInizio => 'El fin es anterior al inicio.';

  @override
  String get coreErrSerializzazioneNonRiuscita => 'Error de serialización.';

  @override
  String coreErrMancaIlClientIdDi(String displayName, String id) {
    return 'Falta el ID de cliente de $displayName: la aplicación debe registrarse y el ID escribirse en oauth-clients.json (sección OAuth:$id).';
  }

  @override
  String coreErrLaSincronizzazioneDeiContattiNon(String displayName) {
    return 'La sincronización de contactos no está disponible con $displayName.';
  }

  @override
  String coreErrLaSincronizzazioneDelCalendarioNon(String displayName) {
    return 'La sincronización del calendario no está disponible con $displayName.';
  }

  @override
  String coreErrAllegatoNonTrovato(String i) {
    return 'Dato adjunto $i no encontrado.';
  }

  @override
  String get coreErrIndicareLaCartellaDelMessaggio =>
      'Indique la carpeta del mensaje original.';

  @override
  String coreErrModalitaNonValidaReplyReplyall(String mode) {
    return 'Modo no válido: $mode (reply, replyAll, forward).';
  }

  @override
  String coreErrMancantePiuCortoDiCaratteri(
    String configKey,
    String minLength,
  ) {
    return '$configKey ausente o de menos de $minLength caracteres.';
  }

  @override
  String get coreErrCartellaDeiDatiDellUtente =>
      'No se puede determinar la carpeta de datos del usuario (¿HOME no definido?): use Cache:Directory.';

  @override
  String get coreErrIndicareAlmenoUnaMail => 'Indique al menos un mensaje.';

  @override
  String coreErrAlMassimoMailPerVolta(String maxBatch) {
    return 'Como máximo $maxBatch mensajes cada vez.';
  }

  @override
  String coreErrAllegatoNonTrovato2(String index) {
    return 'Dato adjunto $index no encontrado.';
  }

  @override
  String get coreErrUnaCategoriaNonPuoEssere =>
      'Una categoría no se puede agregar y quitar a la vez.';

  @override
  String get coreErrIndicareLaCartellaDiDestinazione =>
      'Indique la carpeta de destino.';

  @override
  String get coreErrLaScadenzaValeSoloCon =>
      'La fecha de vencimiento solo se aplica con followUp \"flagged\".';

  @override
  String get coreErrLeRisposteAutomaticheRichiedonoLa =>
      'Las respuestas automáticas requieren la copia local.';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa =>
      'El correo no deseado requiere la copia local (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaIndesiderataRichiedeLa2 =>
      'El correo no deseado requiere la copia local.';

  @override
  String get coreErrLaCartellaSceltaNonEsiste =>
      'La carpeta elegida no existe.';

  @override
  String get coreErrScegliereUnaCartellaDiversaDa =>
      'Elija una carpeta distinta de Bandeja de entrada, Elementos enviados, Borradores y Elementos eliminados.';

  @override
  String get coreErrLaCartellaDiArchiviazioneSceglierne =>
      'Es la carpeta de archivo: elija otra.';

  @override
  String coreErrCartellaNonTrovata5(String name) {
    return 'Carpeta \'$name\' no encontrada.';
  }

  @override
  String get coreErrArchiviaRichiedeLaCopiaLocale =>
      'Archivar requiere la copia local (Cache:Enabled=false).';

  @override
  String get coreErrNessunaCartellaDiArchiviazioneSceglierla =>
      'No hay carpeta de archivo: elíjala con \"Establecer carpeta de archivo\".';

  @override
  String get coreErrLeMailSonoGiaNella =>
      'Los mensajes ya están en la carpeta de archivo.';

  @override
  String get coreErrContattiRichiedonoLaCopiaLocale =>
      'Los contactos requieren la copia local (Cache:Enabled=false).';

  @override
  String get coreErrContenutoDelFileNonValido =>
      'Contenido del archivo no válido.';

  @override
  String get coreErrFileTroppoGrandeAlMassimo =>
      'Archivo demasiado grande (como máximo 10 MB).';

  @override
  String get coreErrLaSincronizzazioneDeiContattiNon2 =>
      'La sincronización de contactos no está activa para esta cuenta.';

  @override
  String get coreErrDa50 => 'De 1 a 50.';

  @override
  String get coreErrIndirizzoMancante => 'Falta la dirección.';

  @override
  String get coreErrLeRegoleRichiedonoLaCopia2 =>
      'Las reglas requieren la copia local (Cache:Enabled=false).';

  @override
  String get coreErrScegliereAlmenoUnaRegolaSalvata =>
      'Elija al menos una regla guardada.';

  @override
  String get coreErrAccountPop3LeMailSono =>
      'Cuenta POP3: el correo solo está en este equipo, no hay ninguna copia que reconstruir desde el servidor.';

  @override
  String get coreErrCalendariRichiedonoLaCopiaLocale =>
      'Los calendarios requieren la copia local (Cache:Enabled=false).';

  @override
  String coreErrIlCalendarioDiSolaLettura(String name) {
    return 'El calendario \"$name\" es de solo lectura: no se pueden crear, modificar ni eliminar citas.';
  }

  @override
  String get coreErrLaSincronizzazioneDelCalendarioNon2 =>
      'La sincronización del calendario no está activa para esta cuenta.';

  @override
  String get coreErrRitardaRecapitoRichiedeLaCache =>
      'Retrasar entrega requiere la copia local (Cache:Enabled=false).';

  @override
  String get coreErrLaPostaInUscitaRichiede =>
      'La Bandeja de salida requiere la copia local (Cache:Enabled=false).';

  @override
  String get coreErrMailNonTrovataNellaPosta =>
      'Mensaje no encontrado en la Bandeja de salida.';

  @override
  String get coreErrNessunaConfermaDiLetturaPer =>
      'No hay confirmaciones de lectura para los mensajes de Correo no deseado, Elementos enviados y Borradores.';

  @override
  String get coreErrAllaRichiestaDiConfermaDi =>
      'Ya se ha respondido a la solicitud de confirmación de lectura.';

  @override
  String get coreErrLaMailNonChiedeUna2 =>
      'El mensaje no solicita una confirmación de lectura a su remitente.';

  @override
  String get davContactsServerLabel => 'servidor de contactos';

  @override
  String get davCalendarServerLabel => 'servidor de calendario';

  @override
  String get printPreviewOpened =>
      'Vista previa abierta en el visor de PDF: imprima desde allí.';

  @override
  String printNoPdfViewer(String path) {
    return 'No hay ningún programa para abrir archivos PDF. Archivo en $path';
  }

  @override
  String printNotPrepared(String message, String path) {
    return 'Impresión no preparada: $message ($path)';
  }

  @override
  String get defaultMessageFileName => 'mensaje';

  @override
  String get preparingPdf => 'Preparando el PDF…';

  @override
  String pdfNotCreated(String error) {
    return 'PDF no creado: $error';
  }

  @override
  String get printFrom => 'De:';

  @override
  String get printSent => 'Enviado:';

  @override
  String get printTo => 'Para:';

  @override
  String get printCc => 'CC:';

  @override
  String get printSubject => 'Asunto:';

  @override
  String get printImportance => 'Importancia:';

  @override
  String get printHigh => 'Alta';

  @override
  String get printLow => 'Baja';

  @override
  String get printAttachments => 'Datos adjuntos:';

  @override
  String get defaultAttachmentFileName => 'adjunto';

  @override
  String get coreExecutableNotFound =>
      'No se encuentra el ejecutable del core. Compílelo con \"cd core && dotnet build\" o indique su ruta en POSTINOVIP_CORE.';

  @override
  String coreCannotStart(String path, String error) {
    return 'No se puede iniciar el core ($path): $error';
  }

  @override
  String coreExitedAtStart(String code) {
    return 'El core se ha detenido durante el inicio (código $code).';
  }

  @override
  String coreNoAnswerAtStart(String seconds) {
    return 'El core no ha respondido en $seconds s.';
  }

  @override
  String coreNotAnsweringCorrectly(String error) {
    return 'El core no responde correctamente: $error';
  }

  @override
  String get startingCore => 'Iniciando el core…';

  @override
  String get coreLastLines => 'Últimas líneas del core:';

  @override
  String get macMenuAbout => 'Acerca de PostinoVip';

  @override
  String get macMenuOptions => 'Opciones…';

  @override
  String get macMenuServices => 'Servicios';

  @override
  String get macMenuHide => 'Ocultar PostinoVip';

  @override
  String get macMenuHideOthers => 'Ocultar otros';

  @override
  String get macMenuShowAll => 'Mostrar todo';

  @override
  String get macMenuQuit => 'Salir de PostinoVip';

  @override
  String get macMenuEdit => 'Edición';

  @override
  String get macMenuUndo => 'Deshacer';

  @override
  String get macMenuRedo => 'Rehacer';

  @override
  String get macMenuCut => 'Cortar';

  @override
  String get macMenuCopy => 'Copiar';

  @override
  String get macMenuPaste => 'Pegar';

  @override
  String get macMenuSelectAll => 'Seleccionar todo';

  @override
  String get macMenuWindow => 'Ventana';

  @override
  String get macMenuMinimize => 'Minimizar';

  @override
  String get macMenuZoom => 'Zoom';

  @override
  String get macMenuFullScreen => 'Pantalla completa';

  @override
  String get macMenuBringAllToFront => 'Traer todo al frente';

  @override
  String get macMenuShowRibbon => 'Cinta de opciones';

  @override
  String get macMenuZoomReset => 'Tamaño real';

  @override
  String get macMenuCloseWindow => 'Cerrar ventana';

  @override
  String get macMenuCalendarView => 'Vista de calendario';

  @override
  String get optionsShowRibbon => 'Mostrar la cinta de opciones';

  @override
  String get optionsShowRibbonHelp =>
      'En la ventana principal. Los comandos siguen en la barra de menús de arriba.';
}
