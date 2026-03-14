struct LabelGenerator {
    private static let chars = "fjrieodksla;nvmc"

    static func generateLabels(count: Int) -> [String] {
        guard count > 0 else { return [] }

        var labels: [String] = []

        // 1文字ラベル
        for char in chars {
            guard labels.count < count else { break }
            labels.append(String(char))
        }

        // 2文字ラベル（足りない場合）
        if labels.count < count {
            for first in chars {
                for second in chars {
                    guard labels.count < count else { break }
                    labels.append(String(first) + String(second))
                }
                if labels.count >= count { break }
            }
        }

        return labels
    }
}
