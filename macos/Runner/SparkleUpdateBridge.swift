import FlutterMacOS
import Sparkle

final class SparkleUpdateBridge: NSObject, FlutterStreamHandler, SPUUserDriver {
  private lazy var updater = SPUUpdater(
    hostBundle: .main,
    applicationBundle: .main,
    userDriver: self,
    delegate: nil
  )
  private var eventSink: FlutterEventSink?
  private var lastEvent: [String: Any]?
  private var automaticallyDownload = true
  private var downloadRequested = false
  private var updateReply: ((SPUUserUpdateChoice) -> Void)?
  private var readyReply: ((SPUUserUpdateChoice) -> Void)?
  private var cancelDownloadHandler: (() -> Void)?
  private var bytesReceived: UInt64 = 0
  private var totalBytes: UInt64 = 0
  private var currentItem: SUAppcastItem?

  func register(with messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(
      name: "senpwai/sparkle_updater",
      binaryMessenger: messenger
    )
    methods.setMethodCallHandler(handle)
    FlutterEventChannel(
      name: "senpwai/sparkle_update_events",
      binaryMessenger: messenger
    ).setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      automaticallyDownload = arguments?["automaticallyDownload"] as? Bool ?? true
      updater.automaticallyChecksForUpdates = true
      updater.automaticallyDownloadsUpdates = false
      do {
        try updater.start()
        result(nil)
      } catch {
        result(flutterError("start_failed", error.localizedDescription))
      }
    case "check":
      guard updater.canCheckForUpdates else {
        result(flutterError("check_in_progress", "An update check is already in progress."))
        return
      }
      updater.checkForUpdates()
      result(nil)
    case "download":
      if let reply = updateReply {
        updateReply = nil
        reply(.install)
      } else if updater.canCheckForUpdates {
        downloadRequested = true
        updater.checkForUpdates()
      } else {
        result(flutterError("update_unavailable", "No update is waiting to download."))
        return
      }
      result(nil)
    case "cancelDownload":
      cancelDownloadHandler?()
      cancelDownloadHandler = nil
      emit("available")
      result(nil)
    case "installAndRestart":
      guard let reply = readyReply else {
        result(flutterError("update_not_ready", "The update is not ready to install."))
        return
      }
      readyReply = nil
      reply(.install)
      result(nil)
    case "setAutomaticallyDownload":
      automaticallyDownload = arguments?["enabled"] as? Bool ?? true
      if automaticallyDownload, let reply = updateReply {
        updateReply = nil
        reply(.install)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emit(_ phase: String, extra: [String: Any] = [:]) {
    var event = extra
    event["phase"] = phase
    if let item = currentItem {
      event["version"] = item.displayVersionString
      event["build"] = item.versionString
      event["notes"] = item.itemDescription ?? ""
    }
    lastEvent = event
    eventSink?(event)
  }

  private func flutterError(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    if let lastEvent { events(lastEvent) }
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func show(
    _ request: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    reply(SUUpdatePermissionResponse(
      automaticUpdateChecks: true,
      automaticUpdateDownloading: false,
      sendSystemProfile: false
    ))
  }

  func showUserInitiatedUpdateCheck(cancellation _: @escaping () -> Void) {
    emit("checking")
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    currentItem = appcastItem
    guard !appcastItem.isInformationOnlyUpdate else {
      reply(.dismiss)
      emit("idle")
      return
    }
    switch state.stage {
    case .notDownloaded:
      emit("available")
      if automaticallyDownload || downloadRequested {
        downloadRequested = false
        reply(.install)
      } else {
        updateReply = reply
      }
    case .downloaded, .installing:
      reply(.install)
    @unknown default:
      reply(.dismiss)
    }
  }

  func showUpdateReleaseNotes(with _: SPUDownloadData) {}
  func showUpdateReleaseNotesFailedToDownloadWithError(_: Error) {}

  func showUpdateNotFoundWithError(_: Error, acknowledgement: @escaping () -> Void) {
    emit("idle")
    acknowledgement()
  }

  func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
    emit("failed", extra: ["error": error.localizedDescription])
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    cancelDownloadHandler = cancellation
    bytesReceived = 0
    totalBytes = 0
    emit("downloading", extra: ["bytesReceived": 0, "totalBytes": 0])
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    totalBytes = expectedContentLength
    emitProgress()
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    bytesReceived += length
    totalBytes = max(totalBytes, bytesReceived)
    emitProgress()
  }

  private func emitProgress() {
    emit("downloading", extra: [
      "bytesReceived": Int64(clamping: bytesReceived),
      "totalBytes": Int64(clamping: totalBytes),
    ])
  }

  func showDownloadDidStartExtractingUpdate() {
    cancelDownloadHandler = nil
    emit("verifying")
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    emit("preparing", extra: [
      "bytesReceived": Int64(progress * 1000),
      "totalBytes": 1000,
    ])
  }

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    readyReply = reply
    emit("ready", extra: ["bytesReceived": 1, "totalBytes": 1])
  }

  func showInstallingUpdate(
    withApplicationTerminated _: Bool,
    retryTerminatingApplication _: @escaping () -> Void
  ) {
    emit("installing")
  }

  func showUpdateInstalledAndRelaunched(_: Bool, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }

  func showUpdateInFocus() {}

  func dismissUpdateInstallation() {
    updateReply = nil
    readyReply = nil
    cancelDownloadHandler = nil
  }
}
