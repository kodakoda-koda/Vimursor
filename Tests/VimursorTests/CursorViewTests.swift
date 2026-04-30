import Testing
@testable import Vimursor

@Suite("CursorView Tests")
struct CursorViewTests {

    @Test("正方向のガイドライン: 5ステップ間隔で生成される")
    func positiveGuideLines() {
        let offsets = CursorView.guideLineOffsets(
            origin: 500, stepPixels: 20, positiveMax: 300, negativeMax: 500
        )
        let positiveSteps = offsets.filter { $0.offset > 0 }.map { $0.stepCount }
        // 300px / 20px = 15 steps max, so 5, 10, 15
        #expect(positiveSteps.contains(5))
        #expect(positiveSteps.contains(10))
        #expect(positiveSteps.contains(15))
        #expect(!positiveSteps.contains(20))  // 20*20=400 > 300
    }

    @Test("負方向のガイドライン")
    func negativeGuideLines() {
        let offsets = CursorView.guideLineOffsets(
            origin: 200, stepPixels: 20, positiveMax: 800, negativeMax: 200
        )
        let negativeSteps = offsets.filter { $0.offset < 0 }.map { $0.stepCount }
        // 200px / 20px = 10 steps max, so 5, 10
        #expect(negativeSteps.contains(5))
        #expect(negativeSteps.contains(10))
        #expect(!negativeSteps.contains(15))  // 15*20=300 > 200
    }

    @Test("stepPixels が 0 の場合は空配列")
    func zeroStepPixels() {
        let offsets = CursorView.guideLineOffsets(
            origin: 500, stepPixels: 0, positiveMax: 500, negativeMax: 500
        )
        #expect(offsets.isEmpty)
    }

    @Test("画面端に近い場合: ガイドラインが少ない")
    func nearEdge() {
        let offsets = CursorView.guideLineOffsets(
            origin: 50, stepPixels: 20, positiveMax: 950, negativeMax: 50
        )
        let negativeSteps = offsets.filter { $0.offset < 0 }.map { $0.stepCount }
        // 50px / 20px = 2.5 → no 5-step line fits
        #expect(negativeSteps.isEmpty)
    }

    @Test("オフセットの値が正しい")
    func correctOffsetValues() {
        let offsets = CursorView.guideLineOffsets(
            origin: 500, stepPixels: 10, positiveMax: 200, negativeMax: 200
        )
        let positive = offsets.filter { $0.offset > 0 }.sorted { $0.stepCount < $1.stepCount }
        // stepPixels=10, so 5 steps = 50px, 10 steps = 100px, 15 steps = 150px, 20 steps = 200px
        #expect(positive.count == 4)
        #expect(positive[0].offset == 50)
        #expect(positive[0].stepCount == 5)
        #expect(positive[1].offset == 100)
        #expect(positive[1].stepCount == 10)
    }
}
