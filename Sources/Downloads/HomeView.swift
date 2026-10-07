import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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
                Text(LocalizedStringKey(item.status == .downloading && queuePaused ? "Paused" : item.status.title))
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

    private var statusMessage: LocalizedStringKey {
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
        Button(LocalizedStringKey(title), action: action)
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
