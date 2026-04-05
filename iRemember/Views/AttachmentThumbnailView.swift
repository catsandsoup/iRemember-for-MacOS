import AppKit
import QuickLookThumbnailing
import SwiftUI

struct AttachmentThumbnailView: View {
    let asset: MediaAsset

    @State private var previewImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundFill)

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: asset.attachment.kind.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(placeholderLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.bubbleStroke, lineWidth: 1)
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
