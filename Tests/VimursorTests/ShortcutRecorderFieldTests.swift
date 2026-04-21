import Testing
import AppKit
@testable import Vimursor

// MARK: - ShortcutRecorderField Validation Logic Tests

@Suite("ShortcutRecorderField Tests")
struct ShortcutRecorderFieldTests {

    // MARK: - isValidModifiers

    @Test("Shift のみは無効")
    func shiftOnlyIsInvalid() {
        let flags: NSEvent.ModifierFlags = [.shift]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == false)
    }

    @Test("修飾キーなしは無効")
    func noModifiersIsInvalid() {
        let flags: NSEvent.ModifierFlags = []
        #expect(ShortcutRecorderField.isValidModifiers(flags) == false)
    }

    @Test("Cmd+Shift は有効")
    func cmdShiftIsValid() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    @Test("Cmd のみは有効")
    func cmdOnlyIsValid() {
        let flags: NSEvent.ModifierFlags = [.command]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    @Test("Option のみは有効")
    func optionOnlyIsValid() {
        let flags: NSEvent.ModifierFlags = [.option]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    @Test("Control のみは有効")
    func controlOnlyIsValid() {
        let flags: NSEvent.ModifierFlags = [.control]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    @Test("Cmd+Option は有効")
    func cmdOptionIsValid() {
        let flags: NSEvent.ModifierFlags = [.command, .option]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    @Test("Shift+Option は有効（Shift 以外の修飾キーがある）")
    func shiftOptionIsValid() {
        let flags: NSEvent.ModifierFlags = [.shift, .option]
        #expect(ShortcutRecorderField.isValidModifiers(flags) == true)
    }

    // MARK: - displayString

    @Test("nil ショートカット → 空文字列")
    func nilShortcutDisplayString() {
        let str = ShortcutRecorderField.displayString(for: nil)
        #expect(str == "")
    }
}
