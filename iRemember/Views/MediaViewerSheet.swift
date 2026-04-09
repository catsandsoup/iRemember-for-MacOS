import AppKit
import QuickLookUI
import SwiftUI

struct MediaViewerSheet: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Group {
            if let asset = appModel.selectedMediaAsset {
                VStack(spacing: 0) {
                    MediaViewerCanvas(asset: asset)

                    Divider()

                    MediaViewerFooter(
                        asset: asset,
                        index: appModel.selectedMediaAssetIndex,
                        totalCount: appModel.previewableMediaAssets.count
                    )
                }
                .background(.background)
                .highPriorityGesture(navigationGesture)
                .toolbar {
                    ToolbarItemGroup {
                        Button("Previous", systemImage: "chevron.left") {
                            appModel.selectAdjacentMedia(offset: -1)
                        }
                        .disabled(!appModel.canSelectPreviousMedia)

                        Button("Next", systemImage: "chevron.right") {
                            appModel.selectAdjacentMedia(offset: 1)
                        }
                        .disabled(!appModel.canSelectNextMedia)
                    }

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(asset.attachment.filename)
                                .font(.headline)
                                .lineLimit(1)

                            Text(asset.sentAt.compactDateTimeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 360)
                    }

                    ToolbarItemGroup {
                        Button("Show in Conversation", systemImage: "text.bubble") {
                            Task {
                                await appModel.revealMediaInTranscript(asset)
                                appModel.dismissMediaViewer()
                            }
                        }

                        MediaOpenMenu(asset: asset)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Media Unavailable",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Choose a photo or video to preview it here.")
                )
            }
        }
        .frame(minWidth: 900, idealWidth: 980, minHeight: 640, idealHeight: 760)
    }

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 32)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width <= -80 {
                    appModel.selectAdjacentMedia(offset: 1)
                } else if value.translation.width >= 80 {
                    appModel.selectAdjacentMedia(offset: -1)
                }
            }
    }
}

private struct MediaViewerCanvas: View {
    let asset: MediaAsset

    var body: some View {
        Group {
            if asset.attachment.isAvailableLocally, let fileURL = asset.attachment.fileURL {
                QuickLookPreviewContainer(fileURL: fileURL)
                    .padding(20)
            } else {
                ContentUnavailableView(
                    "Original Unavailable",
                    systemImage: "icloud.slash",
                    description: Text("This attachment is not available locally on this Mac.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct MediaViewerFooter: View {
    let asset: MediaAsset
    let index: Int?
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(asset.attachment.filename)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 12)

                if let index {
                    Text("\(index + 1) of \(totalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(asset.contextSnippet.isEmpty ? asset.sender?.displayName ?? "Shared media" : asset.contextSnippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(asset.attachment.kind.label, systemImage: asset.attachment.kind.symbolName)
                Text(ByteCountFormatter.string(fromByteCount: Int64(asset.attachment.byteSize), countStyle: .file))
                Text(asset.sentAt.compactDateTimeLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

private struct MediaOpenMenu: View {
    let asset: MediaAsset

    var body: some View {
        Menu {
            if asset.attachment.isAvailableLocally, let fileURL = asset.attachment.fileURL {
                Button("Open in Default App") {
                    NSWorkspace.shared.open(fileURL)
                }

                if asset.attachment.kind == .image {
                    Button("Open in Preview") {
                        open(fileURL, withApplicationAt: URL(filePath: "/System/Applications/Preview.app"))
                    }
                }

                if asset.attachment.kind == .video {
                    Button("Open in QuickTime Player") {
                        open(fileURL, withApplicationAt: URL(filePath: "/System/Applications/QuickTime Player.app"))
                    }
                }

                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
        } label: {
            Label("Open", systemImage: "arrow.up.forward.app")
        }
        .disabled(!asset.attachment.isAvailableLocally || asset.attachment.fileURL == nil)
    }

    private func open(_ fileURL: URL, withApplicationAt applicationURL: URL) {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            NSWorkspace.shared.open(fileURL)
            return
        }

        Task {
            do {
                try await NSWorkspace.shared.open(
                    [fileURL],
                    withApplicationAt: applicationURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } catch {
                NSWorkspace.shared.open(fileURL)
            }
        }
    }
}

private struct QuickLookPreviewContainer: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView(frame: .zero)!
        previewView.autostarts = true
        previewView.shouldCloseWithWindow = true
        previewView.previewItem = fileURL as NSURL
        return previewView
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = fileURL as NSURL
        nsView.refreshPreviewItem()
    }
}
