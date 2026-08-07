import Cocoa
import FlutterMacOS
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        guard let arguments = call.arguments as? [String: Any],
              let isEnabled = arguments["setEnabledValue"] as? Bool else {
          result(FlutterError(code: "invalid_arguments", message: "Expected a startup enabled value.", details: nil))
          return
        }
        LaunchAtLogin.isEnabled = isEnabled
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let terminationChannel = FlutterMethodChannel(
      name: "senpwai/app_termination", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.setTerminationChannel(terminationChannel)

    let windowReopenChannel = FlutterMethodChannel(
      name: "senpwai/window_reopen", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.setWindowReopenChannel(windowReopenChannel)

    FlutterMethodChannel(
      name: "senpwai/menu_bar_mode", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "setEnabled",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(NSApp.setActivationPolicy(enabled ? .accessory : .regular))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(
    _ place: NSWindow.OrderingMode,
    relativeTo otherWin: Int
  ) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
