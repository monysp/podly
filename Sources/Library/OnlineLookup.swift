import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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

    enum LyricsLookupResult {
        case found(Lyrics)
        case notFound
        case unavailable
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
    static func lyrics(title: String, artist: String, duration: Int) async -> LyricsLookupResult {
        var attempts: [[URLQueryItem]] = []
        var gotValidResponse = false

        var precise = [URLQueryItem(name: "track_name", value: title)]
        if !artist.isEmpty { precise.append(URLQueryItem(name: "artist_name", value: artist)) }
        attempts.append(precise)
        attempts.append([URLQueryItem(name: "q", value: "\(artist) \(title)")])

        for items in attempts {
            var components = URLComponents(string: "https://lrclib.net/api/search")!
            components.queryItems = items

            guard let url = components.url,
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
            else { continue }
            gotValidResponse = true

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
            return .found(Lyrics(plain: plain, synced: synced))
        }

        return gotValidResponse ? .notFound : .unavailable
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

