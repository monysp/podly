# 🎵 Podly

> A minimal, native macOS music downloader powered by spotDL.

Podly is a simple and modern macOS music downloader designed to make downloading music easier without using Terminal commands every time.

Built with **SwiftUI**, Podly provides an Apple-style interface for searching and downloading songs while automatically handling metadata, album artwork, lyrics, and your music library.

---

## ✨ Features

* 🎵 **Search & Download Music**

  * Search for songs directly from the app.
  * Powered by `spotDL`.

* 🖥️ **Native macOS UI**

  * Built with SwiftUI.
  * Minimal Apple-inspired interface.
  * Supports Light, Dark, and System appearance.

* 📁 **Custom Output Folder**

  * Choose where downloaded music should be stored.
  * Default location:

    ```text
    ~/Desktop/songs
    ```

* 🏷️ **Automatic Metadata**

  * Title
  * Artist
  * Album
  * Album Artist
  * Year
  * Track Number
  * Genre

* 🖼️ **Album Artwork**

  * Automatically retrieves and embeds cover artwork when available.

* 📝 **Lyrics**

  * Attempts to retrieve lyrics automatically.
  * Supports plain and synchronized lyrics.

* 📚 **Music Library**

  * Browse recently downloaded music.
  * View track metadata and artwork.

* 🔎 **Clear Download Status**

  * Downloading
  * Download complete
  * Song not found
  * Already downloaded
  * Download failed

* 🧹 **Automatic Input Reset**

  * Clears the search field after a completed download.

* ⏱️ **Automatic Return**

  * After a successful download, Podly waits briefly before returning to the initial state.

---

## 🖥️ Requirements

* macOS
* Apple Silicon or Intel Mac
* Xcode
* Swift / SwiftUI
* Python 3
* `spotdl`
* `mutagen` for metadata processing

---

## 📦 Installation

### 1. Install Homebrew

If you don't already have Homebrew:

[Homebrew](https://brew.sh/?utm_source=chatgpt.com)

Then install the required dependencies.

### 2. Install spotDL

```bash
python3 -m pip install spotdl
```

Verify:

```bash
spotdl --version
```

### 3. Install Mutagen

```bash
python3 -m pip install mutagen
```

Verify:

```bash
python3 -c "import mutagen; print(mutagen.version_string)"
```

---

## 🚀 Build Podly

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/Podly.git
cd Podly
```

Open the project in Xcode:

```bash
open Podly.xcodeproj
```

Select your Mac as the run destination and press:

```text
⌘ R
```

---

## 🎧 Download Music

1. Open **Podly**
2. Enter a song name or supported URL
3. Press **Download**
4. Podly retrieves the song information
5. The song is downloaded through `spotDL`
6. Metadata and artwork are processed automatically
7. The completed file is saved to your selected folder

Example:

```text
Always
```

or a supported music URL.

---

## 📁 Output

By default, downloaded music is stored in:

```text
~/Desktop/songs
```

You can change this from the application's output folder selector.

Example:

```text
songs/
├── Artist A/
│   └── Song A.mp3
├── Artist B/
│   └── Song B.mp3
└── Artist C/
    └── Song C.m4a
```

The exact folder structure depends on the `spotDL` configuration.

---

## 🏷️ Metadata

Podly includes a metadata processing system for downloaded files.

Supported information includes:

| Metadata      | Supported |
| ------------- | :-------: |
| Title         |     ✅     |
| Artist        |     ✅     |
| Album         |     ✅     |
| Album Artist  |     ✅     |
| Year          |     ✅     |
| Track Number  |     ✅     |
| Genre         |     ✅     |
| Lyrics        |     ✅     |
| Album Artwork |     ✅     |

Supported audio formats include:

```text
MP3
M4A
FLAC
OGG
OPUS
WAV
```

---

## 🎨 Interface

Podly follows a minimal macOS design philosophy:

* Native SwiftUI components
* Sidebar navigation
* System appearance support
* Light / Dark mode
* Subtle animations
* Artwork previews
* Clear download states
* Minimal visual clutter

---

## 🧩 Project Structure

```text
Podly/
│
├── Podly.swift
├── README.md
└── ...
```

The main application source is currently contained in:

```text
Podly.swift
```

---

## 🔧 How It Works

Podly acts as a graphical frontend for `spotDL`.

The general workflow is:

```text
User
  │
  ▼
Podly
  │
  ├── Search / Metadata
  │
  ▼
spotDL
  │
  ▼
Downloaded Audio
  │
  ├── Metadata
  ├── Artwork
  └── Lyrics
  │
  ▼
Selected Output Folder
```

Podly handles the graphical interface and file processing while `spotDL` performs the actual music downloading.

---

## 🔐 Privacy

Podly does not require an account or its own cloud backend.

Search and download operations are handled through the services used by `spotDL` and the configured music sources.

Do not use Podly to download or distribute copyrighted music without the necessary rights or permission.

---

## ⚠️ Disclaimer

Podly is an independent project and is **not affiliated with, endorsed by, or sponsored by Apple or Spotify**.

`spotDL` is an external dependency and is subject to its own project license and terms.

Users are responsible for complying with applicable copyright laws and the terms of the services they use.

---

## 🛠️ Roadmap

Planned improvements:

* [ ] iPod synchronization
* [ ] Automatic iPod detection
* [ ] Playlist downloading
* [ ] Download queue
* [ ] Download history
* [ ] Better library management
* [ ] Drag & drop downloads
* [ ] More audio format options
* [ ] Improved metadata editor
* [ ] Native macOS notifications
* [ ] Better error diagnostics

---

## 🤝 Contributing

Contributions, ideas, and bug reports are welcome.

If you find a bug or have an idea for a feature, open an issue or submit a pull request.

---

## 📄 License

MIT License

Copyright (c) 2026

See [LICENSE](LICENSE).

---

## ⭐ Support

If you find Podly useful, consider giving the repository a ⭐ on GitHub.

Made with ❤️ and SwiftUI on macOS.
