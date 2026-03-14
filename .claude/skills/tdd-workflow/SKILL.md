---
name: tdd-workflow
description: Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage including unit and integration tests.
---

# Test-Driven Development Workflow

This skill ensures all code development follows TDD principles with comprehensive test coverage.

## When to Activate

- Writing new features or functionality
- Fixing bugs or issues
- Refactoring existing code
- Adding new modules or functions

## Core Principles

### 1. Tests BEFORE Code
ALWAYS write tests first, then implement code to make tests pass.

### 2. Coverage Requirements
- Minimum 80% coverage (unit + integration)
- All edge cases covered
- Error scenarios tested
- Boundary conditions verified

### 3. Test Types

#### Unit Tests
- Individual functions and utilities
- Pure functions, parsers, data transformations
- Helpers and utilities

#### Integration Tests
- External API calls (with mocks)
- File I/O operations

---

## TDD Workflow Steps

### Step 1: Write User Journey
```
As a [role], I want to [action], so that [benefit]
```

### Step 2: Generate Test Cases

```python
import pytest

def test_happy_path():
    ...

def test_empty_input_raises():
    ...

def test_network_error_propagates():
    ...
```

### Step 3: Run Tests (They Should Fail)
```bash
pytest
# Tests should fail — implementation not written yet
```

### Step 4: Implement Code
Write minimal code to make tests pass.

### Step 5: Run Tests Again
```bash
pytest
# Tests should now pass
```

### Step 6: Refactor
Improve code quality while keeping tests green.

### Step 7: Verify Coverage
```bash
pytest --cov=src --cov-report=term-missing
# Verify 80%+ coverage achieved
```

---

## Testing Patterns

### Unit Test Pattern

```python
import pytest
from mypackage.parser import parse_items

def test_parse_items_returns_expected_count():
    raw = [{"title": "A", "url": "https://a"}, {"title": "B", "url": "https://b"}]
    items = parse_items(raw, limit=2)
    assert len(items) == 2

def test_parse_items_empty_input_returns_empty():
    items = parse_items([], limit=10)
    assert items == []

def test_parse_items_extracts_title_and_url():
    raw = [{"title": "A", "url": "https://a"}]
    items = parse_items(raw, limit=1)
    assert items[0].title == "A"
    assert items[0].url == "https://a"
```

### Integration Test Pattern (external API with mock)

```python
import pytest
import httpx
from unittest.mock import patch, MagicMock
from mypackage.fetcher import fetch_items

def test_fetch_items_returns_parsed_results():
    mock_response = MagicMock()
    mock_response.json.return_value = [
        {"id": "1", "title": "Item A", "score": 5},
        {"id": "2", "title": "Item B", "score": 20},
    ]
    mock_response.raise_for_status = MagicMock()

    with patch("mypackage.fetcher.httpx.get", return_value=mock_response):
        result = fetch_items()

    assert len(result) == 2

def test_fetch_items_network_error_raises():
    with patch("mypackage.fetcher.httpx.get", side_effect=httpx.RequestError("timeout")):
        with pytest.raises(httpx.RequestError):
            fetch_items()
```

### Mocking: Use `unittest.mock` (standard library, preferred)

依存を最小化するため `unittest.mock` を優先する。`pytest-mock` は依存追加が必要なため、特別な理由がない限り使わない。

```python
# PREFERRED: unittest.mock (no extra dependency)
from unittest.mock import patch, MagicMock

with patch("mypackage.client.httpx.get") as mock_get:
    mock_get.return_value = MagicMock(json=lambda: {"data": []})
    result = my_function()
```

### pytest-mock pattern (optional — requires `pytest-mock` in pyproject.toml)

```python
def test_summarize_calls_api(mocker):
    mock_client = mocker.patch("mypackage.summarizer.ApiClient")
    mock_client.return_value.call.return_value = "summary text"

    result = summarize("original text")

    assert result == "summary text"
    mock_client.return_value.call.assert_called_once()
```

### Fixture Pattern

```python
import pytest
from pathlib import Path

@pytest.fixture
def sample_config_file(tmp_path: Path) -> Path:
    config = tmp_path / "config.json"
    config.write_text('{"key": "value"}')
    return config

def test_load_config_reads_key(sample_config_file: Path):
    from mypackage.config import load_config
    config = load_config(sample_config_file)
    assert config["key"] == "value"
```

---

## Test File Organization

```
tests/
├── unit/
│   ├── test_parser.py       # 純粋関数・データ変換
│   ├── test_fetcher.py      # API レスポンス処理
│   └── test_selector.py     # ビジネスロジック
└── integration/
    ├── test_fetcher_integration.py   # HTTP API 呼び出し（モック）
    └── test_writer_integration.py    # ファイル I/O（tmp_path）
```

---

## Edge Cases You MUST Test

1. **None / empty** input（空のリスト、空文字列）
2. **Invalid types**（予期しないデータ型・フォーマット）
3. **Network errors**（タイムアウト、接続エラー）
4. **API errors**（rate limit、認証エラー、5xx）
5. **File not found**（ファイルが存在しない場合）
6. **Encoding issues**（マルチバイト文字の扱い）

---

## Coverage Verification

```bash
pytest --cov=src --cov-report=term-missing
pytest --cov=src --cov-report=html   # htmlcov/index.html で詳細確認
```

`pyproject.toml` で閾値を設定:
```toml
[tool.pytest.ini_options]
addopts = "--cov=src --cov-fail-under=80"
```

---

## Common Mistakes to Avoid

### ❌ Testing implementation details
```python
# Internal state をテストしない
assert obj._cache == {}
```

### ✅ Test observable behavior
```python
# 出力・副作用をテストする
assert process("input") == "expected output"
```

### ❌ Tests that depend on each other
```python
# 共有状態に依存するテストは書かない
```

### ✅ Independent tests with fixtures
```python
@pytest.fixture(autouse=True)
def reset_state():
    yield
    # cleanup here
```

---

**Remember**: Mock all external dependencies. Each test should be independent and deterministic.
