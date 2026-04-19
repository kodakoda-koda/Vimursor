import AppKit
@testable import Vimursor

@MainActor
final class MockOverlayProviding: OverlayProviding {
    var showCallCount = 0
    var hideCallCount = 0
    var showAsKeyWindowCallCount = 0
    private let _contentView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))

    var contentView: NSView? { _contentView }

    func show() { showCallCount += 1 }
    func hide() { hideCallCount += 1 }
    func showAsKeyWindow() { showAsKeyWindowCallCount += 1 }
}
