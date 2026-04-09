import SwiftUI

struct InspectorView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppChrome.sectionSpacing) {
                if let archive = appModel.selectedArchiveSummary {
                    PersonCard(archive: archive, linkedHandleSummary: appModel.linkedHandleSummary)

                    SharedCard(appModel: appModel)

                    ExportCard(appModel: appModel)

                    ArchiveCard(
                        archiveRangeSummary: appModel.archiveRangeSummary,
                        messageCount: archive.messageCount.groupedCount,
                        mediaCount: archive.mediaCount.groupedCount,
                        participantCount: archive.participants.count.groupedCount,
                        mergeStateLabel: appModel.mergeStateLabel
                    )

                    if appModel.showsMergeSuggestion {
                        MergeCard(appModel: appModel)
                    }

                    if let message = appModel.selectedMessage {
                        MessageCard(message: message)
                    }

                    if let asset = appModel.selectedMediaAsset {
                        SelectedMediaCard(appModel: appModel, asset: asset)
                    }

                    SourceCard(appModel: appModel)
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "sidebar.right",
                        description: Text("Inspector details appear when a conversation, person archive, or media item is selected.")
                    )
                }
            }
            .padding(AppChrome.spacing16)
        }
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .controlSize(.small)
    }
}

private struct PersonCard: View {
    let archive: ArchiveSummary
    let linkedHandleSummary: String

    var body: some View {
        InspectorSectionCard(title: "Person") {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.activeTint)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(initials(for: archive.title))
                            .font(.headline.weight(.semibold))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(archive.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(linkedHandleSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.metadataText)
                }
            }

            if !archive.linkedHandles.isEmpty {
                Text(archive.linkedHandles.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

private struct SharedCard: View {
    @Bindable var appModel: AppModel

    var body: some View {
        InspectorSectionCard(title: "Shared") {
            VStack(alignment: .leading, spacing: 10) {
                SharedMetricRow(label: "Photos", value: photoCount)
                SharedMetricRow(label: "Links", value: appModel.linkAttachmentItems.count.groupedCount)
                SharedMetricRow(label: "Attachments", value: fileCount)
            }

            if !(appModel.selectedArchiveDetail?.mediaAssets.isEmpty ?? true) {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(appModel.selectedArchiveDetail?.mediaAssets.prefix(6) ?? []) { asset in
                            Button {
                                appModel.presentMediaViewer(for: asset)
                            } label: {
                                AttachmentThumbnailView(asset: asset)
                                    .frame(width: 72, height: 72)
                            }
                            .buttonStyle(.plain)
                            .help("Open shared media")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var photoCount: String {
        let count = appModel.selectedArchiveDetail?.mediaAssets.filter { $0.attachment.kind == .image }.count ?? 0
        return count.groupedCount
    }

    private var fileCount: String {
        let count = appModel.selectedArchiveDetail?.attachmentItems.filter { $0.attachment.kind == .file }.count ?? 0
        return count.groupedCount
    }
}

private struct ExportCard: View {
    @Bindable var appModel: AppModel

    var body: some View {
        InspectorSectionCard(title: "Export") {
            VStack(alignment: .leading, spacing: 10) {
                ExportActionButton(title: "Export Conversation") {
                    appModel.presentExport(scope: .entireConversation, format: .pdf)
                }

                ExportActionButton(title: "Export Loaded Range") {
                    appModel.presentExport(scope: .currentLoadedRange, format: .pdf)
                }

                ExportActionButton(title: "Export JSON Archive") {
                    appModel.presentExport(scope: .entireConversation, format: .json)
                }

                ExportActionButton(title: "Export DOCX") {
                    appModel.presentExport(scope: .entireConversation, format: .docx)
                }

                ExportActionButton(title: "Export Shared Content") {
                    appModel.presentSharedContentExport()
                }

                Text("Also available from File, the iRemember menu, and archive context menus.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ArchiveCard: View {
    let archiveRangeSummary: String
    let messageCount: String
    let mediaCount: String
    let participantCount: String
    let mergeStateLabel: String

    var body: some View {
        InspectorSectionCard(title: "Archive") {
            SharedMetricRow(label: "Range", value: archiveRangeSummary)
            SharedMetricRow(label: "Messages", value: messageCount)
            SharedMetricRow(label: "Media", value: mediaCount)
            SharedMetricRow(label: "Participants", value: participantCount)
            SharedMetricRow(label: "Merge", value: mergeStateLabel)
        }
    }
}

private struct MergeCard: View {
    @Bindable var appModel: AppModel

    var body: some View {
        InspectorSectionCard(title: "Merge Identity") {
            Text("These conversations may belong to the same contact.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(appModel.mergeSuggestionHandles, id: \.self) { handle in
                Text(handle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.metadataText)
            }

            HStack(spacing: 8) {
                Button("View Merged") {
                    Task { await appModel.setSidebarMode(.people) }
                }
                .buttonStyle(.borderedProminent)

                Button("Keep Separate") {
                    Task { await appModel.applyMergeDecision(.keepSeparate) }
                }
                .buttonStyle(.bordered)

                Button("Always Merge for This Contact") {
                    Task { await appModel.applyMergeDecision(.alwaysMerge) }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct MessageCard: View {
    let message: Message

    var body: some View {
        InspectorSectionCard(title: "Selected Message") {
            SharedMetricRow(label: "Sender", value: message.sender?.displayName ?? "System")
            SharedMetricRow(label: "Sent", value: message.sentAt.compactDateTimeLabel)

            if !message.body.isEmpty {
                Text(message.body)
                    .font(.callout)
                    .foregroundStyle(AppTheme.metadataText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SelectedMediaCard: View {
    @Bindable var appModel: AppModel
    let asset: MediaAsset

    var body: some View {
        InspectorSectionCard(title: "Selected Media") {
            AttachmentThumbnailView(asset: asset)
                .frame(height: 148)

            SharedMetricRow(label: "Filename", value: asset.attachment.filename)
            SharedMetricRow(label: "Type", value: asset.attachment.kind.label)
            SharedMetricRow(label: "Sent", value: asset.sentAt.compactDateTimeLabel)
            SharedMetricRow(label: "Availability", value: asset.attachment.isAvailableLocally ? "Available locally" : "Original unavailable")

            Button("Open Media") {
                appModel.presentMediaViewer(for: asset)
            }
            .buttonStyle(.borderedProminent)

            Button("Show in Conversation") {
                Task { await appModel.revealMediaInTranscript(asset) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct SourceCard: View {
    @Bindable var appModel: AppModel

    var body: some View {
        InspectorSectionCard(title: "Source") {
            SharedMetricRow(label: "Mode", value: "Read-only")
            SharedMetricRow(label: "Strategy", value: appModel.sourceStrategy.label)
            SharedMetricRow(label: "Library", value: appModel.sourceModeName)
        }
    }
}

private struct InspectorSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.headline)
        }
    }
}

private struct SharedMetricRow: View {
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

private struct ExportActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
