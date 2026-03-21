import AppKit

@MainActor
final class ScrollAreaView: NSView {
    private var areas: [ScrollAreaInfo] = []
    private var selectedIndex: Int = 0
    private let screenHeight: CGFloat

    init(screenHeight: CGFloat, frame: NSRect) {
        self.screenHeight = screenHeight
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(areas: [ScrollAreaInfo], selectedIndex: Int) {
        self.areas = areas
        self.selectedIndex = selectedIndex
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        for (i, area) in areas.enumerated() {
            let nsFrame = toNSViewFrame(area.frame)
            drawAreaBorder(nsFrame: nsFrame, isSelected: i == selectedIndex)
            drawLabelBadge(label: area.label, at: nsFrame)
        }
    }

    // AX スクリーン座標（原点:左上）→ NSView 座標（原点:左下）変換
    // 変換式: nsY = screenHeight - axY - axHeight
    func toNSViewFrame(_ axFrame: CGRect) -> CGRect {
        ScrollAreaView.toNSViewFrame(axFrame, screenHeight: screenHeight)
    }

    nonisolated static func toNSViewFrame(_ axFrame: CGRect, screenHeight: CGFloat) -> CGRect {
        let nsY = screenHeight - axFrame.origin.y - axFrame.height
        return CGRect(x: axFrame.origin.x, y: nsY, width: axFrame.width, height: axFrame.height)
    }

    private func drawAreaBorder(nsFrame: CGRect, isSelected: Bool) {
        if isSelected {
            // 選択中: 青ボーダー (2.5px)
            NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
            let path = NSBezierPath(roundedRect: nsFrame.insetBy(dx: 1.25, dy: 1.25), xRadius: 4, yRadius: 4)
            path.lineWidth = 2.5
            path.stroke()
        } else {
            // 非選択: グレーボーダー (1px)
            NSColor.systemGray.withAlphaComponent(0.5).setStroke()
            let path = NSBezierPath(roundedRect: nsFrame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            path.lineWidth = 1.0
            path.stroke()
        }
    }

    private func drawLabelBadge(label: String, at nsFrame: CGRect) {
        // バッジサイズ: 22×22、左上角から 6px インセット
        let badgeSize: CGFloat = 22
        let badgeRect = CGRect(
            x: nsFrame.minX + 6,
            y: nsFrame.maxY - 6 - badgeSize,
            width: badgeSize,
            height: badgeSize
        )
        // バッジ背景
        NSColor(white: 0.1, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
        // バッジテキスト
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = label as NSString
        let strSize = str.size(withAttributes: attrs)
        let textOrigin = CGPoint(
            x: badgeRect.midX - strSize.width / 2,
            y: badgeRect.midY - strSize.height / 2
        )
        str.draw(at: textOrigin, withAttributes: attrs)
    }
}
