import AppKit
import CoreGraphics

// CGEventTap コールバックは非同期スレッドから呼ばれるため @unchecked Sendable を宣言し、
// スレッド安全性の責任をこのクラスが負う
final class HotkeyManager: @unchecked Sendable {
    var onHintModeActivated: (() -> Void)?
    var onSearchModeActivated: (() -> Void)?
    var onScrollModeActivated: (() -> Void)?
    var onCursorModeActivated: (() -> Void)?

    // CGEventTap スレッド（読み取り）とメインスレッド（書き込み）をまたぐため NSLock で保護
    private let handlerLock = NSLock()
    private var _keyEventHandler: ((CGKeyCode, CGEventFlags, String) -> Bool)?
    var keyEventHandler: ((CGKeyCode, CGEventFlags, String) -> Bool)? {
        get {
            handlerLock.lock()
            defer { handlerLock.unlock() }
            return _keyEventHandler
        }
        set {
            handlerLock.lock()
            defer { handlerLock.unlock() }
            _keyEventHandler = newValue
        }
    }

    private var eventTap: CFMachPort?

    func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("[HotkeyManager] CGEventTap の作成に失敗しました。アクセシビリティ権限を確認してください。")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        if let handler = keyEventHandler {
            // CGEvent から実際の入力文字を取得（Shift 状態を含む）
            // ハンドラ未設定時は不要なので遅延実行する
            let unicodeString = Self.extractUnicodeString(from: event)
            if handler(keyCode, flags, unicodeString) {
                return nil  // HintModeが消費
            }
        }

        // モード起動は KeyboardShortcuts.onKeyUp（Carbon ホットキー）側に委譲しており、
        // この CGEventTap は通常入力の監視/消費のみを担当するためパススルーで安全。
        return Unmanaged.passRetained(event)
    }

    /// CGEvent から unicode 文字列を取得するユーティリティ
    /// IME 通過前のキーコードレベルの文字を返す（Shift 状態は反映される）
    private static func extractUnicodeString(from event: CGEvent) -> String {
        var actualLength: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &actualLength,
            unicodeString: &chars
        )
        guard actualLength > 0 else { return "" }
        return String(utf16CodeUnits: Array(chars.prefix(actualLength)), count: actualLength)
    }
}

// MARK: - KeyEventHandling
extension HotkeyManager: KeyEventHandling {}
