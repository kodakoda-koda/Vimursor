import CoreGraphics
@testable import Vimursor

final class MockKeyEventHandling: KeyEventHandling {
    var keyEventHandler: ((CGKeyCode, CGEventFlags, String) -> Bool)?

    /// handler が nil でないか（active 状態の代替指標）
    var isHandlerSet: Bool { keyEventHandler != nil }

    /// キーイベントをシミュレートする（handler が設定されている場合）
    @discardableResult
    func simulateKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], char: String = "") -> Bool {
        keyEventHandler?(keyCode, flags, char) ?? false
    }
}
