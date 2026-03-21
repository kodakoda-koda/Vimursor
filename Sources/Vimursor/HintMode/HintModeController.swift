import AppKit

private enum HintModeState {
    case inactive
    case fetching   // 要素取得中。この状態でも activate() を弾く
    case active(hints: [UIElementInfo], input: String)
}

// CGEventTapスレッドからアクティブ状態だけを読めるよう分離
// すべてのUI操作はメインスレッドで実行する
@MainActor
final class HintModeController {
    private let axManager = AXManager()
    private var state: HintModeState = .inactive
    private var hintView: HintView?
    private weak var overlayWindow: OverlayWindow?
    private weak var hotkeyManager: HotkeyManager?

    func activate(overlayWindow: OverlayWindow, hotkeyManager: HotkeyManager) {
        guard case .inactive = state else { return }  // fetching / active 中はスキップ
        state = .fetching                              // 同期的に状態変更（二重起動防止）

        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        axManager.fetchClickableElements(in: appElement) { [weak self] elements in
            Task { @MainActor [weak self] in
                self?.startHintMode(elements: elements, overlayWindow: overlayWindow, hotkeyManager: hotkeyManager)
            }
        }
    }

    private func startHintMode(
        elements: [AXElement],
        overlayWindow: OverlayWindow,
        hotkeyManager: HotkeyManager
    ) {
        guard !elements.isEmpty else {
            state = .inactive  // 要素がなければ inactive に戻す
            return
        }

        let labels = LabelGenerator.generateLabels(count: elements.count)
        let hints = axManager.buildUIElementInfos(elements: elements, labels: labels)

        state = .active(hints: hints, input: "")

        let view = HintView(frame: overlayWindow.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.update(hints: hints, inputPrefix: "")
        overlayWindow.contentView?.addSubview(view)
        hintView = view

        overlayWindow.show()

        // CGEventTapスレッドからキーを受け取り、メインスレッドで処理する
        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags in
            guard let self else { return false }
            Task { @MainActor [weak self] in
                self?.handleKey(keyCode: keyCode, flags: flags)
            }
            return true  // アクティブ中はすべてのキーを消費
        }
    }

    func deactivate() {
        state = .inactive
        hintView?.removeFromSuperview()
        hintView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard case .active(let hints, let input) = state else { return }

        // ESC
        if keyCode == 53 {
            deactivate()
            return
        }

        // 修飾キー付きは無視（Cmd+Tab等）
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }

        guard let char = keyCodeToChar(keyCode) else { return }

        let newInput = input + char
        let matches = hints.filter { $0.label.hasPrefix(newInput) }

        if matches.isEmpty {
            deactivate()
            return
        }

        if let exact = matches.first(where: { $0.label == newInput }) {
            let frame = exact.frame
            let element = exact.axElement.ref
            deactivate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.axManager.press(element: element, frame: frame)
            }
            return
        }

        state = .active(hints: hints, input: newInput)
        hintView?.update(hints: hints, inputPrefix: newInput)
    }

    private func keyCodeToChar(_ keyCode: CGKeyCode) -> String? {
        // ホームポジション文字のキーコードマッピング
        let map: [CGKeyCode: String] = [
            0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
            3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
            40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
            35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
            32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z"
        ]
        return map[keyCode]
    }
}
