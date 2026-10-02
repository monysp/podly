import SwiftUI
import AppKit
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

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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

    @AppStorage("appearance")
    private var appearanceRawValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $page)
        } detail: {
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
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(appearance.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: page)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selection: AppPage

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Home", systemImage: "music.note")
                    .tag(AppPage.home)

                Label("Library", systemImage: "music.note.list")
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
    static func fetchMetadata(executable: String, query: String) -> Metadata {
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
        } catch {
            return Metadata(tracks: [], fileURL: nil)
        }

        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

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

// MARK: - Home

struct HomeView: View {
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

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

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
        .background(Color(nsColor: .windowBackgroundColor))
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

            if !trimmedQuery.isEmpty && !isDownloading {
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
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Download")
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
                        statusAction("Try again") { download() }
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
        guard !input.isEmpty, !isDownloading else { return }

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
            "Starting spotDL…\n" +
            "Input: \(input)\n" +
            "Destination: \(outputFolder.path)\n\n"

        DispatchQueue.global(qos: .userInitiated).async {
            guard let executable = SpotDLService.findExecutable() else {
                DispatchQueue.main.async {
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
                }
                return
            }

            let metadata = SpotDLService.fetchMetadata(
                executable: executable,
                query: input
            )

            DispatchQueue.main.async {
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

    private func runDownload(executable: String, saveFile: URL?, input: String) {
        let process = Process()
        let pipe = Pipe()

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

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                let status = process.terminationStatus

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
            }
        }
    }

    private func finishDownload(status: Int32, saveFile: URL?) {
        if let saveFile {
            try? FileManager.default.removeItem(at: saveFile)
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

        withAnimation(.easeInOut(duration: 0.3)) {
            downloadStatus = detectedStatus
            isDownloading = false

            if detectedStatus == .success || detectedStatus == .duplicate {
                completedTracks = tracks.count
                withinTrack = 0
            }

            if detectedStatus == .success {
                query = ""
            }
        }

        // หน่วงเวลา 15 วินาทีแล้วกลับไปที่หน้าแรก (Hero View / Initial Search View)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(15))

            // ตรวจสอบว่าไม่มีการดาวน์โหลดใหม่เริ่มต้นขึ้นระหว่างรอ 15 วินาที
            guard !isDownloading, downloadStatus != .ready else { return }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                tracks = []
                completedTracks = 0
                withinTrack = 0
                metadataLoaded = false
                lookupFailed = false
                missedCount = 0
                downloadStatus = .ready
                query = ""
            }
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
            with open(out, "wb") as fh:
                fh.write(pic)
            d["cover"] = out
    return d


def scan(folder):
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
            d = read(p)
        except ImportError:
            raise
        except Exception:
            d = blank(p, None)
        d["lyrics"] = ""
        d["mtime"] = os.path.getmtime(p)
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
            res = {"files": scan(req["folder"])}
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
    var editable: Bool

    var id: URL { url }
    var fileName: String { url.deletingPathExtension().lastPathComponent }
    var displayTitle: String { title.isEmpty ? fileName : title }

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
        editable = false
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

    // MARK: Loading

    func reload(folder: URL) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let result = TagService.run(["action": "scan", "folder": folder.path])

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

// MARK: - Library View

struct LibraryRow: View {
    let file: MusicFile
    let isBusy: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.07))

                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)

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

            Text(file.formatLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .trailing)

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
    @StateObject private var model = LibraryModel()

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    @State private var search = ""
    @State private var editing: MusicFile?
    @State private var pendingTrash: MusicFile?

    private var folder: URL {
        URL(fileURLWithPath: customOutputPath)
    }

    private var filtered: [MusicFile] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.files }

        return model.files.filter {
            [$0.title, $0.artist, $0.album, $0.fileName]
                .joined(separator: " ")
                .lowercased()
                .contains(q)
        }
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
        .background(Color(nsColor: .windowBackgroundColor))
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
            Text("No songs match “\(search)”.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filtered) { file in
                LibraryRow(
                    file: file,
                    isBusy: model.busy.contains(file.url)
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

struct SettingsView: View {
    @AppStorage("appearance")
    private var appearanceRawValue = AppAppearance.system.rawValue

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(AppAppearance.allCases, id: \.rawValue) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how Podly should appear.")
            }

            Section {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Download folder")
                        Text(customOutputPath)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }

                    Spacer()

                    Button("Choose…") {
                        selectFolder()
                    }
                }
            } header: {
                Text("Downloads")
            }

            Section {
                LabeledContent("App", value: "Podly")
                LabeledContent("Engine", value: "spotDL")
                LabeledContent("Interface", value: "SwiftUI")
                LabeledContent("Version", value: "1.0")
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
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
}
