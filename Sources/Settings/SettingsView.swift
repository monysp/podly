import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

// MARK: - Settings

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case language
    case sources
    case tools
    case about

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .appearance: return "Appearance"
        case .language: return "Language"
        case .sources: return "Download Sources"
        case .tools: return "Tools"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintpalette"
        case .language: return "globe"
        case .sources: return "arrow.down.circle"
        case .tools: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

private enum ToolCheckState {
    case checking
    case available(String)
    case missing
    case failed(String)
}

private struct RequiredTool: Identifiable {
    let id: String
    let title: String
    let icon: String
    let installCommand: String

    static let all = [
        RequiredTool(id: "spotdl", title: "spotDL", icon: "music.note", installCommand: "python3 -m pip install spotdl"),
        RequiredTool(id: "yt-dlp", title: "yt-dlp", icon: "play.rectangle", installCommand: "brew install yt-dlp"),
        RequiredTool(id: "ffmpeg", title: "FFmpeg", icon: "waveform", installCommand: "brew install ffmpeg"),
        RequiredTool(id: "mutagen", title: "mutagen", icon: "tag", installCommand: "python3 -m pip install mutagen")
    ]
}

struct SettingsView: View {
    @AppStorage("appearance")
    private var themeRawValue = AppTheme.system.rawValue
    @AppStorage("appLanguage")
    private var languageRawValue = AppLanguage.english.rawValue

    @AppStorage("primaryDownloadSource")
    private var primaryDownloadSourceRawValue = DownloadSource.spotDL.rawValue

    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var toolCheckStates: [String: ToolCheckState] = [:]
    @State private var isCheckingTools = false

    private var theme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private var primaryDownloadSource: DownloadSource {
        DownloadSource(rawValue: primaryDownloadSourceRawValue) ?? .spotDL
    }

    var body: some View {
        HStack(spacing: 0) {
            categoryNavigation
            Divider()
            ScrollView {
                selectedSettings
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
        .onChange(of: selectedCategory) { category in
            if category == .tools && toolCheckStates.isEmpty {
                checkRequiredTools()
            }
        }
    }

    private var categoryNavigation: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.icon)
                        .font(.system(size: 12, weight: selectedCategory == category ? .medium : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            if selectedCategory == category {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.accentColor.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.primary)
            }
        }
        .padding(14)
        .frame(width: 156)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var selectedSettings: some View {
        switch selectedCategory {
        case .appearance:
            appearanceSettings
        case .language:
            languageSettings
        case .sources:
            sourceSettings
        case .tools:
            toolsSettings
        case .about:
            aboutSettings
        }
    }

    private var languageSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Language",
                subtitle: "Choose the language used throughout Podly."
            )

            settingsCard {
                SettingsDropdown(
                    title: "App language",
                    selectedTitle: AppLanguage(rawValue: languageRawValue)?.nativeName ?? AppLanguage.english.nativeName,
                    options: AppLanguage.allCases.map(\.rawValue),
                    selection: $languageRawValue
                ) { rawValue in
                    Text(AppLanguage(rawValue: rawValue)?.nativeName ?? rawValue)
                }
            }
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Theme & Appearance",
                subtitle: "Choose the colors Podly uses across the app."
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 4),
                alignment: .leading,
                spacing: 9
            ) {
                ForEach(AppTheme.allCases, id: \.rawValue) { option in
                    ThemeOptionCard(
                        theme: option,
                        isSelected: theme == option
                    ) {
                        themeRawValue = option.rawValue
                    }
                }
            }
        }
    }

    private var sourceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Download Sources",
                subtitle: "Choose which service Podly tries first."
            )

            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsDropdown(
                        title: "Try first",
                        selectedTitle: primaryDownloadSource.title,
                        options: DownloadSource.allCases.map(\.rawValue),
                        selection: $primaryDownloadSourceRawValue
                    ) { rawValue in
                        if let source = DownloadSource(rawValue: rawValue) {
                            Label(source.title, systemImage: source.icon)
                        } else {
                            Text(rawValue)
                        }
                    }

                    Divider()

                    LabeledContent("Automatic fallback") {
                        Label(
                            primaryDownloadSource.alternate.title,
                            systemImage: primaryDownloadSource.alternate.icon
                        )
                    }
                }

            }

            Text("The other source is tried automatically if the first one fails or finds no match.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var toolsSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                settingsHeading(
                    "Required Tools",
                    subtitle: "Check whether the tools used by downloads and Library features are ready."
                )

                Spacer()

                Button {
                    checkRequiredTools()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                }
                .disabled(isCheckingTools)
            }

            settingsCard {
                VStack(spacing: 0) {
                    ForEach(RequiredTool.all) { tool in
                        toolStatusRow(tool)
                        if tool.id != RequiredTool.all.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

    private func toolStatusRow(_ tool: RequiredTool) -> some View {
        let state = toolCheckStates[tool.id] ?? .checking

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: tool.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tool.title)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    toolStatusLabel(state)
                }

                switch state {
                case .available(let version):
                    if !version.isEmpty {
                        Text(version)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                case .missing:
                    Text(tool.id == "mutagen" ? TagService.installCommand : tool.installCommand)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                case .failed(let message):
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                case .checking:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func toolStatusLabel(_ state: ToolCheckState) -> some View {
        switch state {
        case .checking:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                Text("Checking…")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green)
        case .missing:
            Label("Not found", systemImage: "xmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
        case .failed:
            Label("Check failed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.red)
        }
    }

    private func checkRequiredTools() {
        guard !isCheckingTools else { return }
        isCheckingTools = true
        toolCheckStates = Dictionary(
            uniqueKeysWithValues: RequiredTool.all.map { ($0.id, ToolCheckState.checking) }
        )

        DispatchQueue.global(qos: .utility).async {
            var results: [String: ToolCheckState] = [:]
            for tool in RequiredTool.all {
                results[tool.id] = Self.check(tool)
            }

            DispatchQueue.main.async {
                toolCheckStates = results
                isCheckingTools = false
            }
        }
    }

    private static func check(_ tool: RequiredTool) -> ToolCheckState {
        if tool.id == "mutagen" {
            switch TagService.checkMutagen() {
            case .available(let version): return .available("mutagen \(version)")
            case .missing: return .missing
            case .failed(let message): return .failed(message)
            }
        }

        let executable: String?
        let arguments: [String]
        switch tool.id {
        case "spotdl":
            executable = SpotDLService.findExecutable()
            arguments = ["--version"]
        case "yt-dlp":
            executable = BackupDownloadService.findExecutable(named: "yt-dlp")
            arguments = ["--version"]
        case "ffmpeg":
            executable = BackupDownloadService.findExecutable(named: "ffmpeg")
            arguments = ["-version"]
        default:
            return .failed("Unknown tool.")
        }

        guard let executable else { return .missing }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            return .failed(result.isEmpty ? "Command exited with code \(process.terminationStatus)." : result)
        }

        return .available(result.components(separatedBy: .newlines).first ?? result)
    }

    private struct SettingsDropdown<OptionLabel: View>: View {
        let title: LocalizedStringKey
        let selectedTitle: String
        let options: [String]
        @Binding var selection: String
        @ViewBuilder let optionLabel: (String) -> OptionLabel

        var body: some View {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack {
                            optionLabel(option)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 12)

                    Text(selectedTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(selectedTitle))
        }
    }

    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading("About Podly", subtitle: "Application information.")

            settingsCard {
                VStack(spacing: 0) {
                    aboutRow("App", value: "Podly")
                    Divider()
                    aboutRow("Engine", value: "spotDL")
                    Divider()
                    aboutRow("Interface", value: "SwiftUI")
                    Divider()
                    aboutRow("Version", value: "1.0")
                }
            }
        }
    }

    private func aboutRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.system(size: 12))
        .padding(.vertical, 8)
    }

    private func settingsHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 20, weight: .semibold))
            Text(LocalizedStringKey(subtitle))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.previewSurface.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
    }

    private struct ThemeOptionCard: View {
        let theme: AppTheme
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 7) {
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: 5) {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(0..<4) { index in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.accentColor.opacity(index == 0 ? 1 : 0.35))
                                            .frame(width: 4, height: 4)
                                        Capsule()
                                            .fill(theme.previewInk.opacity(index == 0 ? 0.3 : 0.16))
                                            .frame(height: 3)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(7)
                            .background(theme.previewSurface, in: RoundedRectangle(cornerRadius: 6))

                            VStack(spacing: 5) {
                                Capsule()
                                    .fill(theme.previewInk.opacity(0.22))
                                    .frame(height: 4)
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.accentColor)
                                    .frame(width: 12, height: 7)
                            }
                            .padding(6)
                            .frame(width: 28, height: 58)
                            .background(theme.previewSurface.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isSelected ? theme.accentColor : Color.primary.opacity(0.08),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.accentColor)
                                .background(.background, in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }

                    Text(LocalizedStringKey(theme.title))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(theme.title) theme\(isSelected ? ", selected" : "")")
        }
    }
}
