import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tasti della piattaforma (tappa «Mac», M2a, scelta 2a): sul Mac ⌘ al posto di Ctrl, su Linux e Windows
/// invariati. Si guarda [defaultTargetPlatform] e non `Platform`: nei test (che girano come Android) restano
/// i tasti di Linux e Windows, e i test del Mac la cambiano con `debugDefaultTargetPlatformOverride`.
bool get usesCommandKey => defaultTargetPlatform == TargetPlatform.macOS;

/// Ctrl+[key] su Linux e Windows, ⌘[key] sul Mac.
SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false, bool alt = false}) =>
    SingleActivator(key, control: !usesCommandKey, meta: usesCommandKey, shift: shift, alt: alt);

/// Ctrl (Linux, Windows) o ⌘ (Mac) premuto: zoom con la rotella.
bool get isCommandPressed =>
    usesCommandKey ? HardwareKeyboard.instance.isMetaPressed : HardwareKeyboard.instance.isControlPressed;

/// Segna come letto / da leggere: Ctrl+Q e Ctrl+U come Outlook classico; sul Mac ⌘T e ⇧⌘T come Outlook per Mac
/// (⌘Q esce dall'app: i tasti arrivano prima all'app e poi ai menu, quindi non va mai preso).
SingleActivator get markReadKey => usesCommandKey ? cmd(LogicalKeyboardKey.keyT) : cmd(LogicalKeyboardKey.keyQ);
SingleActivator get markUnreadKey =>
    usesCommandKey ? cmd(LogicalKeyboardKey.keyT, shift: true) : cmd(LogicalKeyboardKey.keyU);

/// Elemento precedente / successivo nella finestra della mail: Ctrl+, e Ctrl+. come Outlook; sul Mac ⌘[ e ⌘]
/// (⌘, apre le Opzioni, come in tutte le app del Mac).
SingleActivator get previousItemKey =>
    usesCommandKey ? cmd(LogicalKeyboardKey.bracketLeft) : cmd(LogicalKeyboardKey.comma);
SingleActivator get nextItemKey =>
    usesCommandKey ? cmd(LogicalKeyboardKey.bracketRight) : cmd(LogicalKeyboardKey.period);

/// Archivia: Backspace come Outlook classico; sul Mac ⌃E come Outlook per Mac, perché lì il tasto ⌫ (che è
/// Backspace) elimina, come Canc sugli altri sistemi.
SingleActivator get archiveKey => usesCommandKey
    ? const SingleActivator(LogicalKeyboardKey.keyE, control: true)
    : const SingleActivator(LogicalKeyboardKey.backspace);

/// Sul Mac ⌫ elimina come Canc (la tastiera del Mac non ha Canc: c'è solo fn+⌫). Da aggiungere accanto alle
/// scorciatoie con Canc; vuoto altrove.
Map<ShortcutActivator, VoidCallback> macBackspaceDeletes(VoidCallback action) =>
    usesCommandKey ? {const SingleActivator(LogicalKeyboardKey.backspace): action} : const {};

final _ctrl = RegExp(
  r'(?:Ctrl|Strg)\+((?:Maiusc|Shift|Umschalt|Maj|Mayús)\+)?(Alt\+)?(F\d{1,2}|[A-Za-zÀ-ÿ]{2,}|.)',
);
final _delete = RegExp(r'\((?:Canc|Del|Supr|Suppr|Entf)\)');
final _backspace = RegExp(r'\((?:Backspace|Retroceso|Retour arrière|Rücktaste)\)');

/// Tasti scritti nei testi (suggerimenti, voci dei menu): le traduzioni dicono «Ctrl+Maiusc+V» e simili; sul Mac
/// diventano i simboli del Mac nell'ordine di Apple (⌥⇧⌘V), con i tasti cambiati come sopra. Altrove il testo
/// resta com'è.
String keyLabel(String text) {
  if (!usesCommandKey) return text;
  return text
      .replaceAllMapped(_ctrl, (m) {
        final key = switch (m[3]!) {
          ',' => '[',
          '.' => ']',
          final k when k.length > 2 && !k.startsWith('F') => ' + $k', // «Ctrl+rotella» → «⌘ + rotella»
          final k => k,
        };
        return '${m[2] != null ? '⌥' : ''}${m[1] != null ? '⇧' : ''}⌘$key';
      })
      .replaceAll(_delete, '(⌫)')
      .replaceAll(_backspace, '(⌃E)');
}
