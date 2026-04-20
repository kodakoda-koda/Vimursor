import AppKit

private enum Limits {
    /// 祖先スクロール領域検索の最大深さ
    static let ancestorMaxDepth = 10
    /// スクロール可能要素収集の最大深さ
    static let collectMaxDepth = 20
    /// 分割ポイント検出の最大深さ
    static let splitMaxDepth = 5
    /// スクロール領域として認識する最小サイズ（ポイント）
    static let minScrollAreaSize: CGFloat = 100
    /// ラッパー要素判定の幅閾値（親の何割以上か）
    static let wrapperWidthRatio: CGFloat = 0.9
}

enum ScrollTarget {
    private static let scrollableRoles: Set<String> = [
        "AXScrollArea", "AXWebArea", "AXTextArea", "AXList", "AXTable", "AXOutline"
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
    /// - スクロール可能ロールの要素を発見したら子への再帰を止める（ネスト重複防止）
    /// - minScrollAreaSize 未満の要素はスキップ（ツールバー内の小さな AXList 等を除外）
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

        let selfIsScrollable = isScrollable(element: element)
            && AXAttributes.frame(of: element).map {
                $0.width >= Limits.minScrollAreaSize && $0.height >= Limits.minScrollAreaSize
            } ?? false

        // 子を先に探索（自身がスクロール可能でも止めない）
        let countBefore = result.count
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectScrollable(element: child, into: &result, depth: depth + 1)
            }
        }
        let childrenAdded = result.count > countBefore

        if selfIsScrollable {
            if !childrenAdded, let f = AXAttributes.frame(of: element) {
                // リーフ: そのまま追加
                let center = CGPoint(x: f.midX, y: f.midY)
                let label = String(result.count + 1)
                result.append(ScrollAreaInfo(frame: f, centerPoint: center, label: label))
            } else if childrenAdded, let parentFrame = AXAttributes.frame(of: element) {
                // 補完検出: 子にスクロール領域があるが、カバーされていない分割領域も追加
                let addedAreas = Array(result[countBefore..<result.count])
                addComplementRegions(element: element, parentFrame: parentFrame, existingAreas: addedAreas, into: &result)
            }
        }
    }

    /// スクロール可能な親の中から分割ポイントを見つけ、
    /// 既存スクロール領域にカバーされていない子領域を追加する
    private static func addComplementRegions(
        element: AXUIElement,
        parentFrame: CGRect,
        existingAreas: [ScrollAreaInfo],
        into result: inout [ScrollAreaInfo]
    ) {
        let splitChildren = findSplitChildren(element: element, parentFrame: parentFrame, maxDepth: Limits.splitMaxDepth)
        guard splitChildren.count >= 2 else { return }

        for childFrame in splitChildren {
            // 既存のスクロール領域の centerPoint がこの子フレーム内に含まれるかチェック
            let containsExisting = existingAreas.contains { childFrame.contains($0.centerPoint) }
            if !containsExisting {
                let center = CGPoint(x: childFrame.midX, y: childFrame.midY)
                let label = String(result.count + 1)
                result.append(ScrollAreaInfo(frame: childFrame, centerPoint: center, label: label))
            }
        }
    }

    /// 親と同サイズのラッパーを飛ばしつつ、分割ポイント（複数の子が並ぶレベル）を探す
    /// 返すのは各子の CGRect（フレーム）のリスト
    private static func findSplitChildren(
        element: AXUIElement,
        parentFrame: CGRect,
        maxDepth: Int
    ) -> [CGRect] {
        guard maxDepth > 0 else { return [] }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return [] }

        // 子のうちサイズが十分なものだけ取得
        var significantChildren: [(element: AXUIElement, frame: CGRect)] = []
        for child in children {
            if let f = AXAttributes.frame(of: child),
               f.width >= Limits.minScrollAreaSize,
               f.height >= Limits.minScrollAreaSize {
                significantChildren.append((child, f))
            }
        }

        // 親と同サイズ（幅が wrapperWidthRatio 以上）の子はラッパーとみなしてスキップ
        let nonWrappers = significantChildren.filter { $0.frame.width < parentFrame.width * Limits.wrapperWidthRatio }

        if nonWrappers.count >= 2 {
            // 分割ポイント発見
            return nonWrappers.map { $0.frame }
        }

        // ラッパー（親と同サイズの子）がある場合、その中を再帰探索
        for (child, frame) in significantChildren where frame.width >= parentFrame.width * Limits.wrapperWidthRatio {
            let result = findSplitChildren(element: child, parentFrame: parentFrame, maxDepth: maxDepth - 1)
            if result.count >= 2 { return result }
        }

        return []
    }

}
