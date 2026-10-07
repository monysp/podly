import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

@main
struct PodlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    case midnight
    case paper
    case nord
    case cupcake
    case corporate

    var title: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        case .midnight: return "Midnight"
        case .paper: return "Paper"
        case .nord: return "Nord"
        case .cupcake: return "Cupcake"
        case .corporate: return "Corporate"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .midnight: return "moon.stars"
        case .paper: return "doc.text"
        case .nord: return "snowflake"
        case .cupcake: return "birthday.cake"
        case .corporate: return "building.2"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .paper, .nord, .cupcake, .corporate: return .light
        case .dark, .midnight: return .dark
        }
    }

    var accentColor: Color {
        switch self {
        case .system, .light: return Color(red: 0.20, green: 0.48, blue: 0.92)
        case .dark: return Color(red: 0.58, green: 0.48, blue: 0.98)
        case .midnight: return Color(red: 0.00, green: 0.78, blue: 0.61)
        case .paper: return Color(red: 0.38, green: 0.29, blue: 0.20)
        case .nord: return Color(red: 0.35, green: 0.51, blue: 0.68)
        case .cupcake: return Color(red: 0.24, green: 0.78, blue: 0.70)
        case .corporate: return Color(red: 0.10, green: 0.45, blue: 0.72)
        }
    }

    var canvas: Color {
        switch self {
        case .system: return Color(nsColor: .windowBackgroundColor)
        case .light: return Color(red: 0.96, green: 0.96, blue: 0.97)
        case .dark: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .midnight: return Color(red: 0.04, green: 0.06, blue: 0.08)
        case .paper: return Color(red: 0.97, green: 0.94, blue: 0.88)
        case .nord: return Color(red: 0.89, green: 0.91, blue: 0.94)
        case .cupcake: return Color(red: 0.96, green: 0.92, blue: 0.93)
        case .corporate: return Color(red: 0.91, green: 0.93, blue: 0.95)
        }
    }

    var previewSurface: Color {
        switch self {
        case .system: return Color(nsColor: .controlBackgroundColor)
        case .light: return .white
        case .dark: return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .midnight: return Color(red: 0.07, green: 0.09, blue: 0.12)
        case .paper: return Color(red: 1.00, green: 0.98, blue: 0.93)
        case .nord: return Color(red: 0.92, green: 0.94, blue: 0.97)
        case .cupcake: return Color(red: 0.99, green: 0.96, blue: 0.96)
        case .corporate: return Color(red: 0.96, green: 0.97, blue: 0.98)
        }
    }

    var previewInk: Color {
        switch self {
        case .system: return .primary
        case .dark, .midnight: return .white
        case .light, .paper, .nord, .cupcake, .corporate:
            return Color(red: 0.18, green: 0.20, blue: 0.23)
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case thai = "th"
    case korean = "ko"
    case japanese = "ja"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .thai: return "ไทย"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        }
    }
}

private struct PodlyThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.system
}

extension EnvironmentValues {
    var podlyTheme: AppTheme {
        get { self[PodlyThemeKey.self] }
        set { self[PodlyThemeKey.self] = newValue }
    }
}

enum DownloadSource: String, CaseIterable {
    case spotDL
    case ytDlp

    var title: String {
        switch self {
        case .spotDL: return "spotDL"
        case .ytDlp: return "yt-dlp"
        }
    }

    var icon: String {
        switch self {
        case .spotDL: return "music.note"
        case .ytDlp: return "play.rectangle"
        }
    }

    var alternate: DownloadSource {
        self == .spotDL ? .ytDlp : .spotDL
    }
}

// MARK: - Navigation

enum AppPage: Hashable {
    case home
    case library
    case settings
}

// MARK: - Main View

struct ContentView: View {
    @State private var page: AppPage = .home
    @StateObject private var audioPlayer = AudioPlayerModel()

    @AppStorage("appearance")
    private var themeRawValue = AppTheme.system.rawValue
    @AppStorage("appLanguage")
    private var languageRawValue = AppLanguage.english.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $page)
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch page {
                    case .home:
                        HomeView()
                    case .library:
                        LibraryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                if audioPlayer.currentTrack != nil {
                    MiniPlayerView(player: audioPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.accentColor)
        .environment(\.podlyTheme, theme)
        .environment(
            \.locale,
            Locale(identifier: AppLanguage(rawValue: languageRawValue)?.rawValue ?? AppLanguage.english.rawValue)
        )
        .environmentObject(audioPlayer)
        .animation(.easeInOut(duration: 0.2), value: page)
        .animation(.easeInOut(duration: 0.2), value: audioPlayer.currentTrack != nil)
    }
}
