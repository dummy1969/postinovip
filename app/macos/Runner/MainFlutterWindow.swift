import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Canale del primo piano (clic sulla notifica di nuova posta), lo stesso di Linux
  /// (linux/runner/my_application.cc) e Windows (windows/runner/flutter_window.cpp).
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
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
      guard call.method == "present" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let window = self else {
        result(FlutterError(code: "no-window", message: "finestra non disponibile", details: nil))
        return
      }
      if window.isMiniaturized { window.deminiaturize(nil) }
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      result("foreground")
    }
    windowChannel = channel

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
