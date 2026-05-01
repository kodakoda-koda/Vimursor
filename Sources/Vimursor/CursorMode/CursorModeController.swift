import AppKit

@MainActor
final class CursorModeController {
    private var isActive = false
    private var cursorView: CursorView?
    private weak var overlayWindow: (any OverlayProviding)?
    private weak var hotkeyManager: (any KeyEventHandling)?
    private let settings: AppSettings
    private var multiplierBuffer: String = ""

    init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    func activate(overlayWindow: any OverlayProviding, hotkeyManager: any KeyEventHandling) {
        guard !isActive else { return }
        isActive = true

        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        let view = CursorView(frame: overlayWindow.contentView?.bounds ?? .zero, settings: settings)
        view.autoresizingMask = [.width, .height]

        // Get current cursor position in NSView coordinates (origin: bottom-left)
        let mouseLocation = NSEvent.mouseLocation
        view.update(cursorPosition: mouseLocation)

        overlayWindow.contentView?.addSubview(view)
        cursorView = view

        overlayWindow.show()

        // Set key event handler
        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags, _ in
            guard let self else { return false }
            Task { @MainActor [weak self] in
                self?.handleKey(keyCode: keyCode, flags: flags)
            }
            return true  // consume all keys while active
        }
    }

    func deactivate() {
        isActive = false
        multiplierBuffer = ""
        cursorView?.removeFromSuperview()
        cursorView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard isActive else { return }

        // ESC → deactivate
        if keyCode == KeyCodeMapping.escapeKeyCode {
            deactivate()
            return
        }

        // Ignore modifier-only keys (Cmd+Tab etc.)
        guard flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) else { return }

        // Enter → click
        let returnKeyCode: CGKeyCode = 36
        if keyCode == returnKeyCode {
            let isRightClick = flags.contains(.maskShift)
            performClick(isRightClick: isRightClick)
            return
        }

        // Number keys → accumulate multiplier
        if let digit = digitFromKeyCode(keyCode) {
            multiplierBuffer += digit
            return
        }

        // Direction keys (hjkl)
        if let direction = directionFromKeyCode(keyCode) {
            let steps = Int(multiplierBuffer) ?? 1
            multiplierBuffer = ""
            performMove(direction: direction, steps: steps)
            return
        }

        // Unknown key → ignore (don't deactivate)
    }

    private func performMove(direction: CursorDirection, steps: Int) {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let mouseLocation = NSEvent.mouseLocation
        let currentScreenPoint = CursorEngine.screenPointFromMouseLocation(mouseLocation, screenHeight: screenHeight)
        let screenBounds = CGRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 1920, height: screenHeight)

        let newPoint = CursorEngine.moveCursor(
            from: currentScreenPoint,
            direction: direction,
            steps: steps,
            stepPixels: settings.cursorStepPixels,
            screenBounds: screenBounds
        )

        CursorEngine.applyMove(to: newPoint)

        // Update view with new cursor position (convert back to NSView coords)
        let newMouseLocation = CGPoint(x: newPoint.x, y: screenHeight - newPoint.y)
        cursorView?.update(cursorPosition: newMouseLocation)
    }

    private func performClick(isRightClick: Bool) {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let mouseLocation = NSEvent.mouseLocation
        let screenPoint = CursorEngine.screenPointFromMouseLocation(mouseLocation, screenHeight: screenHeight)

        deactivate()
        CursorEngine.click(at: screenPoint, isRightClick: isRightClick)
    }

    // MARK: - Key code helpers

    /// Parse multiplier from accumulated buffer.
    /// Exposed for testing.
    nonisolated static func parseMultiplier(_ buffer: String) -> Int {
        Int(buffer) ?? 1
    }

    private func directionFromKeyCode(_ keyCode: CGKeyCode) -> CursorDirection? {
        switch keyCode {
        case 4:  return .left   // h
        case 38: return .down   // j
        case 40: return .up     // k
        case 37: return .right  // l
        default: return nil
        }
    }

    private static let digitKeyCodeMap: [CGKeyCode: String] = [
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4",
        23: "5", 22: "6", 26: "7", 28: "8", 25: "9"
    ]

    private func digitFromKeyCode(_ keyCode: CGKeyCode) -> String? {
        Self.digitKeyCodeMap[keyCode]
    }
}
