@preconcurrency import KeyboardShortcuts

// MARK: - KeyboardShortcuts.Name definitions

extension KeyboardShortcuts.Name {
    // KeyboardShortcuts.Name が Sendable 非準拠のため暫定対応 (KeyboardShortcuts v1.x)
    // ライブラリ側が Sendable 準拠した場合は nonisolated(unsafe) と @preconcurrency を削除すること

    /// ヒントモード起動ショートカット（デフォルト: Cmd+Shift+Space）
    nonisolated(unsafe) static let hintMode = Self(
        "hintMode",
        default: .init(.space, modifiers: [.command, .shift])
    )

    /// 検索モード起動ショートカット（デフォルト: Cmd+Shift+/）
    nonisolated(unsafe) static let searchMode = Self(
        "searchMode",
        default: .init(.slash, modifiers: [.command, .shift])
    )

    /// スクロールモード起動ショートカット（デフォルト: Cmd+Shift+J）
    nonisolated(unsafe) static let scrollMode = Self(
        "scrollMode",
        default: .init(.j, modifiers: [.command, .shift])
    )

    /// カーソルモード起動ショートカット（デフォルト: Cmd+Shift+K）
    nonisolated(unsafe) static let cursorMode = Self(
        "cursorMode",
        default: .init(.k, modifiers: [.command, .shift])
    )
}
