import AppKit
import QuickLookThumbnailing
import SwiftUI

struct AttachmentThumbnailView: View {
    enum DisplayMode {
        case fill
        case fit
    }

    let asset: MediaAsset
    let displayMode: DisplayMode

    @State private var previewImage: NSImage?

    init(asset: MediaAsset, displayMode: DisplayMode = .fill) {
        self.asset = asset
        self.displayMode = displayMode
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundFill)

                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: displayMode == .fill ? .fill : .fit)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: asset.attachment.kind.symbolName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(placeholderLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if asset.attachment.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(AppTheme.videoPlayOverlay, in: Circle())
                }

                if !asset.attachment.isAvailableLocally {
                    VStack {
                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "icloud.slash")
                            Text("Not on this Mac")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.metadataText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(12)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .task(id: asset.attachment.id) {
            await loadPreview()
        }
    }

    @MainActor
    private func loadPreview() async {
        guard let fileURL = asset.attachment.fileURL, asset.attachment.isAvailableLocally else {
            previewImage = nil
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 520, height: 360),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            previewImage = representation.nsImage
        } catch {
            previewImage = NSImage(contentsOf: fileURL)
        }
    }

    private var placeholderLabel: String {
        asset.attachment.isAvailableLocally ? asset.attachment.kind.label : "Original unavailable"
    }

    private var backgroundFill: Color {
        if !asset.attachment.isAvailableLocally {
            return AppTheme.secondarySurface
        }

        switch asset.attachment.kind {
        case .image:
            return AppTheme.activeTint
        case .video:
            return AppTheme.videoAttachmentFill
        case .file:
            return AppTheme.secondarySurface
        case .link:
            return AppTheme.linkAttachmentFill
        }
    }
}
