# Testing Requirements

## Minimum Test Coverage: 80%

Test Types (ALL required):
1. **Unit Tests** — 純粋なロジック関数（LabelGenerator、UIElementEnumeratorのフィルタロジック等）
2. **Integration Tests** — AXUIElement・CGEvent等のシステムAPI呼び出し（モックを使用）

Run tests with:
```bash
swift test
swift test --enable-code-coverage
```

## テスト対象の分類

| 対象 | テスト方法 |
|------|-----------|
| LabelGenerator など純粋ロジック | XCTest で単体テスト |
| AXUIElement 呼び出し | プロトコルでラップしてモック差し替え |
| NSPanel・CGEventTap | システム依存のため手動テスト |

## Test-Driven Development

MANDATORY workflow:
1. Write test first (RED)
2. Run test — it should FAIL: `swift test`
3. Write minimal implementation (GREEN)
4. Run test — it should PASS: `swift test`
5. Refactor (IMPROVE)
6. Verify coverage (80%+): `swift test --enable-code-coverage`

## Troubleshooting Test Failures

1. Use **developer** agent（TDD ガイド内蔵）
2. Check test isolation（XCTestCase は setUp/tearDown で状態をリセット）
3. Verify mocks are correct
4. Fix implementation, not tests (unless tests are wrong)

## Agent Support

- **developer** - Use PROACTIVELY for new features, enforces write-tests-first (TDD built-in)
