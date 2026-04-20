import CoreGraphics

enum ScrollDirection {
    case up, down
}

struct ScrollAmount {
    let lines: Int32   // CGEvent wheel1 に渡す（正=上、負=下）

    static func step(direction: ScrollDirection, settings: AppSettings = .shared) -> ScrollAmount {
        let step = Int32(settings.scrollStepLines)
        return ScrollAmount(lines: direction == .up ? step : -step)
    }

    static func halfPage(direction: ScrollDirection, settings: AppSettings = .shared) -> ScrollAmount {
        // halfPage は step の 5 倍（固定比率）
        let step = Int32(settings.scrollStepLines)
        let halfPageLines = step * 5
        return ScrollAmount(lines: direction == .up ? halfPageLines : -halfPageLines)
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
