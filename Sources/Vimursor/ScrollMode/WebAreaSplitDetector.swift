import AppKit

/// AXWebArea 子ツリーのフレーム情報を保持する値型。
/// AXUIElement 依存を分離することで `findSplitFrames` を純粋関数としてテスト可能にする。
struct ChildInfo {
    let frame: CGRect
    let children: [ChildInfo]
}

/// AXWebArea の子ツリーを走査してレイアウトベースの分割を検出する。
/// Notion・Slack・GitHub のサイドバー/メイン分割を統一的に扱う。
enum WebAreaSplitDetector {

    // MARK: - Constants

    /// 再帰の最大深さ（ラッパーを透過する上限）
    static let maxDepth = 10
    /// スクロール領域として認識する最小サイズ（ポイント）
    static let minChildSize: CGFloat = 100
    /// この比率以上の幅を持つ子はラッパーとみなす（親幅に対する割合）
    static let wrapperWidthRatio: CGFloat = 0.9

    // MARK: - Public API

    /// AXWebArea から ScrollAreaInfo のリストを返す。
    /// 分割が検出されれば複数の ScrollAreaInfo を、検出されなければ webArea 全体を1つとして返す。
    static func detect(webArea: AXUIElement, nextLabel: Int) -> [ScrollAreaInfo] {
        guard let parentFrame = AXAttributes.frame(of: webArea),
              parentFrame.width >= minChildSize,
              parentFrame.height >= minChildSize else { return [] }

        let rootChildren = extractChildren(element: webArea, depth: 0)
        if let splitFrames = findSplitFrames(children: rootChildren, parentFrame: parentFrame, depth: 0) {
            return splitFrames.enumerated().map { i, f in
                ScrollAreaInfo(
                    frame: f,
                    centerPoint: CGPoint(x: f.midX, y: f.midY),
                    label: String(nextLabel + i)
                )
            }
        }

        // フォールバック: AXWebArea 全体を1領域として返す
        return [ScrollAreaInfo(
            frame: parentFrame,
            centerPoint: CGPoint(x: parentFrame.midX, y: parentFrame.midY),
            label: String(nextLabel)
        )]
    }

    // MARK: - Pure Logic (testable)

    /// ChildInfo のリストからレイアウト分割フレームを返す純粋関数。
    /// 分割が見つからない（または depth が maxDepth に達した）場合は nil を返す。
    static func findSplitFrames(
        children: [ChildInfo],
        parentFrame: CGRect,
        depth: Int
    ) -> [CGRect]? {
        guard depth < maxDepth else { return nil }

        // minChildSize 以上の子だけ対象にする
        let significant = children.filter {
            $0.frame.width >= minChildSize && $0.frame.height >= minChildSize
        }

        // parentFrame に対して幅が wrapperWidthRatio 未満の子だけを「分割候補」とする
        let nonWrappers = significant.filter {
            $0.frame.width < parentFrame.width * wrapperWidthRatio
        }

        if nonWrappers.count >= 2 {
            // 分割ポイント発見
            return nonWrappers.map { $0.frame }
        }

        // ラッパー（幅が wrapperWidthRatio 以上）の子を透過して再帰
        for child in significant where child.frame.width >= parentFrame.width * wrapperWidthRatio {
            if let result = findSplitFrames(
                children: child.children,
                parentFrame: parentFrame,
                depth: depth + 1
            ) {
                return result
            }
        }

        return nil
    }

    // MARK: - AX Tree Extraction

    /// すべての直接子を ChildInfo にマップする。
    /// AXGroup の場合のみ再帰してサブツリーを展開する（不要な AX コールを抑制）。
    private static func extractChildren(element: AXUIElement, depth: Int) -> [ChildInfo] {
        guard depth < maxDepth else { return [] }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef) == .success,
              let axChildren = childrenRef as? [AXUIElement] else { return [] }

        return axChildren.compactMap { child -> ChildInfo? in
            guard let frame = AXAttributes.frame(of: child) else { return nil }
            // AXGroup のみ再帰して子ツリーを展開する
            var roleRef: CFTypeRef?
            let isGroup = AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &roleRef) == .success
                && (roleRef as? String) == "AXGroup"
            let subChildren = isGroup ? extractChildren(element: child, depth: depth + 1) : []
            return ChildInfo(frame: frame, children: subChildren)
        }
    }
}
