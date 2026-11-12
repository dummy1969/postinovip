#ifndef RUNNER_CLIPBOARD_CHANNEL_H_
#define RUNNER_CLIPBOARD_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

// Canale "com.dumm1969.postinovip/clipboard": appunti di sistema per l'editor della composizione
// (HTML e immagini), con le funzioni di GTK al posto dello xclip incluso da quill_native_bridge_linux.
// Funziona sia con X11 sia con Wayland. Restituisce il canale (da liberare con g_object_unref).
FlMethodChannel* clipboard_channel_new(FlBinaryMessenger* messenger);

#endif  // RUNNER_CLIPBOARD_CHANNEL_H_
