import AppKit

final class HintView: NSView {
    private var hints: [UIElementInfo] = []
    private var inputPrefix: String = ""

    override init(frame: NSRect) {
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

    private func drawLabel(hint: UIElementInfo, isMatch: Bool) {
        let label = hint.label
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isMatch ? NSColor.black : NSColor.gray
        ]

        let size = (label as NSString).size(withAttributes: attrs)
        let padding: CGFloat = 3
        let boxWidth = size.width + padding * 2
        let boxHeight = size.height + padding * 2

        // ラベルをUI要素の左上に配置
        let origin = CGPoint(x: hint.frame.minX, y: hint.frame.maxY)
        let boxRect = CGRect(x: origin.x, y: origin.y, width: boxWidth, height: boxHeight)

        let path = NSBezierPath(roundedRect: boxRect, xRadius: 3, yRadius: 3)
        let bgColor: NSColor = isMatch ? NSColor.white : NSColor.lightGray
        bgColor.withAlphaComponent(isMatch ? 0.95 : 0.5).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(isMatch ? 1.0 : 0.4).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        let textOrigin = CGPoint(x: origin.x + padding, y: origin.y + padding)
        (label as NSString).draw(at: textOrigin, withAttributes: attrs)
    }
}
