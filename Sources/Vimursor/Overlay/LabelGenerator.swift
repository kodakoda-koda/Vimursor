struct LabelGenerator {
    static let defaultCharacterSet = AppSettings.Defaults.hintCharacterSet

    /// 指定した文字セットを使ってラベルを生成する。
    /// - Parameters:
    ///   - count: 生成するラベルの数
    ///   - characterSet: 使用する文字セット（デフォルト: "fjrieodkslapnvmc"）
    static func generateLabels(count: Int, characterSet: String = defaultCharacterSet) -> [String] {
        let chars = characterSet.isEmpty ? defaultCharacterSet : characterSet
        guard count > 0 else { return [] }
        let clampedCount = min(count, chars.count * chars.count)

        // count が chars 数以下なら全部1文字ラベル（prefix 競合なし）
        if clampedCount <= chars.count {
            return chars.prefix(clampedCount).map { String($0) }
        }

        // count が多い場合は全部2文字ラベル（最大 N×N）
        var labels: [String] = []
        for first in chars {
            for second in chars {
                guard labels.count < clampedCount else { break }
                labels.append(String(first) + String(second))
            }
            if labels.count >= clampedCount { break }
        }
        return labels
    }
}
