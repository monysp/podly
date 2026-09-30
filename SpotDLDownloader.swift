import SwiftUI
import AppKit
import Foundation

@main
struct SpotDLDownloaderApp: App {
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

                Text("SpotDL")
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

        // Drain the pipe first so a chatty process can't block on a full buffer.
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
            // Quiet top bar: icons only
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

            // Everything lives in one fixed layout, so nothing needs scrolling.
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

            // Footer: download location
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

    /// Fixed-height area so the search field never jumps when things appear.
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

    /// Welcome header, shown until the first download starts.
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

    /// Below the field before a download: quick paste + recent downloads.
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

    /// One quiet line: what happened, and what you can do about it.
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
                case .failed:
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

    /// spotDL doesn't report a percentage when its output is piped, so the bar
    /// eases toward ~93% for the current track and jumps forward when spotDL
    /// prints that the track has finished.
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

            // Step 1: ask spotDL for title / artist / cover before downloading.
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

                // Step 2: download.
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

            // Keep the SwiftUI main thread responsive while spotDL runs.
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
        let detectedStatus: DownloadStatus

        // spotDL can print "LookupError: No results found for song: …"
        // and still exit with code 0, so read its own output, not just the exit code.
        let raw = downloadOutput.lowercased()
        let downloaded = raw.components(separatedBy: "downloaded \"").count - 1
        let skipped = raw.components(separatedBy: "skipping").count - 1
        let missed = max(
            raw.components(separatedBy: "lookuperror").count - 1,
            raw.components(separatedBy: "no results found").count - 1
        )
        missedCount = missed

        if status == 0 && missed > 0 && downloaded == 0 && skipped == 0 {
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
        } else if output.contains("no results") ||
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

            // Clear the input only after a real successful download.
            if detectedStatus == .success {
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
                Text("Choose how SpotDL should appear.")
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
                LabeledContent("App", value: "SpotDL Downloader")
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
