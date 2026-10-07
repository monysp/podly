import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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

