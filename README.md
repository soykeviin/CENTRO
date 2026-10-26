<p align="center">
  <img src="docs/icon.png" width="128" alt="CENTRO icon">
</p>

<h1 align="center">CENTRO</h1>

<p align="center">
  <b>A native macOS home for all your code projects.</b><br>
  Find any project in a keystroke and open it in Claude Code, your editor, the terminal or Finder.
</p>

<p align="center">
  <a href="https://github.com/soykeviin/CENTRO/releases/latest"><img src="https://img.shields.io/github/v/release/soykeviin/CENTRO?label=download&color=B14EFF" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-black" alt="macOS 15+">
  <img src="https://img.shields.io/badge/SwiftUI-native-orange" alt="SwiftUI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT"></a>
</p>

<p align="center">
  <a href="README.es.md">Leer en español</a>
</p>

<p align="center">
  <img src="docs/demo.gif" width="560" alt="Menu bar search: type a few letters and open the project in Claude Code">
</p>

<p align="center">
  <img src="docs/screenshot-main.jpg" width="820" alt="CENTRO main window">
</p>

---

If you have dozens (or hundreds) of side projects, client work and experiments scattered across folders, CENTRO keeps them in one dashboard: searchable, categorized, with their git state and stack visible at a glance, and one click away from whatever tool you use to work on them.

It was built for a daily workflow with **Claude Code**: pick a project and a terminal opens in its folder with `claude` already running.

## Features

**Find and open projects fast**
- **Menu bar search**: click the magnifying glass in the menu bar, type a name, and open the project with one click on the tool's logo. Press Enter to use your first option. Works even when the main window is closed.
- **Command palette** (`⌘K`) to jump to any project, section or action.
- **Configurable launchers**: Claude Code, Terminal or iTerm2, Finder, Cursor, VS Code, Antigravity, the Claude app, or your own shell commands. Choose which buttons appear on each card and in the menu bar search.
- **Your Claude Code command**: defaults to `claude --dangerously-skip-permissions`. Change it to `claude`, `claude --continue` or anything else.

**Organize**
- Add a folder that contains your projects (new subfolders are picked up automatically) or add projects one by one.
- Categories and subcategories, favorites, pinning, custom names, notes, hide or remove (files on disk are never touched).
- Drag files onto CENTRO to copy or move them into any project.

**See what's going on**
- Detected stack (Node, React, Vite, Swift, Python and more), git branch and dirty state, health hints (missing `node_modules`, missing `.env`).
- **Home**: running dev servers and their ports, projects with uncommitted changes, recents.
- **Activity** heatmap from your commits, **Daily digest** of today's commits, **Outdated deps** (`npm outdated`) across projects.
- Project page with file browser, README preview, git panel (commit, pull, push, branches) and smart actions from `package.json` scripts.
- Built-in dev server runner with live logs.

**Productivity**
- Time tracking per project with a live timer in the menu bar.
- Tasks and an inbox for quick capture.
- GitHub: list and clone your repos, or publish a local folder as a new repo (uses the official `gh` CLI).

**Native and private**
- SwiftUI, fast with hundreds of projects.
- English and Spanish, chosen on first launch.
- No account, no telemetry, no network calls of its own. Everything lives in `~/Library/Application Support/CENTRO/`, with an automatic backup on every launch.

## Install

1. Download `CENTRO-x.y.z.dmg` from the [latest release](https://github.com/soykeviin/CENTRO/releases/latest).
2. Open it and drag **CENTRO** to **Applications**.
3. The first time you open it, macOS will block it because the app is not notarized by Apple yet:
   - Open **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to CENTRO.
   - Or run once in the terminal: `xattr -dr com.apple.quarantine /Applications/CENTRO.app`
4. On first launch pick your language and how you want to open projects. You can change everything later in **Settings**.

To launch projects in Terminal or iTerm2, macOS will ask you once to allow CENTRO to control that app.

### Requirements

- macOS 15 Sequoia or later. On macOS 26 Tahoe it uses the Liquid Glass look.
- Optional: [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), [GitHub CLI](https://cli.github.com) (`brew install gh`) for the GitHub section, Node/npm for the outdated deps check.

## Build from source

Requires Xcode 26 or later.

```bash
git clone https://github.com/soykeviin/CENTRO.git
cd CENTRO
open CENTRO.xcodeproj   # then press Run
```

To produce the universal `.dmg` and `.zip` for a release:

```bash
./scripts/build-release.sh   # outputs to dist/
```

## Where is my data?

```
~/Library/Application Support/CENTRO/
  config.json      folders, categories, custom actions
  metadata.json    favorites, names, notes per project
  prefs.json       launchers, Claude command, terminal
  respaldos/       automatic backups (last 30 launches)
```

Removing a project from CENTRO never deletes anything from disk.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), including how to add a new language.

## License

[MIT](LICENSE) © Kevin Caballero
