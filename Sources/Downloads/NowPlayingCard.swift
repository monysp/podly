import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

// MARK: - Now Playing Card

struct WaveformBadge: View {
    let isActive: Bool

    var body: some View {
        if #available(macOS 14.0, *) {
            Image(systemName: "waveform")
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    isActive: isActive
                )
        } else {
            Image(systemName: "waveform")
        }
    }
}

struct ArtworkThumbnail: View {
    let image: NSImage?
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.38), .gray.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

struct NowPlayingProgressBar: View {
    let progress: Double
    let tint: Color

    @State private var hovering = false

    var body: some View {
        let value = min(max(progress, 0), 1)

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.12))

                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: hovering ? 7 : 4)
        .clipShape(Capsule())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.linear(duration: 0.2), value: value)
        .accessibilityElement()
        .accessibilityLabel("Download progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct NowPlayingCard: View {
    let track: TrackInfo
    let progress: Double
    let stage: String
    let status: DownloadStatus
    let position: Int
    let total: Int
    var lookupFailed = false

    @State private var artwork: NSImage?

    private var barTint: Color {
        status == .downloading ? Color.primary.opacity(0.8) : status.tint
    }

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(image: artwork)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)

                        Text(track.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(lookupFailed ? Color.orange : Color.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Group {
                        if status == .downloading {
                            WaveformBadge(isActive: true)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: status.icon)
                                .foregroundStyle(status.tint)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                }

                NowPlayingProgressBar(progress: progress, tint: barTint)

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(stage))

                    Spacer()

                    if total > 1 {
                        Text("\(position) of \(total)")
                    }

                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .animation(.easeInOut(duration: 0.2), value: stage)
            }
        }
        .padding(14)
        .background {
            ZStack {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 40)
                        .saturation(1.4)
                        .opacity(0.5)
                        .transition(.opacity)
                }

                Rectangle().fill(.thinMaterial)
            }
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .task(id: track.coverURL) {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        guard let url = track.coverURL else {
            withAnimation(.easeOut(duration: 0.2)) { artwork = nil }
            return
        }

        if let (data, _) = try? await URLSession.shared.data(from: url),
           let image = NSImage(data: data) {
            withAnimation(.easeOut(duration: 0.35)) { artwork = image }
        }
    }
}
