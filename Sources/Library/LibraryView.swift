import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

// MARK: - Library View

struct LibraryRow: View {
    let file: MusicFile
    let lyricsNotFound: Bool
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
                badge(
                    "text.quote",
                    isOn: file.hasLyrics,
                    on: "Has lyrics",
                    off: "No lyrics",
                    failed: lyricsNotFound
                )
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

    private func badge(
        _ symbol: String,
        isOn: Bool,
        on: String,
        off: String,
        failed: Bool = false
    ) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12))
            .foregroundStyle(
                isOn ? Color.accentColor : (failed ? Color.red : Color.primary.opacity(0.18))
            )
            .help(isOn ? on : (failed ? "Lyrics not found" : off))
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
                            Text(LocalizedStringKey(option.title))
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: sortOrder.icon)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(LocalizedStringKey("Sort songs by \(sortOrder.title.lowercased())"))
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
            Text(emptyFilterMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filtered) { file in
                LibraryRow(
                    file: file,
                    lyricsNotFound: model.lyricsNotFoundPaths.contains(file.url.path),
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

    private var emptyFilterMessage: LocalizedStringKey {
        if showDuplicates {
            return duplicateTitleKeys.isEmpty
                ? "No duplicate song titles found."
                : "No duplicate songs match “\(search)”."
        }
        return "No songs match “\(search)”."
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
