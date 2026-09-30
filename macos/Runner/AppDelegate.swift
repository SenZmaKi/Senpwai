import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var terminationChannel: FlutterMethodChannel?
  private var windowReopenChannel: FlutterMethodChannel?
  private var isAwaitingTerminationDecision = false

  func setTerminationChannel(_ channel: FlutterMethodChannel) {
    terminationChannel = channel
  }

  func setWindowReopenChannel(_ channel: FlutterMethodChannel) {
    windowReopenChannel = channel
  }

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !isAwaitingTerminationDecision, let terminationChannel else {
      return .terminateCancel
    }
    isAwaitingTerminationDecision = true
    terminationChannel.invokeMethod("requestQuit", arguments: nil) { result in
      DispatchQueue.main.async {
        self.isAwaitingTerminationDecision = false
        NSApp.reply(toApplicationShouldTerminate: result as? Bool ?? false)
      }
    }
    return .terminateLater
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows _: Bool
  ) -> Bool {
    requestWindowRestore()
    return true
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    requestWindowRestore()
  }

  private func requestWindowRestore() {
    guard NSApp.activationPolicy() == .regular else { return }
    windowReopenChannel?.invokeMethod("restoreWindow", arguments: nil)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
