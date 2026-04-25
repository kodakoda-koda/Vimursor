import Testing
import AppKit
@testable import Vimursor

@Suite("AXAttributes Tests")
struct AXAttributesTests {

    // MARK: - rectFromValues

    @Test("正常系: 有効な position + size → CGRect が返る")
    func rectFromValidValues() {
        var point = CGPoint(x: 100, y: 200)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        var size = CGSize(width: 300, height: 400)
        let sizeValue = AXValueCreate(.cgSize, &size)! as CFTypeRef

        let rect = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: sizeValue)

        #expect(rect != nil)
        #expect(rect?.origin.x == 100)
        #expect(rect?.origin.y == 200)
        #expect(rect?.size.width == 300)
        #expect(rect?.size.height == 400)
    }

    @Test("ゼロ幅 → nil が返る")
    func zeroWidthReturnsNil() {
        var point = CGPoint(x: 0, y: 0)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        var size = CGSize(width: 0, height: 100)
        let sizeValue = AXValueCreate(.cgSize, &size)! as CFTypeRef

        let rect = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: sizeValue)
        #expect(rect == nil)
    }

    @Test("ゼロ高さ → nil が返る")
    func zeroHeightReturnsNil() {
        var point = CGPoint(x: 0, y: 0)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        var size = CGSize(width: 100, height: 0)
        let sizeValue = AXValueCreate(.cgSize, &size)! as CFTypeRef

        let rect = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: sizeValue)
        #expect(rect == nil)
    }

    @Test("両方ゼロサイズ → nil が返る")
    func bothZeroSizeReturnsNil() {
        var point = CGPoint(x: 10, y: 20)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        var size = CGSize(width: 0, height: 0)
        let sizeValue = AXValueCreate(.cgSize, &size)! as CFTypeRef

        let rect = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: sizeValue)
        #expect(rect == nil)
    }

    @Test("不正な CFTypeRef (AXValue でない文字列) → nil が返る")
    func invalidCFTypeRefReturnsNil() {
        let notAXValue = "not an AXValue" as CFTypeRef

        var point = CGPoint(x: 100, y: 200)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        // positionValue が不正
        let rect1 = AXAttributes.rectFromValues(positionValue: notAXValue, sizeValue: posValue)
        #expect(rect1 == nil)

        // sizeValue が不正
        let rect2 = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: notAXValue)
        #expect(rect2 == nil)
    }

    @Test("負の座標でも有効なサイズなら CGRect が返る")
    func negativeOriginWithValidSize() {
        var point = CGPoint(x: -50, y: -100)
        let posValue = AXValueCreate(.cgPoint, &point)! as CFTypeRef

        var size = CGSize(width: 200, height: 150)
        let sizeValue = AXValueCreate(.cgSize, &size)! as CFTypeRef

        let rect = AXAttributes.rectFromValues(positionValue: posValue, sizeValue: sizeValue)
        #expect(rect != nil)
        #expect(rect?.origin.x == -50)
        #expect(rect?.origin.y == -100)
    }
}
