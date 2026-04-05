import Foundation

public enum MessageDirection: String, Codable, Hashable, Sendable {
    case incoming
    case outgoing
    case system
}

public enum AttachmentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case image
    case video
    case file
    case link

    public var label: String {
        switch self {
        case .image: "Image"
        case .video: "Video"
        case .file: "File"
        case .link: "Link"
        }
    }

    public var symbolName: String {
        switch self {
        case .image: "photo"
        case .video: "video"
        case .file: "doc"
        case .link: "link"
        }
    }
}

public enum MessageReactionKind: Hashable, Sendable {
    case loved
    case liked
    case disliked
    case laughed
    case emphasized
    case questioned
    case emoji(String)
    case sticker

    public var symbol: String {
        switch self {
        case .loved: return "heart.fill"
        case .liked: return "hand.thumbsup.fill"
        case .disliked: return "hand.thumbsdown.fill"
        case .laughed: return "ha"
        case .emphasized: return "exclamationmark"
        case .questioned: return "questionmark"
        case .emoji(let emoji): return emoji
        case .sticker: return "face.smiling"
        }
    }
}

public struct MessageReaction: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sender: Participant?
    public let kind: MessageReactionKind

    public nonisolated init(
        id: UUID = UUID(),
        sender: Participant?,
        kind: MessageReactionKind
    ) {
        self.id = id
        self.sender = sender
        self.kind = kind
    }
}

public struct MessageReplyContext: Hashable, Sendable {
    public let referencedMessageGUID: String
    public let quotedText: String
    public let quotedSender: String?

    public nonisolated init(referencedMessageGUID: String, quotedText: String, quotedSender: String?) {
        self.referencedMessageGUID = referencedMessageGUID
        self.quotedText = quotedText
        self.quotedSender = quotedSender
    }
}

public enum MediaFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case images
    case videos

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: "All Media"
        case .images: "Photos"
        case .videos: "Videos"
        }
    }
}

public enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case text
    case people
    case attachments

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .people: "People"
        case .attachments: "Attachments"
        }
    }
}

public enum TimelineRange: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case year

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

public struct Participant: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let handle: String
    public let accentColorName: String

    public nonisolated init(
        id: UUID = UUID(),
        displayName: String,
        handle: String,
        accentColorName: String = "blue"
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.accentColorName = accentColorName
    }
}

public struct Attachment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: AttachmentKind
    public let filename: String
    public let uti: String
    public let byteSize: Int
    public let sentAt: Date
    public let fileURL: URL?
    public let isAvailableLocally: Bool

    public nonisolated init(
        id: UUID = UUID(),
        kind: AttachmentKind,
        filename: String,
        uti: String,
        byteSize: Int,
        sentAt: Date,
        fileURL: URL? = nil,
        isAvailableLocally: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.uti = uti
        self.byteSize = byteSize
        self.sentAt = sentAt
        self.fileURL = fileURL
        self.isAvailableLocally = isAvailableLocally
    }
}

public struct Message: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let guid: String?
    public let conversationID: UUID
    public let sender: Participant?
    public let body: String
    public let sentAt: Date
    public let direction: MessageDirection
    public let attachments: [Attachment]
    public let replyContext: MessageReplyContext?
    public let reactions: [MessageReaction]

    public nonisolated init(
        id: UUID = UUID(),
        guid: String? = nil,
        conversationID: UUID,
        sender: Participant?,
        body: String,
        sentAt: Date,
        direction: MessageDirection,
        attachments: [Attachment] = [],
        replyContext: MessageReplyContext? = nil,
        reactions: [MessageReaction] = []
    ) {
        self.id = id
        self.guid = guid
        self.conversationID = conversationID
        self.sender = sender
        self.body = body
        self.sentAt = sentAt
        self.direction = direction
        self.attachments = attachments
        self.replyContext = replyContext
        self.reactions = reactions
    }
}

public struct Conversation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let participants: [Participant]
    public let snippet: String
    public let lastActivityAt: Date
    public let messageCount: Int?
    public let mediaCount: Int?
    public let isPinned: Bool

    public nonisolated init(
        id: UUID = UUID(),
        title: String,
        participants: [Participant],
        snippet: String,
        lastActivityAt: Date,
        messageCount: Int?,
        mediaCount: Int?,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.participants = participants
        self.snippet = snippet
        self.lastActivityAt = lastActivityAt
        self.messageCount = messageCount
        self.mediaCount = mediaCount
        self.isPinned = isPinned
    }

    public nonisolated func updatingCounts(messageCount: Int, mediaCount: Int) -> Conversation {
        Conversation(
            id: id,
            title: title,
            participants: participants,
            snippet: snippet,
            lastActivityAt: lastActivityAt,
            messageCount: messageCount,
            mediaCount: mediaCount,
            isPinned: isPinned
        )
    }
}

public struct MediaAsset: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let messageID: UUID
    public let attachment: Attachment
    public let sender: Participant?
    public let sentAt: Date
    public let contextSnippet: String

    public nonisolated init(
        id: UUID = UUID(),
        conversationID: UUID,
        messageID: UUID,
        attachment: Attachment,
        sender: Participant?,
        sentAt: Date,
        contextSnippet: String
    ) {
        self.id = id
        self.conversationID = conversationID
        self.messageID = messageID
        self.attachment = attachment
        self.sender = sender
        self.sentAt = sentAt
        self.contextSnippet = contextSnippet
    }
}

public struct AttachmentItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let messageID: UUID
    public let attachment: Attachment
    public let sender: Participant?
    public let sentAt: Date
    public let contextSnippet: String

    public nonisolated init(
        id: UUID = UUID(),
        conversationID: UUID,
        messageID: UUID,
        attachment: Attachment,
        sender: Participant?,
        sentAt: Date,
        contextSnippet: String
    ) {
        self.id = id
        self.conversationID = conversationID
        self.messageID = messageID
        self.attachment = attachment
        self.sender = sender
        self.sentAt = sentAt
        self.contextSnippet = contextSnippet
    }

    public nonisolated var mediaAsset: MediaAsset? {
        switch attachment.kind {
        case .image, .video:
            return MediaAsset(
                id: id,
                conversationID: conversationID,
                messageID: messageID,
                attachment: attachment,
                sender: sender,
                sentAt: sentAt,
                contextSnippet: contextSnippet
            )
        case .file, .link:
            return nil
        }
    }
}

public struct MessageIndexEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sentAt: Date

    public nonisolated init(id: UUID, sentAt: Date) {
        self.id = id
        self.sentAt = sentAt
    }
}

public struct ConversationDetail: Hashable, Sendable {
    public let conversation: Conversation
    public let messageIndex: [MessageIndexEntry]
    public let attachmentItems: [AttachmentItem]

    public nonisolated init(
        conversation: Conversation,
        messageIndex: [MessageIndexEntry],
        attachmentItems: [AttachmentItem]
    ) {
        self.conversation = conversation
        self.messageIndex = messageIndex
        self.attachmentItems = attachmentItems
    }

    public nonisolated var mediaAssets: [MediaAsset] {
        attachmentItems.compactMap(\.mediaAsset)
    }
}

public struct TranscriptSlice: Sendable {
    public let messages: [Message]
    public let range: Range<Int>
    public let totalCount: Int

    public nonisolated init(messages: [Message], range: Range<Int>, totalCount: Int) {
        self.messages = messages
        self.range = range
        self.totalCount = totalCount
    }
}

public struct LibrarySnapshot: Sendable {
    public let conversations: [Conversation]

    public nonisolated init(conversations: [Conversation]) {
        self.conversations = conversations.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }
}

public struct TimelineBucket: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let messageCount: Int

    public nonisolated init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        messageCount: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.messageCount = messageCount
    }
}

public struct SavedSearch: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let query: String
    public let createdAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        title: String,
        query: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.query = query
        self.createdAt = createdAt
    }
}

public struct ExportJob: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let createdAt: Date
    public let itemCount: Int
    public let destinationDescription: String

    public nonisolated init(
        id: UUID = UUID(),
        conversationID: UUID,
        createdAt: Date = .now,
        itemCount: Int,
        destinationDescription: String
    ) {
        self.id = id
        self.conversationID = conversationID
        self.createdAt = createdAt
        self.itemCount = itemCount
        self.destinationDescription = destinationDescription
    }
}
