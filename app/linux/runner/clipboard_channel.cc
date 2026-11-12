#include "clipboard_channel.h"

#include <gtk/gtk.h>

#include <cstring>

// Metodi (codec standard):
//   getHtml   -> Uint8List con i byte di "text/html" così come li dà il programma di origine
//                (UTF-8 o UTF-16: li decodifica il codice Dart), null se negli appunti non c'è HTML;
//   getImage  -> Uint8List PNG dell'immagine negli appunti, null se non ce n'è;
//   copyImage (Uint8List, un'immagine in un formato che gdk-pixbuf conosce) -> null, mette l'immagine
//                negli appunti.
// Le letture sono asincrone (gtk_clipboard_request_*): la finestra non si blocca mentre il programma
// che possiede gli appunti risponde.

static GtkClipboard* system_clipboard() {
  return gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
}

static void respond(FlMethodCall* call, FlMethodResponse* response) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("Risposta sul canale clipboard non inviata: %s", error->message);
  }
}

static void respond_value(FlMethodCall* call, FlValue* value) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  respond(call, response);
}

static void html_received(GtkClipboard* clipboard, GtkSelectionData* data,
                          gpointer user_data) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(user_data);
  gint length = data == nullptr ? -1 : gtk_selection_data_get_length(data);
  if (length <= 0) {
    respond_value(call, nullptr);
    return;
  }
  g_autoptr(FlValue) bytes = fl_value_new_uint8_list(
      gtk_selection_data_get_data(data), static_cast<size_t>(length));
  respond_value(call, bytes);
}

static void image_received(GtkClipboard* clipboard, GdkPixbuf* pixbuf,
                           gpointer user_data) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(user_data);
  if (pixbuf == nullptr) {
    respond_value(call, nullptr);
    return;
  }
  gchar* buffer = nullptr;
  gsize size = 0;
  g_autoptr(GError) error = nullptr;
  if (!gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &size, "png", &error,
                                 nullptr)) {
    g_warning("Immagine degli appunti non convertita in PNG: %s",
              error->message);
    respond_value(call, nullptr);
    return;
  }
  g_autoptr(FlValue) bytes =
      fl_value_new_uint8_list(reinterpret_cast<const uint8_t*>(buffer), size);
  g_free(buffer);
  respond_value(call, bytes);
}

static void copy_image(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_UINT8_LIST) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("bad-args", "Serve un Uint8List", nullptr));
    respond(call, response);
    return;
  }
  g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new();
  g_autoptr(GError) error = nullptr;
  if (!gdk_pixbuf_loader_write(loader, fl_value_get_uint8_list(args),
                               fl_value_get_length(args), &error) ||
      !gdk_pixbuf_loader_close(loader, &error)) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("bad-image", error->message, nullptr));
    respond(call, response);
    return;
  }
  GdkPixbuf* pixbuf = gdk_pixbuf_loader_get_pixbuf(loader);  // del loader
  gtk_clipboard_set_image(system_clipboard(), pixbuf);
  respond_value(call, nullptr);
}

static void clipboard_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                                gpointer user_data) {
  const gchar* method = fl_method_call_get_name(call);
  if (strcmp(method, "getHtml") == 0) {
    // Il riferimento a call lo rilascia la funzione che riceve gli appunti.
    gtk_clipboard_request_contents(system_clipboard(),
                                   gdk_atom_intern_static_string("text/html"),
                                   html_received, g_object_ref(call));
  } else if (strcmp(method, "getImage") == 0) {
    gtk_clipboard_request_image(system_clipboard(), image_received,
                                g_object_ref(call));
  } else if (strcmp(method, "copyImage") == 0) {
    copy_image(call);
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    respond(call, response);
  }
}

FlMethodChannel* clipboard_channel_new(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, "com.dumm1969.postinovip/clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, clipboard_method_cb,
                                            nullptr, nullptr);
  return channel;
}
