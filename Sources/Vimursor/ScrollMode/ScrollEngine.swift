import CoreGraphics

enum ScrollDirection {
    case up, down
}

struct ScrollAmount {
    let lines: Int32   // CGEvent wheel1 に渡す（正=上、負=下）

    static func step(direction: ScrollDirection) -> ScrollAmount {
        ScrollAmount(lines: direction == .up ? 3 : -3)
    }

    static func halfPage(direction: ScrollDirection) -> ScrollAmount {
        ScrollAmount(lines: direction == .up ? 15 : -15)
    }
}

enum ScrollEngine {
    static func scroll(
        amount: ScrollAmount,
        targetPoint: CGPoint? = nil,
        source: CGEventSource? = nil
    ) {
        let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 1,
            wheel1: amount.lines,
            wheel2: 0,
            wheel3: 0
        )
        if let point = targetPoint {
            event?.location = point
        }
        event?.post(tap: .cghidEventTap)
    }
}
