import AppKit

private enum Limits {
    /// 祖先スクロール領域検索の最大深さ
    static let ancestorMaxDepth = 10
    /// スクロール可能要素収集の最大深さ
    static let collectMaxDepth = 20
    /// スクロール領域として認識する最小サイズ（ポイント）
    static let minScrollAreaSize: CGFloat = 100
}

enum ScrollTarget {
    private static let scrollableRoles: Set<String> = [
        "AXScrollArea", "AXTextArea", "AXList", "AXTable", "AXOutline"
    ]

    /// フォーカスアプリの AXFocusedUIElement からスクロール可能な祖先を探す
    /// 見つからなければ nil を返す（呼び出し元はターゲットなしスクロールにフォールバック）
    static func findScrollableElement(in app: AXUIElement) -> AXUIElement? {
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXFocusedUIElement" as CFString, &focusedRef) == .success,
              let focusedRef,
              let focused = AXAttributes.element(from: focusedRef) else { return nil }

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
        guard depth < Limits.ancestorMaxDepth else { return nil }
        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXParent" as CFString, &parentRef) == .success,
              let parentRef,
              let parent = AXAttributes.element(from: parentRef) else { return nil }
        if isScrollable(element: parent) { return parent }
        return findScrollableAncestor(of: parent, depth: depth + 1)
    }

    /// AXUIElement の中心点をスクリーン座標系（原点:左上）で返す
    /// CGEvent.location にそのまま使える（NSWindow座標変換は不要）
    static func centerPoint(of element: AXUIElement) -> CGPoint? {
        guard let frame = AXAttributes.frame(of: element) else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - 全スクロール領域列挙

    /// AX ツリーを走査し、スクロール可能な全領域を返す
    /// - AXWebArea を検出したら WebAreaSplitDetector に委譲してレイアウト分割を検出する
    /// - 通常のスクロール可能ロールはリーフ優先で収集する
    static func enumerateScrollableElements(root: AXUIElement) -> [ScrollAreaInfo] {
        var result: [ScrollAreaInfo] = []
        collectScrollable(element: root, into: &result, depth: 0)
        return result
    }

    private static func collectScrollable(
        element: AXUIElement,
        into result: inout [ScrollAreaInfo],
        depth: Int
    ) {
        guard depth < Limits.collectMaxDepth else { return }

        // AXWebArea: WebAreaSplitDetector に委譲してレイアウトベース分割を検出
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef) == .success,
           (roleRef as? String) == "AXWebArea",
           let f = AXAttributes.frame(of: element),
           f.width >= Limits.minScrollAreaSize,
           f.height >= Limits.minScrollAreaSize {
            let areas = WebAreaSplitDetector.detect(webArea: element, nextLabel: result.count + 1)
            result.append(contentsOf: areas)
            return
        }

        let frame = AXAttributes.frame(of: element)
        let selfIsScrollable = isScrollable(element: element)
            && frame.map {
                $0.width >= Limits.minScrollAreaSize && $0.height >= Limits.minScrollAreaSize
            } ?? false

        // 子を先に探索（リーフ優先）
        let countBefore = result.count
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectScrollable(element: child, into: &result, depth: depth + 1)
            }
        }
        let childrenAdded = result.count > countBefore

        if selfIsScrollable, let f = frame, !childrenAdded {
            let center = CGPoint(x: f.midX, y: f.midY)
            let label = String(result.count + 1)
            result.append(ScrollAreaInfo(frame: f, centerPoint: center, label: label))
        }
    }
}
