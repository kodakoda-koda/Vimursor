import Testing
@testable import Vimursor

@Suite
struct LabelGeneratorTests {
    @Test func zeroCount() {
        #expect(LabelGenerator.generateLabels(count: 0) == [])
    }

    @Test func singleLabel() {
        let labels = LabelGenerator.generateLabels(count: 1)
        #expect(labels == ["f"])
    }

    @Test func sixteenLabels() {
        // chars = "fjrieodkslapnvmc" (16文字) なので count=16 まで1文字ラベル
        let labels = LabelGenerator.generateLabels(count: 16)
        #expect(labels.count == 16)
        #expect(labels.allSatisfy { $0.count == 1 })
        #expect(Set(labels).count == 16)  // 重複なし
    }

    @Test func seventeenLabelsIncludesTwoChars() {
        // count=17 以上は全部2文字ラベル（prefix-free を保証するため1文字と2文字を混在させない）
        let labels = LabelGenerator.generateLabels(count: 17)
        #expect(labels.count == 17)
        #expect(labels.contains { $0.count == 2 })
        #expect(Set(labels).count == 17)  // 重複なし
    }

    @Test func noDuplicates() {
        let labels = LabelGenerator.generateLabels(count: 100)
        #expect(labels.count == Set(labels).count)
    }

    // prefix-free: 全ラベルが同じ長さであること
    @Test func testNoMixedLengthLabels() {
        let labels = LabelGenerator.generateLabels(count: 20)
        let lengths = Set(labels.map { $0.count })
        #expect(lengths.count == 1, "全ラベルが同じ長さであること")
    }

    // セミコロンが含まれないこと
    @Test func testNoSemicolon() {
        let labels = LabelGenerator.generateLabels(count: 256)
        #expect(!labels.contains { $0.contains(";") })
    }

    // 16個以下は1文字ラベル
    @Test func testSingleCharLabelsForSmallCount() {
        let labels = LabelGenerator.generateLabels(count: 16)
        #expect(labels.allSatisfy { $0.count == 1 })
    }

    // 17個以上は全部2文字ラベル
    @Test func testDoubleCharLabelsForLargeCount() {
        let labels = LabelGenerator.generateLabels(count: 17)
        #expect(labels.allSatisfy { $0.count == 2 })
    }

    // ラベルに重複がないこと（大量生成）
    @Test func testLabelsAreUniqueForLargeCount() {
        let labels = LabelGenerator.generateLabels(count: 100)
        #expect(Set(labels).count == labels.count)
    }
}
