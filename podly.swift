import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

@main
struct PodlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    case midnight
    case paper
    case nord
    case cupcake
    case corporate

    var title: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        case .midnight: return "Midnight"
        case .paper: return "Paper"
        case .nord: return "Nord"
        case .cupcake: return "Cupcake"
        case .corporate: return "Corporate"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .midnight: return "moon.stars"
        case .paper: return "doc.text"
        case .nord: return "snowflake"
        case .cupcake: return "birthday.cake"
        case .corporate: return "building.2"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .paper, .nord, .cupcake, .corporate: return .light
        case .dark, .midnight: return .dark
        }
    }

    var accentColor: Color {
        switch self {
        case .system, .light: return Color(red: 0.20, green: 0.48, blue: 0.92)
        case .dark: return Color(red: 0.58, green: 0.48, blue: 0.98)
        case .midnight: return Color(red: 0.00, green: 0.78, blue: 0.61)
        case .paper: return Color(red: 0.38, green: 0.29, blue: 0.20)
        case .nord: return Color(red: 0.35, green: 0.51, blue: 0.68)
        case .cupcake: return Color(red: 0.24, green: 0.78, blue: 0.70)
        case .corporate: return Color(red: 0.10, green: 0.45, blue: 0.72)
        }
    }

    var canvas: Color {
        switch self {
        case .system: return Color(nsColor: .windowBackgroundColor)
        case .light: return Color(red: 0.96, green: 0.96, blue: 0.97)
        case .dark: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .midnight: return Color(red: 0.04, green: 0.06, blue: 0.08)
        case .paper: return Color(red: 0.97, green: 0.94, blue: 0.88)
        case .nord: return Color(red: 0.89, green: 0.91, blue: 0.94)
        case .cupcake: return Color(red: 0.96, green: 0.92, blue: 0.93)
        case .corporate: return Color(red: 0.91, green: 0.93, blue: 0.95)
        }
    }

    var previewSurface: Color {
        switch self {
        case .system: return Color(nsColor: .controlBackgroundColor)
        case .light: return .white
        case .dark: return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .midnight: return Color(red: 0.07, green: 0.09, blue: 0.12)
        case .paper: return Color(red: 1.00, green: 0.98, blue: 0.93)
        case .nord: return Color(red: 0.92, green: 0.94, blue: 0.97)
        case .cupcake: return Color(red: 0.99, green: 0.96, blue: 0.96)
        case .corporate: return Color(red: 0.96, green: 0.97, blue: 0.98)
        }
    }

    var previewInk: Color {
        switch self {
        case .system: return .primary
        case .dark, .midnight: return .white
        case .light, .paper, .nord, .cupcake, .corporate:
            return Color(red: 0.18, green: 0.20, blue: 0.23)
        }
    }
}

private struct PodlyThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.system
}

private extension EnvironmentValues {
    var podlyTheme: AppTheme {
        get { self[PodlyThemeKey.self] }
        set { self[PodlyThemeKey.self] = newValue }
    }
}

enum DownloadSource: String, CaseIterable {
    case spotDL
    case ytDlp

    var title: String {
        switch self {
        case .spotDL: return "spotDL"
        case .ytDlp: return "yt-dlp"
        }
    }

    var icon: String {
        switch self {
        case .spotDL: return "music.note"
        case .ytDlp: return "play.rectangle"
        }
    }

    var alternate: DownloadSource {
        self == .spotDL ? .ytDlp : .spotDL
    }
}

// MARK: - Navigation

enum AppPage: Hashable {
    case home
    case library
    case settings
}

// MARK: - Main View

struct ContentView: View {
    @State private var page: AppPage = .home
    @StateObject private var audioPlayer = AudioPlayerModel()

    @AppStorage("appearance")
    private var themeRawValue = AppTheme.system.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $page)
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch page {
                    case .home:
                        HomeView()
                    case .library:
                        LibraryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                if audioPlayer.currentTrack != nil {
                    MiniPlayerView(player: audioPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.accentColor)
        .environment(\.podlyTheme, theme)
        .environmentObject(audioPlayer)
        .animation(.easeInOut(duration: 0.2), value: page)
        .animation(.easeInOut(duration: 0.2), value: audioPlayer.currentTrack != nil)
    }
}

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
                Text(status.title)
                    .font(.system(size: 13, weight: .semibold))

                Text(status.subtitle)
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

// MARK: - spotDL Service

enum SpotDLService {
    struct Metadata {
        var tracks: [TrackInfo]
        var fileURL: URL?
    }

    /// Runs `spotdl save` to get title / artist / cover without downloading.
    static func fetchMetadata(
        executable: String,
        query: String,
        control: DownloadJobControl? = nil
    ) -> Metadata {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotdl-\(UUID().uuidString).spotdl")

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["save", query, "--save-file", file.path]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            control?.attach(process)
        } catch {
            return Metadata(tracks: [], fileURL: nil)
        }

        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        control?.detach(process)

        guard control?.isCancelled != true else {
            try? FileManager.default.removeItem(at: file)
            return Metadata(tracks: [], fileURL: nil)
        }

        guard process.terminationStatus == 0,
              let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data),
              let array = json as? [[String: Any]],
              !array.isEmpty
        else {
            try? FileManager.default.removeItem(at: file)
            return Metadata(tracks: [], fileURL: nil)
        }

        return Metadata(tracks: array.map(TrackInfo.init(spotdl:)), fileURL: file)
    }

    static func findExecutable() -> String? {
        let candidates = [
            "/opt/homebrew/bin/spotdl",
            "/usr/local/bin/spotdl",
            "\(NSHomeDirectory())/.local/bin/spotdl",
            "\(NSHomeDirectory())/Library/Python/3.12/bin/spotdl",
            "\(NSHomeDirectory())/Library/Python/3.13/bin/spotdl",
            "\(NSHomeDirectory())/Library/Python/3.14/bin/spotdl"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v spotdl"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()

                if let result = String(
                    data: data,
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !result.isEmpty {
                    return result
                }
            }
        } catch {}

        return nil
    }
}

// MARK: - Backup Download Service

enum BackupDownloadService {
    struct TrackMetadata: Sendable {
        let title: String
        let artist: String
        let album: String
        let artworkURL: URL
        let year: String
        let trackNumber: String
        let trackCount: String?
        let genre: String?

        var trackInfo: TrackInfo {
            TrackInfo(title: title, artist: artist, album: album, coverURL: artworkURL)
        }
    }

    enum BackupError: LocalizedError {
        case missingTool(String)
        case incompleteMetadata
        case alreadyDownloaded(URL)
        case commandFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingTool(let name): return "Could not find \(name). Install it and try again."
            case .incompleteMetadata: return "Could not find complete track metadata and cover art. No file was saved."
            case .alreadyDownloaded(let url): return "Already downloaded: \(url.lastPathComponent)"
            case .commandFailed(let output): return output.isEmpty ? "The backup download failed." : output
                case .cancelled: return "Download cancelled."
            }
        }
    }

    static func lookupMetadata(query: String) async throws -> TrackMetadata {
        let searchTerm = try await iTunesSearchTerm(for: query)
        let matches = await OnlineLookup.searchSongs(searchTerm)

        guard let match = matches.first(where: {
            !$0.album.isEmpty && !$0.year.isEmpty && !$0.track.isEmpty && $0.artworkURL != nil
        }),
        let artworkURL = match.artworkURL
        else {
            throw BackupError.incompleteMetadata
        }

        let trackParts = match.track.split(separator: "/", omittingEmptySubsequences: true)
        guard let trackNumber = trackParts.first.map(String.init) else {
            throw BackupError.incompleteMetadata
        }
        return TrackMetadata(
            title: match.title,
            artist: match.artist,
            album: match.album,
            artworkURL: artworkURL,
            year: match.year,
            trackNumber: trackNumber,
            trackCount: trackParts.dropFirst().first.map(String.init),
            genre: match.genre.isEmpty ? nil : match.genre
        )
    }

    private static func iTunesSearchTerm(for query: String) async throws -> String {
        guard query.lowercased().contains("spotify.com") else { return query }

        var components = URLComponents(string: "https://open.spotify.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: query)]
        guard let url = components.url else { throw BackupError.incompleteMetadata }
        let request = URLRequest(url: url, timeoutInterval: 15)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = response["title"] as? String,
              let artist = response["author_name"] as? String
        else {
            throw BackupError.incompleteMetadata
        }
        return "\(artist) \(title)"
    }

    static func download(
        metadata: TrackMetadata,
        destinationFolder: URL,
        searchQuery: String,
        control: DownloadJobControl? = nil
    ) throws -> (URL, String) {
        if control?.isCancelled == true { throw BackupError.cancelled }
        if let existingURL = existingTrack(matching: metadata, in: destinationFolder) {
            throw BackupError.alreadyDownloaded(existingURL)
        }

        guard let ytDlp = findExecutable(named: "yt-dlp") else {
            throw BackupError.missingTool("yt-dlp")
        }
        guard let ffmpeg = findExecutable(named: "ffmpeg") else {
            throw BackupError.missingTool("FFmpeg")
        }

        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("podly-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryFolder,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryFolder) }

        let artworkData = try Data(contentsOf: metadata.artworkURL)
        guard !artworkData.isEmpty else { throw BackupError.incompleteMetadata }
        let artworkFile = temporaryFolder.appendingPathComponent("cover.jpg")
        try artworkData.write(to: artworkFile)

        let audioTemplate = temporaryFolder.appendingPathComponent("audio.%(ext)s").path
        let searchProcess = Process()
        searchProcess.executableURL = URL(fileURLWithPath: ytDlp)
        searchProcess.arguments = [
            "--no-playlist",
            "--extract-audio",
            "--audio-format", "mp3",
            "--output", audioTemplate,
            "ytsearch1:\(searchQuery)"
        ]

        let searchOutput = try run(searchProcess, control: control)
        guard let audioFile = try FileManager.default.contentsOfDirectory(
            at: temporaryFolder,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension.lowercased() == "mp3" }) else {
            throw BackupError.commandFailed(searchOutput)
        }

        let stem = "\(metadata.title) - \(metadata.artist)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let target = uniqueURL(
            for: stem,
            in: destinationFolder
        )

        let tagProcess = Process()
        tagProcess.executableURL = URL(fileURLWithPath: ffmpeg)
        var tagArguments = [
            "-i", audioFile.path,
            "-i", artworkFile.path,
            "-map", "0:a:0",
            "-map", "1:v:0",
            "-c:a", "copy",
            "-c:v", "mjpeg",
            "-disposition:v:0", "attached_pic",
            "-metadata:s:v", "title=Album cover",
            "-metadata:s:v", "comment=Cover (front)",
            "-metadata", "title=\(metadata.title)",
            "-metadata", "artist=\(metadata.artist)",
            "-metadata", "album=\(metadata.album)",
            "-metadata", "album_artist=\(metadata.artist)",
            "-metadata", "date=\(metadata.year)",
            "-metadata", "track=\(metadata.trackNumber)\(metadata.trackCount.map { "/\($0)" } ?? "")",
            "-id3v2_version", "3",
            "-write_id3v1", "1"
        ]
        if let genre = metadata.genre {
            tagArguments += ["-metadata", "genre=\(genre)"]
        }
        tagArguments += ["-y", target.path]
        tagProcess.arguments = tagArguments

        do {
            let tagOutput = try run(tagProcess, control: control)
            return (target, searchOutput + tagOutput)
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    private static func existingTrack(matching metadata: TrackMetadata, in folder: URL) -> URL? {
        let result = TagService.run(["action": "scan", "folder": folder.path])
        if let tracks = result["files"] as? [[String: Any]],
           let match = tracks.first(where: {
               normalized($0["title"] as? String ?? "") == normalized(metadata.title) &&
               normalized($0["artist"] as? String ?? "") == normalized(metadata.artist)
           }),
           let path = match["path"] as? String {
            return URL(fileURLWithPath: path)
        }

        let audioExtensions: Set<String> = ["mp3", "m4a", "flac", "ogg", "opus", "wav"]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let titleArtist = normalized(metadata.title + metadata.artist)
        let artistTitle = normalized(metadata.artist + metadata.title)

        return files.first { url in
            guard audioExtensions.contains(url.pathExtension.lowercased()) else { return false }
            let stem = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: #"\s+\(\d+\)$"#, with: "", options: .regularExpression)
            let normalizedStem = normalized(stem)
            return normalizedStem == titleArtist || normalizedStem == artistTitle
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private static func run(_ process: Process, control: DownloadJobControl? = nil) throws -> String {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        control?.attach(process)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        control?.detach(process)
        let output = String(data: data, encoding: .utf8) ?? ""
        if control?.isCancelled == true { throw BackupError.cancelled }
        guard process.terminationStatus == 0 else {
            throw BackupError.commandFailed(output)
        }
        return output
    }

    private static func findExecutable(named name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)"
        ]
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v \(name)"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueURL(for stem: String, in folder: URL) -> URL {
        var url = folder.appendingPathComponent(stem).appendingPathExtension("mp3")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(stem) (\(suffix))").appendingPathExtension("mp3")
            suffix += 1
        }
        return url
    }
}

// MARK: - Now Playing Card

struct WaveformBadge: View {
    let isActive: Bool

    var body: some View {
        if #available(macOS 14.0, *) {
            Image(systemName: "waveform")
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    isActive: isActive
                )
        } else {
            Image(systemName: "waveform")
        }
    }
}

struct ArtworkThumbnail: View {
    let image: NSImage?
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.38), .gray.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

struct NowPlayingProgressBar: View {
    let progress: Double
    let tint: Color

    @State private var hovering = false

    var body: some View {
        let value = min(max(progress, 0), 1)

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.12))

                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: hovering ? 7 : 4)
        .clipShape(Capsule())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.linear(duration: 0.2), value: value)
        .accessibilityElement()
        .accessibilityLabel("Download progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct NowPlayingCard: View {
    let track: TrackInfo
    let progress: Double
    let stage: String
    let status: DownloadStatus
    let position: Int
    let total: Int
    var lookupFailed = false

    @State private var artwork: NSImage?

    private var barTint: Color {
        status == .downloading ? Color.primary.opacity(0.8) : status.tint
    }

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(image: artwork)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)

                        Text(track.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(lookupFailed ? Color.orange : Color.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Group {
                        if status == .downloading {
                            WaveformBadge(isActive: true)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: status.icon)
                                .foregroundStyle(status.tint)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                }

                NowPlayingProgressBar(progress: progress, tint: barTint)

                HStack(spacing: 6) {
                    Text(stage)

                    Spacer()

                    if total > 1 {
                        Text("\(position) of \(total)")
                    }

                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .animation(.easeInOut(duration: 0.2), value: stage)
            }
        }
        .padding(14)
        .background {
            ZStack {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 40)
                        .saturation(1.4)
                        .opacity(0.5)
                        .transition(.opacity)
                }

                Rectangle().fill(.thinMaterial)
            }
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .task(id: track.coverURL) {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        guard let url = track.coverURL else {
            withAnimation(.easeOut(duration: 0.2)) { artwork = nil }
            return
        }

        if let (data, _) = try? await URLSession.shared.data(from: url),
           let image = NSImage(data: data) {
            withAnimation(.easeOut(duration: 0.35)) { artwork = image }
        }
    }
}

// MARK: - Recent Files

struct RecentFile: Identifiable, Equatable {
    let url: URL
    let date: Date

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum DownloadQueueStatus: String {
    case queued
    case downloading
    case failed
    case completed
    case cancelled

    var title: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .failed: return "Failed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case title
    case dateAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .title: return "Title"
        case .dateAdded: return "Date Added"
        }
    }

    var icon: String {
        switch self {
        case .title: return "textformat"
        case .dateAdded: return "calendar"
        }
    }
}

struct DownloadQueueItem: Identifiable {
    let id: UUID
    let input: String
    var status: DownloadQueueStatus

    init(input: String, status: DownloadQueueStatus = .queued) {
        id = UUID()
        self.input = input
        self.status = status
    }
}

final class DownloadJobControl: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var paused = false
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        if cancelled {
            process.terminate()
        } else if paused {
            _ = process.suspend()
        }
        lock.unlock()
    }

    func detach(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func pause() {
        lock.lock()
        if !paused && !cancelled {
            paused = true
            if let process { _ = process.suspend() }
        }
        lock.unlock()
    }

    func resume() {
        lock.lock()
        if paused {
            paused = false
            if let process { _ = process.resume() }
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        if paused, let process {
            _ = process.resume()
            paused = false
        }
        process?.terminate()
        lock.unlock()
    }
}

// MARK: - Home

struct HomeView: View {
    @Environment(\.podlyTheme) private var theme
    @State private var query = ""
    @State private var log = "Ready"
    @State private var isDownloading = false
    @State private var showLogs = false
    @State private var appeared = false
    @State private var downloadCount = 0
    @State private var downloadStatus: DownloadStatus = .ready
    @State private var tracks: [TrackInfo] = []
    @State private var completedTracks = 0
    @State private var withinTrack = 0.0
    @State private var metadataLoaded = false
    @State private var downloadOutput = ""
    @State private var recentFiles: [RecentFile] = []
    @State private var lookupFailed = false
    @State private var missedCount = 0
    @State private var activeDownloadSource: DownloadSource = .spotDL
    @State private var homeResetTask: Task<Void, Never>?
    @State private var downloadQueue: [DownloadQueueItem] = []
    @State private var activeQueueID: UUID?
    @State private var activeQueueInput = ""
    @State private var queuePaused = false
    @State private var downloadControl: DownloadJobControl?
    @State private var showQueue = false
    @State private var nextSourceOverride: DownloadSource?

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    @AppStorage("primaryDownloadSource")
    private var primaryDownloadSourceRawValue = DownloadSource.spotDL.rawValue

    private var primaryDownloadSource: DownloadSource {
        DownloadSource(rawValue: primaryDownloadSourceRawValue) ?? .spotDL
    }

    private var outputFolder: URL {
        URL(fileURLWithPath: customOutputPath)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Spacer()

                Button {
                    NSWorkspace.shared.open(outputFolder)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open download folder")

                Button {
                    showLogs = true
                } label: {
                    Image(systemName: "terminal")
                }
                .help("View logs")

                Button {
                    showQueue.toggle()
                } label: {
                    Label(
                        "\(downloadQueue.filter { $0.status == .queued || $0.status == .downloading }.count)",
                        systemImage: "text.badge.plus"
                    )
                }
                .help("Download queue")
                .popover(isPresented: $showQueue, arrowEdge: .top) {
                    downloadQueuePopover
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .padding(.top, 16)

            Spacer(minLength: 0)

            VStack(spacing: 24) {
                if currentTrack == nil {
                    hero
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom))
                        )
                }

                VStack(spacing: 18) {
                    searchField
                    nowPlayingSlot
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentTrack != nil)
            .frame(maxWidth: 460)
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "folder")

                Text(outputFolder.path)
                    .lineLimit(1)
                    .truncationMode(.head)

                Button("Change") {
                    selectOutputFolder()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(isDownloading)

                if downloadCount > 0 {
                    Text("·  \(downloadCount) saved this session")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.canvas)
        .onAppear {
            createOutputFolderIfNeeded()
            loadRecent()

            withAnimation(.easeOut(duration: 0.45).delay(0.05)) {
                appeared = true
            }
        }
        .onChange(of: downloadStatus) { _ in loadRecent() }
        .onChange(of: customOutputPath) { _ in loadRecent() }
        .sheet(isPresented: $showLogs) {
            LogView(log: log)
        }
        .onReceive(ticker) { _ in tick() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Song, artist, or Spotify URL", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .onSubmit { download() }

            if !trimmedQuery.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .transition(.opacity)

                Button {
                    download()
                } label: {
                    Image(systemName: isDownloading ? "text.badge.plus" : "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(isDownloading ? "Add to download queue" : "Download")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: trimmedQuery.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: isDownloading)
    }

    private var downloadQueuePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Download Queue")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    showQueue = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close queue")

                if isDownloading || queuePaused {
                    Button(queuePaused ? "Resume" : "Pause") {
                        toggleQueuePause()
                    }
                    .controlSize(.small)
                }

                if isDownloading {
                    Button("Cancel") {
                        cancelActiveDownload()
                    }
                    .controlSize(.small)
                }
            }

            if downloadQueue.isEmpty {
                Text("Add songs using the search box.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(downloadQueue) { item in
                            downloadQueueRow(item)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private func downloadQueueRow(_ item: DownloadQueueItem) -> some View {
        HStack(spacing: 9) {
            Image(systemName: queueIcon(for: item.status))
                .foregroundStyle(queueTint(for: item.status))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.input)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(item.status == .downloading && queuePaused ? "Paused" : item.status.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if item.status == .failed || item.status == .cancelled {
                Button {
                    retryQueueItem(item)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Retry")
            } else if item.status == .queued {
                HStack(spacing: 8) {
                    Button {
                        moveQueuedItem(item, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(queuedPosition(of: item) == 0)
                    .help("Move earlier")

                    Button {
                        moveQueuedItem(item, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(queuedPosition(of: item) == queuedCount - 1)
                    .help("Move later")

                    Button {
                        cancelQueuedItem(item)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Remove from queue")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }

    private func queueIcon(for status: DownloadQueueStatus) -> String {
        switch status {
        case .queued: return "clock"
        case .downloading: return queuePaused ? "pause.circle" : "arrow.down.circle"
        case .failed: return "exclamationmark.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    private func queueTint(for status: DownloadQueueStatus) -> Color {
        switch status {
        case .queued: return .secondary
        case .downloading: return .accentColor
        case .failed, .cancelled: return .orange
        case .completed: return .green
        }
    }

    private var queuedCount: Int {
        downloadQueue.filter { $0.status == .queued }.count
    }

    private func queuedPosition(of item: DownloadQueueItem) -> Int {
        downloadQueue.filter { $0.status == .queued }.firstIndex(where: { $0.id == item.id }) ?? -1
    }

    private func moveQueuedItem(_ item: DownloadQueueItem, by offset: Int) {
        let queued = downloadQueue.indices.filter { downloadQueue[$0].status == .queued }
        guard let position = queued.firstIndex(where: { downloadQueue[$0].id == item.id }) else { return }
        let targetPosition = position + offset
        guard queued.indices.contains(targetPosition) else { return }
        downloadQueue.swapAt(queued[position], queued[targetPosition])
    }

    private var nowPlayingSlot: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                if let track = currentTrack {
                    NowPlayingCard(
                        track: track,
                        progress: overallProgress,
                        stage: stageText,
                        status: downloadStatus,
                        position: min(completedTracks + 1, tracks.count),
                        total: tracks.count,
                        lookupFailed: lookupFailed
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                } else {
                    emptyHint
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100, alignment: .top)

            statusLine
                .frame(height: 22)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentTrack != nil)
        .animation(.easeInOut(duration: 0.2), value: downloadStatus)
    }

    // MARK: Friendly status

    private var clipboardLink: String? {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text.lowercased().hasPrefix("http"),
              text.lowercased().contains("spotify")
        else { return nil }
        return text
    }

    private var spotdlMissing: Bool {
        log.contains("Could not find spotdl")
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 14, y: 7)

                Image(systemName: "music.note")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Download music")
                    .font(.system(size: 24, weight: .semibold))

                Text("Search for a song, or paste a Spotify link.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 16) {
            if query.isEmpty, let link = clipboardLink {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { query = link }
                } label: {
                    Label("Paste Spotify link", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !recentFiles.isEmpty {
                recentSection
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(recentFiles.enumerated()), id: \.element.id) { index, file in
                    if index > 0 {
                        Divider().padding(.leading, 40)
                    }

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)

                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 8)

                            Text(Self.relativeFormatter.localizedString(for: file.date, relativeTo: Date()))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            }
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private func loadRecent() {
        let folder = outputFolder

        DispatchQueue.global(qos: .utility).async {
            let keys: [URLResourceKey] = [.contentModificationDateKey]
            let audio: Set<String> = ["mp3", "m4a", "flac", "ogg", "opus", "wav"]

            let urls = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )) ?? []

            let recent = urls
                .filter { audio.contains($0.pathExtension.lowercased()) }
                .compactMap { url -> RecentFile? in
                    guard let date = try? url.resourceValues(forKeys: Set(keys))
                        .contentModificationDate
                    else { return nil }
                    return RecentFile(url: url, date: date)
                }
                .sorted { $0.date > $1.date }
                .prefix(3)

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recentFiles = Array(recent)
                }
            }
        }
    }

    private var statusMessage: String {
        let folder = outputFolder.lastPathComponent

        switch downloadStatus {
        case .success:
            if missedCount > 0 {
                return "Saved to “\(folder)” · \(missedCount) not found"
            }
            return lookupFailed
                ? "Saved to “\(folder)” · no song info found"
                : "Saved to “\(folder)”"
        case .duplicate: return "Already in “\(folder)”"
        case .notFound: return "No results found. Try another spelling or a Spotify link."
        case .failed:
            return spotdlMissing
                ? "spotDL isn’t installed. The log has the install steps."
                : (lookupFailed
                    ? "No song info found. Try artist + title or a Spotify link."
                    : "Something went wrong.")
        case .ready, .downloading: return ""
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch downloadStatus {
        case .ready, .downloading:
            EmptyView()

        case .success, .duplicate, .notFound, .failed:
            HStack(spacing: 8) {
                Image(systemName: downloadStatus.icon)
                    .foregroundStyle(downloadStatus.tint)

                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                switch downloadStatus {
                case .success, .duplicate:
                    statusAction("Show in Finder") {
                        NSWorkspace.shared.open(outputFolder)
                    }
                case .failed, .notFound:
                    if !spotdlMissing {
                        statusAction("Try again") { retryLastFailed() }
                    }
                    if downloadStatus == .notFound {
                        statusAction("Try backup") { backupDownload() }
                    }
                    statusAction("View log") { showLogs = true }
                default:
                    EmptyView()
                }
            }
            .font(.system(size: 12))
            .transition(.opacity)
        }
    }

    private func statusAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.accentColor)
    }

    private var lastLogLine: String {
        log
            .components(separatedBy: .newlines)
            .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? "Ready"
    }

    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolder

        if panel.runModal() == .OK, let url = panel.url {
            withAnimation(.easeInOut(duration: 0.2)) {
                customOutputPath = url.path
            }

            createOutputFolderIfNeeded()
            log = "Output folder changed to:\n\(url.path)\n\n" + log
        }
    }

    private func createOutputFolderIfNeeded() {
        try? FileManager.default.createDirectory(
            at: outputFolder,
            withIntermediateDirectories: true
        )
    }

    // MARK: Now Playing state

    private var currentTrack: TrackInfo? {
        guard !tracks.isEmpty, downloadStatus != .ready else { return nil }
        return tracks[min(completedTracks, tracks.count - 1)]
    }

    private var overallProgress: Double {
        guard !tracks.isEmpty else { return 0 }
        if downloadStatus == .success || downloadStatus == .duplicate { return 1 }
        let done = Double(completedTracks) + withinTrack
        return min(done / Double(tracks.count), 1)
    }

    private var stageText: String {
        switch downloadStatus {
        case .ready: return ""
        case .success: return "Saved"
        case .duplicate: return "Already in folder"
        case .notFound: return "Not found"
        case .failed: return "Failed"
        case .downloading:
            if !metadataLoaded { return "Finding song info…" }
            if lookupFailed && withinTrack < 0.85 { return "No song info · trying anyway…" }
            if withinTrack < 0.2 { return "Searching…" }
            if withinTrack < 0.85 { return "Downloading…" }
            return "Converting…"
        }
    }

    private func tick() {
        guard isDownloading, completedTracks < tracks.count else { return }
        let cap = metadataLoaded ? 0.93 : 0.08
        withinTrack += (cap - withinTrack) * 0.035
    }

    private func finishedTrackCount(in output: String) -> Int {
        let text = output.lowercased()
        let downloaded = text.components(separatedBy: "downloaded \"").count - 1
        let skipped = text.components(separatedBy: "skipping").count - 1
        return downloaded + skipped
    }

    private func handleOutput(_ text: String) {
        log += text
        downloadOutput += text

        let finished = min(finishedTrackCount(in: downloadOutput), tracks.count)
        if finished > completedTracks {
            withAnimation(.easeInOut(duration: 0.3)) {
                completedTracks = finished
                withinTrack = 0
            }
        }
    }

    // MARK: Download flow

    private func download() {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        downloadQueue.append(DownloadQueueItem(input: input))
        query = ""
        startNextQueuedDownload()
    }

    private func startNextQueuedDownload() {
        guard !isDownloading, !queuePaused,
              activeQueueID == nil,
              let index = downloadQueue.firstIndex(where: { $0.status == .queued })
        else { return }

        let item = downloadQueue[index]
        activeQueueID = item.id
        activeQueueInput = item.input
        downloadQueue[index].status = .downloading
        downloadControl = DownloadJobControl()
        startDownload(input: item.input)
    }

    private func startDownload(input: String) {
        cancelHomeReset()
        let sourceOverride = nextSourceOverride
        activeDownloadSource = nextSourceOverride ?? primaryDownloadSource
        nextSourceOverride = nil

        createOutputFolderIfNeeded()

        downloadOutput = ""
        completedTracks = 0
        withinTrack = 0
        metadataLoaded = false
        lookupFailed = false
        missedCount = 0

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            tracks = [TrackInfo.placeholder(for: input)]
            isDownloading = true
            downloadStatus = .downloading
        }

        log =
            "Starting download with \(activeDownloadSource.title)…\n" +
            "Input: \(input)\n" +
            "Destination: \(outputFolder.path)\n\n"

        if activeDownloadSource == .ytDlp {
            runBackupDownload(
                input: input,
                metadataQuery: input,
                fallbackToSpotDL: sourceOverride == nil
            )
        } else {
            startSpotDL(input: input, fallbackToYtDlp: true)
        }
    }

    private func toggleQueuePause() {
        queuePaused.toggle()
        if queuePaused {
            downloadControl?.pause()
        } else {
            downloadControl?.resume()
            startNextQueuedDownload()
        }
    }

    private func cancelActiveDownload() {
        guard isDownloading else { return }
        downloadControl?.cancel()
    }

    private func cancelQueuedItem(_ item: DownloadQueueItem) {
        guard let index = downloadQueue.firstIndex(where: { $0.id == item.id }),
              downloadQueue[index].status == .queued
        else { return }
        downloadQueue[index].status = .cancelled
    }

    private func retryQueueItem(_ item: DownloadQueueItem) {
        guard let index = downloadQueue.firstIndex(where: { $0.id == item.id }),
              (downloadQueue[index].status == .failed ||
                downloadQueue[index].status == .cancelled)
        else { return }
        downloadQueue[index].status = .queued
        startNextQueuedDownload()
    }

    private func retryLastFailed() {
        guard let item = downloadQueue.last(where: { $0.status == .failed }) else {
            download()
            return
        }
        retryQueueItem(item)
    }

    private func finishActiveQueueItem(_ status: DownloadQueueStatus) {
        guard let queueID = activeQueueID,
              let index = downloadQueue.firstIndex(where: { $0.id == queueID })
        else { return }
        downloadQueue[index].status = status
        activeQueueID = nil
        activeQueueInput = ""
        downloadControl = nil
        isDownloading = false
        if status != .failed,
           !downloadQueue.contains(where: { $0.status == .queued || $0.status == .downloading }),
           !downloadQueue.contains(where: { $0.status == .failed }) {
            showQueue = false
        }
        startNextQueuedDownload()
    }

    private func finishCancelledDownload() {
        log += "\n\nDownload cancelled."
        withAnimation(.easeInOut(duration: 0.2)) {
            tracks = []
            completedTracks = 0
            withinTrack = 0
            downloadStatus = .ready
            isDownloading = false
        }
        finishActiveQueueItem(.cancelled)
    }

    private func startSpotDL(input: String, fallbackToYtDlp: Bool) {
        downloadOutput = ""
        completedTracks = 0
        withinTrack = 0
        metadataLoaded = false
        lookupFailed = false

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            tracks = [TrackInfo.placeholder(for: input)]
            isDownloading = true
            downloadStatus = .downloading
        }
        log += "\nStarting spotDL…\n"
        let control = downloadControl

        DispatchQueue.global(qos: .userInitiated).async {
            guard let executable = SpotDLService.findExecutable() else {
                DispatchQueue.main.async {
                    if fallbackToYtDlp {
                        log += "\nCould not find spotdl. Trying yt-dlp instead…\n"
                        runBackupDownload(
                            input: input,
                            metadataQuery: input,
                            fallbackToSpotDL: false
                        )
                        return
                    }

                    log += """

                    Could not find spotdl.

                    Install it with:
                    python3 -m pip install spotdl

                    Make sure spotdl is available in your PATH.
                    """

                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDownloading = false
                        downloadStatus = .failed
                    }
                    finishActiveQueueItem(.failed)
                    scheduleHomeReset()
                }
                return
            }

            let metadata = SpotDLService.fetchMetadata(
                executable: executable,
                query: input,
                control: control
            )

            DispatchQueue.main.async {
                guard control?.isCancelled != true else {
                    finishCancelledDownload()
                    return
                }

                if !metadata.tracks.isEmpty {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        tracks = metadata.tracks
                    }
                    log += "Found \(metadata.tracks.count) track(s).\n\n"
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        lookupFailed = true
                        tracks = [TrackInfo.unknown(for: input)]
                    }
                    log += "No song info found for this search. Trying to download anyway…\n\n"
                }

                metadataLoaded = true

                runDownload(
                    executable: executable,
                    saveFile: metadata.fileURL,
                    input: input
                )
            }
        }
    }

    private func backupDownload() {
        guard !isDownloading else { return }
        if let index = downloadQueue.lastIndex(where: { $0.status == .failed }) {
            downloadQueue[index].status = .queued
            nextSourceOverride = .ytDlp
            startNextQueuedDownload()
        } else {
            let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { return }
            downloadQueue.append(DownloadQueueItem(input: input))
            query = ""
            nextSourceOverride = .ytDlp
            startNextQueuedDownload()
        }
    }

    private func runBackupDownload(
        input: String,
        metadataQuery: String,
        fallbackToSpotDL: Bool
    ) {
        downloadOutput = ""
        completedTracks = 0
        withinTrack = 0
        metadataLoaded = false
        lookupFailed = false
        missedCount = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            tracks = [TrackInfo.placeholder(for: input)]
            isDownloading = true
            downloadStatus = .downloading
        }
        log += "\nStarting yt-dlp…\n"
        let control = downloadControl

        Task {
            do {
                let metadata = try await BackupDownloadService.lookupMetadata(query: metadataQuery)
                guard control?.isCancelled != true else {
                    finishCancelledDownload()
                    return
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    tracks = [metadata.trackInfo]
                    metadataLoaded = true
                }
                log += "Found complete track metadata and cover art.\n"

                let destinationFolder = outputFolder
                let searchQuery = "\(metadata.artist) - \(metadata.title)"
                let (savedURL, output) = try await Task.detached(priority: .userInitiated) {
                    try BackupDownloadService.download(
                        metadata: metadata,
                        destinationFolder: destinationFolder,
                        searchQuery: searchQuery,
                        control: control
                    )
                }.value

                guard control?.isCancelled != true else {
                    finishCancelledDownload()
                    return
                }
                log += output
                log += "\nBackup download saved to: \(savedURL.path)\n"
                downloadCount += 1
                if query == activeQueueInput { query = "" }
                withAnimation(.easeInOut(duration: 0.3)) {
                    completedTracks = tracks.count
                    withinTrack = 0
                    isDownloading = false
                    downloadStatus = .success
                }
                finishActiveQueueItem(.completed)
                scheduleHomeReset()
            } catch {
                if control?.isCancelled == true {
                    finishCancelledDownload()
                    return
                }

                    if let backupError = error as? BackupDownloadService.BackupError,
                       case .alreadyDownloaded(let existingURL) = backupError {
                        log += "\nAlready in Library: \(existingURL.path)\n"
                        withAnimation(.easeInOut(duration: 0.2)) {
                            completedTracks = tracks.count
                            withinTrack = 0
                            isDownloading = false
                            downloadStatus = .duplicate
                        }
                        finishActiveQueueItem(.completed)
                        scheduleHomeReset()
                        return
                    }

                log += "\nBackup download failed: \(error.localizedDescription)\n"
                if fallbackToSpotDL {
                    log += "Trying spotDL instead…\n"
                    startSpotDL(input: input, fallbackToYtDlp: false)
                    return
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    isDownloading = false
                    downloadStatus = .failed
                }
                finishActiveQueueItem(.failed)
                scheduleHomeReset()
            }
        }
    }

    private func cancelHomeReset() {
        homeResetTask?.cancel()
        homeResetTask = nil
    }

    private func scheduleHomeReset() {
        cancelHomeReset()
        homeResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }

            guard !isDownloading,
                  downloadStatus != .ready,
                  downloadStatus != .notFound
            else {
                homeResetTask = nil
                return
            }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                tracks = []
                completedTracks = 0
                withinTrack = 0
                metadataLoaded = false
                lookupFailed = false
                missedCount = 0
                downloadStatus = .ready
            }
            homeResetTask = nil
        }
    }

    private func runDownload(executable: String, saveFile: URL?, input: String) {
        let process = Process()
        let pipe = Pipe()
        let control = downloadControl

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = saveFile.map { ["download", $0.path] } ?? [input]
        process.currentDirectoryURL = outputFolder
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData

            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            DispatchQueue.main.async {
                handleOutput(text)
            }
        }

        do {
            try process.run()
            control?.attach(process)

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                let status = process.terminationStatus
                control?.detach(process)

                pipe.fileHandleForReading.readabilityHandler = nil
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                let restText = String(data: rest, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if !restText.isEmpty { handleOutput(restText) }
                    finishDownload(status: status, saveFile: saveFile)
                }
            }
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil

            if let saveFile {
                try? FileManager.default.removeItem(at: saveFile)
            }

            DispatchQueue.main.async {
                log +=
                    "\nFailed to start spotDL: " +
                    "\(error.localizedDescription)"

                withAnimation(.easeInOut(duration: 0.2)) {
                    isDownloading = false
                    downloadStatus = .failed
                }
                finishActiveQueueItem(.failed)
                scheduleHomeReset()
            }
        }
    }

    private func finishDownload(status: Int32, saveFile: URL?) {
        if let saveFile {
            try? FileManager.default.removeItem(at: saveFile)
        }

        if downloadControl?.isCancelled == true {
            finishCancelledDownload()
            return
        }

        let output = log.lowercased()
        let raw = downloadOutput.lowercased()
        let downloaded = raw.components(separatedBy: "downloaded \"").count - 1
        let skipped = raw.components(separatedBy: "skipping").count - 1
        let missed = max(
            raw.components(separatedBy: "lookuperror").count - 1,
            raw.components(separatedBy: "no results found").count - 1
        )
        missedCount = missed

        // ตรวจจับ LookupError หรือ No results found ทั้งใน raw output และ log
        let hasLookupError = raw.contains("lookuperror") ||
                             raw.contains("no results found") ||
                             output.contains("lookuperror") ||
                             output.contains("no results found for song")

        let detectedStatus: DownloadStatus

        if (status == 0 && missed > 0 && downloaded == 0 && skipped == 0) || (hasLookupError && downloaded == 0 && skipped == 0) {
            detectedStatus = .notFound
            log += "\n\nSong not found. Try another title, artist, or Spotify URL."
        } else if status == 0 {
            if output.contains("already exists") ||
                output.contains("file exists") ||
                output.contains("skipping") ||
                output.contains("already downloaded") {
                detectedStatus = .duplicate
                log += "\n\nAlready downloaded. The existing file was kept."
            } else {
                detectedStatus = .success
                log += "\n\nFinished successfully."
                downloadCount += max(downloaded, 1)
            }
        } else if hasLookupError ||
                  output.contains("no results") ||
                  output.contains("could not find") ||
                  output.contains("no song") ||
                  output.contains("song not found") ||
                  output.contains("no matches") {
            detectedStatus = .notFound
            log += "\n\nSong not found. Try another title, artist, or Spotify URL."
        } else if output.contains("already exists") ||
                  output.contains("file exists") ||
                  output.contains("already downloaded") {
            detectedStatus = .duplicate
            log += "\n\nAlready downloaded. The existing file was kept."
        } else {
            detectedStatus = .failed
            log += "\n\nspotDL exited with code \(status)."
        }

        var startedFallback = false
        withAnimation(.easeInOut(duration: 0.3)) {
            if activeDownloadSource == .spotDL,
               (detectedStatus == .notFound || detectedStatus == .failed) {
                startedFallback = true
                let input = activeQueueInput
                let metadataQuery: String
                if let track = tracks.first, track.artist != "No song info found" {
                    metadataQuery = "\(track.artist) \(track.title)"
                } else {
                    metadataQuery = input
                }
                log += "Trying yt-dlp as the backup source…\n"
                runBackupDownload(
                    input: input,
                    metadataQuery: metadataQuery,
                    fallbackToSpotDL: false
                )
                return
            }

            downloadStatus = detectedStatus
            isDownloading = false

            if detectedStatus == .success || detectedStatus == .duplicate {
                completedTracks = tracks.count
                withinTrack = 0
            }

            if detectedStatus == .success, query == activeQueueInput {
                query = ""
            }
        }

        if !startedFallback, detectedStatus != .notFound {
            finishActiveQueueItem(
                detectedStatus == .success || detectedStatus == .duplicate
                    ? .completed
                    : .failed
            )
            scheduleHomeReset()
        } else if !startedFallback {
            finishActiveQueueItem(.failed)
        }
    }
}

// MARK: - Output Card

struct OutputCard: View {
    let outputFolder: URL
    let isDownloading: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Download location")
                        .font(.system(size: 13, weight: .medium))

                    Text(outputFolder.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                Button("Change") {
                    onChange()
                }
                .buttonStyle(.borderless)
                .disabled(isDownloading)
            }
        }
        .padding(14)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(
                    .primary.opacity(0.07),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Log View

struct LogView: View {
    let log: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Download Log")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(18)

            Divider()

            ScrollView {
                Text(log)
                    .font(.system(.body, design: .monospaced))
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .textSelection(.enabled)
                    .padding(18)
            }
        }
        .frame(width: 620, height: 420)
    }
}

// MARK: - Tag Service (mutagen through Python)

/// Reads and writes tags, lyrics and cover art with Python's `mutagen`,
/// which is already installed as a dependency of spotDL.
enum TagService {
    private static let python: String? = resolvePython()

    static var installCommand: String {
        "\(python ?? "python3") -m pip install mutagen"
    }

    /// Uses the same interpreter that spotDL runs on (read from its shebang line).
    private static func resolvePython() -> String? {
        if let spotdl = SpotDLService.findExecutable(),
           let handle = FileHandle(forReadingAtPath: spotdl) {
            let head = handle.readData(ofLength: 512)
            try? handle.close()

            if let text = String(data: head, encoding: .utf8),
               let line = text.split(separator: "\n").first,
               line.hasPrefix("#!") {
                let path = line.dropFirst(2).split(separator: " ").first.map(String.init) ?? ""

                if !path.isEmpty,
                   !path.hasSuffix("/env"),
                   FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v python3"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? nil : result
    }

    /// Blocking. Call from a background queue (or use `runAsync`).
    static func run(_ request: [String: Any]) -> [String: Any] {
        guard let interpreter = python else {
            return ["error": "Couldn’t find Python. Install spotDL first."]
        }

        guard let payload = try? JSONSerialization.data(withJSONObject: request) else {
            return ["error": "Couldn’t build the request."]
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: interpreter)
        process.arguments = ["-c", script]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONIOENCODING"] = "utf-8"
        environment["PYTHONUTF8"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            return ["error": "Couldn’t start Python: \(error.localizedDescription)"]
        }

        try? input.fileHandleForWriting.write(contentsOf: payload)
        try? input.fileHandleForWriting.close()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ["error": "Python didn’t return an answer."]
        }

        if json["missingModule"] != nil {
            json["error"] = "mutagen isn’t installed. Run: \(installCommand)"
        }

        return json
    }

    static func runAsync(_ request: [String: Any]) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: run(request))
            }
        }
    }

    private static let script = #"""
import sys, json, os, hashlib

AUDIO_EXTS = (".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav")
KINDS = {".mp3": "mp3", ".m4a": "m4a", ".flac": "flac", ".ogg": "ogg", ".opus": "ogg"}
TEXT_KEYS = ("title", "artist", "album", "albumartist", "year", "track", "genre")


def first(v):
    if v is None:
        return ""
    if isinstance(v, (list, tuple)):
        return str(v[0]) if len(v) else ""
    return str(v)


def kind_of(path):
    return KINDS.get(os.path.splitext(path)[1].lower())


def mime_of(data):
    return "image/png" if data[:8] == b"\x89PNG\r\n\x1a\n" else "image/jpeg"


def blank(path, kind):
    return {
        "path": path, "kind": kind or "", "title": "", "artist": "", "album": "",
        "albumartist": "", "year": "", "track": "", "genre": "", "lyrics": "",
        "hasCover": False, "hasLyrics": False, "cover": "", "duration": 0,
        "bitrate": 0, "editable": kind is not None,
    }


def read(path, cover_dir=None):
    from mutagen import File

    k = kind_of(path)
    d = blank(path, k)
    if k is None:
        return d
    f = File(path)
    if f is None:
        d["editable"] = False
        return d

    info = getattr(f, "info", None)
    d["duration"] = int(getattr(info, "length", 0) or 0)
    d["bitrate"] = int((getattr(info, "bitrate", 0) or 0) / 1000)

    tags = f.tags
    pic = None

    if k == "mp3":
        def tx(key):
            fr = tags.get(key) if tags is not None else None
            try:
                return str(fr.text[0]) if fr is not None and fr.text else ""
            except Exception:
                return ""

        d["title"] = tx("TIT2")
        d["artist"] = tx("TPE1")
        d["album"] = tx("TALB")
        d["albumartist"] = tx("TPE2")
        d["year"] = (tx("TDRC") or tx("TYER"))[:4]
        d["track"] = tx("TRCK")
        d["genre"] = tx("TCON")
        if tags is not None:
            us = tags.getall("USLT")
            if us:
                d["lyrics"] = us[0].text
            ap = tags.getall("APIC")
            if ap:
                best = next((a for a in ap if a.type == 3), ap[0])
                pic = best.data

    elif k == "m4a":
        def g(key):
            return first(tags.get(key)) if tags is not None else ""

        d["title"] = g("\xa9nam")
        d["artist"] = g("\xa9ART")
        d["album"] = g("\xa9alb")
        d["albumartist"] = g("aART")
        d["year"] = g("\xa9day")[:4]
        d["genre"] = g("\xa9gen")
        d["lyrics"] = g("\xa9lyr")
        trk = tags.get("trkn") if tags is not None else None
        if trk:
            n, t = trk[0]
            d["track"] = ("%d/%d" % (n, t)) if t else str(n)
        cv = tags.get("covr") if tags is not None else None
        if cv:
            pic = bytes(cv[0])

    else:
        def g(key):
            return first(tags.get(key)) if tags is not None else ""

        d["title"] = g("title")
        d["artist"] = g("artist")
        d["album"] = g("album")
        d["albumartist"] = g("albumartist")
        d["year"] = g("date")[:4]
        d["track"] = g("tracknumber")
        d["genre"] = g("genre")
        d["lyrics"] = g("lyrics") or g("unsyncedlyrics")
        if k == "flac" and getattr(f, "pictures", None):
            pic = f.pictures[0].data

    d["hasLyrics"] = bool(str(d["lyrics"]).strip())
    if pic:
        d["hasCover"] = True
        if cover_dir:
            os.makedirs(cover_dir, exist_ok=True)
            key = "%s-%d" % (path, int(os.path.getmtime(path)))
            name = hashlib.md5(key.encode("utf-8")).hexdigest()
            name += ".png" if mime_of(pic) == "image/png" else ".jpg"
            out = os.path.join(cover_dir, name)
            if not os.path.isfile(out):
                with open(out, "wb") as fh:
                    fh.write(pic)
            d["cover"] = out
    return d


def scan(folder, cover_dir=None):
    out = []
    if not os.path.isdir(folder):
        return out
    for name in os.listdir(folder):
        if name.startswith("."):
            continue
        p = os.path.join(folder, name)
        if not os.path.isfile(p) or os.path.splitext(name)[1].lower() not in AUDIO_EXTS:
            continue
        try:
            d = read(p, cover_dir)
        except ImportError:
            raise
        except Exception:
            d = blank(p, None)
        d["lyrics"] = ""
        stat = os.stat(p)
        d["added"] = getattr(stat, "st_birthtime", stat.st_mtime)
        d["mtime"] = stat.st_mtime
        out.append(d)
    out.sort(key=lambda x: -x["mtime"])
    return out


def write(path, e):
    k = kind_of(path)
    if k is None:
        raise ValueError("This file format can't be edited")

    ca = e.get("coverAction", "keep")
    cover = None
    if ca == "set":
        with open(e["coverPath"], "rb") as fh:
            cover = fh.read()

    text = {}
    for key in TEXT_KEYS:
        if key in e:
            text[key] = (e.get(key) or "").strip()
    lyrics = None
    if "lyrics" in e:
        lyrics = (e.get("lyrics") or "").replace("\r\n", "\n").strip()

    result = {"ok": True}

    if k == "mp3":
        from mutagen.id3 import (ID3, ID3NoHeaderError, TIT2, TPE1, TALB, TPE2,
                                 TDRC, TRCK, TCON, USLT, APIC)
        try:
            tags = ID3(path)
        except ID3NoHeaderError:
            tags = ID3()

        frames = (("title", TIT2, "TIT2"), ("artist", TPE1, "TPE1"),
                  ("album", TALB, "TALB"), ("albumartist", TPE2, "TPE2"),
                  ("year", TDRC, "TDRC"), ("track", TRCK, "TRCK"),
                  ("genre", TCON, "TCON"))
        for key, cls, frame_id in frames:
            if key in text:
                tags.delall(frame_id)
                if key == "year":
                    tags.delall("TYER")
                if text[key]:
                    tags.add(cls(encoding=1, text=[text[key]]))
        if lyrics is not None:
            tags.delall("USLT")
            if lyrics:
                thai = any("\u0e00" <= c <= "\u0e7f" for c in lyrics)
                tags.add(USLT(encoding=1, lang="tha" if thai else "eng",
                              desc="", text=lyrics))
        if ca in ("set", "remove"):
            tags.delall("APIC")
        if ca == "set":
            tags.add(APIC(encoding=0, mime=mime_of(cover), type=3,
                          desc="Cover", data=cover))
        tags.save(path, v2_version=3)

    elif k == "m4a":
        from mutagen.mp4 import MP4, MP4Cover
        f = MP4(path)
        if f.tags is None:
            f.add_tags()
        t = f.tags

        def setk(key, val):
            if val:
                t[key] = [val]
            elif key in t:
                del t[key]

        names = {"title": "\xa9nam", "artist": "\xa9ART", "album": "\xa9alb",
                 "albumartist": "aART", "year": "\xa9day", "genre": "\xa9gen"}
        for key, atom in names.items():
            if key in text:
                setk(atom, text[key])
        if "track" in text:
            tr = text["track"]
            if tr:
                parts = tr.split("/")
                try:
                    n = int(parts[0])
                    total = int(parts[1]) if len(parts) > 1 and parts[1] else 0
                    t["trkn"] = [(n, total)]
                except ValueError:
                    pass
            elif "trkn" in t:
                del t["trkn"]
        if lyrics is not None:
            setk("\xa9lyr", lyrics)
        if ca in ("set", "remove") and "covr" in t:
            del t["covr"]
        if ca == "set":
            fmt = MP4Cover.FORMAT_PNG if mime_of(cover) == "image/png" else MP4Cover.FORMAT_JPEG
            t["covr"] = [MP4Cover(cover, imageformat=fmt)]
        f.save()

    else:
        from mutagen import File
        f = File(path)
        if f is None:
            raise ValueError("Unreadable file")
        if f.tags is None:
            f.add_tags()
        t = f.tags

        def setv(key, val):
            if val:
                t[key] = [val]
            elif key in t:
                del t[key]

        names = {"title": "title", "artist": "artist", "album": "album",
                 "albumartist": "albumartist", "year": "date",
                 "track": "tracknumber", "genre": "genre"}
        for key, field in names.items():
            if key in text:
                setv(field, text[key])
        if lyrics is not None:
            setv("lyrics", lyrics)
            if "unsyncedlyrics" in t:
                del t["unsyncedlyrics"]
        if k == "flac":
            if ca in ("set", "remove"):
                f.clear_pictures()
            if ca == "set":
                from mutagen.flac import Picture
                pic = Picture()
                pic.type = 3
                pic.mime = mime_of(cover)
                pic.desc = "Cover"
                pic.data = cover
                f.add_picture(pic)
        elif ca != "keep":
            result["warning"] = "Cover art isn't supported for OGG/Opus files"
        f.save()

    return result


def main():
    try:
        req = json.loads(sys.stdin.buffer.read().decode("utf-8"))
        action = req.get("action")
        if action == "ping":
            res = {"ok": True}
        elif action == "scan":
            res = {"files": scan(req["folder"], req.get("coverDir"))}
        elif action == "read":
            res = {"file": read(req["path"], req.get("coverDir"))}
        elif action == "write":
            res = write(req["path"], req["edits"])
        else:
            res = {"error": "Unknown action"}
    except ImportError:
        res = {"error": "The Python package mutagen is not installed", "missingModule": True}
    except Exception as ex:
        res = {"error": "%s: %s" % (type(ex).__name__, ex)}
    sys.stdout.write(json.dumps(res, ensure_ascii=True))
    sys.stdout.flush()


main()
"""#
}

// MARK: - Library Models

struct MusicFile: Identifiable, Equatable {
    var url: URL
    var kind: String
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var year: String
    var track: String
    var genre: String
    var lyrics: String
    var coverPath: String
    var hasCover: Bool
    var hasLyrics: Bool
    var duration: Int
    var bitrate: Int
    var fileSizeBytes: Int64
    var addedDate: Date
    var editable: Bool

    var id: URL { url }
    var fileName: String { url.deletingPathExtension().lastPathComponent }
    var displayTitle: String { title.isEmpty ? fileName : title }
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var subtitle: String {
        let parts = [artist, album].filter { !$0.isEmpty }
        return parts.isEmpty ? "No tags" : parts.joined(separator: " — ")
    }

    var formatLabel: String {
        let ext = url.pathExtension.uppercased()
        return bitrate > 0 ? "\(ext) · \(bitrate)k" : ext
    }

    /// Title / artist to search online with; falls back to "Artist - Title" in the file name.
    var searchTerms: (title: String, artist: String) {
        if !title.isEmpty { return (title, artist) }

        let parts = fileName.components(separatedBy: " - ")
        if parts.count >= 2 {
            return (parts.dropFirst().joined(separator: " - "), parts[0])
        }
        return (fileName, artist)
    }

    init(json d: [String: Any]) {
        url = URL(fileURLWithPath: d["path"] as? String ?? "")
        kind = d["kind"] as? String ?? ""
        title = d["title"] as? String ?? ""
        artist = d["artist"] as? String ?? ""
        album = d["album"] as? String ?? ""
        albumArtist = d["albumartist"] as? String ?? ""
        year = d["year"] as? String ?? ""
        track = d["track"] as? String ?? ""
        genre = d["genre"] as? String ?? ""
        lyrics = d["lyrics"] as? String ?? ""
        coverPath = d["cover"] as? String ?? ""
        hasCover = d["hasCover"] as? Bool ?? false
        hasLyrics = d["hasLyrics"] as? Bool ?? false
        duration = d["duration"] as? Int ?? 0
        bitrate = d["bitrate"] as? Int ?? 0
        fileSizeBytes = Self.fileSize(of: url)
        addedDate = Self.addedDate(of: url, timestamp: d["added"] as? Double)
        editable = d["editable"] as? Bool ?? false
    }

    /// Used when tags can’t be read (for example, mutagen is missing).
    init(plain url: URL) {
        self.url = url
        kind = ""
        title = ""
        artist = ""
        album = ""
        albumArtist = ""
        year = ""
        track = ""
        genre = ""
        lyrics = ""
        coverPath = ""
        hasCover = false
        hasLyrics = false
        duration = 0
        bitrate = 0
        fileSizeBytes = Self.fileSize(of: url)
        addedDate = Self.addedDate(of: url, timestamp: nil)
        editable = false
    }

    private static func addedDate(of url: URL, timestamp: Double?) -> Date {
        if let timestamp, timestamp.isFinite {
            return Date(timeIntervalSince1970: timestamp)
        }
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate ?? .distantPast
    }

    private static func fileSize(of url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
}

enum CoverChange: Equatable {
    case keep
    case remove
    case set(String)
}

struct TagEdit: Equatable {
    var title = ""
    var artist = ""
    var album = ""
    var albumArtist = ""
    var year = ""
    var track = ""
    var genre = ""
    var lyrics = ""

    init() {}

    init(_ f: MusicFile) {
        title = f.title
        artist = f.artist
        album = f.album
        albumArtist = f.albumArtist
        year = f.year
        track = f.track
        genre = f.genre
        lyrics = f.lyrics
    }

    /// Only the fields that changed are sent, so untouched tags are never rewritten.
    func payload(changedFrom old: TagEdit, cover: CoverChange) -> [String: Any] {
        var d: [String: Any] = [:]

        if title != old.title { d["title"] = title }
        if artist != old.artist { d["artist"] = artist }
        if album != old.album { d["album"] = album }
        if albumArtist != old.albumArtist { d["albumartist"] = albumArtist }
        if year != old.year { d["year"] = year }
        if track != old.track { d["track"] = track }
        if genre != old.genre { d["genre"] = genre }
        if lyrics != old.lyrics { d["lyrics"] = lyrics }

        switch cover {
        case .keep:
            d["coverAction"] = "keep"
        case .remove:
            d["coverAction"] = "remove"
        case .set(let path):
            d["coverAction"] = "set"
            d["coverPath"] = path
        }

        return d
    }
}

// MARK: - Online Lookup (Apple Music search + LRCLIB lyrics)

struct OnlineMatch: Identifiable, Equatable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let genre: String
    let year: String
    let track: String
    let artworkURL: URL?
    let thumbnailURL: URL?

    var subtitle: String {
        album.isEmpty ? artist : "\(artist) — \(album)"
    }

    init?(itunes d: [String: Any]) {
        guard let title = d["trackName"] as? String,
              let artist = d["artistName"] as? String
        else { return nil }

        self.title = title
        self.artist = artist
        id = d["trackId"] as? Int ?? Int.random(in: 1...Int.max)
        album = d["collectionName"] as? String ?? ""
        genre = d["primaryGenreName"] as? String ?? ""
        year = String((d["releaseDate"] as? String ?? "").prefix(4))

        let number = d["trackNumber"] as? Int ?? 0
        let total = d["trackCount"] as? Int ?? 0
        track = number == 0 ? "" : (total > 0 ? "\(number)/\(total)" : "\(number)")

        let small = d["artworkUrl100"] as? String
        thumbnailURL = small.flatMap { URL(string: $0) }
        artworkURL = small.flatMap {
            URL(string: $0.replacingOccurrences(of: "100x100bb", with: "1200x1200bb"))
        }
    }

    func looksLike(title other: String) -> Bool {
        let a = Self.normalize(title)
        let b = Self.normalize(other)
        return !a.isEmpty && !b.isEmpty && (a.contains(b) || b.contains(a))
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

enum OnlineLookup {
    struct Lyrics {
        var plain: String?
        var synced: String?
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("SpotDLDownloader/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200
        else { return nil }

        return data
    }

    /// Apple Music (iTunes Search API). No key needed.
    static func searchSongs(_ term: String) async -> [OnlineMatch] {
        let region = Locale.current.region?.identifier ?? "US"
        let regions = region == "US" ? ["US"] : [region, "US"]

        for country in regions {
            var components = URLComponents(string: "https://itunes.apple.com/search")!
            components.queryItems = [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "media", value: "music"),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "limit", value: "6"),
                URLQueryItem(name: "country", value: country)
            ]

            guard let url = components.url,
                  let data = await fetch(url),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let results = json["results"] as? [[String: Any]]
            else { continue }

            let matches = results.compactMap { OnlineMatch(itunes: $0) }
            if !matches.isEmpty { return matches }
        }

        return []
    }

    static func cover(url: URL) async -> (path: String, image: NSImage)? {
        guard let data = await fetch(url) else { return nil }
        return CoverTool.prepare(data: data)
    }

    /// Best-effort cover for a song, only when the result clearly matches the title.
    static func cover(title: String, artist: String) async -> (path: String, image: NSImage)? {
        let matches = await searchSongs("\(artist) \(title)")

        guard let match = matches.first(where: { $0.looksLike(title: title) }),
              let url = match.artworkURL
        else { return nil }

        return await cover(url: url)
    }

    /// LRCLIB: free lyrics database, plain and timed (LRC).
    static func lyrics(title: String, artist: String, duration: Int) async -> Lyrics? {
        var attempts: [[URLQueryItem]] = []

        var precise = [URLQueryItem(name: "track_name", value: title)]
        if !artist.isEmpty { precise.append(URLQueryItem(name: "artist_name", value: artist)) }
        attempts.append(precise)
        attempts.append([URLQueryItem(name: "q", value: "\(artist) \(title)")])

        for items in attempts {
            var components = URLComponents(string: "https://lrclib.net/api/search")!
            components.queryItems = items

            guard let url = components.url,
                  let data = await fetch(url),
                  let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
            else { continue }

            let usable = list.filter {
                !(($0["plainLyrics"] as? String) ?? "").isEmpty ||
                !(($0["syncedLyrics"] as? String) ?? "").isEmpty
            }
            guard !usable.isEmpty else { continue }

            var best = usable[0]
            if duration > 0 {
                best = usable.min { a, b in
                    abs(((a["duration"] as? Double) ?? 0) - Double(duration)) <
                    abs(((b["duration"] as? Double) ?? 0) - Double(duration))
                } ?? usable[0]
            }

            let plain = (best["plainLyrics"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let synced = (best["syncedLyrics"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return Lyrics(plain: plain, synced: synced)
        }

        return nil
    }

    /// "[00:12.34] text" → "text"
    static func stripTimestamps(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\[[0-9:.]+\]\s*"#,
            with: "",
            options: .regularExpression
        )
    }
}

enum CoverTool {
    /// Re-encodes any image as a JPEG (max 1200 px) so it’s small and works in every player.
    static func prepare(data: Data) -> (path: String, image: NSImage)? {
        guard let source = NSImage(data: data),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let scale = min(1, 1200 / max(width, height))
        let size = NSSize(width: (width * scale).rounded(), height: (height * scale).rounded())

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSImage(cgImage: cg, size: size).draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        guard let jpeg = rep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.92]
        ) else { return nil }

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotdl-cover-\(UUID().uuidString).jpg")

        do {
            try jpeg.write(to: file)
        } catch {
            return nil
        }

        return (file.path, NSImage(data: jpeg) ?? source)
    }
}

enum MusicSyncService {
    struct Result {
        let added: Int
        let alreadyPresent: Int
        let failed: Int
    }

    enum SyncError: LocalizedError {
        case unavailable(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): return message
            case .invalidResponse: return "Music returned an unexpected response."
            }
        }
    }

    static func addTracks(paths: [String]) throws -> Result {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script] + paths
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw SyncError.unavailable(error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw SyncError.unavailable(output.isEmpty ? "Could not contact Music." : output)
        }

        let counts = output.split(separator: "|").compactMap { Int($0) }
        guard counts.count == 3 else { throw SyncError.invalidResponse }
        return Result(added: counts[0], alreadyPresent: counts[1], failed: counts[2])
    }

    private static let script = #"""
    on run argv
        tell application "Music"
            if not (exists user playlist "Podly Sync") then
                make new user playlist with properties {name:"Podly Sync"}
            end if
            set syncPlaylist to user playlist "Podly Sync"
            set existingPaths to {}
            repeat with playlistTrack in (get tracks of syncPlaylist)
                try
                    set end of existingPaths to POSIX path of (get location of playlistTrack)
                end try
            end repeat
            set addedCount to 0
            set existingCount to 0
            set failedCount to 0
            repeat with songPath in argv
                set pathText to contents of songPath
                if pathText is in existingPaths then
                    set existingCount to existingCount + 1
                else
                    try
                        add (POSIX file pathText) to syncPlaylist
                        set end of existingPaths to pathText
                        set addedCount to addedCount + 1
                    on error
                        set failedCount to failedCount + 1
                    end try
                end if
            end repeat
        end tell
        return (addedCount as text) & "|" & (existingCount as text) & "|" & (failedCount as text)
    end run
    """#
}

// MARK: - Library Model

final class LibraryModel: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    struct SaveResult {
        var file: MusicFile?
        var error: String?
        var warning: String?
    }

    enum BatchKind {
        case lyrics
        case covers

        var label: String { self == .lyrics ? "lyrics" : "covers" }
    }

    @Published var files: [MusicFile] = []
    @Published var isLoading = false
    @Published var toolsMissing = false
    @Published var toast: Toast?
    @Published var busy: Set<URL> = []
    @Published var batchStatus: String?
    @Published var isSyncingToMusic = false

    private var cancelBatch = false

    let coverDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("spotdl-covers").path

    var isBatching: Bool { batchStatus != nil }

    // MARK: Feedback

    func showToast(_ text: String, error: Bool = false) {
        let item = Toast(text: text, isError: error)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toast = item
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, self.toast?.id == item.id else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.toast = nil
            }
        }
    }

    func sendToMusic() {
        guard !isSyncingToMusic, !files.isEmpty else { return }
        isSyncingToMusic = true
        let paths = files.map { $0.url.path }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try MusicSyncService.addTracks(paths: paths)
                DispatchQueue.main.async {
                    self.isSyncingToMusic = false
                    if result.failed > 0 {
                        self.showToast(
                            "Added \(result.added) · \(result.alreadyPresent) already there · \(result.failed) failed",
                            error: true
                        )
                    } else {
                        self.showToast(
                            "Podly Sync ready · added \(result.added), already there \(result.alreadyPresent) · finish in Finder"
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSyncingToMusic = false
                    self.showToast(error.localizedDescription, error: true)
                }
            }
        }
    }

    // MARK: Loading

    func reload(folder: URL) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let result = TagService.run([
                "action": "scan",
                "folder": folder.path,
                "coverDir": self.coverDir
            ])

            var list: [MusicFile] = []
            var missing = false

            if let items = result["files"] as? [[String: Any]] {
                list = items.map { MusicFile(json: $0) }
            } else {
                missing = true
                list = LibraryModel.plainListing(folder)
            }

            DispatchQueue.main.async {
                self.files = list
                self.toolsMissing = missing
                self.isLoading = false
            }
        }
    }

    /// File names only — used when tags can’t be read.
    private static func plainListing(_ folder: URL) -> [MusicFile] {
        let audio: Set<String> = ["mp3", "m4a", "flac", "ogg", "opus", "wav"]
        let keys: [URLResourceKey] = [.contentModificationDateKey]

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { audio.contains($0.pathExtension.lowercased()) }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                return a > b
            }
            .map { MusicFile(plain: $0) }
    }

    func replace(_ updated: MusicFile) {
        if let index = files.firstIndex(where: { $0.url == updated.url }) {
            files[index] = updated
        }
    }

    /// Full read of one file: all tags, lyrics and a preview of the cover.
    func readDetail(_ file: MusicFile, completion: @escaping (MusicFile?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = TagService.run([
                "action": "read",
                "path": file.url.path,
                "coverDir": self.coverDir
            ])

            DispatchQueue.main.async {
                if let dict = result["file"] as? [String: Any] {
                    completion(MusicFile(json: dict), nil)
                } else {
                    completion(nil, result["error"] as? String ?? "Couldn’t read this file.")
                }
            }
        }
    }

    // MARK: Saving

    func save(_ file: MusicFile, edits: [String: Any], completion: @escaping (SaveResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = TagService.run([
                "action": "write",
                "path": file.url.path,
                "edits": edits
            ])

            if let error = result["error"] as? String {
                DispatchQueue.main.async {
                    completion(SaveResult(file: nil, error: error, warning: nil))
                }
                return
            }

            let fresh = TagService.run([
                "action": "read",
                "path": file.url.path,
                "coverDir": self.coverDir
            ])
            let updated = (fresh["file"] as? [String: Any]).map { MusicFile(json: $0) }

            DispatchQueue.main.async {
                if let updated { self.replace(updated) }
                completion(SaveResult(
                    file: updated,
                    error: nil,
                    warning: result["warning"] as? String
                ))
            }
        }
    }

    // MARK: File actions

    func rename(_ file: MusicFile) {
        let name = [file.artist, file.title]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")

        guard !file.title.isEmpty, !name.isEmpty else {
            showToast("Add a title first, then rename.", error: true)
            return
        }

        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)

        let destination = file.url
            .deletingLastPathComponent()
            .appendingPathComponent(safe)
            .appendingPathExtension(file.url.pathExtension)

        if destination == file.url {
            showToast("Already named that way.")
            return
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            showToast("A file with that name already exists.", error: true)
            return
        }

        do {
            try FileManager.default.moveItem(at: file.url, to: destination)

            if let index = files.firstIndex(where: { $0.url == file.url }) {
                files[index].url = destination
            }
            showToast("Renamed to “\(destination.lastPathComponent)”")
        } catch {
            showToast("Couldn’t rename: \(error.localizedDescription)", error: true)
        }
    }

    func trash(_ file: MusicFile) {
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            files.removeAll { $0.url == file.url }
            showToast("Moved to Trash")
        } catch {
            showToast("Couldn’t move to Trash: \(error.localizedDescription)", error: true)
        }
    }

    /// Lets spotDL match the song on Spotify and rewrite its tags, cover and lyrics.
    func retag(_ file: MusicFile) {
        guard !busy.contains(file.url) else { return }
        busy.insert(file.url)

        DispatchQueue.global(qos: .userInitiated).async {
            var succeeded = false

            if let executable = SpotDLService.findExecutable() {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = ["meta", file.url.path]
                process.currentDirectoryURL = file.url.deletingLastPathComponent()
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                if (try? process.run()) != nil {
                    process.waitUntilExit()
                    succeeded = process.terminationStatus == 0
                }
            }

            let fresh = succeeded
                ? TagService.run(["action": "read", "path": file.url.path])
                : [:]

            DispatchQueue.main.async {
                self.busy.remove(file.url)

                if succeeded {
                    if let dict = fresh["file"] as? [String: Any] {
                        self.replace(MusicFile(json: dict))
                    }
                    self.showToast("Updated from Spotify")
                } else {
                    self.showToast("spotDL couldn’t update this file.", error: true)
                }
            }
        }
    }

    // MARK: Batch

    func stopBatch() {
        cancelBatch = true
    }

    /// Adds lyrics or covers to every song that is missing them.
    func startBatch(_ kind: BatchKind) {
        guard !isBatching else { return }

        let targets = files.filter {
            $0.editable && (kind == .lyrics ? !$0.hasLyrics : !$0.hasCover)
        }

        guard !targets.isEmpty else {
            showToast("Every song already has \(kind.label).")
            return
        }

        cancelBatch = false
        batchStatus = "Adding \(kind.label) · 0 of \(targets.count)"

        Task { @MainActor in
            var added = 0

            for (index, file) in targets.enumerated() {
                if cancelBatch { break }

                batchStatus = "Adding \(kind.label) · \(index + 1) of \(targets.count)"

                let terms = file.searchTerms
                var edits: [String: Any]?

                switch kind {
                case .lyrics:
                    if let found = await OnlineLookup.lyrics(
                        title: terms.title,
                        artist: terms.artist,
                        duration: file.duration
                    ),
                       let text = found.plain ?? found.synced.map(OnlineLookup.stripTimestamps) {
                        edits = ["lyrics": text]
                    }
                    try? await Task.sleep(nanoseconds: 400_000_000)

                case .covers:
                    if let cover = await OnlineLookup.cover(
                        title: terms.title,
                        artist: terms.artist
                    ) {
                        edits = ["coverAction": "set", "coverPath": cover.path]
                    }
                    // Apple’s search API allows roughly 20 requests a minute.
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }

                if let edits {
                    let result = await TagService.runAsync([
                        "action": "write",
                        "path": file.url.path,
                        "edits": edits
                    ])

                    if result["error"] == nil,
                       let i = files.firstIndex(where: { $0.url == file.url }) {
                        if kind == .lyrics {
                            files[i].hasLyrics = true
                        } else {
                            files[i].hasCover = true
                        }
                        added += 1
                    }
                }
            }

            let stopped = cancelBatch
            batchStatus = nil
            showToast(
                stopped
                    ? "Stopped · added \(kind.label) to \(added) songs"
                    : "Added \(kind.label) to \(added) of \(targets.count) songs"
            )
        }
    }
}

@MainActor
final class AudioPlayerModel: ObservableObject {
    @Published private(set) var queue: [MusicFile] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var playbackError: String?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemStatusObservation: NSKeyValueObservation?

    var currentTrack: MusicFile? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if time.seconds.isFinite { currentTime = max(0, time.seconds) }
                if let seconds = player.currentItem?.duration.seconds, seconds.isFinite {
                    duration = max(0, seconds)
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let currentIndex, currentIndex + 1 < queue.count {
                    startTrack(at: currentIndex + 1)
                } else {
                    isPlaying = false
                    currentTime = duration
                }
            }
        }
    }

    func play(_ file: MusicFile, from files: [MusicFile]) {
        let currentURL = currentTrack?.url
        queue = files
        guard let index = queue.firstIndex(where: { $0.url == file.url }) else { return }

        if currentURL == file.url, player.currentItem != nil {
            togglePlayback()
        } else {
            startTrack(at: index)
        }
    }

    func togglePlayback() {
        guard player.currentItem != nil else {
            if let currentIndex { startTrack(at: currentIndex) }
            return
        }

        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemStatusObservation = nil
        queue = []
        currentIndex = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        playbackError = nil
    }

    func previous() {
        guard let currentIndex else { return }
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            startTrack(at: currentIndex - 1)
        }
    }

    func next() {
        guard let currentIndex, currentIndex + 1 < queue.count else { return }
        startTrack(at: currentIndex + 1)
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        currentTime = max(0, seconds)
    }

    private func startTrack(at index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        currentTime = 0
        duration = 0
        playbackError = nil
        let item = AVPlayerItem(url: queue[index].url)
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "This audio format could not be played."
            Task { @MainActor [weak self] in
                self?.playbackError = message
                self?.isPlaying = false
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
    }
}

struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayerModel

    var body: some View {
        HStack(spacing: 14) {
            artwork
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.displayTitle ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(player.playbackError ?? player.currentTrack?.subtitle ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(player.playbackError == nil ? Color.secondary : Color.red)
                    .lineLimit(1)
            }
            .frame(width: 180, alignment: .leading)

            Spacer(minLength: 4)

            HStack(spacing: 18) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.end.fill")
                }
                .help("Previous track")
                .disabled(player.queue.count < 2)

                Button { player.togglePlayback() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .help(player.isPlaying ? "Pause" : "Play")

                Button { player.next() } label: {
                    Image(systemName: "forward.end.fill")
                }
                .help("Next track")
                .disabled(player.queue.count < 2)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                HStack {
                    Text(Self.time(player.currentTime))
                    Spacer()
                    Text(Self.time(player.duration))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 300)
            .disabled(player.duration <= 0)

            Button { player.stop() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Stop and close player")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var artwork: some View {
        if let track = player.currentTrack,
           track.hasCover,
           let image = NSImage(contentsOfFile: track.coverPath) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.primary.opacity(0.07)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

// MARK: - Library View

struct LibraryRow: View {
    let file: MusicFile
    let isBusy: Bool
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.07))

                    if file.hasCover,
                       let image = NSImage(contentsOfFile: file.coverPath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isCurrentTrack && isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(isCurrentTrack && isPlaying ? "Pause" : "Play")

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(file.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                badge("photo", isOn: file.hasCover, on: "Has cover art", off: "No cover art")
                badge("text.quote", isOn: file.hasLyrics, on: "Has lyrics", off: "No lyrics")
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(file.formattedFileSize)
                    .font(.system(size: 11, weight: .medium))

                Text(file.formatLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 100, alignment: .trailing)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Edit tags")
            .disabled(!file.editable)
        }
        .padding(.vertical, 4)
        .opacity(file.editable ? 1 : 0.6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if file.editable { onEdit() }
        }
    }

    private func badge(_ symbol: String, isOn: Bool, on: String, off: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12))
            .foregroundStyle(isOn ? Color.accentColor : Color.primary.opacity(0.18))
            .help(isOn ? on : off)
    }
}

struct LibraryView: View {
    @Environment(\.podlyTheme) private var theme
    @StateObject private var model = LibraryModel()
    @EnvironmentObject private var player: AudioPlayerModel

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    @State private var search = ""
    @State private var showDuplicates = false
    @State private var editing: MusicFile?
    @State private var pendingTrash: MusicFile?
    @AppStorage("librarySortOrder")
    private var sortOrderRawValue = LibrarySortOrder.dateAdded.rawValue

    private var folder: URL {
        URL(fileURLWithPath: customOutputPath)
    }

    private var sortOrder: LibrarySortOrder {
        LibrarySortOrder(rawValue: sortOrderRawValue) ?? .dateAdded
    }

    private var duplicateTitleKeys: Set<String> {
        Set(
            Dictionary(grouping: model.files, by: Self.normalizedTitle)
                .filter { !$0.key.isEmpty && $0.value.count > 1 }
                .keys
        )
    }

    private var filtered: [MusicFile] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let duplicateTitles = duplicateTitleKeys

        let matches = model.files.filter { file in
            if showDuplicates && !duplicateTitles.contains(Self.normalizedTitle(file)) {
                return false
            }

            guard !q.isEmpty else { return true }
            return [file.title, file.artist, file.album, file.fileName]
                .joined(separator: " ")
                .lowercased()
                .contains(q)
        }

        switch sortOrder {
        case .title:
            return matches.sorted {
                let result = $0.displayTitle.localizedStandardCompare($1.displayTitle)
                if result == .orderedSame {
                    return $0.artist.localizedStandardCompare($1.artist) == .orderedAscending
                }
                return result == .orderedAscending
            }
        case .dateAdded:
            return matches.sorted {
                if $0.addedDate == $1.addedDate {
                    return $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
                }
                return $0.addedDate > $1.addedDate
            }
        }
    }

    private static func normalizedTitle(_ file: MusicFile) -> String {
        normalizedTitle(file.displayTitle)
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private var totalStorageUsed: String {
        let bytes = model.files.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if model.toolsMissing {
                toolsBanner
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.canvas)
        .overlay(alignment: .bottom) { toastView }
        .onAppear { model.reload(folder: folder) }
        .onChange(of: customOutputPath) { _ in model.reload(folder: folder) }
        .sheet(item: $editing) { file in
            TrackEditorView(file: file, model: model)
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            ),
            presenting: pendingTrash
        ) { file in
            Button("Move “\(file.displayTitle)” to Trash", role: .destructive) {
                model.trash(file)
            }
        } message: { _ in
            Text("You can restore it from the Trash.")
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: 20, weight: .semibold))

            if !model.files.isEmpty {
                Text("\(model.files.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Text("\(totalStorageUsed) used")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let status = model.batchStatus {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)

                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Button("Stop") { model.stopBatch() }
                        .controlSize(.small)
                }
            } else {
                Menu {
                    Button("Add missing lyrics") { model.startBatch(.lyrics) }
                    Button("Add missing covers") { model.startBatch(.covers) }
                } label: {
                    Label("Complete", systemImage: "wand.and.stars")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(model.toolsMissing || model.files.isEmpty)
                .help("Fill in missing lyrics or covers for the whole library")
            }

            Button {
                model.sendToMusic()
            } label: {
                if model.isSyncingToMusic {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.to.line")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Add all Library songs to the Podly Sync playlist in Music; finish syncing in Finder")
            .disabled(model.isSyncingToMusic || model.files.isEmpty)

            Button {
                showDuplicates.toggle()
            } label: {
                Image(systemName: showDuplicates ? "doc.on.doc.fill" : "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(showDuplicates ? Color.accentColor : Color.secondary)
            .accessibilityLabel(showDuplicates ? "Show all songs" : "Show duplicate titles")
            .help(showDuplicates ? "Show all songs" : "Show songs with duplicate titles")
            .disabled(model.files.isEmpty)

            Menu {
                ForEach(LibrarySortOrder.allCases) { option in
                    Button {
                        sortOrderRawValue = option.rawValue
                    } label: {
                        if sortOrder == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: sortOrder.icon)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Sort songs by \(sortOrder.title.lowercased())")
            .disabled(model.files.isEmpty)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .frame(width: 170)

            Button {
                model.reload(folder: folder)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var toolsBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Editing tags needs Python with the mutagen package.")
                    .font(.system(size: 12, weight: .medium))

                Text(TagService.installCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(TagService.installCommand, forType: .string)
            }
            .controlSize(.small)

            Button("Recheck") {
                model.reload(folder: folder)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.files.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.files.isEmpty {
            emptyState
        } else if filtered.isEmpty {
            Text(
                showDuplicates
                    ? (duplicateTitleKeys.isEmpty
                        ? "No duplicate song titles found."
                        : "No duplicate songs match “\(search)”.")
                    : "No songs match “\(search)”."
            )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filtered) { file in
                LibraryRow(
                    file: file,
                    isBusy: model.busy.contains(file.url),
                    isCurrentTrack: player.currentTrack?.url == file.url,
                    isPlaying: player.isPlaying,
                    onPlay: { player.play(file, from: filtered) }
                ) {
                    editing = file
                }
                .contextMenu { rowMenu(file) }
            }
            .listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No songs yet")
                .font(.system(size: 15, weight: .medium))

            Text("Songs you download appear here, ready to tag.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(folder.path)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rowMenu(_ file: MusicFile) -> some View {
        Button("Edit Tags…") { editing = file }
            .disabled(!file.editable)

        Button("Re-tag with spotDL") { model.retag(file) }
            .disabled(!file.editable)

        Button("Rename from Tags") { model.rename(file) }
            .disabled(file.title.isEmpty)

        Divider()

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        }

        Button("Move to Trash…", role: .destructive) {
            pendingTrash = file
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = model.toast {
            Label(
                toast.text,
                systemImage: toast.isError
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.circle.fill"
            )
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Track Editor

struct EditorMessage {
    let text: String
    let isError: Bool
}

struct TrackEditorView: View {
    let file: MusicFile
    @ObservedObject var model: LibraryModel

    @Environment(\.dismiss) private var dismiss

    @State private var edit = TagEdit()
    @State private var original = TagEdit()
    @State private var cover: NSImage?
    @State private var coverChange: CoverChange = .keep
    @State private var detail: MusicFile?

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: EditorMessage?

    @State private var matches: [OnlineMatch] = []
    @State private var showMatches = false
    @State private var isSearching = false
    @State private var isFindingLyrics = false
    @State private var preferSynced = false
    @State private var dropTargeted = false

    private var isDirty: Bool {
        edit != original || coverChange != .keep
    }

    private var canEdit: Bool {
        file.editable && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(alignment: .top, spacing: 22) {
                coverColumn
                fieldsColumn
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 12)

            lyricsSection
                .padding(.horizontal, 22)

            Spacer(minLength: 0)

            Divider()
            footer
        }
        .frame(width: 660, height: 520)
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(infoLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private var infoLine: String {
        let source = detail ?? file
        var parts = [source.url.pathExtension.uppercased()]

        if source.bitrate > 0 { parts.append("\(source.bitrate) kbps") }
        if source.duration > 0 {
            parts.append(String(format: "%d:%02d", source.duration / 60, source.duration % 60))
        }
        return parts.joined(separator: " · ")
    }

    private var coverColumn: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))

                if let cover {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .light))

                        Text("Drop an image")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        dropTargeted ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: dropTargeted ? 2 : 1
                    )
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)

            HStack(spacing: 8) {
                Button("Choose…", action: chooseCover)

                Button {
                    removeCover()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Remove cover")
                .disabled(cover == nil)
            }
            .controlSize(.small)
            .disabled(!canEdit)
        }
        .frame(width: 160)
    }

    private var fieldsColumn: some View {
        VStack(spacing: 8) {
            field("Title", $edit.title)
            field("Artist", $edit.artist)
            field("Album", $edit.album)
            field("Album artist", $edit.albumArtist)

            HStack(spacing: 10) {
                field("Genre", $edit.genre)
                field("Year", $edit.year, labelWidth: 34)
                    .frame(width: 110)
                field("Track", $edit.track, labelWidth: 38)
                    .frame(width: 112)
            }

            HStack(spacing: 8) {
                Button {
                    autoFill()
                } label: {
                    Label("Auto-fill from Apple Music", systemImage: "wand.and.stars")
                }
                .controlSize(.small)
                .disabled(isSearching)
                .popover(isPresented: $showMatches, arrowEdge: .bottom) {
                    matchesList
                }

                if isSearching {
                    ProgressView().controlSize(.small)
                }

                Spacer()
            }
            .padding(.leading, 86)
        }
        .disabled(!canEdit)
    }

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Lyrics")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Timed (LRC)", isOn: $preferSynced)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .font(.system(size: 11))

                Button {
                    findLyrics()
                } label: {
                    if isFindingLyrics {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Find lyrics", systemImage: "text.quote")
                    }
                }
                .controlSize(.small)
                .disabled(!canEdit || isFindingLyrics)
            }

            TextEditor(text: $edit.lyrics)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .frame(height: 130)
                .disabled(!canEdit)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let message {
                Label(
                    message.text,
                    systemImage: message.isError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.system(size: 12))
                .foregroundStyle(message.isError ? Color.orange : Color.secondary)
                .lineLimit(2)
            } else if !file.editable {
                Text("This format can’t be edited.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isDirty || isSaving || !canEdit)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private var matchesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick the right song")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ForEach(matches) { match in
                Button {
                    apply(match)
                } label: {
                    HStack(spacing: 10) {
                        AsyncImage(url: match.thumbnailURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.primary.opacity(0.08)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Text(match.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 320)
        .padding(.bottom, 8)
    }

    private func field(_ label: String, _ text: Binding<String>, labelWidth: CGFloat = 76) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)

            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Actions

    private func load() {
        model.readDetail(file) { loaded, error in
            isLoading = false

            if let loaded {
                detail = loaded
                edit = TagEdit(loaded)
                original = edit

                if !loaded.coverPath.isEmpty {
                    cover = NSImage(contentsOfFile: loaded.coverPath)
                }
            } else {
                edit = TagEdit(file)
                original = edit

                if let error {
                    message = EditorMessage(text: error, isError: true)
                }
            }
        }
    }

    private func chooseCover() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cover Image"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            setCover(from: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard canEdit, let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                setCover(from: url)
            }
        }
        return true
    }

    private func setCover(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let prepared = CoverTool.prepare(data: data)
        else {
            message = EditorMessage(text: "That file isn’t a readable image.", isError: true)
            return
        }
        applyCover(prepared)
    }

    private func applyCover(_ prepared: (path: String, image: NSImage)) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cover = prepared.image
        }
        coverChange = .set(prepared.path)
    }

    private func removeCover() {
        withAnimation(.easeInOut(duration: 0.2)) {
            cover = nil
        }
        coverChange = .remove
    }

    private func autoFill() {
        let words = [edit.artist, edit.title].filter { !$0.isEmpty }.joined(separator: " ")
        let term = words.isEmpty ? file.fileName : words

        isSearching = true
        message = nil

        Task { @MainActor in
            let found = await OnlineLookup.searchSongs(term)
            isSearching = false
            matches = found

            if found.isEmpty {
                message = EditorMessage(
                    text: "No matches on Apple Music. Try changing the title or artist.",
                    isError: true
                )
            } else {
                showMatches = true
            }
        }
    }

    private func apply(_ match: OnlineMatch) {
        showMatches = false

        edit.title = match.title
        edit.artist = match.artist
        edit.album = match.album
        if !match.genre.isEmpty { edit.genre = match.genre }
        if !match.year.isEmpty { edit.year = match.year }
        if !match.track.isEmpty { edit.track = match.track }
        if edit.albumArtist.isEmpty { edit.albumArtist = match.artist }

        message = EditorMessage(text: "Filled in from Apple Music.", isError: false)

        guard let url = match.artworkURL else { return }

        Task { @MainActor in
            if let prepared = await OnlineLookup.cover(url: url) {
                applyCover(prepared)
            }
        }
    }

    private func findLyrics() {
        let terms = file.searchTerms
        let title = edit.title.isEmpty ? terms.title : edit.title
        let artist = edit.artist.isEmpty ? terms.artist : edit.artist

        isFindingLyrics = true
        message = nil

        Task { @MainActor in
            let found = await OnlineLookup.lyrics(
                title: title,
                artist: artist,
                duration: (detail ?? file).duration
            )
            isFindingLyrics = false

            var text: String?
            var timed = false

            if let found {
                if preferSynced, let synced = found.synced {
                    text = synced
                    timed = true
                } else {
                    text = found.plain ?? found.synced.map(OnlineLookup.stripTimestamps)
                }
            }

            if let text {
                edit.lyrics = text
                message = EditorMessage(
                    text: timed ? "Timed lyrics added." : "Lyrics added.",
                    isError: false
                )
            } else {
                message = EditorMessage(text: "No lyrics found for this song.", isError: true)
            }
        }
    }

    private func save() {
        isSaving = true
        message = nil

        let edits = edit.payload(changedFrom: original, cover: coverChange)

        model.save(file, edits: edits) { result in
            isSaving = false

            if let error = result.error {
                message = EditorMessage(text: error, isError: true)
                return
            }

            if let warning = result.warning {
                model.showToast(warning, error: true)
            } else {
                let name = edit.title.isEmpty ? file.fileName : edit.title
                model.showToast("Saved “\(name)”")
            }

            dismiss()
        }
    }
}

// MARK: - Settings

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case sources
    case folder
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "Appearance"
        case .sources: return "Download Sources"
        case .folder: return "Download Folder"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintpalette"
        case .sources: return "arrow.down.circle"
        case .folder: return "folder"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance")
    private var themeRawValue = AppTheme.system.rawValue

    @AppStorage("primaryDownloadSource")
    private var primaryDownloadSourceRawValue = DownloadSource.spotDL.rawValue

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    @State private var selectedCategory: SettingsCategory = .appearance

    private var theme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private var primaryDownloadSource: DownloadSource {
        DownloadSource(rawValue: primaryDownloadSourceRawValue) ?? .spotDL
    }

    var body: some View {
        HStack(spacing: 0) {
            categoryNavigation
            Divider()
            ScrollView {
                selectedSettings
                    .padding(22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }

    private var categoryNavigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 19, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.icon)
                        .font(.system(size: 12, weight: selectedCategory == category ? .medium : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            if selectedCategory == category {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.accentColor.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.primary)
            }
        }
        .padding(14)
        .frame(width: 170)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var selectedSettings: some View {
        switch selectedCategory {
        case .appearance:
            appearanceSettings
        case .sources:
            sourceSettings
        case .folder:
            folderSettings
        case .about:
            aboutSettings
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Theme & Appearance",
                subtitle: "Choose the colors Podly uses across the app."
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(AppTheme.allCases, id: \.rawValue) { option in
                    ThemeOptionCard(
                        theme: option,
                        isSelected: theme == option
                    ) {
                        themeRawValue = option.rawValue
                    }
                }
            }
        }
    }

    private var sourceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Download Sources",
                subtitle: "Choose which service Podly tries first."
            )

            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Try first", selection: $primaryDownloadSourceRawValue) {
                        ForEach(DownloadSource.allCases, id: \.rawValue) { source in
                            Label(source.title, systemImage: source.icon)
                                .tag(source.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Divider()

                    LabeledContent("Automatic fallback") {
                        Label(
                            primaryDownloadSource.alternate.title,
                            systemImage: primaryDownloadSource.alternate.icon
                        )
                    }
                }
            }

            Text("The other source is tried automatically if the first one fails or finds no match.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var folderSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Download Folder",
                subtitle: "Choose where new songs are saved."
            )

            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Save downloads to", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))

                    Text(customOutputPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.head)

                    Button("Choose Folder…") {
                        selectFolder()
                    }
                }
            }
        }
    }

    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading("About Podly", subtitle: "Application information.")

            settingsCard {
                VStack(spacing: 10) {
                    LabeledContent("App", value: "Podly")
                    LabeledContent("Engine", value: "spotDL")
                    LabeledContent("Interface", value: "SwiftUI")
                    LabeledContent("Version", value: "1.0")
                }
            }
        }
    }

    private func settingsHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.previewSurface.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: customOutputPath)

        if panel.runModal() == .OK, let url = panel.url {
            customOutputPath = url.path
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
    }

    private struct ThemeOptionCard: View {
        let theme: AppTheme
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 7) {
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: 5) {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(0..<4) { index in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.accentColor.opacity(index == 0 ? 1 : 0.35))
                                            .frame(width: 4, height: 4)
                                        Capsule()
                                            .fill(theme.previewInk.opacity(index == 0 ? 0.3 : 0.16))
                                            .frame(height: 3)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(7)
                            .background(theme.previewSurface, in: RoundedRectangle(cornerRadius: 6))

                            VStack(spacing: 5) {
                                Capsule()
                                    .fill(theme.previewInk.opacity(0.22))
                                    .frame(height: 4)
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.accentColor)
                                    .frame(width: 12, height: 7)
                            }
                            .padding(6)
                            .frame(width: 28, height: 58)
                            .background(theme.previewSurface.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isSelected ? theme.accentColor : Color.primary.opacity(0.08),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.accentColor)
                                .background(.background, in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }

                    Text(theme.title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(theme.title) theme\(isSelected ? ", selected" : "")")
        }
    }
}
