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
        // chars = "fjrieodksla;nvmc" (16文字) なので count=16 まで1文字ラベル
        let labels = LabelGenerator.generateLabels(count: 16)
        #expect(labels.count == 16)
        #expect(labels.allSatisfy { $0.count == 1 })
        #expect(Set(labels).count == 16)  // 重複なし
    }

    @Test func seventeenLabelsIncludesTwoChars() {
        // count=17 で初めて2文字ラベルが登場する
        let labels = LabelGenerator.generateLabels(count: 17)
        #expect(labels.count == 17)
        #expect(labels.contains { $0.count == 2 })
        #expect(Set(labels).count == 17)  // 重複なし
    }

    @Test func noDuplicates() {
        let labels = LabelGenerator.generateLabels(count: 100)
        #expect(labels.count == Set(labels).count)
    }
}
