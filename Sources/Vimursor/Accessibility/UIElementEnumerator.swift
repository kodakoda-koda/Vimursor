import AppKit

enum UIElementEnumerator {
    private static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXCheckBox", "AXRadioButton",
        "AXMenuItem", "AXPopUpButton", "AXComboBox", "AXTab"
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
        guard depth < 25 else { return }  // 無限再帰防止

        if isClickable(element: element) {
            result.append(element)
        }

        var childrenRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        guard err == .success, let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            collectClickable(element: child, into: &result, depth: depth + 1)
        }
    }

    // ロール先頭チェックで IPC 呼び出し数を最小化
    // skip-list → 1 IPC、clickableRoles → 2 IPC、不明ロール → 3 IPC（Electron 対応）
    private static func isClickable(element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            if skippableRoles.contains(role) { return false }
            if clickableRoles.contains(role) { return isEnabled(element: element) }
        }
        guard isEnabled(element: element) else { return false }
        var actionsRef: CFArray?
        guard AXUIElementCopyActionNames(element, &actionsRef) == .success,
              let actions = actionsRef as? [String] else { return false }
        return actions.contains("AXPress")
    }

    // AXEnabled = false の要素はクリック不能なのでスキップ（属性なければ有効とみなす）
    private static func isEnabled(element: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXEnabled" as CFString, &ref) == .success,
              let enabled = ref as? Bool else { return true }
        return enabled
    }

    static func enumerateSearchableElements(root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        collectVisible(element: root, into: &result, depth: 0)
        return result
    }

    private static func collectVisible(
        element: AXUIElement,
        into result: inout [AXUIElement],
        depth: Int
    ) {
        guard depth < 30, result.count < 3000 else { return }

        var hiddenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXHidden" as CFString, &hiddenRef) == .success,
           let hidden = hiddenRef as? Bool, hidden { return }

        let searchKeys = ["AXTitle", "AXLabel", "AXDescription"]
        let hasText = searchKeys.contains { key in
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, key as CFString, &ref) == .success,
                  let s = ref as? String else { return false }
            return !s.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if hasText { result.append(element) }

        var childrenRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        guard err == .success, let children = childrenRef as? [AXUIElement] else { return }
        for child in children {
            collectVisible(element: child, into: &result, depth: depth + 1)
        }
    }
}
