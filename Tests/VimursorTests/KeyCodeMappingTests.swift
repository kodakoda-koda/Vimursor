import Testing
@testable import Vimursor

@Suite("KeyCodeMapping Tests")
struct KeyCodeMappingTests {

    // MARK: - 既知キーコードのマッピング

    @Test("keyCode 0 returns 'a'")
    func keyCode0ReturnsA() {
        #expect(KeyCodeMapping.charFromKeyCode(0) == "a")
    }

    @Test("keyCode 11 returns 'b'")
    func keyCode11ReturnsB() {
        #expect(KeyCodeMapping.charFromKeyCode(11) == "b")
    }

    @Test("keyCode 8 returns 'c'")
    func keyCode8ReturnsC() {
        #expect(KeyCodeMapping.charFromKeyCode(8) == "c")
    }

    @Test("keyCode 2 returns 'd'")
    func keyCode2ReturnsD() {
        #expect(KeyCodeMapping.charFromKeyCode(2) == "d")
    }

    @Test("keyCode 14 returns 'e'")
    func keyCode14ReturnsE() {
        #expect(KeyCodeMapping.charFromKeyCode(14) == "e")
    }

    @Test("keyCode 3 returns 'f'")
    func keyCode3ReturnsF() {
        #expect(KeyCodeMapping.charFromKeyCode(3) == "f")
    }

    @Test("keyCode 38 returns 'j'")
    func keyCode38ReturnsJ() {
        #expect(KeyCodeMapping.charFromKeyCode(38) == "j")
    }

    @Test("keyCode 40 returns 'k'")
    func keyCode40ReturnsK() {
        #expect(KeyCodeMapping.charFromKeyCode(40) == "k")
    }

    @Test("keyCode 37 returns 'l'")
    func keyCode37ReturnsL() {
        #expect(KeyCodeMapping.charFromKeyCode(37) == "l")
    }

    @Test("keyCode 15 returns 'r'")
    func keyCode15ReturnsR() {
        #expect(KeyCodeMapping.charFromKeyCode(15) == "r")
    }

    // MARK: - 未知キーコードは nil を返す

    @Test("unknown keyCode returns nil")
    func unknownKeyCodeReturnsNil() {
        #expect(KeyCodeMapping.charFromKeyCode(999) == nil)
    }

    @Test("keyCode 53 (ESC) returns nil")
    func escKeyCodeReturnsNil() {
        #expect(KeyCodeMapping.charFromKeyCode(53) == nil)
    }

    // MARK: - ラベルで使用するキーが全てマッピングされている

    @Test("all label keys are mapped correctly")
    func allLabelKeysAreMapped() {
        // LabelGenerator.swift のデフォルトラベル文字
        let labelKeys: [(UInt16, String)] = [
            (3, "f"), (38, "j"), (15, "r"), (34, "i"), (14, "e"),
            (31, "o"), (2, "d"), (40, "k"), (1, "s"), (37, "l"),
            (0, "a"), (35, "p"), (45, "n"), (9, "v"), (46, "m"), (8, "c")
        ]

        for (keyCode, expectedChar) in labelKeys {
            #expect(
                KeyCodeMapping.charFromKeyCode(keyCode) == expectedChar,
                "keyCode \(keyCode) should map to '\(expectedChar)'"
            )
        }
    }

    // MARK: - アルファベット全26文字が網羅されている

    @Test("all 26 alphabet characters are mapped")
    func allAlphabetCharactersMapped() {
        let allAlphabetChars: Set<String> = [
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
            "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
        ]

        let mappedChars = Set(KeyCodeMapping.allMappings.values)
        #expect(mappedChars == allAlphabetChars)
    }

    // MARK: - マッピングの一意性

    @Test("each keyCode maps to a unique character")
    func eachKeyCodeMapsToUniqueChar() {
        let values = Array(KeyCodeMapping.allMappings.values)
        let uniqueValues = Set(values)
        #expect(values.count == uniqueValues.count)
    }

    @Test("total mapping count is 26")
    func mappingCountIs26() {
        #expect(KeyCodeMapping.allMappings.count == 26)
    }
}
