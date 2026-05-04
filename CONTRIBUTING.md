# Contributing to Vimursor

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor
git checkout main
swift build
```

### Accessibility Permission

Vimursor uses the macOS Accessibility API. On first launch:

1. Run `.build/debug/Vimursor`
2. Open "System Settings" → "Privacy & Security" → "Accessibility"
3. Enable `Vimursor` or Terminal
4. Restart the app

Without permission, UI element operations will fail.

---

## Architecture

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

---

## Making Changes

1. Create a branch from `main`
   ```bash
   git checkout main
   git checkout -b feature/my-change
   ```

2. Make your changes and add tests where applicable
   ```bash
   swift build   # Verify build
   swift test    # Run tests
   ```
   Code style is enforced by [SwiftLint](https://github.com/realm/SwiftLint) in CI. You can run it locally with `swiftlint lint`.

3. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
   ```bash
   git commit -m "feat: add my feature"
   ```

4. Push and open a PR targeting `main`
   ```bash
   git push -u origin feature/my-change
   ```

### Testing

- PRs should include tests for new features and bug fixes
- Use **Swift Testing** (`import Testing`, `@Test`, `#expect`)
- UI/system-dependent code (`NSPanel`, `CGEventTap`) can be tested manually

### Commit Types

| Type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Refactoring |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Build, tooling |

---

## Reporting Issues

- **Bugs**: Use the [Bug Report](https://github.com/kodakoda-koda/Vimursor/issues/new/choose) template
- **Feature ideas**: Open a [Feature Request](https://github.com/kodakoda-koda/Vimursor/issues/new?template=2_feature.yml)

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
