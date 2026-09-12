# Life in Weeks

A native macOS app that renders your life as a grid of weeks, from birth to age 90 — one row per year, one cell per week, based on Tim Urban's [Life in Weeks](https://waitbutwhy.com/2014/05/life-weeks.html) article. Each week can carry a markdown note and an emoji; arbitrary date ranges can be painted as colour-coded "chapters" behind the grid. Everything lives in plain, readable files on disk: no database, no server, no account, no analytics. A menu bar extra lets you log the current week without opening the map.

This app isn't distributed as a ready-made download — you build it yourself, on your own Mac, from this source code. That sounds intimidating if you've never done it before, but it's about ten minutes of copy-pasting a few commands into an app called Terminal. The steps below assume you've never used Terminal and walk through every click.

## What you'll need

- A Mac running macOS 13 (Ventura) or later.
- About 15 minutes and an internet connection (to download some free
  developer tools from Apple, one time only).

You do **not** need to buy anything, sign up for an Apple Developer account, or install the full Xcode application (though it's fine if you already have it).

## Step 1: Get the project files onto your Mac

If someone sent you a link to this project's page (for example on GitHub),
look for a green **Code** button, click it, then click **Download ZIP**.
Once it downloads, double-click the ZIP file to unzip it — you'll get a
folder called something like `life-in-weeks`. Move that folder somewhere
you'll remember, like your Desktop.

*(If you already know what `git clone` is, feel free to use that instead.)*

## Step 2: Open Terminal

Terminal is a built-in Mac app for typing commands. To open it:

1. Press `Cmd + Space` to open Spotlight search.
2. Type `Terminal` and press `Return`.

A plain window with a blinking cursor will appear. That's it — that's
Terminal.

## Step 3: Point Terminal at the project folder

In Terminal, type `cd ` (with a trailing space) — **don't press Return
yet**. Then, using Finder, drag the `life-in-weeks` folder from Step 1
straight into the Terminal window. Its full path will appear after `cd `.
Now press `Return`. Terminal is now "inside" the project folder.

## Step 4: Install Apple's Command Line Tools (one time only)

This project needs Apple's Swift compiler to build. You almost certainly
already have it if you've ever installed developer tools before; if not,
type this into Terminal and press `Return`:

```sh
xcode-select --install
```

A window will pop up asking to install the "Command Line Tools" — click
**Install**, accept the license, and wait for it to finish (a few minutes).
If Terminal instead says something like "command line tools are already
installed," that's fine — skip ahead to Step 5.

You do not need to install the full Xcode app from the App Store for this
project.

## Step 5: Build the app

Back in Terminal (still inside the project folder from Step 3), copy and
paste this command and press `Return`:

```sh
./Scripts/build-app.sh release
```

You'll see some text scroll by as it compiles — this can take a minute or
two the first time. When it's done, it will print:

```
Built dist/LifeInWeeks.app
```

That's the finished app.

## Step 6: Move it into place and open it

1. In Finder, open the project folder, then open the `dist` folder inside
   it. You'll see `LifeInWeeks.app`.
2. Drag `LifeInWeeks.app` into your **Applications** folder (or just leave
   it in place and double-click it there — either works).
3. Double-click `LifeInWeeks.app` to open it.

Because this app was built on your own Mac rather than downloaded
pre-built and signed by Apple, macOS may show a warning the first time you
open it, saying it's from an "unidentified developer." If that happens:
**right-click** (or Control-click) `LifeInWeeks.app` and choose **Open**
from the menu, then click **Open** again in the dialog that appears. You
only need to do this once — after that, it opens normally with a regular
double-click.

The app doesn't appear in the Dock or app switcher — it's a menu bar app,
so look for its icon in the row of icons at the top-right of your screen,
near the clock.

## Updating later

If you download a newer version of the project files, just repeat Steps 3,
5, and 6 — you can skip Steps 2 and 4 since Terminal and the Command Line
Tools are already set up.

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

## If something goes wrong

- **"xcrun: error" or Swift-related errors during build** — reopen Terminal
  and try Step 4 again; the Command Line Tools may not have finished
  installing.
- **The build command says "No such file or directory"** — you're not inside
  the project folder. Redo Step 3, making sure you drag the folder icon
  itself (not a file inside it) into Terminal.
- **macOS still refuses to open the app after right-click → Open** — go to
   **System Settings → Privacy & Security**, scroll down, and look for a
   message about `LifeInWeeks.app` being blocked, with an **Open Anyway**
   button next to it.
- Still stuck? Re-running `./Scripts/build-app.sh release` from Step 5 is
  always safe — it rebuilds from scratch and won't touch your saved weeks,
  which live entirely in the storage folder you chose on first launch.

## For developers

The sections below are for anyone modifying the source code rather than
just running the app.

### Running the test suite

```sh
./Scripts/test.sh
```

The tests are written against swift-testing. On a machine with only the Command
Line Tools installed, plain `swift test` compiles SwiftPM's generated runner
with `canImport(Testing)` false and exits having run nothing, so use the script;
it adds the one search path that fixes this. With Xcode installed, `swift test`
works directly.

### Layout

- `Sources/LifeInWeeksCore` — pure Swift, no UI framework: week arithmetic, the
  two row groupings, the file format, chapter overlap resolution, and file I/O.
  All of it is unit-tested.
- `Sources/LifeInWeeksApp` — SwiftUI: the map window, the `Canvas`-drawn grid,
  the menu bar scene, and the folder watcher.
- `Tests/LifeInWeeksCoreTests` — the suite for the above.

## Distribution

Personal software, shared as source. If a friend wants it, hand them this repo
and let them build it — a locally built app is trusted by the machine that built
it, whereas a pre-built `.app` downloaded from a release page gets quarantined
and hits Gatekeeper all the same. That trade avoids code signing, notarization,
and the annual Developer Program fee entirely.

No analytics, no telemetry, no network calls of any kind.
