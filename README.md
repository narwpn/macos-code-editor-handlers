# macOS Code Editor Handlers

Set your preferred code editor as the default Finder opener for developer files on macOS.

---

## Quick Start

```sh
# Check status (defaults to code / VS Code)
swift run code-editor-handlers

# Preview changes
swift run code-editor-handlers set code --dry-run

# Apply changes
swift run code-editor-handlers set code -y
```

---

## Commands

| Command | Description |
| :--- | :--- |
| `status [editor]` | View which editor opens developer file types *(default)* |
| `set <editor>` | Set default opener for all 162 developer file types |
| `list` | List installed editors detected on this Mac |

### Flags
* `--dry-run` — Preview proposed changes without applying
* `-y`, `--yes` — Apply without interactive `y/N` confirmation
* `-v`, `--all` — List every individual extension

---

## Supported Editors

Auto-detects editors in `/Applications` and `~/Applications`:

* `antigravity` (or `ag`) — Antigravity IDE
* `vscode` (or `code`) — Visual Studio Code
* `cursor` — Cursor
* `zed` — Zed
* `windsurf` — Windsurf
* `sublime` — Sublime Text
* Custom path: `swift run code-editor-handlers set /path/to/Editor.app`

---

## Handled vs. Protected Files

* **Handled (162 types)**: Code (`.py`, `.ts`, `.rs`, `.go`, `.c`, `.zig`), configs (`.json`, `.yaml`, `.toml`, `.env`), scripts (`.sh`, `.zsh`), and docs (`.md`, `.txt`).
* **Protected (untouched)**: Web browsers (`.html`), vector images (`.svg`), Xcode projects (`.xcodeproj`), .NET solutions (`.sln`), and spreadsheets (`.csv`).

---

## Requirements

macOS 13+ · Swift 6.4+ (Xcode or Command Line Tools)
