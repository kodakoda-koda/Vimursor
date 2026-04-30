import Testing
import CoreGraphics
@testable import Vimursor

@Suite("CursorModeController Tests")
struct CursorModeControllerTests {

    @Test("parseMultiplier: 空文字列は 1 を返す")
    func parseMultiplierEmpty() {
        #expect(CursorModeController.parseMultiplier("") == 1)
    }

    @Test("parseMultiplier: 数字文字列をパースする")
    func parseMultiplierNumber() {
        #expect(CursorModeController.parseMultiplier("5") == 5)
        #expect(CursorModeController.parseMultiplier("12") == 12)
        #expect(CursorModeController.parseMultiplier("99") == 99)
    }

    @Test("parseMultiplier: 不正な文字列は 1 を返す")
    func parseMultiplierInvalid() {
        #expect(CursorModeController.parseMultiplier("abc") == 1)
    }
}
