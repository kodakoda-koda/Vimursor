# Security Policy

## Supported Versions

Vimursor has not yet reached an official release. All development is ongoing on the `main` branch.

| Version | Supported |
|---------|-----------|
| pre-release (development) | Yes (active development) |

Once a stable release is published, this table will be updated to reflect the supported version range.

## Reporting a Vulnerability

Please use **GitHub Security Advisories** to report security vulnerabilities privately.

1. Navigate to the [Security tab](../../security/advisories) of this repository.
2. Click **"Report a vulnerability"**.
3. Fill in the details: affected component, reproduction steps, potential impact, and any suggested fix.

Do not open a public GitHub Issue for security vulnerabilities, as it may expose the issue before a fix is available.

### Response Timeline

| Step | Target timeframe |
|------|-----------------|
| Acknowledgement | Within 3 business days |
| Initial assessment | Within 7 business days |
| Fix and disclosure | As soon as a patch is ready (coordinated with reporter) |

If you do not receive a response within the timeframe above, feel free to follow up on the same Security Advisory thread.

## Security Considerations

Vimursor uses macOS Accessibility APIs and global event monitoring. The following points are important for users and security researchers:

### Accessibility API Usage

- Vimursor requests **Accessibility permission** (System Settings > Privacy & Security > Accessibility) to enumerate on-screen UI elements and simulate mouse clicks.
- This permission must be **explicitly granted by the user**; Vimursor will not function without it.
- Access is scoped to read-only enumeration of UI element attributes and performing click actions — no data is written to other applications.

### Global Key Event Monitoring

- Vimursor uses **KeyboardShortcuts** (Carbon hotkey API) for mode activation (e.g., Cmd+Shift+Space) and a **CGEventTap** to consume key events while a mode is active.
- Only the configured shortcuts and in-mode key events are consumed; all other key events are passed through unmodified.
- No keystrokes are logged or stored.

### No Network Communication

- Vimursor does **not** make any network requests.
- No user data, usage statistics, or telemetry is collected or transmitted to external servers.

### Sandboxing

- Vimursor is distributed **outside the Mac App Store** and runs without an App Sandbox, which is required to use the Accessibility API.
- Users should obtain Vimursor only from the official repository or a trusted release channel to avoid tampered binaries.
