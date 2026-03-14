---
description: Enforce test-driven development workflow. Scaffold interfaces, generate tests FIRST, then implement minimal code to pass. Ensure 80%+ coverage.
---

# TDD Command

This command invokes the **tdd-guide** agent to enforce test-driven development methodology.

## What This Command Does

1. **Scaffold Interfaces** - Define function signatures / dataclasses first
2. **Generate Tests First** - Write failing tests (RED)
3. **Implement Minimal Code** - Write just enough to pass (GREEN)
4. **Refactor** - Improve code while keeping tests green (REFACTOR)
5. **Verify Coverage** - Ensure 80%+ test coverage

## When to Use

Use `/tdd` when:
- Implementing new features
- Adding new functions or modules
- Fixing bugs (write test that reproduces bug first)
- Refactoring existing code

## TDD Cycle

```
RED → GREEN → REFACTOR → REPEAT

RED:      Write a failing test
GREEN:    Write minimal code to pass
REFACTOR: Improve code, keep tests passing
REPEAT:   Next feature/scenario
```

## Example Usage

```
User: /tdd I need a function to select the highest-scored item from a list

Agent (tdd-guide):
# TDD Session: Select Top Item

## Step 1: Define Interface (SCAFFOLD)

# src/mypackage/selector.py
from dataclasses import dataclass

@dataclass(frozen=True)
class Item:
    id: str
    title: str
    score: int

def select_top(items: list[Item]) -> Item:
    raise NotImplementedError

## Step 2: Write Failing Test (RED)

# tests/unit/test_selector.py
import pytest
from mypackage.selector import Item, select_top

def test_select_top_returns_highest_score():
    items = [
        Item(id="a", title="A", score=5),
        Item(id="b", title="B", score=20),
        Item(id="c", title="C", score=3),
    ]
    result = select_top(items)
    assert result.id == "b"

def test_select_top_empty_list_raises():
    with pytest.raises(ValueError):
        select_top([])

def test_select_top_single_item():
    items = [Item(id="a", title="A", score=1)]
    result = select_top(items)
    assert result.id == "a"

## Step 3: Run Tests - Verify FAIL

pytest tests/unit/test_selector.py
# 3 failed ✅ Tests fail as expected.

## Step 4: Implement Minimal Code (GREEN)

def select_top(items: list[Item]) -> Item:
    if not items:
        raise ValueError("Cannot select from empty list")
    return max(items, key=lambda item: item.score)

## Step 5: Run Tests - Verify PASS

pytest tests/unit/test_selector.py
# 3 passed ✅

## Step 6: Verify Coverage

pytest --cov=src --cov-report=term-missing tests/unit/test_selector.py
# src/mypackage/selector.py   100%  ✅
```

## TDD Best Practices

**DO:**
- ✅ Write the test FIRST, before any implementation
- ✅ Run tests and verify they FAIL before implementing
- ✅ Write minimal code to make tests pass
- ✅ Refactor only after tests are green
- ✅ Mock external dependencies (HTTP APIs, file system, etc.)

**DON'T:**
- ❌ Write implementation before tests
- ❌ Skip running tests after each change
- ❌ Write too much code at once
- ❌ Test implementation details (test behavior, not internals)

## Coverage Requirements

- **80% minimum** for all code
- **100% required** for core business logic

## Related Agents

This command invokes the `tdd-guide` agent and references the `tdd-workflow` skill.
