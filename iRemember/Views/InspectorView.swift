import SwiftUI

struct InspectorView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            if let archive = appModel.selectedArchiveSummary {
                VStack(alignment: .leading, spacing: 0) {
                    InspectorIdentityHeader(
                        archive: archive,
                        subtitle: archiveSubtitle(for: archive),
                        identitySourceSummary: appModel.archiveIdentitySourceSummary,
                        handleSummary: appModel.linkedHandleSummary,
                        accessState: appModel.contactIdentityAccessState
                    )
                    .padding(.bottom, 18)

                    Divider()

                    InspectorSection(title: "Shared") {
                        SharedOverviewSection(appModel: appModel)
                    }

                    InspectorSection(title: "Conversation") {
                        ArchiveSnapshotSection(
                            archiveRangeSummary: appModel.archiveRangeSummary,
                            messageCount: archive.messageCount.groupedCount,
                            mediaCount: archive.mediaCount.groupedCount,
                            participantCount: archive.participants.count.groupedCount,
                            conversationCount: archive.conversationIDs.count.groupedCount
                        )
                    }

                    if !appModel.archiveHandles.isEmpty {
                        InspectorSection(title: "Addresses") {
                            IdentityAddressesSection(handles: appModel.archiveHandles)
                        }
                    }

                    InspectorSection(title: "Export") {
                        ExportSection(appModel: appModel)
                    }

                    if appModel.showsMergeSuggestion {
                        InspectorSection(title: "Suggested Merge") {
                            MergeSuggestionSection(appModel: appModel)
                        }
                    }

                    if let message = appModel.selectedMessage {
                        InspectorSection(title: "Selected Message") {
                            MessageSection(message: message)
                        }
                    }

                    if let asset = appModel.selectedMediaAsset {
                        InspectorSection(title: "Selected Media") {
                            MediaSelectionSection(appModel: appModel, asset: asset)
                        }
                    }

                    InspectorSection(title: "Library", showsDivider: false) {
                        LibrarySection(appModel: appModel)
                    }
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.right",
                    description: Text("Conversation details appear here when you select a contact, conversation, or shared item.")
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(20)
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .controlSize(.small)
    }

    private func archiveSubtitle(for archive: ArchiveSummary) -> String {
        let participantCount = archive.participants.filter { $0.handle != "me" && $0.displayName != "You" }.count

        if archive.kind == .person, archive.conversationIDs.count > 1 {
            return "\(archive.conversationIDs.count.groupedCount) conversations collected under one contact"
        }

        if participantCount <= 1 {
            return "1 person in this conversation"
        }

        return "\(participantCount.groupedCount) people in this conversation"
    }
}

private struct InspectorIdentityHeader: View {
    let archive: ArchiveSummary
    let subtitle: String
    let identitySourceSummary: String
    let handleSummary: String
    let accessState: ContactIdentityAccessState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(initials(for: archive.title))
                        .font(.headline.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(archive.title)
                    .font(.title3.bold())
                    .lineLimit(2)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label(identitySourceSummary, systemImage: accessState.symbolName)
                        .lineLimit(2)

                    Text(handleSummary)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func initials(for title: String) -> String {
        let parts = title
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()

        return parts.isEmpty ? "?" : parts
    }
}

private struct SharedOverviewSection: View {
    @Bindable var appModel: AppModel

    private let previewColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorStatRow(
                items: [
                    ("Photos", photoCount),
                    ("Links", appModel.linkAttachmentItems.count.groupedCount),
                    ("Files", fileCount)
                ]
            )

            if previewAssets.isEmpty {
                Text("No shared media has been indexed for this conversation yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: previewColumns, spacing: 10) {
                    ForEach(previewAssets) { asset in
                        Button {
                            appModel.presentMediaViewer(for: asset)
                        } label: {
                            AttachmentThumbnailView(asset: asset)
                                .frame(height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Open shared media")
                    }
                }

                Button("Browse Shared Media", systemImage: "photo.on.rectangle.angled") {
                    appModel.contentMode = .media
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var previewAssets: [MediaAsset] {
        Array(appModel.selectedArchiveDetail?.mediaAssets.prefix(6) ?? [])
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

private struct IdentityAddressesSection: View {
    let handles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(handles, id: \.self) { handle in
                Text(handle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private struct ExportSection: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Export Conversation…", systemImage: "square.and.arrow.up") {
                appModel.presentExport(scope: .entireConversation, format: .pdf)
            }
            .buttonStyle(.borderedProminent)

            Button("Export Shared Content…", systemImage: "photo.on.rectangle.angled") {
                appModel.presentSharedContentExport()
            }
            .buttonStyle(.bordered)

            Menu("More Export Options") {
                Button("Export Loaded Range as PDF") {
                    appModel.presentExport(scope: .currentLoadedRange, format: .pdf)
                }

                Button("Export JSON Archive") {
                    appModel.presentExport(scope: .entireConversation, format: .json)
                }

                Button("Export DOCX") {
                    appModel.presentExport(scope: .entireConversation, format: .docx)
                }
            }

            Text("The same export commands are available from the File menu and conversation context menus.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ArchiveSnapshotSection: View {
    let archiveRangeSummary: String
    let messageCount: String
    let mediaCount: String
    let participantCount: String
    let conversationCount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InspectorLabeledValue(label: "Range", value: archiveRangeSummary)
            InspectorLabeledValue(label: "Messages", value: messageCount)
            InspectorLabeledValue(label: "Media", value: mediaCount)
            InspectorLabeledValue(label: "People", value: participantCount)
            InspectorLabeledValue(label: "Conversations", value: conversationCount)
        }
    }
}

private struct MergeSuggestionSection: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This conversation appears to belong to the same contact as another archive in your library.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(appModel.mergeSuggestionHandles, id: \.self) { handle in
                Text(handle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Contact View", systemImage: "person.crop.circle") {
                Task { await appModel.setSidebarMode(.people) }
            }
            .buttonStyle(.borderedProminent)

            Button("Keep Separate", systemImage: "arrow.triangle.branch") {
                Task { await appModel.applyMergeDecision(.keepSeparate) }
            }
            .buttonStyle(.bordered)

            Button("Always Merge This Contact", systemImage: "link.badge.plus") {
                Task { await appModel.applyMergeDecision(.alwaysMerge) }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct MessageSection: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InspectorLabeledValue(label: "Sender", value: message.sender?.displayName ?? "System")
            InspectorLabeledValue(label: "Sent", value: message.sentAt.compactDateTimeLabel)

            if !message.body.isEmpty {
                Text(message.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct MediaSelectionSection: View {
    @Bindable var appModel: AppModel
    let asset: MediaAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AttachmentThumbnailView(asset: asset)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            InspectorLabeledValue(label: "Filename", value: asset.attachment.filename)
            InspectorLabeledValue(label: "Type", value: asset.attachment.kind.label)
            InspectorLabeledValue(label: "Sent", value: asset.sentAt.compactDateTimeLabel)
            InspectorLabeledValue(
                label: "Availability",
                value: asset.attachment.isAvailableLocally ? "Available locally" : "Original unavailable"
            )

            Button("Open Media", systemImage: "arrow.up.forward.app") {
                appModel.presentMediaViewer(for: asset)
            }
            .buttonStyle(.borderedProminent)

            Button("Show in Conversation", systemImage: "message") {
                Task { await appModel.revealMediaInTranscript(asset) }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LibrarySection: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InspectorLabeledValue(label: "Source", value: appModel.sourceModeName)
            InspectorLabeledValue(label: "Contacts", value: appModel.archiveIdentitySourceSummary)
            InspectorLabeledValue(label: "Access", value: "Read-only")
        }
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let showsDivider: Bool
    let content: Content

    init(title: String, showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
            }
        }
    }
}

private struct InspectorLabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private struct InspectorStatRow: View {
    let items: [(title: String, value: String)]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(items, id: \.title) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.headline.monospacedDigit())

                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
