import Testing
import CoreGraphics
@testable import Vimursor

@Suite
struct ClickModifierTests {

    @Test func noModifierReturnsLeftClick() {
        #expect(ClickModifier.from(flags: []) == .leftClick)
    }

    @Test func commandReturnsCommandClick() {
        #expect(ClickModifier.from(flags: .maskCommand) == .commandClick)
    }

    @Test func shiftReturnsRightClick() {
        #expect(ClickModifier.from(flags: .maskShift) == .rightClick)
    }

    @Test func controlReturnsControlClick() {
        #expect(ClickModifier.from(flags: .maskControl) == .controlClick)
    }

    @Test func optionReturnsOptionClick() {
        #expect(ClickModifier.from(flags: .maskAlternate) == .optionClick)
    }

    @Test func commandTakesPriorityOverShift() {
        #expect(ClickModifier.from(flags: [.maskCommand, .maskShift]) == .commandClick)
    }

    @Test func controlTakesPriorityOverOption() {
        #expect(ClickModifier.from(flags: [.maskControl, .maskAlternate]) == .controlClick)
    }

    @Test func optionTakesPriorityOverShift() {
        #expect(ClickModifier.from(flags: [.maskAlternate, .maskShift]) == .optionClick)
    }

    @Test func allModifiersPressedReturnsCommand() {
        #expect(ClickModifier.from(flags: [.maskCommand, .maskControl, .maskAlternate, .maskShift]) == .commandClick)
    }
}
