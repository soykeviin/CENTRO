# Contributing to CENTRO

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Running locally

1. Xcode 26 or later.
2. `open CENTRO.xcodeproj` and Run.

Your real data lives in `~/Library/Application Support/CENTRO/`. If you are changing how data is saved or loaded, back that folder up first. CENTRO also keeps automatic backups in `respaldos/` inside it.

## Code notes

- The target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Anything that runs `git`, `npm`, `lsof` or reads project files must live in a `nonisolated` type (see `GitService`, `Insights`, `IconCache`), or it will run on the main thread and freeze the UI.
- Many users keep projects in iCloud-synced folders. Never read files from project folders on the main thread.
- Persisted JSON formats must stay backward compatible: add new fields as optionals.

## Adding a language

The UI source language is Spanish. Strings live in `CENTRO/Localizable.xcstrings` (String Catalog).

1. In Xcode, open `Localizable.xcstrings`, click **+** and add your language.
2. Translate the strings (you can also edit `InfoPlist.xcstrings`).
3. Add the language code to `CFBundleLocalizations` in `CENTRO/Info.plist` and to the `AppLanguage` enum in `LaunchActions.swift`, so it appears in the language picker.
4. Open a pull request.

New UI text: write it in Spanish inside `Text("...")`, `Label`, `Button`, or `String(localized: "...")` so Xcode can extract it, then add the English translation.

## Pull requests

- Keep them focused on one change.
- Describe what you changed and how you tested it.
