import AppKit

// MARK: - ラベル描画定数（非設定項目）

private enum HintLabelLayout {
    static let padding: CGFloat = 3
    static let cornerRadius: CGFloat = 3
    static let noMatchBgAlpha: CGFloat = 0.5
    static let noMatchBorderAlpha: CGFloat = 0.4
    static let matchBorderAlpha: CGFloat = 1.0
}

final class HintView: NSView {
    private var hints: [UIElementInfo] = []
    private var inputPrefix: String = ""
    private let settings: AppSettings

    init(frame: NSRect, settings: AppSettings = .shared) {
        self.settings = settings
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(hints: [UIElementInfo], inputPrefix: String) {
        self.hints = hints
        self.inputPrefix = inputPrefix
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for hint in hints {
            let isMatch = inputPrefix.isEmpty || hint.label.hasPrefix(inputPrefix)
            drawLabel(hint: hint, isMatch: isMatch)
        }
    }

    /// ラベルボックスの origin を計算する純粋関数。
    /// NSWindow 座標系（原点: 左下）で、要素の左端・縦中央にラベルを配置する。
    nonisolated static func labelOrigin(elementFrame: CGRect, boxHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: elementFrame.minX,
            y: elementFrame.midY - boxHeight / 2
        )
    }

    private func drawLabel(hint: UIElementInfo, isMatch: Bool) {
        let label = hint.label
        let font = NSFont.systemFont(ofSize: settings.labelFontSize, weight: .semibold)
        let textColor: NSColor = isMatch ? settings.labelTextColor : .gray
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let size = (label as NSString).size(withAttributes: attrs)
        let padding = HintLabelLayout.padding
        let boxWidth = size.width + padding * 2
        let boxHeight = size.height + padding * 2

        // ラベルをUI要素の左端・縦中央に配置（Vimiumスタイル）
        let origin = HintView.labelOrigin(elementFrame: hint.frame, boxHeight: boxHeight)
        let boxRect = CGRect(x: origin.x, y: origin.y, width: boxWidth, height: boxHeight)

        let cornerRadius = HintLabelLayout.cornerRadius
        let path = NSBezierPath(roundedRect: boxRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let bgColor: NSColor = isMatch ? settings.labelBackgroundColor : .lightGray
        let bgAlpha = isMatch ? settings.labelBackgroundOpacity : HintLabelLayout.noMatchBgAlpha
        bgColor.withAlphaComponent(bgAlpha).setFill()
        path.fill()
        let borderAlpha = isMatch ? HintLabelLayout.matchBorderAlpha : HintLabelLayout.noMatchBorderAlpha
        NSColor.black.withAlphaComponent(borderAlpha).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        let textOrigin = CGPoint(x: origin.x + padding, y: origin.y + padding)
        (label as NSString).draw(at: textOrigin, withAttributes: attrs)
    }
}
