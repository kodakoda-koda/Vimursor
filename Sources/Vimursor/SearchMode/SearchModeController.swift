import AppKit

private enum SearchModeState {
    case inactive
    case active(elements: [SearchElementInfo], query: String, matched: [SearchElementInfo])
}

@MainActor
final class SearchModeController {
    private let axManager = AXManager()
    private var state: SearchModeState = .inactive
    private var isActive: Bool = false
    private var searchView: SearchView?
    private weak var overlayWindow: OverlayWindow?
    private weak var hotkeyManager: HotkeyManager?
    private var previousApp: NSRunningApplication?

    func activate(overlayWindow: OverlayWindow, hotkeyManager: HotkeyManager) {
        guard !isActive else { return }
        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return }
        self.previousApp = focusedApp
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        axManager.fetchSearchableElements(in: appElement) { [weak self] elements in
            guard !elements.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.startSearchMode(elements: elements, overlayWindow: overlayWindow, hotkeyManager: hotkeyManager)
            }
        }
    }

    private func startSearchMode(
        elements: [SearchElementInfo],
        overlayWindow: OverlayWindow,
        hotkeyManager: HotkeyManager
    ) {
        state = .active(elements: elements, query: "", matched: elements)
        isActive = true

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
        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags, _ in
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
        isActive = false
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.axManager.clickAt(frame: frame)
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
