import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Canale della finestra, lo stesso di Linux (linux/runner/my_application.cc) e Windows
  /// (windows/runner/flutter_window.cpp) per «present» (clic sulla notifica di nuova posta); solo sul Mac anche i
  /// comandi della barra dei menu (lib/ui/mac_menu_bar.dart, M2a).
  private var windowChannel: FlutterMethodChannel?

  /// La voce «Services» del MainMenu.xib, presa prima che Flutter sostituisca il menu: Flutter ne fa una copia a
  /// ogni aggiornamento della barra, quindi il titolo nella lingua dell'app va scritto qui (e nella copia attuale).
  private var servicesItem: NSMenuItem?

  override func awakeFromNib() {
    // Le prese del nib (menu principale e NSApp.servicesMenu) sono già collegate quando arriva awakeFromNib.
    servicesItem = NSApp.mainMenu?.items.first?.submenu?.items.first {
      $0.submenu != nil && $0.submenu === NSApp.servicesMenu
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Come su Linux e Windows: titolo e dimensione minima 640×480 (sotto, l'interfaccia trabocca).
    self.title = "PostinoVip"
    self.contentMinSize = NSSize(width: 640, height: 480)

    let channel = FlutterMethodChannel(
      name: "com.dumm1969.postinovip/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let window = self else {
        result(FlutterError(code: "no-window", message: "finestra non disponibile", details: nil))
        return
      }
      switch call.method {
      case "present":
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result("foreground")
      // Barra dei menu del Mac: le voci che Flutter darebbe in inglese, qui nella lingua dell'app.
      case "hide": NSApp.hide(nil); result(nil)
      case "hideOthers": NSApp.hideOtherApplications(nil); result(nil)
      case "showAll": NSApp.unhideAllApplications(nil); result(nil)
      case "quit": NSApp.terminate(nil); result(nil)
      case "minimize": window.performMiniaturize(nil); result(nil)
      case "zoom": window.performZoom(nil); result(nil)
      case "fullScreen": window.toggleFullScreen(nil); result(nil)
      case "bringAllToFront": NSApp.arrangeInFront(nil); result(nil)
      case "servicesTitle":
        guard let title = call.arguments as? String else {
          result(FlutterError(code: "bad-args", message: "titolo mancante", details: nil))
          return
        }
        window.servicesItem?.title = title
        // Copia già nella barra (Flutter la mette nel primo menu: è l'unica voce lì con un sottomenu).
        NSApp.mainMenu?.items.first?.submenu?.items.first { $0.submenu != nil }?.title = title
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
