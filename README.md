# 🎵 SpotDL Downloader

A small native macOS GUI for [spotDL](https://github.com/spotDL/spotify-downloader).

Instead of opening Terminal and typing:

```bash
cd ~/Desktop/songs
spotdl "Always"
```

you can simply open the app, enter a song name or Spotify URL, and click **Download**.

Downloads are saved to:

```text
~/Desktop/songs
```

---

## ✨ Features

- 🎵 Native SwiftUI macOS interface
- 🔗 Supports Spotify URLs
- 🔎 Supports song-name searches
- 📁 Downloads directly to `~/Desktop/songs`
- 📜 Shows spotDL output inside the app
- 📂 Open the output folder with one click
- 🖥️ No Terminal required after building the app
- 🍎 Designed for Apple Silicon Macs

---

## 📸 How it works

```text
┌─────────────────────────────────────┐
│ 🎵 SpotDL Downloader               │
│                                     │
│ Spotify URL / Song name             │
│ ┌─────────────────────────────────┐ │
│ │ Always                          │ │
│ └─────────────────────────────────┘ │
│                                     │
│        [ ↓ Download ]               │
│                                     │
│ 📁 ~/Desktop/songs                  │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Starting spotDL...              │ │
│ │ Searching...                    │ │
│ │ Downloading...                  │ │
│ │ ✅ Finished!                    │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## 🧰 Requirements

- macOS 13 Ventura or newer
- Xcode Command Line Tools
- Python 3
- spotDL

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

Install spotDL:

```bash
python3 -m pip install spotdl
```

Check that spotDL works:

```bash
spotdl --version
```

If `spotdl` is already installed, you can skip this step.

---

## 🚀 Build

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/spotdl-downloader.git
cd spotdl-downloader
```

Make the build script executable:

```bash
chmod +x build.command
```

Build the app:

```bash
./build.command
```

The script creates:

```text
build/
└── SpotDL Downloader.app
```

The app will also open automatically after a successful build.

You can then drag:

```text
SpotDL Downloader.app
```

to your Applications folder.

---

## 🎧 Usage

Open **SpotDL Downloader.app**.

Enter either:

```text
Always
```

or a Spotify URL:

```text
https://open.spotify.com/track/...
```

Then click:

```text
Download
```

The downloaded file will be placed in:

```text
~/Desktop/songs
```

---

## 📂 Project Structure

```text
spotdl-downloader/
├── SpotDLDownloader.swift
├── build.command
├── README.md
├── .gitignore
└── LICENSE
```

### `SpotDLDownloader.swift`

The complete SwiftUI application.

### `build.command`

Builds the Swift source into a native `.app` bundle using `swiftc`.

### `README.md`

Project documentation.

---

## 🛠️ How it works

The application launches the existing `spotdl` executable installed on your Mac.

It searches common locations such as:

```text
/opt/homebrew/bin/spotdl
/usr/local/bin/spotdl
~/.local/bin/spotdl
~/Library/Python/.../bin/spotdl
```

If it cannot find spotDL in those locations, it falls back to:

```bash
command -v spotdl
```

The app then runs:

```bash
spotdl "<your input>"
```

with the working directory set to:

```text
~/Desktop/songs
```

---

## ⚠️ Notes

This project is a GUI wrapper around spotDL. It does **not** bundle spotDL or any third-party music service.

You are responsible for complying with the terms of the services you use and applicable copyright laws.

---

## 📜 License

MIT License

Copyright (c) 2026

See [LICENSE](LICENSE).
