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

    // MARK: - clickableRoles: 元々のロール

    @Test("AXButton は clickableRoles に含まれる")
    func buttonIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXButton"))
    }

    @Test("AXLink は clickableRoles に含まれる")
    func linkIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXLink"))
    }

    @Test("AXCheckBox は clickableRoles に含まれる")
    func checkBoxIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXCheckBox"))
    }

    @Test("AXRadioButton は clickableRoles に含まれる")
    func radioButtonIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXRadioButton"))
    }

    @Test("AXMenuItem は clickableRoles に含まれる")
    func menuItemIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXMenuItem"))
    }

    @Test("AXPopUpButton は clickableRoles に含まれる")
    func popUpButtonIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXPopUpButton"))
    }

    @Test("AXComboBox は clickableRoles に含まれる")
    func comboBoxIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXComboBox"))
    }

    @Test("AXTab は clickableRoles に含まれる")
    func tabIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXTab"))
    }

    // MARK: - clickableRoles: 新規追加ロール

    @Test("AXMenuBarItem は clickableRoles に含まれる（新規追加）")
    func menuBarItemIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXMenuBarItem"))
    }

    @Test("AXTextField は clickableRoles に含まれる（新規追加）")
    func textFieldIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXTextField"))
    }

    @Test("AXTextArea は clickableRoles に含まれる（新規追加）")
    func textAreaIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXTextArea"))
    }

    @Test("AXMenuButton は clickableRoles に含まれる（新規追加）")
    func menuButtonIsClickable() {
        #expect(UIElementEnumerator.isClickableRole("AXMenuButton"))
    }

    // MARK: - skippableRoles: 既存ロール

    @Test("AXStaticText は skippableRoles に含まれる")
    func staticTextIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXStaticText"))
    }

    @Test("AXImage は skippableRoles に含まれる")
    func imageIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXImage"))
    }

    @Test("AXSeparator は skippableRoles に含まれる")
    func separatorIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXSeparator"))
    }

    @Test("AXScrollBar は skippableRoles に含まれる")
    func scrollBarIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXScrollBar"))
    }

    @Test("AXScrollArea は skippableRoles に含まれる")
    func scrollAreaIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXScrollArea"))
    }

    @Test("AXSplitter は skippableRoles に含まれる")
    func splitterIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXSplitter"))
    }

    @Test("AXToolbar は skippableRoles に含まれる")
    func toolbarIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXToolbar"))
    }

    @Test("AXStatusBar は skippableRoles に含まれる")
    func statusBarIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXStatusBar"))
    }

    @Test("AXTable は skippableRoles に含まれる")
    func tableIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXTable"))
    }

    @Test("AXOutline は skippableRoles に含まれる")
    func outlineIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXOutline"))
    }

    @Test("AXList は skippableRoles に含まれる")
    func listIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXList"))
    }

    @Test("AXBrowser は skippableRoles に含まれる")
    func browserIsSkippable() {
        #expect(UIElementEnumerator.isSkippableRole("AXBrowser"))
    }

    // MARK: - clickableRoles と skippableRoles に重複がないこと

    @Test("clickableRoles と skippableRoles に重複がない")
    func noOverlapBetweenClickableAndSkippable() {
        let clickableRoles: [String] = [
            "AXButton", "AXLink", "AXCheckBox", "AXRadioButton",
            "AXMenuItem", "AXPopUpButton", "AXComboBox", "AXTab",
            "AXMenuBarItem", "AXTextField", "AXTextArea", "AXMenuButton"
        ]
        for role in clickableRoles {
            #expect(
                !UIElementEnumerator.isSkippableRole(role),
                "'\(role)' は clickable と skippable の両方に含まれてはいけない"
            )
        }
    }

    // MARK: - どちらにも含まれないロール

    @Test("AXGroup は clickable にも skippable にも含まれない")
    func groupIsNeitherClickableNorSkippable() {
        #expect(!UIElementEnumerator.isClickableRole("AXGroup"))
        #expect(!UIElementEnumerator.isSkippableRole("AXGroup"))
    }

    @Test("AXWindow は clickable にも skippable にも含まれない")
    func windowIsNeitherClickableNorSkippable() {
        #expect(!UIElementEnumerator.isClickableRole("AXWindow"))
        #expect(!UIElementEnumerator.isSkippableRole("AXWindow"))
    }

    @Test("未知のロールは clickable にも skippable にも含まれない")
    func unknownRoleIsNeitherClickableNorSkippable() {
        #expect(!UIElementEnumerator.isClickableRole("AXUnknown"))
        #expect(!UIElementEnumerator.isSkippableRole("AXUnknown"))
    }
}
