import AppKit
import CoreGraphics

private enum KeyCode {
    static let space: CGKeyCode = 49
}

private enum ModifierFlags {
    static let cmdShift: CGEventFlags = [.maskCommand, .maskShift]
}

// CGEventTap コールバックは非同期スレッドから呼ばれるため @unchecked Sendable を宣言し、
// スレッド安全性の責任をこのクラスが負う
final class HotkeyManager: @unchecked Sendable {
    var onHintModeActivated: (() -> Void)?
    // HintMode中にキー入力を委譲するハンドラ（true=消費, false=通常処理）
    var keyEventHandler: ((CGKeyCode, CGEventFlags) -> Bool)?
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

        if let handler = keyEventHandler, handler(keyCode, flags) {
            return nil  // HintModeが消費
        }

        if keyCode == KeyCode.space && flags == ModifierFlags.cmdShift {
            DispatchQueue.main.async { [weak self] in
                self?.onHintModeActivated?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
