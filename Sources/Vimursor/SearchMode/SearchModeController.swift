import AppKit

// MARK: - キーコード定数

private enum SearchKeyCode {
    /// ESC キー
    static let escape: CGKeyCode = 53
}

// MARK: - 状態

private enum SearchModeState {
    case inactive
    case fetching  // 要素取得中（二重起動防止）
    case searching(elements: [SearchElementInfo], query: String, matched: [SearchElementInfo])
    case selecting(
        elements: [SearchElementInfo],
        query: String,
        matched: [SearchElementInfo],
        labels: [String],
        input: String
    )
}

@MainActor
final class SearchModeController {
    private let elementFetcher: any ElementFetching
    private var state: SearchModeState = .inactive
    private var searchView: SearchView?
    private weak var overlayWindow: (any OverlayProviding)?
    private weak var hotkeyManager: (any KeyEventHandling)?
    private var previousApp: NSRunningApplication?

    init(elementFetcher: any ElementFetching = AXManager()) {
        self.elementFetcher = elementFetcher
    }

    func activate(overlayWindow: any OverlayProviding, hotkeyManager: any KeyEventHandling) {
        guard case .inactive = state else { return }
        state = .fetching  // 同期的に状態変更（二重起動防止）

        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            state = .inactive
            return
        }
        self.previousApp = focusedApp
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        elementFetcher.fetchSearchableElements(in: appElement) { [weak self] elements in
            Task { @MainActor [weak self] in
                guard let self,
                      let overlay = self.overlayWindow,
                      let hotkey = self.hotkeyManager else {
                    self?.state = .inactive
                    return
                }
                self.startSearchMode(elements: elements, overlayWindow: overlay, hotkeyManager: hotkey)
            }
        }
    }

    private func startSearchMode(
        elements: [SearchElementInfo],
        overlayWindow: any OverlayProviding,
        hotkeyManager: any KeyEventHandling
    ) {
        guard case .fetching = state else { return }
        guard !elements.isEmpty else {
            state = .inactive  // 要素がなければ inactive に戻す
            return
        }
        state = .searching(elements: elements, query: "", matched: elements)

        let view = SearchView(frame: overlayWindow.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.update(query: "", matched: elements)

        // テキスト変更のコールバック登録
        view.onQueryChanged = { [weak self] newQuery in
            Task { @MainActor [weak self] in
                self?.applyQuery(newQuery)
            }
        }

        // Enter 処理は NSTextField デリゲートに委譲（IME 変換確定 Enter との区別のため）
        view.onEnterPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.executeSearch()
            }
        }

        overlayWindow.contentView?.addSubview(view)
        searchView = view

        // key window として表示し、NSTextField を first responder に
        overlayWindow.showAsKeyWindow()
        NSApp.activate(ignoringOtherApps: true)
        view.focusSearchField()

        // CGEventTap は ESC のみ処理（Enter は NSTextField デリゲートで処理）
        setSearchingKeyHandler()
    }

    func deactivate() {
        state = .inactive
        searchView?.removeFromSuperview()
        searchView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
        previousApp?.activate(options: [])
        previousApp = nil
    }

    nonisolated static func filter(
        elements: [SearchElementInfo],
        query: String
    ) -> [SearchElementInfo] {
        guard !query.isEmpty else { return elements }
        let q = query.lowercased()
        return elements.filter { $0.searchableText.contains(q) }
    }

    // MARK: - キーハンドラ設定

    /// searching 状態用: ESC のみ処理するハンドラを設定する
    private func setSearchingKeyHandler() {
        hotkeyManager?.keyEventHandler = { [weak self] keyCode, _, _ in
            guard let self else { return false }
            guard keyCode == SearchKeyCode.escape else { return false }
            Task { @MainActor [weak self] in
                self?.deactivate()
            }
            return true
        }
    }

    /// selecting 状態用: 全キーを消費して handleSelectingKey に渡すハンドラを設定する
    private func setSelectingKeyHandler() {
        hotkeyManager?.keyEventHandler = { [weak self] keyCode, flags, char in
            guard let self else { return false }
            Task { @MainActor [weak self] in
                self?.handleSelectingKey(keyCode: keyCode, flags: flags, char: char)
            }
            return true
        }
    }

    // MARK: - executeSearch

    /// Enter 確定時の処理（NSTextField デリゲート経由で呼ばれる）
    private func executeSearch() {
        guard case .searching(let elements, let query, let matched) = state else { return }

        switch matched.count {
        case 0:
            // マッチなし: 何もしない
            break
        case 1:
            // マッチ1件: 即クリック
            let frame = matched[0].frame
            deactivate()
            Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(0.05))
                } catch is CancellationError {
                    return
                }
                self?.elementFetcher.clickAt(frame: frame)
            }
        default:
            // マッチ2件以上: selecting 状態に遷移
            let labels = LabelGenerator.generateLabels(count: matched.count)
            state = .selecting(
                elements: elements,
                query: query,
                matched: matched,
                labels: labels,
                input: ""
            )
            setSelectingKeyHandler()
        }
    }

    // MARK: - handleSelectingKey

    /// selecting 状態でのキーイベント処理
    private func handleSelectingKey(keyCode: CGKeyCode, flags: CGEventFlags, char: String) {
        guard case .selecting(let elements, let query, let matched, let labels, let input) = state else { return }

        if keyCode == SearchKeyCode.escape {
            // ESC → searching に戻る（クエリ維持）
            state = .searching(elements: elements, query: query, matched: matched)
            setSearchingKeyHandler()
            return
        }

        // ラベル文字入力: KeyCodeMapping 経由でアルファベット文字を取得
        guard let char = KeyCodeMapping.charFromKeyCode(keyCode) else { return }

        let newInput = input + char
        let filtered = zip(labels, matched).filter { label, _ in
            label.hasPrefix(newInput)
        }

        if filtered.isEmpty {
            // マッチなし → deactivate
            deactivate()
            return
        }

        // 完全一致チェック
        if let exactMatch = filtered.first(where: { label, _ in label == newInput }) {
            let frame = exactMatch.1.frame
            deactivate()
            Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(0.05))
                } catch is CancellationError {
                    return
                }
                self?.elementFetcher.clickAt(frame: frame)
            }
            return
        }

        // prefix マッチが残っている → input を更新
        state = .selecting(
            elements: elements,
            query: query,
            matched: matched,
            labels: labels,
            input: newInput
        )
    }

    // MARK: - applyQuery

    /// NSTextField からのクエリ更新（IME 確定後の文字列を受け取る）
    private func applyQuery(_ query: String) {
        guard case .searching(let elements, _, _) = state else { return }
        let matched = SearchModeController.filter(elements: elements, query: query)
        state = .searching(elements: elements, query: query, matched: matched)
        searchView?.update(query: query, matched: matched)
    }
}
