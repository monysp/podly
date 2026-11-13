import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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
            Text(LocalizedStringKey(label))
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
            let result = await OnlineLookup.lyrics(
                title: title,
                artist: artist,
                duration: (detail ?? file).duration
            )
            isFindingLyrics = false

            var text: String?
            var timed = false

            if case .found(let found) = result {
                if preferSynced, let synced = found.synced {
                    text = synced
                    timed = true
                } else {
                    text = found.plain ?? found.synced.map(OnlineLookup.stripTimestamps)
                }
            }

            if let text {
                edit.lyrics = text
                model.clearLyricsNotFound(for: file)
                message = EditorMessage(
                    text: timed ? "Timed lyrics added." : "Lyrics added.",
                    isError: false
                )
            } else {
                if case .unavailable = result {
                    message = EditorMessage(
                        text: "Couldn’t check lyrics right now. Try again later.",
                        isError: true
                    )
                } else {
                    model.markLyricsNotFound(for: file)
                    message = EditorMessage(text: "No lyrics found for this song.", isError: true)
                }
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
