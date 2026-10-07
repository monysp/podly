import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selection: AppPage

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Home", systemImage: "arrow.down.circle")
                    .tag(AppPage.home)

                Label("Library", systemImage: "books.vertical")
                    .tag(AppPage.library)
            }

            Section("App") {
                Label("Settings", systemImage: "gearshape")
                    .tag(AppPage.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)

                Text("Podly")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Download Status

enum DownloadStatus {
    case ready
    case downloading
    case success
    case notFound
    case duplicate
    case failed

    var title: String {
        switch self {
        case .ready: return "Ready to download"
        case .downloading: return "Downloading"
        case .success: return "Download complete"
        case .notFound: return "Song not found"
        case .duplicate: return "Already downloaded"
        case .failed: return "Download failed"
        }
    }

    var subtitle: String {
        switch self {
        case .ready: return "Enter a song or Spotify link to begin."
        case .downloading: return "spotDL is searching and downloading your song…"
        case .success: return "The song was saved successfully."
        case .notFound: return "spotDL could not find a matching song."
        case .duplicate: return "A matching file already exists in the download folder."
        case .failed: return "spotDL could not complete the download. Check the log for details."
        }
    }

    var icon: String {
        switch self {
        case .ready: return "music.note"
        case .downloading: return "arrow.down.circle"
        case .success: return "checkmark.circle.fill"
        case .notFound: return "magnifyingglass"
        case .duplicate: return "doc.on.doc.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .secondary
        case .downloading: return .accentColor
        case .success: return .green
        case .notFound: return .orange
        case .duplicate: return .orange
        case .failed: return .red
        }
    }
}

struct DownloadStatusCard: View {
    let status: DownloadStatus

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(status.tint.opacity(0.12))
                    .frame(width: 42, height: 42)

                if status == .downloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: status.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(status.tint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(status.title))
                    .font(.system(size: 13, weight: .semibold))

                Text(LocalizedStringKey(status.subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(13)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(status.tint.opacity(0.12), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: status.title)
    }
}

// MARK: - Track Info

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let album: String?
    let coverURL: URL?

    var subtitle: String {
        if let album, !album.isEmpty { return "\(artist) — \(album)" }
        return artist
    }

    /// Shown instantly while metadata is still being fetched.
    static func placeholder(for input: String) -> TrackInfo {
        let isLink = input.lowercased().hasPrefix("http")
        return TrackInfo(
            title: isLink ? "Looking up track…" : input,
            artist: "spotDL",
            album: nil,
            coverURL: nil
        )
    }

    /// Shown when spotDL can't find any song info for the search.
    static func unknown(for input: String) -> TrackInfo {
        let isLink = input.lowercased().hasPrefix("http")
        return TrackInfo(
            title: isLink ? "Unknown track" : input,
            artist: "No song info found",
            album: nil,
            coverURL: nil
        )
    }

    /// Builds a track from one entry of a `.spotdl` file.
    init(spotdl dict: [String: Any]) {
        title = dict["name"] as? String ?? "Unknown Title"

        if let artists = dict["artists"] as? [String], !artists.isEmpty {
            artist = artists.joined(separator: ", ")
        } else {
            artist = dict["artist"] as? String ?? "Unknown Artist"
        }

        album = dict["album_name"] as? String
        coverURL = (dict["cover_url"] as? String).flatMap { URL(string: $0) }
    }

    init(title: String, artist: String, album: String?, coverURL: URL?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.coverURL = coverURL
    }
}
