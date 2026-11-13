import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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

