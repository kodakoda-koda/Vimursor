import AppKit
import Carbon.HIToolbox
@preconcurrency import KeyboardShortcuts

// MARK: - Key Codes

private enum KeyCode {
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51
    static let deleteForward: UInt16 = 117
}

// MARK: - ShortcutRecorderField

/// RecorderCocoa の衝突チェックを除去した独自キーボードショートカット入力フィールド。
/// Shift のみの修飾キーは無効。Shift 以外の修飾キーが必要。
@MainActor
final class ShortcutRecorderField: NSSearchField, NSSearchFieldDelegate {

    // MARK: - Constants

    private enum Placeholder {
        static let idle = "Click to record"
        static let recording = "Press Shortcut"
    }

    private let minimumWidth: CGFloat = 160

    // MARK: - State

    private let shortcutName: KeyboardShortcuts.Name
    private var eventMonitor: Any?
    private var shortcutChangeObserver: NSObjectProtocol?
    private var cancelButtonCell: NSButtonCell?

    // MARK: - Init

    init(for name: KeyboardShortcuts.Name) {
        self.shortcutName = name
        super.init(frame: .zero)
        delegate = self
        placeholderString = Placeholder.idle
        alignment = .center
        (cell as? NSSearchFieldCell)?.searchButtonCell = nil
        wantsLayer = true
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelButtonCell = (cell as? NSSearchFieldCell)?.cancelButtonCell
        refreshDisplay()
        setUpObserver()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = minimumWidth
        return size
    }

    // MARK: - Display Helpers

    /// nil ショートカットを空文字列に変換して返す（テスト可能な純粋関数）。
    nonisolated static func displayString(for shortcut: KeyboardShortcuts.Shortcut?) -> String {
        shortcut.map { "\($0)" } ?? ""
    }

    /// Shift のみの修飾キーは無効。Shift 以外が少なくとも 1 つ必要。
    nonisolated static func isValidModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.subtracting(.shift).isEmpty
    }

    // MARK: - Private Helpers

    private var showsCancelButton: Bool {
        get { (cell as? NSSearchFieldCell)?.cancelButtonCell != nil }
        set { (cell as? NSSearchFieldCell)?.cancelButtonCell = newValue ? cancelButtonCell : nil }
    }

    private func refreshDisplay() {
        let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName)
        stringValue = Self.displayString(for: shortcut)
        showsCancelButton = !stringValue.isEmpty
    }

    private func setUpObserver() {
        let notificationName = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
        shortcutChangeObserver = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name,
                name == self.shortcutName
            else { return }
            self.refreshDisplay()
        }
    }

    private func endRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        placeholderString = Placeholder.idle
        showsCancelButton = !stringValue.isEmpty
        // ショートカット監視を再開
        KeyboardShortcuts.isEnabled = true
    }

    private func saveShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: shortcutName)
    }

    private func clearShortcut() {
        saveShortcut(nil)
        stringValue = ""
        showsCancelButton = false
        window?.makeFirstResponder(nil)
    }

    // MARK: - First Responder

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }

        placeholderString = Placeholder.recording
        showsCancelButton = !stringValue.isEmpty
        // 録音中は誤ってショートカットが発火しないよう監視を一時停止
        KeyboardShortcuts.isEnabled = false

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }

        return true
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        endRecording()
        return result
    }

    // MARK: - Key Handling

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        // Escape: キャンセル
        if modifiers.isEmpty, event.keyCode == KeyCode.escape {
            window?.makeFirstResponder(nil)
            return nil
        }

        // Delete / Backspace: クリア
        if modifiers.isEmpty,
           event.keyCode == KeyCode.delete || event.keyCode == KeyCode.deleteForward {
            clearShortcut()
            return nil
        }

        // 修飾キー検証
        guard Self.isValidModifiers(modifiers),
              let shortcut = KeyboardShortcuts.Shortcut(event: event)
        else {
            NSSound.beep()
            return nil
        }

        // ショートカットを保存
        stringValue = Self.displayString(for: shortcut)
        showsCancelButton = true
        saveShortcut(shortcut)
        window?.makeFirstResponder(nil)
        return nil
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ object: Notification) {
        showsCancelButton = !stringValue.isEmpty
        if stringValue.isEmpty {
            saveShortcut(nil)
        }
    }

    func controlTextDidEndEditing(_ object: Notification) {
        endRecording()
    }
}
