import AppKit
import ImageIO
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

    private static let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    init(asset: MediaAsset, displayMode: DisplayMode = .fill) {
        self.asset = asset
        self.displayMode = displayMode
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundFill)

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: displayMode == .fill ? .fill : .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: "\(asset.attachment.id.uuidString)-\(displayMode)") {
            await loadPreview()
        }
    }

    @MainActor
    private func loadPreview() async {
        guard let fileURL = asset.attachment.fileURL, asset.attachment.isAvailableLocally else {
            previewImage = nil
            return
        }

        let cacheKey = thumbnailCacheKey(fileURL: fileURL)
        if let cachedImage = Self.thumbnailCache.object(forKey: cacheKey as NSString) {
            previewImage = cachedImage
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: thumbnailRequestSize,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            previewImage = representation.nsImage
            Self.thumbnailCache.setObject(representation.nsImage, forKey: cacheKey as NSString)
        } catch {
            let fallbackImage = downsampledImage(at: fileURL, targetSize: thumbnailRequestSize)
            previewImage = fallbackImage
            if let fallbackImage {
                Self.thumbnailCache.setObject(fallbackImage, forKey: cacheKey as NSString)
            }
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

    private var thumbnailRequestSize: CGSize {
        switch displayMode {
        case .fill:
            return CGSize(width: 640, height: 480)
        case .fit:
            return CGSize(width: 540, height: 540)
        }
    }

    private func thumbnailCacheKey(fileURL: URL) -> String {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return "\(asset.attachment.id.uuidString)-\(Int(thumbnailRequestSize.width))x\(Int(thumbnailRequestSize.height))@\(Int(scale * 100))-\(fileURL.path)"
    }

    private func downsampledImage(at fileURL: URL, targetSize: CGSize) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let maxPixel = max(targetSize.width, targetSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: image, size: targetSize)
    }
}
