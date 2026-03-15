import AppKit

private enum SearchModeState {
    case inactive
    case active(elements: [SearchElementInfo], query: String, matched: [SearchElementInfo])
}

final class SearchModeController: @unchecked Sendable {
    private let axManager = AXManager()
    private var state: SearchModeState = .inactive
    private var isActive: Bool = false
    private var searchView: SearchView?
    private weak var overlayWindow: OverlayWindow?
    private weak var hotkeyManager: HotkeyManager?

    func activate(overlayWindow: OverlayWindow, hotkeyManager: HotkeyManager) {
        guard !isActive else { return }
        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        axManager.fetchSearchableElements(in: appElement) { [weak self] elements in
            guard !elements.isEmpty else { return }
            self?.startSearchMode(elements: elements, overlayWindow: overlayWindow, hotkeyManager: hotkeyManager)
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
        overlayWindow.contentView?.addSubview(view)
        searchView = view

        overlayWindow.show()

        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags in
            guard let self, self.isActive else { return false }
            DispatchQueue.main.async { self.handleKey(keyCode: keyCode, flags: flags) }
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
    }

    static func filter(
        elements: [SearchElementInfo],
        query: String
    ) -> [SearchElementInfo] {
        guard !query.isEmpty else { return elements }
        let q = query.lowercased()
        return elements.filter { $0.searchableText.contains(q) }
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard case .active(let elements, let query, _) = state else { return }

        // ESC
        if keyCode == 53 { deactivate(); return }

        // Backspace
        if keyCode == 51 {
            let newQuery = String(query.dropLast())
            let matched = SearchModeController.filter(elements: elements, query: newQuery)
            state = .active(elements: elements, query: newQuery, matched: matched)
            searchView?.update(query: newQuery, matched: matched)
            return
        }

        // Enter / Space: 先頭マッチをクリック
        if keyCode == 36 || keyCode == 49 {
            guard case .active(_, _, let matched) = state, let first = matched.first else { return }
            let frame = first.frame
            deactivate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.axManager.clickAt(frame: frame)
            }
            return
        }

        // 修飾キー付きは無視
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }
        guard let char = keyCodeToChar(keyCode) else { return }

        let newQuery = query + char
        let matched = SearchModeController.filter(elements: elements, query: newQuery)
        state = .active(elements: elements, query: newQuery, matched: matched)
        searchView?.update(query: newQuery, matched: matched)
    }

    private func keyCodeToChar(_ keyCode: CGKeyCode) -> String? {
        let map: [CGKeyCode: String] = [
            0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
            3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
            40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
            35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
            32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4",
            23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        ]
        return map[keyCode]
    }
}
