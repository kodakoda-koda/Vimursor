# Coding Style

## Immutability (CRITICAL)

Swift では `class`（参照型）より `struct`（値型）を優先し、`var` より `let` を優先する:

```swift
// WRONG: class + var で外部から状態が変更可能
class Config {
    var labels: [String] = []
}

// CORRECT: struct + let でイミュータブル
struct Config {
    let labels: [String]
}
```

Rationale: 値型はコピーセマンティクスにより隠れた副作用を防ぎ、スレッド安全性が高まる。

## File Organization

MANY SMALL FILES > FEW LARGE FILES:
- High cohesion, low coupling
- 200-400 lines typical, 800 max
- Extract utilities from large modules
- Organize by feature/domain（Overlay/, HintMode/, ScrollMode/ 等）

## Error Handling

ALWAYS handle errors comprehensively:
- AXUIElement の戻り値（`AXError`）を必ず確認する
- UI向けコードではユーザーフレンドリーなエラーメッセージを表示する
- 失敗を握りつぶさない（silent failure 禁止）

## Input Validation

ALWAYS validate at system boundaries:
- AXUIElement から取得した値（座標・サイズ等）はゼロチェックを行う
- キーイベントのキーコードは定数で管理し、マジックナンバーを使わない
- 外部データ（AXUIElement属性値）は信頼しない

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] AXError / Optional のハンドリングが適切
- [ ] No hardcoded values（キーコードは定数、座標はAXから取得）
- [ ] `struct` / `let` でイミュータブルを優先
- [ ] UI操作は必ず `DispatchQueue.main` で実行
