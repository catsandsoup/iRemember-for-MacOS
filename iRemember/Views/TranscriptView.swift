import AppKit
import SwiftUI

struct TranscriptView: View {
    @Bindable var appModel: AppModel

    private var showsParticipantNames: Bool {
        (appModel.selectedArchiveSummary?.participants.count ?? 0) > 2
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: AppChrome.spacing12) {
                    if appModel.canLoadEarlierMessages {
                        TranscriptEdgeButton(title: "Load Earlier Messages") {
                            Task { await appModel.loadEarlierMessages() }
                        }
                        .padding(.top, AppChrome.spacing12)
                    }

                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        ForEach(appModel.daySections) { section in
                            Section {
                                VStack(spacing: 2) {
                                    ForEach(Array(section.messages.enumerated()), id: \.element.id) { index, message in
                                        MessageRow(
                                            message: message,
                                            previousMessage: section.messages[safe: index - 1],
                                            nextMessage: section.messages[safe: index + 1],
                                            isSelected: appModel.selectedMessageID == message.id,
                                            isHighlighted: appModel.highlightedMessageID == message.id,
                                            showsParticipantName: showsParticipantNames,
                                            availableMediaAssets: appModel.selectedArchiveDetail?.mediaAssets ?? [],
                                            onSelectMedia: { asset in
                                                appModel.presentMediaViewer(for: asset)
                                            },
                                            onJumpToReply: {
                                                Task { await appModel.jumpToReplyContext(from: message) }
                                            }
                                        )
                                        .id(message.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            appModel.selectMessage(message)
                                        }
                                    }
                                }
                            } header: {
                                TranscriptSectionHeader(title: section.title)
                            }
                        }
                    }
                    .frame(maxWidth: 920)
                    .padding(.horizontal, AppChrome.panePadding)
                    .padding(.bottom, AppChrome.panePadding)

                    if appModel.canLoadLaterMessages {
                        TranscriptEdgeButton(title: "Load Later Messages") {
                            Task { await appModel.loadLaterMessages() }
                        }
                        .padding(.bottom, AppChrome.spacing12)
                    }
                }
            }
            .onChange(of: appModel.scrollTargetMessageID) { _, newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }
}

private struct TranscriptSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.metadataText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.vertical, AppChrome.spacing8)
            .frame(maxWidth: .infinity)
    }
}

private struct TranscriptEdgeButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }
}

private struct MessageRow: View {
    let message: Message
    let previousMessage: Message?
    let nextMessage: Message?
    let isSelected: Bool
    let isHighlighted: Bool
    let showsParticipantName: Bool
    let availableMediaAssets: [MediaAsset]
    let onSelectMedia: (MediaAsset) -> Void
    let onJumpToReply: () -> Void

    private var isOutgoing: Bool {
        message.direction == .outgoing
    }

    private var startsCluster: Bool {
        guard let previousMessage else { return true }
        return !belongsInSameCluster(previousMessage, message)
    }

    private var endsCluster: Bool {
        guard let nextMessage else { return true }
        return !belongsInSameCluster(message, nextMessage)
    }

    private var alignment: HorizontalAlignment {
        isOutgoing ? .trailing : .leading
    }

    private var visibleBodyText: String {
        message.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsOnlyMedia: Bool {
        visibleBodyText.isEmpty && message.attachments.allSatisfy { $0.kind == .image || $0.kind == .video }
    }

    private var stackedMediaAttachments: [MediaAttachmentGroupItem]? {
        guard message.attachments.count > 1,
              message.attachments.allSatisfy({ $0.kind == .image || $0.kind == .video }) else {
            return nil
        }

        let items = message.attachments.compactMap { attachment in
            matchingMediaAsset(for: attachment).map { asset in
                MediaAttachmentGroupItem(attachment: attachment, asset: asset)
            }
        }

        return items.count == message.attachments.count ? items : nil
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isOutgoing {
                Spacer(minLength: 110)
            }

            VStack(alignment: alignment, spacing: 4) {
                if startsCluster {
                    header
                }

                VStack(alignment: alignment, spacing: 4) {
                    if let replyContext = message.replyContext {
                        ReplyPreviewView(replyContext: replyContext, isOutgoing: isOutgoing, action: onJumpToReply)
                    }

                    bubble

                    if !message.reactions.isEmpty {
                        ReactionsBar(reactions: message.reactions, isOutgoing: isOutgoing)
                            .padding(.horizontal, 6)
                            .padding(.top, -2)
                    }
                }

                if endsCluster {
                    footer
                }
            }
            .frame(maxWidth: 620, alignment: isOutgoing ? .trailing : .leading)

            if !isOutgoing {
                Spacer(minLength: 110)
            }
        }
        .padding(.vertical, verticalSpacing)
        .contextMenu {
            if message.replyContext != nil {
                Button("Jump to Original", action: onJumpToReply)
            }
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.body, forType: .string)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if showsParticipantName && !isOutgoing {
            Text(message.sender?.displayName ?? "Unknown")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
                .padding(.bottom, 2)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !visibleBodyText.isEmpty {
                Text(visibleBodyText)
                    .font(.system(size: 17))
                    .foregroundStyle(isOutgoing ? AppTheme.outgoingPrimaryText : Color.primary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
            }

            if !message.attachments.isEmpty {
                if let stackedMediaAttachments {
                    MessageMediaAttachmentGroupView(
                        items: stackedMediaAttachments,
                        onSelectMedia: onSelectMedia
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(message.attachments) { attachment in
                            MessageAttachmentBlock(
                                message: message,
                                attachment: attachment,
                                isOutgoing: isOutgoing,
                                asset: matchingMediaAsset(for: attachment),
                                onSelectMedia: onSelectMedia
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, showsOnlyMedia ? 0 : 14)
        .padding(.vertical, showsOnlyMedia ? 2 : 10)
        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
        .background {
            if showsOnlyMedia {
                Color.clear
            } else {
                bubbleBackground
            }
        }
        .overlay {
            if !showsOnlyMedia {
                BubbleShape(direction: message.direction, showsTail: endsCluster)
                    .stroke(isSelected ? AppTheme.activeSelectionStroke : AppTheme.bubbleStroke, lineWidth: isSelected ? 1.25 : 1)
            }
        }
        .overlay {
            if isHighlighted && !isSelected && !showsOnlyMedia {
                BubbleShape(direction: message.direction, showsTail: endsCluster)
                    .fill(AppTheme.activeTint.opacity(0.12))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var footer: some View {
        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(AppTheme.metadataText)
            .padding(.horizontal, 14)
            .padding(.top, 1)
    }

    private var bubbleBackground: some View {
        BubbleShape(direction: message.direction, showsTail: endsCluster)
            .fill(bubbleFillColor)
    }

    private var bubbleFillColor: Color {
        switch message.direction {
        case .incoming:
            AppTheme.incomingBubbleFill
        case .outgoing:
            AppTheme.outgoingBubbleFill
        case .system:
            AppTheme.systemBubbleFill
        }
    }

    private var bubbleMaxWidth: CGFloat {
        if showsOnlyMedia || stackedMediaAttachments != nil {
            return 300
        }

        return message.attachments.isEmpty ? 520 : 420
    }

    private var verticalSpacing: CGFloat {
        startsCluster ? 10 : 3
    }

    private var accessibilityLabel: String {
        let sender = message.sender?.displayName ?? "System"
        return "\(sender), \(message.sentAt.compactDateTimeLabel). \(message.body)"
    }

    private func belongsInSameCluster(_ lhs: Message, _ rhs: Message) -> Bool {
        guard lhs.direction == rhs.direction else { return false }
        guard lhs.sender?.handle == rhs.sender?.handle else { return false }
        return abs(lhs.sentAt.timeIntervalSince(rhs.sentAt)) < 300
    }

    private func matchingMediaAsset(for attachment: Attachment) -> MediaAsset? {
        availableMediaAssets.first {
            $0.messageID == message.id && $0.attachment.id == attachment.id
        }
    }
}

private struct MediaAttachmentGroupItem: Identifiable {
    let attachment: Attachment
    let asset: MediaAsset

    var id: UUID { attachment.id }
}

private struct ReplyPreviewView: View {
    let replyContext: MessageReplyContext
    let isOutgoing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(isOutgoing ? AppTheme.replyOutgoingBar : AppTheme.replyIncomingBar)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    if let quotedSender = replyContext.quotedSender {
                        Text(quotedSender)
                            .font(.caption.weight(.semibold))
                    }

                    Text(replyContext.quotedText)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(isOutgoing ? AppTheme.replyOutgoingText : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 280, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOutgoing ? AppTheme.replyOutgoingSurface : AppTheme.secondarySurface)
            )
        }
        .buttonStyle(.plain)
        .help("Jump to original message")
        .contextMenu {
            Button("Jump to Original", action: action)
        }
    }
}

private struct MessageMediaAttachmentGroupView: View {
    let items: [MediaAttachmentGroupItem]
    let onSelectMedia: (MediaAsset) -> Void

    private var visibleItems: [MediaAttachmentGroupItem] {
        Array(items.prefix(3))
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(groupLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.activeTint)

            Button {
                if let leadAsset = items.first?.asset {
                    onSelectMedia(leadAsset)
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    ForEach(Array(visibleItems.indices.reversed()), id: \.self) { index in
                        let item = visibleItems[index]
                        AttachmentThumbnailView(asset: item.asset)
                            .frame(width: 282, height: 212)
                            .rotationEffect(.degrees(Double(index) * 2.2))
                            .offset(x: CGFloat(index) * 10, y: CGFloat(index) * 8)
                            .shadow(color: Color.black.opacity(index == 0 ? 0.18 : 0.1), radius: 14, y: 5)
                    }
                }
                .frame(width: 304, height: 228, alignment: .topTrailing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(groupLabel)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var groupLabel: String {
        let hasVideo = items.contains { $0.attachment.kind == .video }
        if hasVideo {
            return items.count == 1 ? "1 Media Item" : "\(items.count) Media Items"
        }
        return items.count == 1 ? "1 Photo" : "\(items.count) Photos"
    }
}

private struct MessageAttachmentBlock: View {
    let message: Message
    let attachment: Attachment
    let isOutgoing: Bool
    let asset: MediaAsset?
    let onSelectMedia: (MediaAsset) -> Void

    var body: some View {
        switch attachment.kind {
        case .image, .video:
            mediaBlock
        case .file, .link:
            fileBlock
        }
    }

    @ViewBuilder
    private var mediaBlock: some View {
        if let asset {
            Button {
                onSelectMedia(asset)
            } label: {
                AttachmentThumbnailView(asset: asset)
                    .frame(width: 282, height: 212)
                    .accessibilityLabel("\(attachment.kind.label): \(attachment.filename)")
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Inspect Media") {
                    onSelectMedia(asset)
                }
            }
        } else {
            fileBlock
        }
    }

    private var fileBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: attachment.kind.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconForeground)
                .frame(width: 28, height: 28)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(textForeground)
                    .lineLimit(1)
                Text(attachmentDetailText)
                    .font(.caption)
                    .foregroundStyle(subtleForeground)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(fileBackground)
        .overlay(alignment: .bottomLeading) {
            if !attachment.isAvailableLocally {
                Text("Original unavailable on this Mac")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(subtleForeground)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
        .contextMenu {
            if attachment.isAvailableLocally, let fileURL = attachment.fileURL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
        }
    }

    private var attachmentDetailText: String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file)
        let availability = attachment.isAvailableLocally ? "Available locally" : "Original unavailable"
        return "\(attachment.kind.label) • \(size) • \(availability)"
    }

    private var iconBackground: Color {
        isOutgoing ? AppTheme.attachmentOutgoingIconBackground : AppTheme.attachmentIncomingIconBackground
    }

    private var iconForeground: Color {
        isOutgoing ? AppTheme.outgoingPrimaryText : .secondary
    }

    private var textForeground: Color {
        isOutgoing ? .white : .primary
    }

    private var subtleForeground: Color {
        isOutgoing ? AppTheme.outgoingSecondaryText : .secondary
    }

    private var fileBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isOutgoing ? AppTheme.attachmentOutgoingSurface : AppTheme.secondarySurface)
    }
}

private struct ReactionsBar: View {
    let reactions: [MessageReaction]
    let isOutgoing: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions) { reaction in
                Text(reactionLabel(reaction.kind))
                    .font(.system(size: 12))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppTheme.chromeBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.bubbleStroke, lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    private func reactionLabel(_ kind: MessageReactionKind) -> String {
        switch kind {
        case .loved:
            return "❤️"
        case .liked:
            return "👍"
        case .disliked:
            return "👎"
        case .laughed:
            return "😂"
        case .emphasized:
            return "‼️"
        case .questioned:
            return "❓"
        case .emoji(let emoji):
            return emoji
        case .sticker:
            return "Sticker"
        }
    }
}

private struct BubbleShape: Shape {
    let direction: MessageDirection
    let showsTail: Bool

    func path(in rect: CGRect) -> Path {
        let bubbleRect: CGRect

        switch direction {
        case .incoming:
            bubbleRect = showsTail ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - 6, height: rect.height) : rect
        case .outgoing:
            bubbleRect = showsTail ? CGRect(x: rect.minX + 6, y: rect.minY, width: rect.width - 6, height: rect.height) : rect
        case .system:
            bubbleRect = rect
        }

        var path = Path(roundedRect: bubbleRect, cornerRadius: 19)

        guard showsTail else { return path }

        switch direction {
        case .incoming:
            path.move(to: CGPoint(x: bubbleRect.minX + 8, y: bubbleRect.maxY - 6))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + 1, y: rect.maxY - 1),
                control: CGPoint(x: rect.minX + 2, y: rect.maxY - 8)
            )
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.minX + 12, y: bubbleRect.maxY - 2),
                control: CGPoint(x: bubbleRect.minX + 4, y: rect.maxY - 1)
            )
        case .outgoing:
            path.move(to: CGPoint(x: bubbleRect.maxX - 8, y: bubbleRect.maxY - 6))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 1),
                control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 8)
            )
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.maxX - 12, y: bubbleRect.maxY - 2),
                control: CGPoint(x: bubbleRect.maxX - 4, y: rect.maxY - 1)
            )
        case .system:
            break
        }

        return path
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
