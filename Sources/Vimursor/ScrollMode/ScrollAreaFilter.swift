import CoreGraphics

/// スクロール領域をウィンドウ可視領域でフィルタリングし、重複を除去する純粋関数群。
enum ScrollAreaFilter {

    struct FilteredArea {
        let frame: CGRect          // クリップ後のフレーム（スクリーン座標）
        let originalFrame: CGRect  // クリップ前のフレーム
        let originMoved: Bool      // クリップにより origin が移動したか
    }

    // MARK: - Constants

    /// クリップ後の面積が元の面積に対して持つべき最小比率
    private static let minVisibleAreaRatio: CGFloat = 0.5
    /// クリップ後の幅または高さの最小値（ポイント）
    private static let minDimensionPoints: CGFloat = 100
    /// 重複とみなすオーバーラップ比率の閾値
    private static let overlapThresholdRatio: CGFloat = 0.5
    /// デスクトップレベルの領域とみなす面積比率（ウィンドウ面積に対する倍率）
    private static let desktopAreaRatio: CGFloat = 1.5

    // MARK: - filterByWindow

    /// スクロール領域をウィンドウの可視領域でフィルタリングする。
    ///
    /// 除外条件:
    /// 1. 領域がウィンドウ全体を包含する（デスクトップレベルの領域）
    /// 2. ウィンドウとの交差がない
    /// 3. クリップ後の面積が元の面積の 50% 未満
    /// 4. クリップ後の幅または高さが 100pt 未満
    static func filterByWindow(
        areas: [CGRect],
        windowFrame: CGRect
    ) -> [FilteredArea] {
        areas.compactMap { areaFrame in
            // 1. デスクトップレベルの領域（ウィンドウより desktopAreaRatio 以上大きい）は除外
            // ウィンドウと同サイズの正当なスクロール領域（Chrome のメインページ等）は除外しない
            let areaSize = areaFrame.width * areaFrame.height
            let windowSize = windowFrame.width * windowFrame.height
            if areaFrame.contains(windowFrame), windowSize > 0, areaSize / windowSize > desktopAreaRatio { return nil }

            // 2. 交差がない場合は除外
            let intersection = areaFrame.intersection(windowFrame)
            if intersection.isNull { return nil }

            // 3. クリップ後の面積が元の面積の minVisibleAreaRatio 未満は除外
            let originalArea = areaFrame.width * areaFrame.height
            let clippedArea = intersection.width * intersection.height
            guard originalArea > 0, clippedArea / originalArea >= minVisibleAreaRatio else { return nil }

            // 4. クリップ後のサイズが最小サイズ未満は除外
            guard intersection.width >= minDimensionPoints,
                  intersection.height >= minDimensionPoints else { return nil }

            let originMoved = intersection.origin != areaFrame.origin
            return FilteredArea(
                frame: intersection,
                originalFrame: areaFrame,
                originMoved: originMoved
            )
        }
    }

    // MARK: - removeOverlaps

    /// 重複するスクロール領域を除去する。
    ///
    /// ペア (i, j) で 50% 超の重複がある場合:
    /// - どちらか一方のみ originMoved=true → その要素を除外（隠れている可能性が高い）
    /// - 両方とも同じ originMoved 値 → 小さい方を除外
    static func removeOverlaps(areas: [FilteredArea]) -> [FilteredArea] {
        var excluded = Set<Int>()

        for i in 0..<areas.count {
            for j in (i + 1)..<areas.count {
                guard !excluded.contains(i), !excluded.contains(j) else { continue }

                let a = areas[i]
                let b = areas[j]
                let intersection = a.frame.intersection(b.frame)
                if intersection.isNull { continue }

                let intersectionArea = intersection.width * intersection.height
                let areaA = a.frame.width * a.frame.height
                let areaB = b.frame.width * b.frame.height

                let overlapRatioA = areaA > 0 ? intersectionArea / areaA : 0
                let overlapRatioB = areaB > 0 ? intersectionArea / areaB : 0

                guard overlapRatioA >= overlapThresholdRatio || overlapRatioB >= overlapThresholdRatio else { continue }

                // どちらか一方のみ originMoved → originMoved を除外
                if a.originMoved && !b.originMoved {
                    excluded.insert(i)
                } else if !a.originMoved && b.originMoved {
                    excluded.insert(j)
                } else {
                    // 両方同じ originMoved → 小さい方を除外
                    if areaA <= areaB {
                        excluded.insert(i)
                    } else {
                        excluded.insert(j)
                    }
                }
            }
        }

        return areas.enumerated().compactMap { (index, area) in
            excluded.contains(index) ? nil : area
        }
    }
}
