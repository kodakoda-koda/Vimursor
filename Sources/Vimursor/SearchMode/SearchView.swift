import AppKit

final class SearchView: NSView {
    private var query: String = ""
    private var matchedElements: [SearchElementInfo] = []

    func update(query: String, matched: [SearchElementInfo]) {
        self.query = query
        self.matchedElements = query.isEmpty ? [] : matched
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawHighlights()
        drawSearchBar()
    }

    private func drawHighlights() {
        for info in matchedElements {
            let path = NSBezierPath(roundedRect: info.frame.insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4)
            NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 2.5
            path.stroke()

            NSColor.systemGreen.withAlphaComponent(0.12).setFill()
            path.fill()
        }
    }

    private func drawSearchBar() {
        let barHeight: CGFloat = 52
        let barRect = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        NSColor.black.withAlphaComponent(0.80).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 0, yRadius: 0).fill()

        let isNoMatch = !query.isEmpty && matchedElements.isEmpty
        let textColor: NSColor = isNoMatch ? .systemRed : (query.isEmpty ? .systemGray : .white)
        let displayText = query.isEmpty ? "検索... (Cmd+Shift+/)" : query

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: textColor
        ]
        (displayText as NSString).draw(at: CGPoint(x: 20, y: 17), withAttributes: attrs)

        if !query.isEmpty {
            let countText = "\(matchedElements.count) 件"
            let countAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.systemGray
            ]
            let countSize = (countText as NSString).size(withAttributes: countAttrs)
            (countText as NSString).draw(
                at: CGPoint(x: bounds.width - countSize.width - 20, y: 19),
                withAttributes: countAttrs
            )
        }
    }
}
