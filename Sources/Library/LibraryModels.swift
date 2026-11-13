import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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

