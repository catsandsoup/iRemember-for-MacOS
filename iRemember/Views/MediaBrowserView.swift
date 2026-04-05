import SwiftUI

struct MediaBrowserView: View {
    @Bindable var appModel: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Picker("Media Filter", selection: $appModel.mediaFilter) {
                    ForEach(MediaFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 284)

                Spacer()

                Text("\(appModel.filteredMediaAssets.count.groupedCount) items")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(appModel.filteredMediaAssets) { asset in
                        Button {
                            appModel.selectedMediaAssetID = asset.id
                        } label: {
                            MediaCard(asset: asset, isSelected: appModel.selectedMediaAssetID == asset.id)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Reveal in Transcript") {
                                Task { await appModel.revealMediaInTranscript(asset) }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(AppTheme.contentBackground)
            .animation(.smooth(duration: 0.2), value: appModel.mediaFilter)
            .animation(.smooth(duration: 0.2), value: appModel.searchText)
        }
        .background(AppTheme.chromeBackground)
    }
}

private struct MediaCard: View {
    let asset: MediaAsset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AttachmentThumbnailView(asset: asset)
                .frame(height: 188)

            VStack(alignment: .leading, spacing: 5) {
                Text(asset.attachment.filename)
                    .font(.headline)
                    .lineLimit(1)

                Text(cardSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.mediaCardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? AppTheme.mediaCardSelectionStroke : AppTheme.mediaCardStroke, lineWidth: isSelected ? 1.5 : 1)
        }
    }

    private var cardSubtitle: String {
        "\(asset.sender?.displayName ?? "Unknown sender") • \(asset.sentAt.compactDateLabel)"
    }
}
