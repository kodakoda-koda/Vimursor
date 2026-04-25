# Contributing to Vimursor

## Development Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor
git checkout develop
swift build
```

### 2. Accessibility Permission Setup

Vimursor uses the macOS Accessibility API, so accessibility permission is required on the first launch.

1. Run `.build/debug/Vimursor` — a permission dialog will appear
2. Open "System Settings" → "Privacy & Security" → "Accessibility"
3. Enable `Vimursor` or Terminal (if running via `swift run`)
4. Restart the app after granting permission

The app can still launch without permission, but AXUIElement operations (element enumeration and clicking) will fail.

### 3. Build Commands

```bash
swift build                        # Debug build
swift build -c release             # Release build
swift test                         # Run tests
swift test --enable-code-coverage  # Run tests with coverage
.build/debug/Vimursor              # Run debug build
```

---

## Architecture Overview

### Directory Structure

```
Sources/Vimursor/
├── main.swift               # Entry point
├── AppDelegate.swift        # Lifecycle management, permission check
├── HotkeyManager.swift      # Global hotkeys via CGEventTap
├── Accessibility/           # AXUIElement wrapper, UI element enumeration
├── Overlay/                 # NSPanel, label generation
├── HintMode/                # Hint mode control and rendering
├── SearchMode/              # Search mode control and UI
└── ScrollMode/              # Scroll mode control
```

### Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `AppDelegate` | Permission check on launch, menu bar icon management |
| `HotkeyManager` | Captures global key events via `CGEventTap` and activates each mode |
| `Accessibility/AXManager` | Enumerates clickable and searchable elements via `AXUIElement`, performs clicks |
| `Overlay/LabelGenerator` | Generates label strings (`a`, `b`, ..., `aa`, `ab`, ...) based on element count |
| `Overlay/OverlayWindow` | Creates and positions overlay windows using `NSPanel` |
| `HintMode/HintModeController` | Manages hint mode state (start → label display → key input → click → exit) |
| `SearchMode/SearchModeController` | Manages search mode state, text filtering (pure functions) |
| `ScrollMode/` | Manages scroll mode state, detects scrollable regions |

### Processing Flow (Hint Mode)

```
Cmd+Shift+Space
  → HotkeyManager
  → HintModeController.start()
  → AXManager.fetchClickableElements()
  → LabelGenerator.generate(count:)
  → OverlayWindow + HintView (label rendering)
  → Key input for filtering
  → Exact match → AXUIElementPerformAction("AXPress")
  → Close overlay
```

---

## Code Style Guidelines

Key rules are listed below.

### Prefer Immutability

- Use `struct` (value types) over `class`
- Use `let` over `var`

```swift
// Preferred
struct Config {
    let labels: [String]
}

// Not preferred
class Config {
    var labels: [String] = []
}
```

### File and Function Size

- Functions should be **50 lines or fewer**
- Files should typically be **200–400 lines**, with a **hard limit of 800 lines**
- Split files by feature or responsibility when they grow too large

### Error Handling

- Always check `AXError` returned by `AXUIElement`
- Force unwrapping (`!`) is prohibited — use `guard let` / `if let`
- Silent failures (swallowing errors) are prohibited

### Other

- Group constants such as key codes at the top of the file (no magic numbers)
- All UI operations must run on `DispatchQueue.main.async`
- Use `[weak self]` in delegates and closures to prevent retain cycles

---

## Testing Policy

Details are described below.

### TDD Flow

All implementation must follow a test-first approach.

1. **RED** — Write a failing test
2. **GREEN** — Write the minimal implementation to make it pass
3. **REFACTOR** — Improve the code while keeping tests green

```bash
swift test   # Verify RED / GREEN
```

### Test Classification

| Target | Approach |
|--------|----------|
| Pure logic (`LabelGenerator`, `SearchModeController.filter`, etc.) | Unit tests with Swift Testing |
| `AXUIElement` calls | Wrap with protocol and substitute a mock |
| `NSPanel` / `CGEventTap` | Manual testing (system-dependent) |

### Test Framework

Use **Swift Testing**, not `XCTest`.

```swift
import Testing
@testable import Vimursor

@Suite("LabelGenerator Tests")
struct LabelGeneratorTests {
    @Test("generates correct count of labels")
    func generatesCorrectCount() {
        let labels = LabelGenerator.generate(count: 5)
        #expect(labels.count == 5)
    }
}
```

### Coverage Target

Maintain **80% or above**.

```bash
swift test --enable-code-coverage
```

---

## Issue Management

Development is driven by GitHub Issues.

| Label | Purpose | Example Title |
|-------|---------|---------------|
| `epic` | Feature group / milestone | `[Epic 3] Distribution Infrastructure` |
| `task` | Individual implementation task (child of Epic) | `[3-1] Create .app bundle` |
| `memo` | Technical knowledge / research notes | `[memo] AX coordinate system conversion` |
| `bug` | Bug report | `[bug] Hint labels not displayed` |
| `enhancement` | Feature request | `[request] Dark mode support` |

Link the corresponding Issue number to each PR.

---

## Branch Strategy

```
main           ── Stable released version
  └─ develop   ── Development integration branch
       ├─ feature/epic<N>-<name>  ── Feature branch (per Epic)
       ├─ fix/<name>              ── Bug fix branch
       └─ docs/<name>             ── Documentation branch
```

### Standard Development Flow (feature → develop)

```bash
# 1. Create a working branch from develop
git checkout develop
git checkout -b feature/epic3-distribution

# 2. Implement and commit
git commit -m "feat: Add my feature"

# 3. Open a PR to develop
git push -u origin feature/epic3-distribution
# Create PR on GitHub → Review → Squash merge
```

### Release Flow (develop → release → main)

```bash
# 1. Create a release branch from develop
git checkout develop
git checkout -b release/v1.0

# 2. Open a PR from release to main
git push -u origin release/v1.0
# Create PR on GitHub → Review → Squash merge

# 3. Tag main
git checkout main
git pull
git tag v1.0
git push origin v1.0
```

---

## Commit Messages

```
<type>: <description>
```

| type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Refactoring |
| `docs` | Documentation-only changes |
| `test` | Adding or updating tests |
| `chore` | Build configuration, tooling, etc. |
| `perf` | Performance improvement |

---

## PR Guidelines

### PR Scope

- **PRs are grouped per Epic** (not per individual task)
- `feature/**` / `fix/**` / `docs/**` → PR targets `develop`
- `release/**` → PR targets `main`

### Merge Strategy

All PRs are merged via **squash merge**.

### PR Title and Body

- Title follows the same format as commit messages (`feat: ...`)
- List the related Issues in the body using `Closes #XX` (auto-closed after squash merge)
- Include the Epic Issue itself in the `Closes #N` list

### PR Template Selection

| Use case | Template | How to use |
|----------|----------|------------|
| Targeting `develop` (standard development) | `.github/pull_request_template.md` | Default when creating a PR |
| Targeting `main` (release) | `.github/PULL_REQUEST_TEMPLATE/release.md` | Append `?template=release.md` to the PR URL |

When creating a release PR, add `?template=release.md` to the GitHub URL:

```
https://github.com/kodakoda-koda/Vimursor/compare/main...release/v1.0?template=release.md
```
