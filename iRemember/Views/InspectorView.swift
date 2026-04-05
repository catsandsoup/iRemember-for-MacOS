import SwiftUI

struct InspectorView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppChrome.sectionSpacing) {
                if let conversation = appModel.selectedConversation {
                    inspectorHeader(conversation: conversation)
                    overviewSection(conversation: conversation)

                    if let message = appModel.selectedMessage {
                        messageSection(message)
                    }

                    if let asset = appModel.selectedMediaAsset {
                        selectedMediaSection(asset)
                    }

                    if !(appModel.selectedDetail?.mediaAssets.isEmpty ?? true) {
                        sharedMediaSection
                    }

                    if !appModel.linkAttachmentItems.isEmpty {
                        sharedLinksSection
                    }

                    sourceSection
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "sidebar.right",
                        description: Text("Inspector details appear when a conversation, message, or media asset is selected.")
                    )
                }
            }
            .padding(AppChrome.spacing16)
        }
        .background(AppTheme.inspectorBackground)
    }

    private func inspectorHeader(conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.activeTint)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(initials(for: conversation.title))
                            .font(.headline.weight(.semibold))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(conversation.participantSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.metadataText)
                        .lineLimit(2)
                }
            }
        }
        .padding(AppChrome.spacing12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.chromeBackground)
        )
    }

    private func overviewSection(conversation: Conversation) -> some View {
        inspectorSection(title: "Overview") {
            HStack(spacing: AppChrome.spacing8) {
                InspectorStatPill(label: "Messages", value: conversation.messageCount.groupedCount)
                InspectorStatPill(label: "Media", value: conversation.mediaCount.groupedCount)
                InspectorStatPill(label: "Active", value: conversation.lastActivityAt.sidebarLabel)
            }
        }
    }

    private func messageSection(_ message: Message) -> some View {
        inspectorSection(title: "Selected Message") {
            InspectorMetricRow(label: "Sender", value: message.sender?.displayName ?? "System")
            InspectorMetricRow(label: "Sent", value: message.sentAt.compactDateTimeLabel)
            InspectorMetricRow(label: "Attachments", value: "\(message.attachments.count.groupedCount)")

            if !message.body.isEmpty {
                Text(message.body)
                    .font(.callout)
                    .foregroundStyle(AppTheme.metadataText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private func selectedMediaSection(_ asset: MediaAsset) -> some View {
        inspectorSection(title: "Selected Media") {
            AttachmentThumbnailView(asset: asset)
                .frame(height: 156)

            InspectorMetricRow(label: "Filename", value: asset.attachment.filename)
            InspectorMetricRow(label: "Type", value: asset.attachment.kind.label)
            InspectorMetricRow(label: "Sender", value: asset.sender?.displayName ?? "Unknown sender")
            InspectorMetricRow(label: "Sent", value: asset.sentAt.compactDateTimeLabel)
            InspectorMetricRow(label: "Availability", value: asset.attachment.isAvailableLocally ? "Available locally" : "Original unavailable")

            Button("Reveal in Transcript") {
                Task { await appModel.revealMediaInTranscript(asset) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(AppChrome.spacing12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.chromeBackground)
        )
    }

    private var sharedMediaSection: some View {
        inspectorSection(title: "Shared Media") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(appModel.selectedDetail?.mediaAssets.prefix(8) ?? []) { asset in
                        Button {
                            appModel.selectedMediaAssetID = asset.id
                            appModel.contentMode = .media
                        } label: {
                            AttachmentThumbnailView(asset: asset)
                                .frame(width: 82, height: 82)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var sharedLinksSection: some View {
        inspectorSection(title: "Shared Links") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(appModel.linkAttachmentItems.prefix(4), id: \.attachment.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.attachment.filename)
                            .font(.subheadline.weight(.semibold))
                        Text(item.contextSnippet)
                            .font(.caption)
                            .foregroundStyle(AppTheme.metadataText)
                            .lineLimit(2)
                        Text(item.sentAt.compactDateLabel)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    if item.attachment.id != appModel.linkAttachmentItems.prefix(4).last?.attachment.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        inspectorSection(title: "Source") {
            InspectorMetricRow(label: "Mode", value: "Read-only")
            InspectorMetricRow(label: "Strategy", value: appModel.sourceStrategy.label)
            InspectorMetricRow(label: "Library", value: appModel.sourceModeName)
        }
    }

    private func inspectorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.metadataText)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.top, AppChrome.spacing12)
        }
        .padding(.bottom, AppChrome.spacing12)
    }

    private func initials(for title: String) -> String {
        title
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

private struct InspectorMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.metadataText)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct InspectorStatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.metadataText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppChrome.spacing12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.chromeBackground)
        )
    }
}
