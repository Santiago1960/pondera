import Cocoa
import Carbon.HIToolbox
import FlutterMacOS
import IOKit

private let ponderaHotKeySignature: OSType = 0x504E4452 // PNDR
private let ponderaF12HotKeyIdentifier: UInt32 = 1
private let ponderaHotKeyHandler: EventHandlerUPP = { _, _, userData in
  guard let userData else {
    return OSStatus(eventNotHandledErr)
  }
  let window = Unmanaged<MainFlutterWindow>
    .fromOpaque(userData)
    .takeUnretainedValue()
  window.notifyF12Pressed()
  return noErr
}

class MainFlutterWindow: NSWindow {
  private var deviceFingerprintChannel: FlutterMethodChannel?
  private var operatorAlertChannel: FlutterMethodChannel?
  private var operatorAlertPanel: NSPanel?
  private var operatorAlertDismissal: DispatchWorkItem?
  private var weightCaptureHotkeyChannel: FlutterMethodChannel?
  private var f12HotKey: EventHotKeyRef?
  private var hotKeyEventHandler: EventHandlerRef?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1040, height: 760)

    RegisterGeneratedPlugins(registry: flutterViewController)
    deviceFingerprintChannel = FlutterMethodChannel(
      name: "bitgenial/device_fingerprint",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    deviceFingerprintChannel?.setMethodCallHandler { call, result in
      guard call.method == "readSystemId" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let systemId = readSystemIdentifier() else {
        result(
          FlutterError(
            code: "device_identity_unavailable",
            message: "macOS device identity is unavailable.",
            details: nil
          )
        )
        return
      }
      result(systemId)
    }
    operatorAlertChannel = FlutterMethodChannel(
      name: "pondera/operator_alert",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    operatorAlertChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let title = arguments["title"] as? String,
        let message = arguments["message"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected title and message strings.",
            details: nil
          )
        )
        return
      }

      let requestedDuration = arguments["durationMs"] as? Int ?? 4000
      self?.showOperatorAlert(
        title: title,
        message: message,
        durationMilliseconds: min(max(requestedDuration, 1500), 10000)
      )
      result(nil)
    }
    weightCaptureHotkeyChannel = FlutterMethodChannel(
      name: "pondera/weight_capture_hotkey",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    weightCaptureHotkeyChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled", let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }

      let status =
        self?.setF12HotKeyEnabled(enabled) ?? OSStatus(eventNotHandledErr)
      if status == noErr {
        result(nil)
      } else {
        result(
          FlutterError(
            code: "hotkey_registration_failed",
            message: "macOS could not \(enabled ? "register" : "unregister") F12.",
            details: Int(status)
          )
        )
      }
    }

    super.awakeFromNib()
  }

  override func close() {
    deviceFingerprintChannel?.setMethodCallHandler(nil)
    operatorAlertChannel?.setMethodCallHandler(nil)
    weightCaptureHotkeyChannel?.setMethodCallHandler(nil)
    dismissOperatorAlert()
    _ = setF12HotKeyEnabled(false)
    super.close()
  }

  deinit {
    operatorAlertDismissal?.cancel()
    operatorAlertPanel?.close()
    if let f12HotKey {
      UnregisterEventHotKey(f12HotKey)
    }
    if let hotKeyEventHandler {
      RemoveEventHandler(hotKeyEventHandler)
    }
  }

  fileprivate func notifyF12Pressed() {
    weightCaptureHotkeyChannel?.invokeMethod("pressed", arguments: nil)
  }

  private func setF12HotKeyEnabled(_ enabled: Bool) -> OSStatus {
    if !enabled {
      guard let f12HotKey else {
        return noErr
      }
      let status = UnregisterEventHotKey(f12HotKey)
      if status == noErr {
        self.f12HotKey = nil
      }
      return status
    }

    if f12HotKey != nil {
      return noErr
    }

    if hotKeyEventHandler == nil {
      var eventType = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed)
      )
      let handlerStatus = InstallEventHandler(
        GetApplicationEventTarget(),
        ponderaHotKeyHandler,
        1,
        &eventType,
        Unmanaged.passUnretained(self).toOpaque(),
        &hotKeyEventHandler
      )
      if handlerStatus != noErr {
        return handlerStatus
      }
    }

    var registeredHotKey: EventHotKeyRef?
    let hotKeyIdentifier = EventHotKeyID(
      signature: ponderaHotKeySignature,
      id: ponderaF12HotKeyIdentifier
    )
    let registrationStatus = RegisterEventHotKey(
      UInt32(kVK_F12),
      0,
      hotKeyIdentifier,
      GetApplicationEventTarget(),
      0,
      &registeredHotKey
    )
    if registrationStatus == noErr {
      f12HotKey = registeredHotKey
    }
    return registrationStatus
  }

  private func showOperatorAlert(
    title: String,
    message: String,
    durationMilliseconds: Int
  ) {
    dismissOperatorAlert()

    let panelSize = NSSize(width: 430, height: 112)
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.animationBehavior = .utilityWindow

    let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.systemRed.cgColor
    container.layer?.cornerRadius = 12

    let titleField = NSTextField(labelWithString: title)
    titleField.textColor = .white
    titleField.font = .systemFont(ofSize: 16, weight: .bold)

    let messageField = NSTextField(wrappingLabelWithString: message)
    messageField.textColor = .white
    messageField.font = .systemFont(ofSize: 13, weight: .medium)
    messageField.maximumNumberOfLines = 3

    let stack = NSStackView(views: [titleField, messageField])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 6
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
      stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    panel.contentView = container

    let mouseLocation = NSEvent.mouseLocation
    let targetScreen =
      NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
      ?? screen
      ?? NSScreen.main
    if let visibleFrame = targetScreen?.visibleFrame {
      panel.setFrameOrigin(
        NSPoint(
          x: visibleFrame.maxX - panelSize.width - 24,
          y: visibleFrame.maxY - panelSize.height - 24
        )
      )
    }

    operatorAlertPanel = panel
    panel.orderFrontRegardless()

    let dismissal = DispatchWorkItem { [weak self, weak panel] in
      guard let self, self.operatorAlertPanel === panel else {
        return
      }
      panel?.close()
      self.operatorAlertPanel = nil
      self.operatorAlertDismissal = nil
    }
    operatorAlertDismissal = dismissal
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .milliseconds(durationMilliseconds),
      execute: dismissal
    )
  }

  private func dismissOperatorAlert() {
    operatorAlertDismissal?.cancel()
    operatorAlertDismissal = nil
    operatorAlertPanel?.close()
    operatorAlertPanel = nil
  }
}

private func readSystemIdentifier() -> String? {
  let service = IOServiceGetMatchingService(
    kIOMasterPortDefault,
    IOServiceMatching("IOPlatformExpertDevice")
  )
  guard service != IO_OBJECT_NULL else {
    return nil
  }
  defer { IOObjectRelease(service) }

  return IORegistryEntryCreateCFProperty(
    service,
    "IOPlatformUUID" as CFString,
    kCFAllocatorDefault,
    0
  )?.takeRetainedValue() as? String
}
