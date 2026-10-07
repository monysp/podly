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
    case folder
    case about

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .appearance: return "Appearance"
        case .language: return "Language"
        case .sources: return "Download Sources"
        case .folder: return "Download Folder"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintpalette"
        case .language: return "globe"
        case .sources: return "arrow.down.circle"
        case .folder: return "folder"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance")
    private var themeRawValue = AppTheme.system.rawValue
    @AppStorage("appLanguage")
    private var languageRawValue = AppLanguage.english.rawValue

    @AppStorage("primaryDownloadSource")
    private var primaryDownloadSourceRawValue = DownloadSource.spotDL.rawValue

    @AppStorage("customOutputFolderPath")
    private var customOutputPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/songs").path

    @State private var selectedCategory: SettingsCategory = .appearance

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
                    .padding(22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }

    private var categoryNavigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 19, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.icon)
                        .font(.system(size: 12, weight: selectedCategory == category ? .medium : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
        .frame(width: 170)
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
        case .folder:
            folderSettings
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
                Picker("App language", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
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
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
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
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Try first", selection: $primaryDownloadSourceRawValue) {
                        ForEach(DownloadSource.allCases, id: \.rawValue) { source in
                            Label(source.title, systemImage: source.icon)
                                .tag(source.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

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

    private var folderSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(
                "Download Folder",
                subtitle: "Choose where new songs are saved."
            )

            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Save downloads to", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))

                    Text(customOutputPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.head)

                    Button("Choose Folder…") {
                        selectFolder()
                    }
                }
            }
        }
    }

    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading("About Podly", subtitle: "Application information.")

            settingsCard {
                VStack(spacing: 10) {
                    LabeledContent("App", value: "Podly")
                    LabeledContent("Engine", value: "spotDL")
                    LabeledContent("Interface", value: "SwiftUI")
                    LabeledContent("Version", value: "1.0")
                }
            }
        }
    }

    private func settingsHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 18, weight: .semibold))
            Text(LocalizedStringKey(subtitle))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.previewSurface.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
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
