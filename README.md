# Podly

Podly is a native macOS app for downloading, organizing, and playing music. Search by song and artist or paste a Spotify link.

Podly is not affiliated with Spotify, spotDL, yt-dlp, or Apple Music.

## Features

- Download with spotDL or yt-dlp, with automatic fallback and a queue.
- Browse and play your library; edit tags, lyrics, and artwork.
- Send tracks to Music for syncing with an iPod through Finder.
- Check spotDL, yt-dlp, FFmpeg, and mutagen in **Settings → Tools**.
- Choose from eight themes and four languages: English, Thai, Korean, and Japanese.

## Requirements

- macOS 13 or later and Xcode Command Line Tools.
- Python 3, spotDL, yt-dlp, FFmpeg, and mutagen.

Install the tools:

```bash
python3 -m pip install spotdl mutagen
brew install yt-dlp ffmpeg
```

## Build and run

```bash
./build.command
```

## Quick start

1. In **Settings**, check **Tools** and choose a download folder.
2. On **Home**, search for a song or paste a Spotify link.
3. Use **Library** to play and manage downloaded tracks.

To sync tracks to an iPod, choose **Send to Music** in Library, then select the `Podly Sync` playlist in Finder.

Use Podly only to download content you have the right to access and save. Follow applicable terms of service and copyright laws.

MIT License. See [LICENSE](LICENSE).
