import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var operatorAlertChannel: FlutterMethodChannel?
  private var operatorAlertPanel: NSPanel?
  private var operatorAlertDismissal: DispatchWorkItem?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1040, height: 760)

    RegisterGeneratedPlugins(registry: flutterViewController)
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

    super.awakeFromNib()
  }

  private func showOperatorAlert(
    title: String,
    message: String,
    durationMilliseconds: Int
  ) {
    operatorAlertDismissal?.cancel()
    operatorAlertPanel?.orderOut(nil)

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
      panel?.orderOut(nil)
      self.operatorAlertPanel = nil
    }
    operatorAlertDismissal = dismissal
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .milliseconds(durationMilliseconds),
      execute: dismissal
    )
  }
}
