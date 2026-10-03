# Podly

Podly is a native macOS music downloader and library manager built with SwiftUI. Search by song and artist or paste a Spotify link, download the match, then review and manage the audio files in your Library.

> Podly is not affiliated with Spotify, spotDL, yt-dlp, or Apple Music.

## Features

- Search by song and artist, or paste a Spotify track, album, or playlist link.
- Choose spotDL or yt-dlp as the first download source. Podly automatically tries the other source if the first one fails or finds no match.
- Queue multiple searches, reorder pending downloads, pause or resume the active download, cancel items, and retry failures.
- View artwork, track details, and download status while a download runs; open the log to inspect command output.
- Choose a download folder and see recent downloads on Home.
- Choose from eight color themes and organize settings by appearance, download sources, download folder, and app information.
- Browse and search the Library, sort by title or date added, find tracks with duplicate titles, see each file's size and the total storage used, edit tags, find lyrics, fill in artwork, rename tracks, or move files to Trash.
- Play Library tracks with the mini-player, seek and skip between tracks. Use the close button to stop playback and dismiss the player.
- Send Library tracks to a `Podly Sync` playlist in Music, then sync that playlist to an iPod touch using Finder.

## Requirements

| Requirement | Notes |
|---|---|
| macOS 13 Ventura or later | Required to run the app. |
| Xcode Command Line Tools | Provides `swiftc` for building. |
| [spotDL](https://github.com/spotDL/spotify-downloader) | Required if selected as the first source or fallback. |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Required if selected as the first source or fallback. |
| [FFmpeg](https://ffmpeg.org) | Used for audio conversion and embedding artwork/tags. |
| Python 3 with `mutagen` | Used by Library features to read and edit audio tags. |

Install the command-line tools:

```bash
python3 -m pip install spotdl mutagen
brew install yt-dlp ffmpeg
```

Confirm the tools are available in Terminal:

```bash
spotdl --version
yt-dlp --version
ffmpeg -version
```

Podly checks common install locations and the login-shell `PATH` when looking for `spotdl`, `yt-dlp`, and `ffmpeg`.

## Build and Run

From the project directory, run:

```bash
./build.command
```

The script compiles `podly.swift`, creates `build/Podly.app`, and opens the app. The build requires `swiftc` and targets macOS 13 or later. The app launches external command-line tools, so build it without App Sandbox if using a separate Xcode project.

## Getting Started

1. Open **Settings** and choose a download folder.
2. In **Download Sources**, choose which source to try first. The other source is used automatically as the fallback.
3. On **Home**, enter a song and artist or paste a Spotify link, then press Return or select the download button. Add more searches while a download is running to queue them.
4. Open the queue button to reorder pending downloads, pause or resume the active download, cancel items, or retry a failed item.
5. Follow the status below the download card. Use the folder button to open the destination and the log button to inspect output.
6. Open **Library** to search, play, or manage downloaded tracks.

The download queue opens from the queue button at the top of Home. Adding a song no longer opens the queue automatically.

Downloads are saved to `~/Desktop/songs` by default. You can change this in Settings or from the folder control on Home.

## Library and iPod Sync

The Library shows audio files in the selected download folder, including their file sizes and the total space they use. Select a track's edit control to change tags, artwork, or lyrics. The Library menu also includes batch options for filling in missing covers or lyrics.

To sync music to an iPod touch:

1. Open **Library** and select **Send to Music**.
2. Podly adds tracks that are not already in the `Podly Sync` playlist; it does not remove existing playlist items.
3. Connect the iPod touch, open it in Finder, enable music syncing for selected playlists, select `Podly Sync`, and apply the changes.

macOS may ask Podly for permission to control Music the first time.

## Troubleshooting

**A source cannot be found** – Install the selected tool and confirm its version command works in Terminal. If it is installed in a nonstandard location, make sure it is available on the login-shell `PATH`.

**No matching song is found** – Check the spelling, try `Artist - Title`, or paste the Spotify track link. Search results can vary by track and region.

**A download fails or has no audio** – Confirm FFmpeg is installed and open the download log from Home. The log includes output from the source tools.

**Library tag editing is unavailable** – Install `mutagen` for the Python interpreter used by Podly, then refresh the Library.

**Music sync does not start** – Allow Podly to control Music in macOS privacy settings, then try **Send to Music** again.

## Limitations

- Pausing and cancelling take effect when the current lookup or tool process reaches a safe checkpoint.
- Download progress within a track is estimated; completion advances when the source reports a finished track.
- The backup source requires its own command-line tools and an internet connection. Metadata and artwork may not be available for every search.

## Legal

Use Podly only to download content you have the right to access and save. Follow the terms of service and copyright laws that apply to you.

## License

MIT License. See [LICENSE](LICENSE).
