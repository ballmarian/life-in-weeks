# Life in Weeks

A native macOS app that renders your life as a grid of weeks, from birth to age
90 — one row per year, one cell per week, after Tim Urban's
[Life in Weeks](https://waitbutwhy.com/2014/05/life-weeks.html). Each week can
carry a markdown note and an emoji; arbitrary date ranges can be painted as
colour-coded "chapters" behind the grid. Everything lives in plain, readable
files on disk: no database, no server, no account. A menu bar extra lets you log
the current week without opening the map.

![The map at default zoom](design-guidance/screenshots/01-grid-default-M-life-year.png)

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later — the **Command Line Tools alone are enough**
  (`xcode-select --install`). Full Xcode is not required; the app is built and
  bundled by a script rather than an `.xcodeproj`.

## Building

```sh
./Scripts/build-app.sh release     # → dist/LifeInWeeks.app
```

Drag `dist/LifeInWeeks.app` to `/Applications`, or run it where it is. The
script ad-hoc signs the bundle, which is all a locally built app needs — there
is no notarization step and no Apple Developer Program membership involved
(see the distribution note below).

To run the test suite:

```sh
./Scripts/test.sh
```

The tests are written against swift-testing. On a machine with only the Command
Line Tools installed, plain `swift test` compiles SwiftPM's generated runner
with `canImport(Testing)` false and exits having run nothing, so use the script;
it adds the one search path that fixes this. With Xcode installed, `swift test`
works directly.

## First launch

There is no configuration to edit by hand. On first launch the app asks for:

- **A storage folder** — a folder of its own (`~/Documents/LifeInWeeks` is
  offered), or a path inside an existing Obsidian vault. Only this folder is
  ever read or watched, never the rest of a vault.
- **Your name, birth date, and the age to draw through** (90 by default).

It then creates:

```
LifeInWeeks/
├── config.yaml     name, birth_date, end_age
├── blocks.yaml     chapter ranges: start, end, colour, title
└── weeks/
    ├── 2011-06-13.md
    └── 2026-09-07.md
```

Week files are named for their Monday, and **that filename is the only thing
that decides which week a note belongs to** — never a field in the file, never
its timestamp. Files are created lazily: a week has a file only once it has
something in it, and clearing a week deletes its file again.

The archive is yours. Delete the app and the files are unaffected; the folder is
git-friendly, syncs through whatever already syncs your vault, and can be read
by anything that reads markdown.

## Using it

- **Click** a cell to select that week; the inspector on the right shows it.
  Click the note (or **Edit week**) to write. Any week, past or future.
- **Drag** across the grid to mark a chapter. The selection is the contiguous
  run of weeks between where you pressed and where you released — not a
  rectangle — so it reproduces the banner shape from the original article.
  Right-click a chapter in the sidebar to edit or delete it.
- **Hover** a week to see its date, your age, and its ISO week. Where two
  chapters overlap, hovering reveals the newer, nested one across its whole
  extent; the older one keeps painting the background.
- **Life Year / Calendar Year** re-groups the same weeks into different rows.
  It is display-only and never moves a file.
- **S / M / L** change grid density. S fits a whole life on one screen; L is
  emoji-forward. The layout and zoom you last used are remembered.
- The **menu bar icon** gives you a quick note appended to this week, a jump
  straight into editing it, and a way back to the map.

## Layout

- `Sources/LifeInWeeksCore` — pure Swift, no UI framework: week arithmetic, the
  two row groupings, the file format, chapter overlap resolution, and file I/O.
  All of it is unit-tested.
- `Sources/LifeInWeeksApp` — SwiftUI: the map window, the `Canvas`-drawn grid,
  the menu bar scene, and the folder watcher.
- `Tests/LifeInWeeksCoreTests` — the suite for the above.
- `design-guidance/` — the product requirements and the design handoff this was
  built from.

## Distribution

Personal software, shared as source. If a friend wants it, hand them this repo
and let them build it — a locally built app is trusted by the machine that built
it, whereas a pre-built `.app` downloaded from a release page gets quarantined
and hits Gatekeeper all the same. That trade avoids code signing, notarization,
and the annual Developer Program fee entirely.

No analytics, no telemetry, no network calls of any kind.
