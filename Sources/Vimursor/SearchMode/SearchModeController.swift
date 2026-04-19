import AppKit

private enum SearchModeState {
    case inactive
    case fetching  // 要素取得中（二重起動防止）
    case active(elements: [SearchElementInfo], query: String, matched: [SearchElementInfo])
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
        state = .active(elements: elements, query: "", matched: elements)

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
        hotkeyManager.keyEventHandler = { [weak self] keyCode, _, _ in
            guard let self else { return false }
            // ESC (53) のみ消費
            guard keyCode == 53 else { return false }
            Task { @MainActor [weak self] in
                self?.deactivate()
            }
            return true
        }
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

    /// Enter 確定時に先頭マッチをクリックする（NSTextField デリゲート経由で呼ばれる）
    private func executeSearch() {
        guard case .active(_, _, let matched) = state, let first = matched.first else { return }
        let frame = first.frame
        deactivate()
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(0.05))
            } catch is CancellationError {
                return
            }
            self?.elementFetcher.clickAt(frame: frame)
        }
    }

    /// NSTextField からのクエリ更新（IME 確定後の文字列を受け取る）
    private func applyQuery(_ query: String) {
        guard case .active(let elements, _, _) = state else { return }
        let matched = SearchModeController.filter(elements: elements, query: query)
        state = .active(elements: elements, query: query, matched: matched)
        searchView?.update(query: query, matched: matched)
    }
}
