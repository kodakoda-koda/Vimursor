import AppKit

// MARK: - 描画定数

private enum CursorViewLayout {
    static let crosshairAlpha: CGFloat = 0.8
    static let crosshairWidth: CGFloat = 1.0
    static let guideLineAlpha: CGFloat = 0.3
    static let guideLineWidth: CGFloat = 0.5
    static let labelAlpha: CGFloat = 0.7
    static let labelFontSize: CGFloat = 10
    static let labelOffsetX: CGFloat = 8
    static let labelOffsetY: CGFloat = 2
    static let verticalLabelOffsetX: CGFloat = 4
    static let verticalLabelOffsetY: CGFloat = 8
    static let indicatorFontSize: CGFloat = 14
    static let indicatorPadding: CGFloat = 8
    static let indicatorCornerRadius: CGFloat = 6
    static let indicatorBorderWidth: CGFloat = 1.5
    static let indicatorMargin: CGFloat = 20
    static let indicatorBgAlpha: CGFloat = 0.7
}

final class CursorView: NSView {
    private var cursorPosition: CGPoint = .zero
    private let settings: AppSettings

    init(frame: NSRect, settings: AppSettings = .shared) {
        self.settings = settings
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(cursorPosition: CGPoint) {
        self.cursorPosition = cursorPosition
        needsDisplay = true
    }

    /// ガイドラインのオフセットとステップ数を計算する純粋関数。
    /// 5ステップ間隔で、画面端まで生成する。
    /// - Parameters:
    ///   - origin: 起点座標（1次元）
    ///   - stepPixels: 1ステップあたりのピクセル数
    ///   - positiveMax: 正方向の最大距離（origin から画面端まで）
    ///   - negativeMax: 負方向の最大距離（origin から画面端まで）
    /// - Returns: (offset from origin in pixels, step count) pairs. Offset can be positive or negative.
    nonisolated static func guideLineOffsets(
        origin: CGFloat,
        stepPixels: CGFloat,
        positiveMax: CGFloat,
        negativeMax: CGFloat
    ) -> [(offset: CGFloat, stepCount: Int)] {
        guard stepPixels > 0 else { return [] }
        var result: [(CGFloat, Int)] = []
        let stepInterval = 5

        // Positive direction
        var step = stepInterval
        while true {
            let offset = CGFloat(step) * stepPixels
            if offset > positiveMax { break }
            result.append((offset, step))
            step += stepInterval
        }

        // Negative direction
        step = stepInterval
        while true {
            let offset = -CGFloat(step) * stepPixels
            if -offset > negativeMax { break }
            result.append((offset, step))
            step += stepInterval
        }

        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawCrosshair()
        drawGuideLines()
        drawModeIndicator()
    }

    private func drawCrosshair() {
        let path = NSBezierPath()
        NSColor.systemGreen.withAlphaComponent(CursorViewLayout.crosshairAlpha).setStroke()
        path.lineWidth = CursorViewLayout.crosshairWidth

        // Horizontal line
        path.move(to: CGPoint(x: 0, y: cursorPosition.y))
        path.line(to: CGPoint(x: bounds.width, y: cursorPosition.y))

        // Vertical line
        path.move(to: CGPoint(x: cursorPosition.x, y: 0))
        path.line(to: CGPoint(x: cursorPosition.x, y: bounds.height))

        path.stroke()
    }

    private func drawGuideLines() {
        let stepPixels = CGFloat(settings.cursorStepPixels)

        // Horizontal guide lines (for vertical movement: j/k)
        let hOffsets = CursorView.guideLineOffsets(
            origin: cursorPosition.y,
            stepPixels: stepPixels,
            positiveMax: bounds.height - cursorPosition.y,
            negativeMax: cursorPosition.y
        )
        for (offset, stepCount) in hOffsets {
            let y = cursorPosition.y + offset
            drawHorizontalGuideLine(y: y, label: "\(stepCount)")
        }

        // Vertical guide lines (for horizontal movement: h/l)
        let vOffsets = CursorView.guideLineOffsets(
            origin: cursorPosition.x,
            stepPixels: stepPixels,
            positiveMax: bounds.width - cursorPosition.x,
            negativeMax: cursorPosition.x
        )
        for (offset, stepCount) in vOffsets {
            let x = cursorPosition.x + offset
            drawVerticalGuideLine(x: x, label: "\(stepCount)")
        }
    }

    private func drawHorizontalGuideLine(y: CGFloat, label: String) {
        let path = NSBezierPath()
        NSColor.systemGreen.withAlphaComponent(CursorViewLayout.guideLineAlpha).setStroke()
        path.lineWidth = CursorViewLayout.guideLineWidth
        path.move(to: CGPoint(x: 0, y: y))
        path.line(to: CGPoint(x: bounds.width, y: y))
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CursorViewLayout.labelFontSize, weight: .medium),
            .foregroundColor: NSColor.systemGreen.withAlphaComponent(CursorViewLayout.labelAlpha)
        ]
        (label as NSString).draw(
            at: CGPoint(x: cursorPosition.x + CursorViewLayout.labelOffsetX, y: y + CursorViewLayout.labelOffsetY),
            withAttributes: attrs
        )
    }

    private func drawVerticalGuideLine(x: CGFloat, label: String) {
        let path = NSBezierPath()
        NSColor.systemGreen.withAlphaComponent(CursorViewLayout.guideLineAlpha).setStroke()
        path.lineWidth = CursorViewLayout.guideLineWidth
        path.move(to: CGPoint(x: x, y: 0))
        path.line(to: CGPoint(x: x, y: bounds.height))
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CursorViewLayout.labelFontSize, weight: .medium),
            .foregroundColor: NSColor.systemGreen.withAlphaComponent(CursorViewLayout.labelAlpha)
        ]
        (label as NSString).draw(
            at: CGPoint(
                x: x + CursorViewLayout.verticalLabelOffsetX,
                y: cursorPosition.y + CursorViewLayout.verticalLabelOffsetY
            ),
            withAttributes: attrs
        )
    }

    private func drawModeIndicator() {
        let text = "CURSOR"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CursorViewLayout.indicatorFontSize, weight: .bold),
            .foregroundColor: NSColor.systemGreen
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let padding = CursorViewLayout.indicatorPadding
        let boxWidth = size.width + padding * 2
        let boxHeight = size.height + padding * 2
        let margin = CursorViewLayout.indicatorMargin
        let x = bounds.width - boxWidth - margin
        let y = bounds.height - boxHeight - margin
        let boxRect = CGRect(x: x, y: y, width: boxWidth, height: boxHeight)

        let bgPath = NSBezierPath(
            roundedRect: boxRect,
            xRadius: CursorViewLayout.indicatorCornerRadius,
            yRadius: CursorViewLayout.indicatorCornerRadius
        )
        NSColor.black.withAlphaComponent(CursorViewLayout.indicatorBgAlpha).setFill()
        bgPath.fill()
        NSColor.systemGreen.setStroke()
        bgPath.lineWidth = CursorViewLayout.indicatorBorderWidth
        bgPath.stroke()

        (text as NSString).draw(at: CGPoint(x: x + padding, y: y + padding), withAttributes: attrs)
    }
}
