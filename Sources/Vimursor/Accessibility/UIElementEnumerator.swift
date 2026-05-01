import AppKit

/// 検索モード用の要素データ（AX属性を1パスで取得済み）
struct SearchableElementData {
    let element: AXUIElement
    let title: String
    let label: String
    let description: String
    let role: String
}

private enum Limits {
    /// クリック可能要素探索の最大深さ（無限再帰防止）
    static let clickableMaxDepth = 25
    /// 検索可能要素探索の最大深さ
    static let searchableMaxDepth = 30
    /// 検索可能要素の最大取得数（メモリ保護）
    static let searchableMaxCount = 3000
}

enum UIElementEnumerator {
    private static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXCheckBox", "AXRadioButton",
        "AXMenuItem", "AXPopUpButton", "AXComboBox", "AXTab",
        "AXMenuBarItem", "AXTextField",
        // AXTextArea は ScrollTarget.scrollableRoles にも含まれる
        // （クリックでフォーカス、スクロールモードではスクロール対象として二重登録）
        "AXTextArea",
        "AXMenuButton"
    ]

    // これらのロールはクリック不能と確定 → AXPress チェックをスキップして高速化
    private static let skippableRoles: Set<String> = [
        "AXStaticText", "AXImage", "AXSeparator", "AXScrollBar",
        "AXScrollArea", "AXSplitter", "AXToolbar", "AXStatusBar",
        "AXTable", "AXOutline", "AXList", "AXBrowser"
    ]

    static func enumerateClickableElements(root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        collectClickable(element: root, into: &result, depth: 0)
        return result
    }

    private static func collectClickable(
        element: AXUIElement,
        into result: inout [AXUIElement],
        depth: Int
    ) {
        guard depth < Limits.clickableMaxDepth else { return }

        if isClickable(element: element) {
            result.append(element)
        }

        // AXVisibleChildren を優先し、未サポートなら AXChildren にフォールバック
        var childrenRef: CFTypeRef?
        let children: [AXUIElement]
        if AXUIElementCopyAttributeValue(element, "AXVisibleChildren" as CFString, &childrenRef) == .success,
           let visChildren = childrenRef as? [AXUIElement] {
            children = visChildren
        } else {
            var fallbackRef: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &fallbackRef)
            guard err == .success, let allChildren = fallbackRef as? [AXUIElement] else { return }
            children = allChildren
        }

        for child in children {
            collectClickable(element: child, into: &result, depth: depth + 1)
        }
    }

    // AXRole + AXEnabled をバッチ取得して IPC を削減
    private static func isClickable(element: AXUIElement) -> Bool {
        // 1 IPC で AXRole + AXEnabled を同時取得
        var valuesRef: CFArray?
        // continueOnError 指定により未サポート属性は NSNull として返されるため、
        // attrs.count == 2 は通常保証される。
        // API 呼び出し自体が失敗した場合（要素無効化等）はクリック不能として扱う。
        guard AXUIElementCopyMultipleAttributeValues(
            element,
            ["AXRole", "AXEnabled"] as CFArray,
            AXAttributes.continueOnError,
            &valuesRef
        ) == .success, let attrs = valuesRef as? [Any], attrs.count == 2 else {
            return false
        }

        let role = (attrs[0] as? String) ?? ""
        // AXEnabled が未サポート(NSNull)ならデフォルト true
        let enabled = (attrs[1] as? Bool) ?? true

        if skippableRoles.contains(role) {
            return false
        }
        if clickableRoles.contains(role) {
            return enabled
        }

        // 不明ロール: enabled + AXPress チェック
        guard enabled else { return false }
        var actionsRef: CFArray?
        guard AXUIElementCopyActionNames(element, &actionsRef) == .success,
              let actions = actionsRef as? [String] else { return false }
        return actions.contains("AXPress")
    }

    /// 指定ロールが clickableRoles に含まれるかを返す。
    /// テストからの検証用に公開。プロダクションコードでは使用しないこと。
    static func isClickableRole(_ role: String) -> Bool {
        clickableRoles.contains(role)
    }

    /// 指定ロールが skippableRoles に含まれるかを返す。
    /// テストからの検証用に公開。プロダクションコードでは使用しないこと。
    static func isSkippableRole(_ role: String) -> Bool {
        skippableRoles.contains(role)
    }

    /// テキスト属性のうち、空白のみでない値が1つでもあるかを判定する。
    /// テストからの検証用に公開。プロダクションコードでは使用しないこと。
    static func hasNonEmptyText(title: String, label: String, description: String) -> Bool {
        [title, label, description].contains { !$0.isEmpty && $0.contains { !$0.isWhitespace } }
    }

    static func enumerateSearchableElements(root: AXUIElement) -> [SearchableElementData] {
        var result: [SearchableElementData] = []
        collectVisible(element: root, into: &result, depth: 0)
        return result
    }

    private static func collectVisible(
        element: AXUIElement,
        into result: inout [SearchableElementData],
        depth: Int
    ) {
        guard depth < Limits.searchableMaxDepth, result.count < Limits.searchableMaxCount else { return }

        var hiddenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXHidden" as CFString, &hiddenRef) == .success,
           let hidden = hiddenRef as? Bool, hidden {
            return
        }

        // AXTitle, AXLabel, AXDescription, AXRole を 1 IPC でバッチ取得
        var valuesRef: CFArray?
        if AXUIElementCopyMultipleAttributeValues(
            element,
            ["AXTitle", "AXLabel", "AXDescription", "AXRole"] as CFArray,
            AXAttributes.continueOnError,
            &valuesRef
        ) == .success, let attrs = valuesRef as? [Any], attrs.count == 4 {
            let title = (attrs[0] as? String) ?? ""
            let label = (attrs[1] as? String) ?? ""
            let desc  = (attrs[2] as? String) ?? ""
            let role  = (attrs[3] as? String) ?? ""

            if hasNonEmptyText(title: title, label: label, description: desc) {
                result.append(SearchableElementData(
                    element: element, title: title, label: label, description: desc, role: role
                ))
            }
        }

        // AXVisibleChildren を優先、未サポートなら AXChildren にフォールバック
        var childrenRef: CFTypeRef?
        let children: [AXUIElement]
        if AXUIElementCopyAttributeValue(element, "AXVisibleChildren" as CFString, &childrenRef) == .success,
           let visChildren = childrenRef as? [AXUIElement] {
            children = visChildren
        } else {
            var fallbackRef: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &fallbackRef)
            guard err == .success, let allChildren = fallbackRef as? [AXUIElement] else { return }
            children = allChildren
        }

        for child in children {
            collectVisible(element: child, into: &result, depth: depth + 1)
        }
    }
}
