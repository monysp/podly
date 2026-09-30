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

// MARK: - Home

struct HomeView: View {
    @State private var query = ""
    @State private var log = "Ready"
    @State private var isDownloading = false
    @State private var showLogs = false
    @State private var appeared = false
    @State private var downloadCount = 0

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    private var outputFolder: URL {
        URL(fileURLWithPath: customOutputPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download")
                        .font(.system(size: 20, weight: .semibold))

                    Text("Music with spotDL")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.open(outputFolder)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Open download folder")

                Button {
                    showLogs = true
                } label: {
                    Image(systemName: "terminal")
                }
                .buttonStyle(.borderless)
                .help("View logs")

                Button {
                    log = "Ready"
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear logs")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 45)

                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.quaternary.opacity(0.55))
                                .frame(width: 76, height: 76)

                            Image(systemName: isDownloading
                                  ? "arrow.down.circle"
                                  : "music.note")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(.primary)
                                .rotationEffect(
                                    .degrees(isDownloading ? 360 : 0)
                                )
                                .animation(
                                    isDownloading
                                    ? .linear(duration: 1.2)
                                        .repeatForever(autoreverses: false)
                                    : .default,
                                    value: isDownloading
                                )
                        }

                        Text("Download music")
                            .font(.system(size: 28, weight: .semibold))

                        Text("Paste a Spotify link or search for a song.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField(
                                "Song, artist, or Spotify URL",
                                text: $query
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .onSubmit {
                                download()
                            }

                            if !query.isEmpty {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        query = ""
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(
                                    .primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        }

                        Button {
                            download()
                        } label: {
                            HStack(spacing: 8) {
                                if isDownloading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down")
                                }

                                Text(isDownloading ? "Downloading…" : "Download")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(
                            query.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || isDownloading
                        )
                        .keyboardShortcut(.return, modifiers: [])
                    }
                    .frame(maxWidth: 460)

                    OutputCard(
                        outputFolder: outputFolder,
                        isDownloading: isDownloading,
                        onChange: selectOutputFolder
                    )
                    .frame(maxWidth: 460)

                    HStack(spacing: 10) {
                        Button {
                            NSWorkspace.shared.open(outputFolder)
                        } label: {
                            Label("Open Folder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isDownloading)

                        if downloadCount > 0 {
                            Text("\(downloadCount) download\(downloadCount == 1 ? "" : "s") completed")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 25)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
            }

            Divider()

            HStack(spacing: 8) {
                Circle()
                    .fill(isDownloading ? .orange : .green)
                    .frame(width: 7, height: 7)

                Text(isDownloading ? "Downloading" : "Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(lastLogLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            createOutputFolderIfNeeded()

            withAnimation(.easeOut(duration: 0.45).delay(0.05)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showLogs) {
            LogView(log: log)
        }
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

    private func download() {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isDownloading else { return }

        createOutputFolderIfNeeded()

        withAnimation(.easeInOut(duration: 0.2)) {
            isDownloading = true
        }

        log =
            "Starting spotDL…\\n" +
            "Input: \(input)\\n" +
            "Destination: \(outputFolder.path)\\n\\n"

        guard let executable = findSpotDL() else {
            log += """

            Could not find spotdl.

            Install it with:
            python3 -m pip install spotdl

            Make sure spotdl is available in your PATH.
            """

            withAnimation(.easeInOut(duration: 0.2)) {
                isDownloading = false
            }
            return
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [input]
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
                log += text
            }
        }

        do {
            try process.run()

            // Keep the SwiftUI main thread responsive while spotDL runs.
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                let status = process.terminationStatus

                DispatchQueue.main.async {
                    pipe.fileHandleForReading.readabilityHandler = nil

                    if status == 0 {
                        log += "\n\nFinished successfully."
                        downloadCount += 1

                        // Clear the input only after a successful download.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            query = ""
                            isDownloading = false
                        }
                    } else {
                        log += "\n\nspotDL exited with code \(status)."

                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDownloading = false
                        }
                    }
                }
            }
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async {
                log +=
                    "\nFailed to start spotDL: " +
                    "\(error.localizedDescription)"

                withAnimation(.easeInOut(duration: 0.2)) {
                    isDownloading = false
                }
            }
        }
    }

    private func findSpotDL() -> String? {
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
