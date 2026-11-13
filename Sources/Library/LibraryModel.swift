import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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
    @Published private(set) var lyricsNotFoundPaths: Set<String>

    private var cancelBatch = false
    private let lyricsNotFoundDefaultsKey = "lyricsNotFoundPaths"

    let coverDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("spotdl-covers").path

    init() {
        lyricsNotFoundPaths = Set(
            UserDefaults.standard.stringArray(forKey: lyricsNotFoundDefaultsKey) ?? []
        )
    }

    var isBatching: Bool { batchStatus != nil }

    func markLyricsNotFound(for file: MusicFile) {
        lyricsNotFoundPaths.insert(file.url.path)
        persistLyricsNotFoundPaths()
    }

    func clearLyricsNotFound(for file: MusicFile) {
        lyricsNotFoundPaths.remove(file.url.path)
        persistLyricsNotFoundPaths()
    }

    private func persistLyricsNotFoundPaths() {
        UserDefaults.standard.set(Array(lyricsNotFoundPaths), forKey: lyricsNotFoundDefaultsKey)
    }

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
        if updated.hasLyrics {
            clearLyricsNotFound(for: updated)
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
            $0.editable &&
            (kind == .lyrics
                ? (!$0.hasLyrics && !lyricsNotFoundPaths.contains($0.url.path))
                : !$0.hasCover)
        }

        guard !targets.isEmpty else {
            showToast("Every song already has \(kind.label), or previous lyric searches found no match.")
            return
        }

        cancelBatch = false
        batchStatus = "Adding \(kind.label) · 0 of \(targets.count)"

        Task { @MainActor in
            var added = 0
            var notFound = 0
            var lookupErrors = 0

            for (index, file) in targets.enumerated() {
                if cancelBatch { break }

                batchStatus = "Adding \(kind.label) · \(index + 1) of \(targets.count)"

                let terms = file.searchTerms
                var edits: [String: Any]?

                switch kind {
                case .lyrics:
                    let result = await OnlineLookup.lyrics(
                        title: terms.title,
                        artist: terms.artist,
                        duration: file.duration
                    )
                    switch result {
                    case .found(let found):
                        let text = found.plain.flatMap { $0.isEmpty ? nil : $0 }
                            ?? found.synced.map(OnlineLookup.stripTimestamps)
                        if let text, !text.isEmpty {
                            edits = ["lyrics": text]
                            clearLyricsNotFound(for: file)
                        } else {
                            markLyricsNotFound(for: file)
                            notFound += 1
                        }
                    case .notFound:
                        markLyricsNotFound(for: file)
                        notFound += 1
                    case .unavailable:
                        lookupErrors += 1
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
                            clearLyricsNotFound(for: files[i])
                        } else {
                            files[i].hasCover = true
                        }
                        added += 1
                    }
                }
            }

            let stopped = cancelBatch
            batchStatus = nil
            let summary: String
            if stopped {
                summary = "Stopped · added \(kind.label) to \(added) songs"
            } else if kind == .lyrics && notFound > 0 {
                let errors = lookupErrors > 0 ? " · \(lookupErrors) lookup errors" : ""
                summary = "Added lyrics to \(added) · \(notFound) not found and skipped next time\(errors)"
            } else if kind == .lyrics && lookupErrors > 0 {
                summary = "Added lyrics to \(added) · couldn't check \(lookupErrors) songs; they can be retried"
            } else {
                summary = "Added \(kind.label) to \(added) of \(targets.count) songs"
            }
            showToast(summary, error: !stopped && kind == .lyrics && notFound > 0)
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

