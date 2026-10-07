import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

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

