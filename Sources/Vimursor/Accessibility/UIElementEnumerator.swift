import AppKit

enum UIElementEnumerator {
    private static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXCheckBox", "AXRadioButton",
        "AXMenuItem", "AXPopUpButton", "AXTextField", "AXComboBox",
        "AXTab", "AXCell"
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
        guard depth < 20 else { return }  // 無限再帰防止

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

    private static func isClickable(element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        guard err == .success, let role = roleRef as? String else { return false }
        return clickableRoles.contains(role)
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
        guard depth < 20, result.count < 500 else { return }

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
