struct LabelGenerator {
    private static let chars = "fjrieodkslapnvmc"  // `;` → `p` に変更

    static func generateLabels(count: Int) -> [String] {
        guard count > 0 else { return [] }

        // count が chars 数以下なら全部1文字ラベル（prefix 競合なし）
        if count <= chars.count {
            return chars.prefix(count).map { String($0) }
        }

        // count が多い場合は全部2文字ラベル（最大 16×16 = 256）
        var labels: [String] = []
        for first in chars {
            for second in chars {
                guard labels.count < count else { break }
                labels.append(String(first) + String(second))
            }
            if labels.count >= count { break }
        }
        return labels
    }
}
