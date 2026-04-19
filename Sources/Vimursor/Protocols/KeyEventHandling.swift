import AppKit

protocol KeyEventHandling: AnyObject {
    var keyEventHandler: ((CGKeyCode, CGEventFlags, String) -> Bool)? { get set }
}
