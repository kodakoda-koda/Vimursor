import Testing
@testable import Vimursor

@Suite("UIElementEnumerator Tests")
struct UIElementEnumeratorTests {

    @Test("テキストがある場合は true")
    func hasTextWithTitle() {
        #expect(UIElementEnumerator.hasNonEmptyText(title: "OK", label: "", description: ""))
    }

    @Test("全て空文字の場合は false")
    func hasTextAllEmpty() {
        #expect(!UIElementEnumerator.hasNonEmptyText(title: "", label: "", description: ""))
    }

    @Test("空白のみの場合は false")
    func hasTextWhitespaceOnly() {
        #expect(!UIElementEnumerator.hasNonEmptyText(title: "   ", label: "", description: ""))
    }

    @Test("改行のみの場合は false")
    func hasTextNewlineOnly() {
        #expect(!UIElementEnumerator.hasNonEmptyText(title: "\n", label: "\t", description: ""))
    }

    @Test("description にテキストがあれば true")
    func hasTextInDescription() {
        #expect(UIElementEnumerator.hasNonEmptyText(title: "", label: "", description: "hello"))
    }

    @Test("label にテキストがあれば true")
    func hasTextInLabel() {
        #expect(UIElementEnumerator.hasNonEmptyText(title: "", label: "btn", description: ""))
    }
}
