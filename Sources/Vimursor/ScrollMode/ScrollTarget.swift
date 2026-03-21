import AppKit

enum ScrollTarget {
    private static let scrollableRoles: Set<String> = [
        "AXScrollArea", "AXWebArea", "AXTextArea", "AXList", "AXTable", "AXOutline"
    ]

    /// フォーカスアプリの AXFocusedUIElement からスクロール可能な祖先を探す
    /// 見つからなければ nil を返す（呼び出し元はターゲットなしスクロールにフォールバック）
    static func findScrollableElement(in app: AXUIElement) -> AXUIElement? {
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXFocusedUIElement" as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }
        let focused = focusedRef as! AXUIElement

        if isScrollable(element: focused) { return focused }
        return findScrollableAncestor(of: focused, depth: 0)
    }

    static func isScrollable(element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef) == .success,
              let role = roleRef as? String else { return false }
        return scrollableRoles.contains(role)
    }

    private static func findScrollableAncestor(of element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 10 else { return nil }
        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXParent" as CFString, &parentRef) == .success,
              let parentRef else { return nil }
        let parent = parentRef as! AXUIElement
        if isScrollable(element: parent) { return parent }
        return findScrollableAncestor(of: parent, depth: depth + 1)
    }

    /// AXUIElement の中心点をスクリーン座標系（原点:左上）で返す
    /// CGEvent.location にそのまま使える（NSWindow座標変換は不要）
    static func centerPoint(of element: AXUIElement) -> CGPoint? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        guard size.width > 0, size.height > 0 else { return nil }
        return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
    }

    // MARK: - 全スクロール領域列挙

    /// AX ツリーを走査し、スクロール可能な全領域を返す
    /// - スクロール可能ロールの要素を発見したら子への再帰を止める（ネスト重複防止）
    /// - minScrollAreaSize 未満の要素はスキップ（ツールバー内の小さな AXList 等を除外）
    static func enumerateScrollableElements(root: AXUIElement) -> [ScrollAreaInfo] {
        var result: [ScrollAreaInfo] = []
        collectScrollable(element: root, into: &result, depth: 0)
        return result
    }

    private static let minScrollAreaSize: CGFloat = 100

    private static func collectScrollable(
        element: AXUIElement,
        into result: inout [ScrollAreaInfo],
        depth: Int
    ) {
        guard depth < 20 else { return }

        if isScrollable(element: element),
           let f = axFrame(of: element),
           f.width >= minScrollAreaSize,
           f.height >= minScrollAreaSize {
            let center = CGPoint(x: f.midX, y: f.midY)
            let label = String(result.count + 1)
            result.append(ScrollAreaInfo(frame: f, centerPoint: center, label: label))
            return  // スクロール領域内には再帰しない（ネスト重複防止）
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }
        for child in children {
            collectScrollable(element: child, into: &result, depth: depth + 1)
        }
    }

    /// AX スクリーン座標系（原点:左上）での要素フレームを返す
    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }
}
