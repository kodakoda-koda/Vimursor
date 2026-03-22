import Testing
import AppKit
@testable import Vimursor

@Suite
struct SearchModeControllerTests {

    private func makeInfo(
        title: String,
        label: String = "",
        description: String = "",
        role: String = "AXButton"
    ) -> SearchElementInfo {
        SearchElementInfo(
            frame: .zero,
            title: title,
            label: label,
            description: description,
            role: role,
            axElement: AXElement(ref: AXUIElementCreateSystemWide())
        )
    }

    @Test func filterByTitle() {
        let elements = [makeInfo(title: "Save"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "save")
        #expect(result.count == 1)
        #expect(result.first?.title == "Save")
    }

    @Test func filterByLabel() {
        let elements = [makeInfo(title: "", label: "Submit Button"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "submit")
        #expect(result.count == 1)
    }

    @Test func filterByDescription() {
        let elements = [makeInfo(title: "", description: "Close the window")]
        let result = SearchModeController.filter(elements: elements, query: "close")
        #expect(result.count == 1)
    }

    @Test func emptyQueryReturnsAllElements() {
        let elements = [makeInfo(title: "A"), makeInfo(title: "B"), makeInfo(title: "C")]
        let result = SearchModeController.filter(elements: elements, query: "")
        #expect(result.count == 3)
    }

    @Test func noMatchReturnsEmpty() {
        let elements = [makeInfo(title: "Save"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "zzz")
        #expect(result.isEmpty)
    }

    @Test func caseInsensitiveMatch() {
        let elements = [makeInfo(title: "System Preferences")]
        let result = SearchModeController.filter(elements: elements, query: "SYSTEM")
        #expect(result.count == 1)
    }

    @Test func partialMatchInMiddle() {
        let elements = [makeInfo(title: "Open in New Tab")]
        let result = SearchModeController.filter(elements: elements, query: "new tab")
        #expect(result.count == 1)
    }

    @Test func multipleMatches() {
        let elements = [
            makeInfo(title: "Save File"),
            makeInfo(title: "Save As"),
            makeInfo(title: "Cancel")
        ]
        let result = SearchModeController.filter(elements: elements, query: "save")
        #expect(result.count == 2)
    }

    @Test func filterWithUpperCaseQuery() {
        let elements = [makeInfo(title: "Save")]
        let result = SearchModeController.filter(elements: elements, query: "S")
        #expect(result.count == 1)
    }

    @Test func filterWithSpaceInQuery() {
        let elements = [makeInfo(title: "Open in New Tab"), makeInfo(title: "New Window")]
        let result = SearchModeController.filter(elements: elements, query: "new tab")
        #expect(result.count == 1)
        #expect(result.first?.title == "Open in New Tab")
    }

    @Test func filterIsCaseInsensitiveForFullUpperCase() {
        let elements = [makeInfo(title: "save file")]
        let result = SearchModeController.filter(elements: elements, query: "SAVE")
        #expect(result.count == 1)
    }
}
