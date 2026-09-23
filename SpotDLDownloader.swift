import SwiftUI
import AppKit
import Foundation

@main
struct SpotDLDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 620, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var query = ""
    @State private var log = "Ready. Paste a Spotify URL or type a song name."
    @State private var isDownloading = false

    // บันทึก path ของโฟลเดอร์ที่เลือกไว้ลงใน UserDefaults (ค่าเริ่มต้นคือ ~/Desktop/songs)
    @AppStorage("customOutputFolderPath") private var customOutputPath: String = 
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/songs").path

    private var outputFolder: URL {
        URL(fileURLWithPath: customOutputPath)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 30, weight: .semibold))
                Text("SpotDL Downloader")
                    .font(.system(size: 26, weight: .bold))
                Spacer()
            }

            Text("Download music with spotDL directly to your chosen folder")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Spotify URL / Song name")
                    .font(.headline)

                TextField("e.g. Always — Daniel Caesar", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
                    .onSubmit { download() }
            }

            HStack(spacing: 12) {
                Button {
                    download()
                } label: {
                    Label(
                        isDownloading ? "Downloading…" : "Download",
                        systemImage: isDownloading
                            ? "arrow.down.circle"
                            : "arrow.down.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isDownloading
                )

                // ปุ่มเลือกโฟลเดอร์
                Button {
                    selectOutputFolder()
                } label: {
                    Label("Choose...", systemImage: "folder.badge.gear")
                }
                .controlSize(.large)

                Button {
                    NSWorkspace.shared.open(outputFolder)
                } label: {
                    Label("Open folder", systemImage: "folder")
                }
                .controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output")
                        .font(.headline)

                    Spacer()

                    Text(outputFolder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                ScrollView {
                    Text(log)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .frame(maxWidth: .infinity, minHeight: 230)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("Tip: paste a Spotify link or search by song title.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .onAppear {
            createOutputFolderIfNeeded()
        }
    }

    // ฟังก์ชันเปิดหน้าต่างเลือกโฟลเดอร์ (NSOpenPanel)
    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Download Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolder

        if panel.runModal() == .OK, let url = panel.url {
            customOutputPath = url.path
            createOutputFolderIfNeeded()
            log = "Changed output folder to:\n\(url.path)\n\n" + log
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
        guard !input.isEmpty else { return }

        createOutputFolderIfNeeded()

        isDownloading = true
        log = "Starting spotDL…\nInput: \(input)\nDestination: \(outputFolder.path)\n\n"

        guard let executable = findSpotDL() else {
            log += """
            ❌ Could not find spotdl.

            Install it first:
              python3 -m pip install spotdl

            Then make sure `spotdl` is available in your PATH.
            """
            isDownloading = false
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
            else { return }

            DispatchQueue.main.async {
                log += text
            }
        }

        do {
            try process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                log += "\n\n"
                log += process.terminationStatus == 0
                    ? "✅ Finished!"
                    : "❌ spotDL exited with code \(process.terminationStatus)."

                isDownloading = false
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        } catch {
            DispatchQueue.main.async {
                log += "\n❌ Failed to start spotDL: \(error.localizedDescription)"
                isDownloading = false
                pipe.fileHandleForReading.readabilityHandler = nil
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

                if let result = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !result.isEmpty {
                    return result
                }
            }
        } catch {}

        return nil
    }
}