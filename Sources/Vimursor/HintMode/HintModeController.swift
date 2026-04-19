import AppKit

private enum HintModeState {
    case inactive
    case fetching   // 要素取得中。この状態でも activate() を弾く
    case active(hints: [UIElementInfo], input: String)
    case restarting // クリック後〜再起動待ち。ESC のみ受付
}

private enum HintKeyCode {
    static let esc: CGKeyCode = 53
}

// CGEventTapスレッドからアクティブ状態だけを読めるよう分離
// すべてのUI操作はメインスレッドで実行する
@MainActor
final class HintModeController {
    private let elementFetcher: any ElementFetching
    private var state: HintModeState = .inactive
    private var hintView: HintView?
    private weak var overlayWindow: (any OverlayProviding)?
    private weak var hotkeyManager: (any KeyEventHandling)?
    private let settings: HintModeSettings

    static let reactivationDelay: TimeInterval = 0.3
    static let clickDelay: TimeInterval = 0.05
    private(set) var reactivationTask: Task<Void, Never>?

    init(settings: HintModeSettings, elementFetcher: any ElementFetching = AXManager()) {
        self.settings = settings
        self.elementFetcher = elementFetcher
    }

    func activate(overlayWindow: any OverlayProviding, hotkeyManager: any KeyEventHandling) {
        guard case .inactive = state else { return }  // fetching / active 中はスキップ
        state = .fetching                              // 同期的に状態変更（二重起動防止）

        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            state = .inactive
            return
        }
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        elementFetcher.fetchClickableElements(in: appElement) { [weak self] elements in
            Task { @MainActor [weak self] in
                guard let self,
                      let overlay = self.overlayWindow,
                      let hotkey = self.hotkeyManager else {
                    self?.state = .inactive
                    return
                }
                self.startHintMode(elements: elements, overlayWindow: overlay, hotkeyManager: hotkey)
            }
        }
    }

    private func startHintMode(
        elements: [AXElement],
        overlayWindow: any OverlayProviding,
        hotkeyManager: any KeyEventHandling
    ) {
        guard !elements.isEmpty else {
            state = .inactive  // 要素がなければ inactive に戻す
            return
        }

        let labels = LabelGenerator.generateLabels(count: elements.count)
        let hints = elementFetcher.buildUIElementInfos(elements: elements, labels: labels)

        state = .active(hints: hints, input: "")

        let view = HintView(frame: overlayWindow.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.update(hints: hints, inputPrefix: "")
        overlayWindow.contentView?.addSubview(view)
        hintView = view

        overlayWindow.show()

        // CGEventTapスレッドからキーを受け取り、メインスレッドで処理する
        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags, _ in
            guard let self else { return false }
            Task { @MainActor [weak self] in
                self?.handleKey(keyCode: keyCode, flags: flags)
            }
            return true  // アクティブ中はすべてのキーを消費
        }
    }

    func deactivate() {
        reactivationTask?.cancel()
        reactivationTask = nil
        state = .inactive
        hintView?.removeFromSuperview()
        hintView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        if case .restarting = state {
            if keyCode == HintKeyCode.esc { deactivate() }  // ESC のみ受付
            return  // 他のキーは消費して無視
        }

        guard case .active(let hints, let input) = state else { return }

        // ESC
        if keyCode == HintKeyCode.esc {
            deactivate()
            return
        }

        // 修飾キー付きは無視（Cmd+Tab等）
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }

        guard let char = KeyCodeMapping.charFromKeyCode(keyCode) else { return }

        let newInput = input + char
        let matches = hints.filter { $0.label.hasPrefix(newInput) }

        if matches.isEmpty {
            deactivate()
            return
        }

        if let exact = matches.first(where: { $0.label == newInput }) {
            let frame = exact.frame
            if settings.isContinuousMode {
                enterRestartingState()
                Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(Self.clickDelay))
                    } catch is CancellationError {
                        return
                    }
                    guard let self else { return }
                    guard case .restarting = self.state else { return }  // ESCでdeactivateされていたら中断
                    self.elementFetcher.clickAt(frame: frame)
                    self.scheduleReactivation()
                }
            } else {
                // 単発モード: オーバーレイ非表示後にクリック送信（連続モードの enterRestartingState と同等の順序）
                deactivate()
                Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(Self.clickDelay))
                    } catch is CancellationError {
                        return
                    }
                    self?.elementFetcher.clickAt(frame: frame)
                }
            }
            return
        }

        state = .active(hints: hints, input: newInput)
        hintView?.update(hints: hints, inputPrefix: newInput)
    }

    private func enterRestartingState() {
        state = .restarting
        hintView?.removeFromSuperview()
        hintView = nil
        overlayWindow?.hide()
        // keyEventHandler は維持（ホットキー誤発火防止 + ESC 受付）
    }

    private func scheduleReactivation() {
        reactivationTask = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(Self.reactivationDelay))
            } catch {
                return  // CancellationError（Task.sleepの唯一のエラー）
            }
            guard case .restarting = self.state else { return }
            self.reactivationTask = nil
            self.state = .inactive
            if let overlay = self.overlayWindow, let hotkey = self.hotkeyManager {
                self.activate(overlayWindow: overlay, hotkeyManager: hotkey)
            } else {
                self.hotkeyManager?.keyEventHandler = nil  // weak ref 解放時の孤立ハンドラ防止
            }
        }
    }


}
