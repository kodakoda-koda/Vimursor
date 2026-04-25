import AppKit

@MainActor
protocol OverlayProviding: AnyObject {
    var contentView: NSView? { get }
    func show()
    func hide()
    func showAsKeyWindow()
}
