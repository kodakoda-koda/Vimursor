import Testing
import CoreGraphics
@testable import Vimursor

@Suite("WebAreaSplitDetector Tests")
struct WebAreaSplitDetectorTests {

    // MARK: - Helpers

    /// ChildInfo を使ったフラットな子リストを parentFrame に対して評価する
    private func children(frames: [CGRect]) -> [ChildInfo] {
        frames.map { ChildInfo(frame: $0, children: []) }
    }

    /// 親フレーム: 一般的な Notion/Slack/GitHub ウィンドウサイズ想定
    private let notionParent = CGRect(x: 0, y: 0, width: 2293, height: 1328)
    private let slackParent  = CGRect(x: 0, y: 0, width: 1079, height: 1374)
    private let githubParent = CGRect(x: 0, y: 0, width: 2279, height: 1203)

    // MARK: - 分割検出テスト

    /// Notion レイアウト: サイドバー(240) + メイン(2053)
    @Test("Notion レイアウト: 2 領域に分割される")
    func splitDetectsNotionLayout() {
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 240,  height: 1328),
            CGRect(x: 240, y: 0, width: 2053, height: 1328),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: notionParent, depth: 0
        )
        #expect(result?.count == 2, "Notion レイアウトは2領域に分割される")
    }

    /// Slack レイアウト: サイドバー(222) + メインチャット(857)
    @Test("Slack レイアウト: 2 領域に分割される")
    func splitDetectsSlackLayout() {
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 222, height: 1374),
            CGRect(x: 222, y: 0, width: 857, height: 1374),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: slackParent, depth: 0
        )
        #expect(result?.count == 2, "Slack レイアウトは2領域に分割される")
    }

    /// GitHub レイアウト: サイドバー(402) + メイン(1877)
    @Test("GitHub レイアウト: 2 領域に分割される")
    func splitDetectsGitHubLayout() {
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 402,  height: 1203),
            CGRect(x: 402, y: 0, width: 1877, height: 1203),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: githubParent, depth: 0
        )
        #expect(result?.count == 2, "GitHub レイアウトは2領域に分割される")
    }

    /// 子が1つだけ → 分割なし（nil）
    @Test("子が1つだけの場合は分割されない")
    func noSplitForSingleChild() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let kids = children(frames: [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result == nil, "子が1つでは分割されない")
    }

    /// minChildSize 未満の子だけ → 分割なし（nil）
    @Test("minChildSize 未満の子は無視されて分割されない")
    func noSplitForTooSmallChildren() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 50, height: 50),  // 小さすぎる
            CGRect(x: 50,  y: 0, width: 50, height: 50),  // 小さすぎる
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result == nil, "minChildSize 未満の子だけでは分割されない")
    }

    /// ラッパー要素を飛ばして再帰して分割を検出する
    @Test("ラッパー要素を透過して子の分割を検出する")
    func wrapperSkippedAndDescended() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // ラッパー: 親と同サイズ (width/parentWidth = 1.0 >= 0.9)
        let inner1 = ChildInfo(frame: CGRect(x: 0,   y: 0, width: 200, height: 800), children: [])
        let inner2 = ChildInfo(frame: CGRect(x: 200, y: 0, width: 800, height: 800), children: [])
        let wrapper = ChildInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),  // ラッパー
            children: [inner1, inner2]
        )
        let result = WebAreaSplitDetector.findSplitFrames(
            children: [wrapper], parentFrame: parent, depth: 0
        )
        #expect(result?.count == 2, "ラッパーを透過して内側の2分割を検出する")
    }

    /// maxDepth に達したら nil を返す
    @Test("maxDepth に達したら nil を返す")
    func maxDepthReached() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let wrapper = ChildInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),  // ラッパー
            children: [
                ChildInfo(frame: CGRect(x: 0,   y: 0, width: 200, height: 800), children: []),
                ChildInfo(frame: CGRect(x: 200, y: 0, width: 800, height: 800), children: []),
            ]
        )
        // maxDepth を 0 に設定してラッパー再帰を禁止
        let result = WebAreaSplitDetector.findSplitFrames(
            children: [wrapper], parentFrame: parent, depth: WebAreaSplitDetector.maxDepth
        )
        #expect(result == nil, "maxDepth に達したら nil を返す")
    }

    /// 3パネルレイアウト → 3つの CGRect
    @Test("3パネルレイアウトは3領域に分割される")
    func threePanelLayout() {
        let parent = CGRect(x: 0, y: 0, width: 1500, height: 900)
        let kids = children(frames: [
            CGRect(x: 0,    y: 0, width: 300, height: 900),
            CGRect(x: 300,  y: 0, width: 900, height: 900),
            CGRect(x: 1200, y: 0, width: 300, height: 900),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result?.count == 3, "3パネルレイアウトは3領域に分割される")
    }

    // MARK: - detect() の戻り値型テスト

    /// 子が0件 → 分割なし（nil）
    @Test("子が0件のとき findSplitFrames は nil を返す")
    func findSplitFramesReturnsNilForEmptyChildren() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let result = WebAreaSplitDetector.findSplitFrames(
            children: [], parentFrame: parent, depth: 0
        )
        #expect(result == nil, "子が0件では分割されない")
    }

    // MARK: - validateTiling Tests

    /// GitHub-like layout: 3 elements with large Y/X spread → rejected
    @Test("GitHub-like layout: タイリング検証で分割が拒否される")
    func githubLikeLayoutRejectedByTilingValidation() {
        // Header-like, main content, another section — not side-by-side
        let parent = CGRect(x: 0, y: 0, width: 1470, height: 900)
        let kids = children(frames: [
            CGRect(x: 0,   y: 0,   width: 1470, height: 68),   // header-like (too small in height, filtered)
            CGRect(x: 220, y: 68,  width: 1250, height: 400),  // main content
            CGRect(x: 220, y: 500, width: 1250, height: 400),  // another section
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        // Header is filtered by wrapperWidthRatio (1470/1470=1.0 >= 0.9).
        // The two remaining candidates: Y spread = 500-68 = 432 > positionTolerance(50) → horizontal check fails.
        // validateTiling returns false → nil
        #expect(result == nil, "GitHub-likeレイアウトはタイリング検証で拒否される")
    }

    /// Slack-like layout: 2 elements side by side → accepted
    @Test("Slack-like layout: タイリング検証で分割が承認される")
    func slackLikeLayoutAcceptedByTilingValidation() {
        let parent = CGRect(x: 0, y: 0, width: 1470, height: 900)
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 300,  height: 900),  // sidebar
            CGRect(x: 300, y: 0, width: 1170, height: 900),  // main
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result?.count == 2, "Slack-likeレイアウトはタイリング検証を通過して2分割される")
    }

    /// Vertical stacking (same-width elements): NOT a valid split — stacked content sections
    @Test("垂直スタック: 同幅の要素が縦に並ぶ場合は分割されない（コンテンツセクション）")
    func verticalStackingRejected() {
        // Two same-width elements stacked vertically = content sections, not independent panes
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let kids = children(frames: [
            CGRect(x: 0, y: 0,   width: 800, height: 380),
            CGRect(x: 0, y: 400, width: 800, height: 400),
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result == nil, "垂直スタックはコンテンツセクションとして分割されない")
    }

    /// validateTiling direct test: horizontal valid
    @Test("validateTiling: 水平タイリングが有効な場合 true を返す")
    func validateTilingHorizontalValid() {
        let parent = CGRect(x: 0, y: 0, width: 1470, height: 900)
        let candidates = [
            CGRect(x: 0,   y: 0, width: 300,  height: 900),
            CGRect(x: 300, y: 0, width: 1170, height: 900),
        ]
        #expect(WebAreaSplitDetector.validateTiling(candidates: candidates, parentFrame: parent) == true)
    }

    /// validateTiling direct test: horizontal invalid (large Y spread)
    @Test("validateTiling: Y スプレッドが大きい場合 false を返す")
    func validateTilingHorizontalInvalidYSpread() {
        let parent = CGRect(x: 0, y: 0, width: 1470, height: 900)
        let candidates = [
            CGRect(x: 220, y: 68,  width: 1250, height: 400),
            CGRect(x: 220, y: 500, width: 1250, height: 400),
        ]
        #expect(WebAreaSplitDetector.validateTiling(candidates: candidates, parentFrame: parent) == false)
    }

    /// validateTiling direct test: vertical stacking (same-width) → false (horizontal-only validation)
    @Test("validateTiling: 垂直スタック（同幅）は false を返す（水平タイリングのみ有効）")
    func validateTilingVerticalStackingReturnsFalse() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let candidates = [
            CGRect(x: 0, y: 0,   width: 800, height: 380),
            CGRect(x: 0, y: 400, width: 800, height: 400),
        ]
        // Vertical stacking of same-width content = content sections, not independent scroll panes
        #expect(WebAreaSplitDetector.validateTiling(candidates: candidates, parentFrame: parent) == false)
    }

    /// validateTiling direct test: large gaps between candidates → false
    @Test("validateTiling: 候補間のギャップが大きい場合 false を返す")
    func validateTilingLargeGap() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let candidates = [
            CGRect(x: 0,   y: 0, width: 200, height: 800),
            CGRect(x: 700, y: 0, width: 200, height: 800),  // gap = 500 > maxGap(50)
        ]
        #expect(WebAreaSplitDetector.validateTiling(candidates: candidates, parentFrame: parent) == false)
    }

    /// validateTiling direct test: insufficient coverage → false
    @Test("validateTiling: カバレッジが不十分な場合 false を返す")
    func validateTilingInsufficientCoverage() {
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let candidates = [
            CGRect(x: 0,  y: 0, width: 100, height: 800),
            CGRect(x: 100, y: 0, width: 100, height: 800),  // total width = 200, 200/1000 = 0.2 < 0.7
        ]
        #expect(WebAreaSplitDetector.validateTiling(candidates: candidates, parentFrame: parent) == false)
    }

    // MARK: - wrapperWidthRatio 境界値テスト

    /// 幅が parentWidth * 0.9 ちょうどの子はラッパーとみなして再帰する
    @Test("幅が parentWidth * wrapperWidthRatio ちょうどの子はラッパー扱いで再帰する")
    func wrapperWidthRatioExactBoundaryIsWrapper() {
        // 親幅 1000 のとき width=900 は 900/1000=0.9 → ラッパー扱い（>= 0.9）
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let inner1 = ChildInfo(frame: CGRect(x: 0,   y: 0, width: 200, height: 800), children: [])
        let inner2 = ChildInfo(frame: CGRect(x: 200, y: 0, width: 700, height: 800), children: [])
        let wrapper = ChildInfo(
            frame: CGRect(x: 0, y: 0, width: 900, height: 800),  // 900/1000 = 0.9 ちょうど → ラッパー
            children: [inner1, inner2]
        )
        let result = WebAreaSplitDetector.findSplitFrames(
            children: [wrapper], parentFrame: parent, depth: 0
        )
        #expect(result?.count == 2, "幅比率 0.9 ちょうどはラッパーとして透過され内側の2分割を検出する")
    }

    /// 幅が parentWidth * 0.9 未満（width=899）の子は分割候補として扱う
    @Test("幅が parentWidth * wrapperWidthRatio 未満の子は分割候補として扱う")
    func wrapperWidthRatioBelowBoundaryIsNonWrapper() {
        // 親幅 1000 のとき width=899 は 899/1000=0.899 < 0.9 → 非ラッパー（分割候補）
        let parent = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let kids = children(frames: [
            CGRect(x: 0,   y: 0, width: 899, height: 800),  // 899/1000 < 0.9 → 非ラッパー
            CGRect(x: 899, y: 0, width: 101, height: 800),  // 101/1000 < 0.9 → 非ラッパー
        ])
        let result = WebAreaSplitDetector.findSplitFrames(
            children: kids, parentFrame: parent, depth: 0
        )
        #expect(result?.count == 2, "幅比率 0.9 未満の子2つは分割候補として検出される")
    }
}
