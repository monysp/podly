# SpotDL GUI

A small, minimal macOS app that puts a native SwiftUI interface on top of [spotDL](https://github.com/spotDL/spotify-downloader). Type a song name or paste a Spotify link, press Return, and watch it download in a Now Playing–style card with cover art, title, artist and progress.

> Not affiliated with Spotify or the spotDL project.

## Features

- **One field for everything** – search by song name / artist, or paste a Spotify track, album or playlist link.
- **Now Playing card** – album art (with a soft blurred glow), title, artist — album, a progress bar, the current stage (*Finding song info → Searching → Downloading → Converting*), and `n of N` for albums and playlists.
- **Clear status, minimal UI** – one quiet line under the card says what happened and what you can do next (*Show in Finder*, *Try again*, *View log*).
- **Honest error handling** – detects `LookupError: No results found` even when spotDL exits with code 0, and tells you when song info couldn't be found.
- **Welcome screen** – shows your 3 most recent downloads (click to reveal in Finder) and a *Paste Spotify link* shortcut when your clipboard contains one.
- **No scrolling** – the Home screen is a single fixed layout.
- **Settings** – Light / Dark / System appearance and a custom download folder.
- **Log viewer** – full spotDL output, with a copy button.

## Requirements

| | |
|---|---|
| macOS | 13 Ventura or later |
| Xcode / Swift | Xcode 15+ (Swift 5.9+) recommended |
| [spotDL](https://github.com/spotDL/spotify-downloader) | installed and runnable from the command line |
| [FFmpeg](https://ffmpeg.org) | required by spotDL for audio conversion |

Install the dependencies:

```bash
python3 -m pip install spotdl
brew install ffmpeg          # or: spotdl --download-ffmpeg
```

Check that it works before using the app:

```bash
spotdl --version
```

The app looks for `spotdl` in these places, then falls back to `command -v spotdl` in a login shell:

```
/opt/homebrew/bin/spotdl
/usr/local/bin/spotdl
~/.local/bin/spotdl
~/Library/Python/3.12|3.13|3.14/bin/spotdl
```

## Build & run

The whole app is a single file, `main.swift`.

**Command line**

```bash
swiftc -parse-as-library -o SpotDLDownloader main.swift
./SpotDLDownloader
```

(`-parse-as-library` is needed because the file uses `@main`.)

**Xcode**

1. Create a new **macOS → App** project (SwiftUI, Swift).
2. Replace the generated app/content files with the contents of `main.swift`.
3. In *Signing & Capabilities*, **remove App Sandbox**. The app launches the external `spotdl` process and reads/writes your download folder, which the sandbox blocks.
4. Run.

> Make sure the folder contains only one copy of `main.swift`. Two copies of the same code (or pasting the file twice) causes `'DownloadStatus' is ambiguous` errors.

## Usage

1. Type a song / artist, or paste a Spotify link.
2. Press **Return** (or click the arrow in the field).
3. Watch the card. When it finishes, use **Show in Finder** or the folder icon in the top bar.

Files are saved to `~/Desktop/songs` by default. Change it with **Change** at the bottom of Home, or in **Settings → Downloads**.

## How it works

1. **Look up** – runs `spotdl save <query> --save-file <tmp>.spotdl` to get title, artist, album and cover URL without downloading anything.
2. **Download** – runs `spotdl download <tmp>.spotdl` in your download folder. If the lookup finds nothing, it falls back to `spotdl <query>` and tells you song info is missing.
3. **Track progress** – spotDL doesn't print a percentage when its output is piped, so the bar is *estimated* for each track and advances for real when spotDL reports `Downloaded "…"` or `Skipping …`. A real `NN%` in the output is used if it ever appears.
4. **Decide the result** – reads spotDL's own output as well as its exit code, so a `LookupError` with exit code 0 is reported as *not found* instead of *saved*.

## Project structure

`main.swift` is organised by `// MARK:` sections:

| Section | Purpose |
|---|---|
| App / Navigation / Sidebar | `@main` app, sidebar (Home, Settings), appearance |
| Download Status | `DownloadStatus` enum (titles, icons, tints) |
| Track Info | `TrackInfo` parsed from spotDL's `.spotdl` JSON |
| spotDL Service | finding the executable, fetching metadata |
| Now Playing Card | artwork, progress bar, card layout |
| Recent Files | model for the welcome screen list |
| Home | search field, status line, download flow |
| Log View | full log sheet |
| Settings | appearance, download folder, about |

Preferences are stored with `@AppStorage`: `appearance` and `customOutputFolderPath`.

## Troubleshooting

**"Could not find spotdl"** – install it (`python3 -m pip install spotdl`) and confirm `spotdl --version` works in Terminal. If it's installed somewhere unusual, make sure it's on the `PATH` of your login shell.

**"No results found" / "No song info found"** – spotDL couldn't match the search on Spotify. Try `Artist - Title` in English, check the spelling, or paste the Spotify link for the track. Non-English titles are often matched more reliably by link.

**Downloads fail or have no audio** – check that FFmpeg is installed (`ffmpeg -version`) and view the log with the terminal icon in the top bar.

**"Already in …"** – the file already exists in the download folder, so spotDL skipped it.

## Known limitations

- There is no **Cancel** button yet.
- Progress within a track is an estimate (see *How it works*).
- Switching to Settings during a download resets the Home screen's progress display; the download itself continues.
- Cover art and song info need an internet connection.

## Legal

spotDL finds matching audio on YouTube using Spotify metadata. Use this app only for content you have the right to download, and follow the terms of service and copyright laws that apply to you.

## License

MIT License

Copyright (c) 2026

See [LICENSE](LICENSE).
