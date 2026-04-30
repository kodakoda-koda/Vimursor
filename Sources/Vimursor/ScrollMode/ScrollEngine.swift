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
    /// 通常スクロール（j/k/d/u）
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

    /// ページ端までスクロール（gg/G）
    /// line 単位の巨大イベントは Chrome/Electron で無視されるため、
    /// pixel 単位のイベントを時間分散して送信する。
    /// 返り値の DispatchWorkItem を cancel() することで未送信イベントを中断可能。
    @discardableResult
    static func scrollToExtreme(
        direction: ScrollDirection,
        targetPoint: CGPoint? = nil
    ) -> DispatchWorkItem {
        let pixelsPerEvent: Int32 = 5_000
        let eventCount = 10
        let pixels = direction == .up ? pixelsPerEvent : -pixelsPerEvent
        let source = CGEventSource(stateID: .combinedSessionState)

        // cancel() でキャンセルフラグを立てるためのセンチネル
        let sentinel = DispatchWorkItem { }
        for i in 0..<eventCount {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.02) {
                guard !sentinel.isCancelled else { return }
                let event = CGEvent(
                    scrollWheelEvent2Source: source,
                    units: .pixel,
                    wheelCount: 1,
                    wheel1: pixels,
                    wheel2: 0,
                    wheel3: 0
                )
                if let point = targetPoint {
                    event?.location = point
                }
                event?.post(tap: .cghidEventTap)
            }
        }
        return sentinel
    }
}
