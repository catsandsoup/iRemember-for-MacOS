import CryptoKit
import Foundation
import SQLite3
import UniformTypeIdentifiers

public enum MessagesSourceError: Error, LocalizedError, MessagesLoadErrorPresentable {
    case fullDiskAccessRequired(databasePath: String, attachmentsPath: String)
    case databaseMissing(path: String)
    case attachmentsDirectoryMissing(path: String)
    case conversationNotFound
    case sqliteFailure(operation: String, code: Int32?, message: String)

    public var errorDescription: String? {
        switch self {
        case .fullDiskAccessRequired(let databasePath, let attachmentsPath):
            return """
            Full Disk Access is required before iRemember can read Apple Messages. Open Privacy & Security in macOS, allow the app and any host tools you use for development, then try again. Required sources:
            \(databasePath)
            \(attachmentsPath)
            """
        case .databaseMissing(let path):
            return "Messages database not found at \(path)."
        case .attachmentsDirectoryMissing(let path):
            return "Messages attachments folder not found at \(path)."
        case .conversationNotFound:
            return "Conversation not found."
        case .sqliteFailure(let operation, let code, let message):
            if let code {
                return "Messages database \(operation) failed (SQLite \(code)): \(message)"
            }
            return "Messages database \(operation) failed: \(message)"
        }
    }

    public var failureTitle: String {
        switch self {
        case .fullDiskAccessRequired:
            "Full Disk Access Required"
        case .databaseMissing, .attachmentsDirectoryMissing:
            "Messages Library Not Found"
        case .conversationNotFound:
            "Conversation Missing"
        case .sqliteFailure:
            "Unable to Read Messages Database"
        }
    }

    public var failureCode: String {
        switch self {
        case .fullDiskAccessRequired:
            "IRM-SRC-001"
        case .databaseMissing:
            "IRM-SRC-002"
        case .attachmentsDirectoryMissing:
            "IRM-SRC-003"
        case .conversationNotFound:
            "IRM-SRC-004"
        case .sqliteFailure:
            "IRM-SRC-005"
        }
    }

    public var failureDescription: String {
        switch self {
        case .fullDiskAccessRequired:
            "iRemember can see the Messages library on this Mac, but macOS is still blocking read access."
        case .databaseMissing:
            "The local Messages database could not be found on this Mac."
        case .attachmentsDirectoryMissing:
            "The local Messages attachments folder could not be found on this Mac."
        case .conversationNotFound:
            "The selected conversation is no longer available."
        case .sqliteFailure(let operation, _, _):
            "The Messages database could not complete the \(operation) step."
        }
    }

    public var recoverySteps: [String] {
        switch self {
        case .fullDiskAccessRequired:
            return [
                "Open System Settings > Privacy & Security > Full Disk Access.",
                "Enable access for iRemember. If you launch from Xcode, allow Xcode too.",
                "Quit and relaunch the app after changing Full Disk Access."
            ]
        case .databaseMissing(let path):
            return [
                "Confirm Messages.app has local history on this Mac.",
                "Verify that \((path as NSString).abbreviatingWithTildeInPath) exists."
            ]
        case .attachmentsDirectoryMissing(let path):
            return [
                "Verify that \((path as NSString).abbreviatingWithTildeInPath) exists locally on this Mac.",
                "If iCloud Messages has offloaded media, some originals may remain unavailable."
            ]
        case .conversationNotFound:
            return [
                "Reload the library and select the conversation again."
            ]
        case .sqliteFailure:
            return [
                "Retry after Messages.app finishes syncing.",
                "If the problem persists, reopen the app and try the library again."
            ]
        }
    }
}

public actor SQLiteMessagesSource: MessagesSource {
    public let strategy: SourceStrategy = .liveBrowse
    public let libraryModeName = "Local Messages Library"
    public let libraryModeDescription = "Read-only access to ~/Library/Messages/chat.db with transcript windows and lazy attachment previews."
    public let sourceLocations: [SourceLocation]

    private let databaseURL: URL
    private let attachmentsURL: URL
    private let conversationBatchSize = 200

    private var conversationLocators: [UUID: ConversationLocator] = [:]
    private var conversationsByID: [UUID: Conversation] = [:]
    private var detailCache: [UUID: LoadedConversationCache] = [:]
    private var cachedMessageTableCapabilities: MessageTableCapabilities?

    public init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Messages/chat.db"),
        attachmentsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Messages/Attachments")
    ) {
        self.databaseURL = databaseURL
        self.attachmentsURL = attachmentsURL
        self.sourceLocations = [
            SourceLocation(label: "Messages database", url: databaseURL),
            SourceLocation(label: "Attachments folder", url: attachmentsURL)
        ]
    }

    public func inspectSetup() async -> SourceSetupSnapshot {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let attachmentsExists = fileManager.fileExists(atPath: attachmentsURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
        let databaseExists = fileManager.fileExists(atPath: databaseURL.path)
        let readAccessState: SetupRequirementState
        let readAccessDetail: String

        do {
            _ = try openDatabase()
            readAccessState = .complete
            readAccessDetail = "The database is readable in read-only mode."
        } catch MessagesSourceError.fullDiskAccessRequired {
            readAccessState = .actionRequired
            readAccessDetail = "Full Disk Access is still required before live Messages can open."
        } catch {
            readAccessState = .informational
            readAccessDetail = "Read access will be checked again when you open the library."
        }

        return SourceSetupSnapshot(
            title: "Set up access to Messages",
            detail: "iRemember reads the Messages library already on this Mac. Nothing is uploaded or modified.",
            requirements: [
                SetupRequirement(
                    id: "read-only",
                    title: "Read-only by design",
                    detail: "The app browses local data without changing your Messages store.",
                    state: .complete
                ),
                SetupRequirement(
                    id: "database",
                    title: "Messages database found",
                    detail: databaseExists ? "chat.db is available on this Mac." : "chat.db is not available yet on this Mac.",
                    state: databaseExists ? .complete : .actionRequired
                ),
                SetupRequirement(
                    id: "attachments",
                    title: "Attachments folder found",
                    detail: attachmentsExists ? "Attachments are available for lazy preview loading." : "The attachments folder is missing or unavailable.",
                    state: attachmentsExists ? .complete : .actionRequired
                ),
                SetupRequirement(
                    id: "full-disk-access",
                    title: "Full Disk Access",
                    detail: readAccessDetail,
                    state: readAccessState
                )
            ],
            locations: sourceLocations
        )
    }

    public func bootstrapLibrary(progressHandler: (@Sendable (LibraryLoadProgress) -> Void)?) async throws -> LibrarySnapshot {
        progressHandler?(
            LibraryLoadProgress(
                step: 1,
                totalSteps: 4,
                title: "Checking local Messages access",
                detail: "Looking for the Messages database and attachments on this Mac."
            )
        )
        try verifyPaths()
        progressHandler?(
            LibraryLoadProgress(
                step: 2,
                totalSteps: 4,
                title: "Opening the Messages database",
                detail: "Connecting in read-only mode so the source data stays untouched."
            )
        )
        let snapshot = try loadLibrarySnapshot(progressHandler: progressHandler)
        progressHandler?(
            LibraryLoadProgress(
                step: 4,
                totalSteps: 4,
                title: "Library ready",
                detail: "Conversation metadata is loaded. Full transcripts stay on demand."
            )
        )
        return snapshot
    }

    public func loadConversationDetail(id: UUID) async throws -> ConversationDetail {
        try verifyPaths()
        try ensureBootstrapLoaded()

        if let cached = detailCache[id] {
            return cached.detail
        }

        guard let locator = conversationLocators[id], let conversation = conversationsByID[id] else {
            throw MessagesSourceError.conversationNotFound
        }

        let database = try openDatabase()
        let capabilities = try messageTableCapabilities(database: database)
        let messageEntries = try fetchMessageIndex(chatRowID: locator.chatRowID, capabilities: capabilities, database: database)
        let messageIDsByRowID = Dictionary(uniqueKeysWithValues: messageEntries.map { ($0.rowID, $0.id) })
        let attachmentItems = try fetchAttachmentItems(
            chatRowID: locator.chatRowID,
            conversationID: id,
            messageIDsByRowID: messageIDsByRowID,
            capabilities: capabilities,
            database: database
        )

        let enrichedConversation = conversation.updatingCounts(
            messageCount: messageEntries.count,
            mediaCount: attachmentItems.compactMap(\.mediaAsset).count
        )
        conversationsByID[id] = enrichedConversation

        let detail = ConversationDetail(
            conversation: enrichedConversation,
            messageIndex: messageEntries.map { MessageIndexEntry(id: $0.id, guid: $0.guid, sentAt: $0.sentAt) },
            attachmentItems: attachmentItems
        )

        detailCache[id] = LoadedConversationCache(
            chatRowID: locator.chatRowID,
            detail: detail,
            messageEntries: messageEntries,
            capabilities: capabilities
        )

        return detail
    }

    public func loadMessages(conversationID: UUID, range: Range<Int>) async throws -> TranscriptSlice {
        let cache = try await ensureConversationLoaded(conversationID)
        let count = cache.messageEntries.count
        let lower = max(0, min(range.lowerBound, count))
        let upper = max(lower, min(range.upperBound, count))
        let sliceEntries = Array(cache.messageEntries[lower..<upper])
        let rowIDs = sliceEntries.map(\.rowID)

        guard !rowIDs.isEmpty else {
            return TranscriptSlice(messages: [], range: lower..<upper, totalCount: count)
        }

        let messages = try fetchMessages(
            rowIDs: rowIDs,
            conversationID: conversationID,
            capabilities: cache.capabilities,
            messageIDsByRowID: cache.messageIDsByRowID,
            database: openDatabase()
        )

        return TranscriptSlice(messages: messages, range: lower..<upper, totalCount: count)
    }

    public func searchLibrary(query: String, scope: SearchScope, limit: Int) async throws -> [ArchiveSearchResult] {
        try verifyPaths()
        try ensureBootstrapLoaded()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let database = try openDatabase()
        let capabilities = try messageTableCapabilities(database: database)
        let reverseConversationIDs = Dictionary(uniqueKeysWithValues: conversationLocators.map { ($1.chatRowID, $0) })
        let likeQuery = "%\(trimmed)%"

        var results: [ArchiveSearchResult] = []

        let conversationMatches = conversationsByID.values
            .filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(trimmed) ||
                conversation.snippet.localizedCaseInsensitiveContains(trimmed) ||
                conversation.participants.contains {
                    $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
                    $0.handle.localizedCaseInsensitiveContains(trimmed)
                }
            }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
            .prefix(limit / 4)

        results.append(contentsOf: conversationMatches.map { conversation in
            ArchiveSearchResult(
                id: "conversation:\(conversation.id.uuidString)",
                kind: .conversation,
                conversationID: conversation.id,
                archiveTitle: conversation.title,
                title: conversation.title,
                subtitle: conversation.snippet,
                sentAt: conversation.lastActivityAt
            )
        })

        if scope == .all || scope == .messages || scope == .people {
            let messageSQL = """
            SELECT
                cmj.chat_id,
                m.ROWID,
                m.guid,
                m.text,
                m.attributedBody,
                COALESCE(m.cache_has_attachments, 0),
                m.date,
                COALESCE(m.is_from_me, 0),
                h.id
            FROM message AS m
            JOIN chat_message_join AS cmj ON cmj.message_id = m.ROWID
            LEFT JOIN handle AS h ON h.ROWID = m.handle_id
            WHERE \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
              AND (
                (m.text LIKE ? COLLATE NOCASE)
                OR (h.id LIKE ? COLLATE NOCASE)
              )
            ORDER BY m.date DESC, m.ROWID DESC
            LIMIT ?
            """

            try database.readRows(sql: messageSQL, bind: { statement in
                try database.bind(string: likeQuery, at: 1, in: statement)
                try database.bind(string: likeQuery, at: 2, in: statement)
                try database.bind(int64: Int64(limit), at: 3, in: statement)
            }) { row in
                guard results.count < limit,
                      let chatRowID = row.int64(0),
                      let messageRowID = row.int64(1),
                      let conversationID = reverseConversationIDs[chatRowID],
                      let conversation = self.conversationsByID[conversationID] else {
                    return
                }

                let messageID = self.stableUUID(for: "message:\(row.string(2) ?? String(messageRowID))")
                let sentAt = Self.appleMessageDate(from: row.int64(6))
                let subtitle = self.resolvedVisibleBody(
                    text: row.string(3),
                    attributedBody: row.data(4),
                    hasAttachments: row.bool(5),
                    context: .transcript
                )
                let sender = self.participant(handle: row.string(8), isFromMe: row.bool(7))

                let include = switch scope {
                case .all, .messages:
                    subtitle.localizedCaseInsensitiveContains(trimmed)
                case .people:
                    sender?.displayName.localizedCaseInsensitiveContains(trimmed) == true ||
                    sender?.handle.localizedCaseInsensitiveContains(trimmed) == true
                case .media, .links, .attachments:
                    false
                }

                guard include else { return }

                results.append(
                    ArchiveSearchResult(
                        id: "message:\(messageID.uuidString)",
                        kind: .message,
                        conversationID: conversationID,
                        messageID: messageID,
                        archiveTitle: conversation.title,
                        title: sender?.displayName ?? conversation.title,
                        subtitle: subtitle,
                        sentAt: sentAt
                    )
                )
            }
        }

        if results.count < limit, scope == .all || scope == .media || scope == .links || scope == .attachments {
            let attachmentSQL = """
            SELECT
                cmj.chat_id,
                m.ROWID,
                m.guid,
                m.text,
                m.attributedBody,
                COALESCE(m.cache_has_attachments, 0),
                m.date,
                COALESCE(m.is_from_me, 0),
                h.id,
                a.ROWID,
                a.guid,
                a.filename,
                a.transfer_name,
                a.mime_type,
                a.uti,
                a.total_bytes
            FROM message AS m
            JOIN chat_message_join AS cmj ON cmj.message_id = m.ROWID
            JOIN message_attachment_join AS maj ON maj.message_id = m.ROWID
            JOIN attachment AS a ON a.ROWID = maj.attachment_id
            LEFT JOIN handle AS h ON h.ROWID = m.handle_id
            WHERE \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
              AND (
                (a.filename LIKE ? COLLATE NOCASE)
                OR (a.transfer_name LIKE ? COLLATE NOCASE)
              )
            ORDER BY m.date DESC, m.ROWID DESC, a.ROWID DESC
            LIMIT ?
            """

            try database.readRows(sql: attachmentSQL, bind: { statement in
                try database.bind(string: likeQuery, at: 1, in: statement)
                try database.bind(string: likeQuery, at: 2, in: statement)
                try database.bind(int64: Int64(limit), at: 3, in: statement)
            }) { row in
                guard results.count < limit,
                      let chatRowID = row.int64(0),
                      let messageRowID = row.int64(1),
                      let attachmentRowID = row.int64(9),
                      let conversationID = reverseConversationIDs[chatRowID],
                      let conversation = self.conversationsByID[conversationID] else {
                    return
                }

                let messageID = self.stableUUID(for: "message:\(row.string(2) ?? String(messageRowID))")
                let sentAt = Self.appleMessageDate(from: row.int64(6))
                let attachment = self.buildAttachment(
                    attachmentRowID: attachmentRowID,
                    attachmentGUID: row.string(10),
                    rawFilename: row.string(11),
                    transferName: row.string(12),
                    mimeType: row.string(13),
                    utiString: row.string(14),
                    byteSize: row.int64(15) ?? 0,
                    sentAt: sentAt
                )
                let kind = switch attachment.kind {
                case .image, .video: SearchResultKind.media
                case .link: SearchResultKind.link
                case .file: SearchResultKind.attachment
                }

                let include = switch scope {
                case .all:
                    true
                case .media:
                    kind == .media
                case .links:
                    kind == .link
                case .attachments:
                    kind == .attachment
                case .messages, .people:
                    false
                }

                guard include else { return }

                let subtitle = self.resolvedVisibleBody(
                    text: row.string(3),
                    attributedBody: row.data(4),
                    hasAttachments: row.bool(5),
                    context: .attachmentContext
                )

                results.append(
                    ArchiveSearchResult(
                        id: "\(kind.rawValue):\(attachment.id.uuidString)",
                        kind: kind,
                        conversationID: conversationID,
                        messageID: messageID,
                        attachmentID: attachment.id,
                        archiveTitle: conversation.title,
                        title: attachment.filename,
                        subtitle: subtitle,
                        sentAt: sentAt
                    )
                )
            }
        }

        return Array(results.prefix(limit))
    }

    private func ensureBootstrapLoaded() throws {
        if conversationLocators.isEmpty || conversationsByID.isEmpty {
            _ = try loadLibrarySnapshot(progressHandler: nil)
        }
    }

    private func ensureConversationLoaded(_ conversationID: UUID) async throws -> LoadedConversationCache {
        if let cached = detailCache[conversationID] {
            return cached
        }

        _ = try await loadConversationDetail(id: conversationID)

        guard let cached = detailCache[conversationID] else {
            throw MessagesSourceError.conversationNotFound
        }
        return cached
    }

    private func loadLibrarySnapshot(progressHandler: (@Sendable (LibraryLoadProgress) -> Void)?) throws -> LibrarySnapshot {
        let database = try openDatabase()
        let capabilities = try messageTableCapabilities(database: database)
        let directory = try fetchConversationDirectory(database: database)
        let totalChats = directory.count

        progressHandler?(
            LibraryLoadProgress(
                step: 2,
                totalSteps: 4,
                title: "Reading conversation directory",
                detail: totalChats == 0
                    ? "No conversations were found in the local Messages database."
                    : "Found \(totalChats.formatted()) conversations. Resolving people and thread metadata.",
                completedUnitCount: totalChats == 0 ? 0 : nil,
                totalUnitCount: totalChats == 0 ? 0 : nil,
                unitLabel: totalChats == 0 ? "Conversations indexed" : nil
            )
        )

        guard !directory.isEmpty else {
            conversationLocators = [:]
            conversationsByID = [:]
            return LibrarySnapshot(conversations: [])
        }

        progressHandler?(
            LibraryLoadProgress(
                step: 2,
                totalSteps: 4,
                title: "Reading participants",
                detail: "Resolving handles for the conversation list."
            )
        )
        let participantsByChat = try fetchParticipantsByChat(database: database)
        var summaries: [ConversationSummary] = []
        summaries.reserveCapacity(totalChats)

        for lowerBound in stride(from: 0, to: totalChats, by: conversationBatchSize) {
            let upperBound = min(totalChats, lowerBound + conversationBatchSize)
            let batch = Array(directory[lowerBound..<upperBound])
            let latestByChat = try fetchLatestMessagesByChat(
                chatRowIDs: batch.map(\.chatRowID),
                capabilities: capabilities,
                database: database
            )

            for chat in batch {
                guard let latest = latestByChat[chat.chatRowID] else { continue }
                summaries.append(
                    ConversationSummary(
                        chatRowID: chat.chatRowID,
                        guid: chat.guid,
                        displayName: chat.displayName,
                        chatIdentifier: chat.chatIdentifier,
                        latestText: latest.text,
                        latestAttributedBody: latest.attributedBody,
                        lastActivityAt: latest.lastActivityAt,
                        latestHasAttachments: latest.hasAttachments
                    )
                )
            }

            progressHandler?(
                LibraryLoadProgress(
                    step: 3,
                    totalSteps: 4,
                    title: "Scanning conversations",
                    detail: "Indexed \(upperBound.formatted()) of \(totalChats.formatted()) conversations. Reading the latest visible message from each thread.",
                    completedUnitCount: upperBound,
                    totalUnitCount: totalChats,
                    unitLabel: "Conversations indexed"
                )
            )
        }

        summaries.sort { lhs, rhs in
            if lhs.lastActivityAt == rhs.lastActivityAt {
                return lhs.chatRowID > rhs.chatRowID
            }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }

        var locators: [UUID: ConversationLocator] = [:]
        var conversations: [Conversation] = []
        var conversationMap: [UUID: Conversation] = [:]

        for summary in summaries {
            let conversationID = stableUUID(for: "chat:\(summary.guid ?? String(summary.chatRowID))")
            let participants = resolvedConversationParticipants(handles: participantsByChat[summary.chatRowID, default: []])
            let title = conversationTitle(displayName: summary.displayName, chatIdentifier: summary.chatIdentifier, participants: participants)
            let snippet = resolvedVisibleBody(
                text: summary.latestText,
                attributedBody: summary.latestAttributedBody,
                hasAttachments: summary.latestHasAttachments,
                context: .conversationPreview
            )

            let conversation = Conversation(
                id: conversationID,
                title: title,
                participants: participants,
                snippet: snippet,
                lastActivityAt: summary.lastActivityAt,
                messageCount: nil,
                mediaCount: nil,
                isPinned: false
            )

            locators[conversationID] = ConversationLocator(chatRowID: summary.chatRowID, guid: summary.guid)
            conversationMap[conversationID] = conversation
            conversations.append(conversation)
        }

        conversationLocators = locators
        conversationsByID = conversationMap
        return LibrarySnapshot(conversations: conversations)
    }

    private func verifyPaths() throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: attachmentsURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            throw MessagesSourceError.attachmentsDirectoryMissing(path: attachmentsURL.path)
        }

        if !fileManager.fileExists(atPath: databaseURL.path) {
            do {
                _ = try openDatabase()
            } catch MessagesSourceError.fullDiskAccessRequired {
                throw MessagesSourceError.fullDiskAccessRequired(
                    databasePath: databaseURL.path,
                    attachmentsPath: attachmentsURL.path
                )
            } catch let error as MessagesSourceError {
                switch error {
                case .fullDiskAccessRequired:
                    throw error
                default:
                    throw MessagesSourceError.databaseMissing(path: databaseURL.path)
                }
            } catch {
                throw MessagesSourceError.databaseMissing(path: databaseURL.path)
            }
        }
    }

    private func openDatabase() throws -> MessagesDatabase {
        do {
            return try MessagesDatabase(url: databaseURL.sqliteReadOnlyURI)
        } catch let error as SQLiteDatabaseError {
            if case .openFailed(_, _, let message) = error,
               message.localizedCaseInsensitiveContains("authorization denied") {
                throw MessagesSourceError.fullDiskAccessRequired(
                    databasePath: databaseURL.path,
                    attachmentsPath: attachmentsURL.path
                )
            }

            throw MessagesSourceError.sqliteFailure(
                operation: "open",
                code: error.sqliteCode,
                message: error.localizedDescription
            )
        } catch {
            throw MessagesSourceError.sqliteFailure(operation: "open", code: nil, message: error.localizedDescription)
        }
    }

    private func messageTableCapabilities(database: MessagesDatabase) throws -> MessageTableCapabilities {
        if let cachedMessageTableCapabilities {
            return cachedMessageTableCapabilities
        }

        var columns = Set<String>()
        try database.readRows(sql: "PRAGMA table_info(message)") { row in
            if let name = row.string(1) {
                columns.insert(name)
            }
        }

        let capabilities = MessageTableCapabilities(columns: columns)
        cachedMessageTableCapabilities = capabilities
        return capabilities
    }

    private func fetchParticipantsByChat(database: MessagesDatabase) throws -> [Int64: [String]] {
        let sql = """
        SELECT chj.chat_id, h.id
        FROM chat_handle_join AS chj
        JOIN handle AS h ON h.ROWID = chj.handle_id
        ORDER BY chj.chat_id ASC, h.id ASC
        """

        var result: [Int64: [String]] = [:]
        try database.readRows(sql: sql) { row in
            guard let chatID = row.int64(0), let handle = row.string(1), !handle.isEmpty else { return }
            result[chatID, default: []].append(handle)
        }
        return result
    }

    private func fetchConversationDirectory(database: MessagesDatabase) throws -> [ChatDirectoryEntry] {
        let sql = """
        SELECT c.ROWID, c.guid, c.display_name, c.chat_identifier
        FROM chat AS c
        ORDER BY c.ROWID ASC
        """

        var directory: [ChatDirectoryEntry] = []
        try database.readRows(sql: sql) { row in
            guard let chatRowID = row.int64(0) else { return }
            directory.append(
                ChatDirectoryEntry(
                    chatRowID: chatRowID,
                    guid: row.string(1),
                    displayName: row.string(2),
                    chatIdentifier: row.string(3)
                )
            )
        }
        return directory
    }

    private func fetchLatestMessagesByChat(
        chatRowIDs: [Int64],
        capabilities: MessageTableCapabilities,
        database: MessagesDatabase
    ) throws -> [Int64: LatestConversationRecord] {
        guard !chatRowIDs.isEmpty else { return [:] }

        let placeholders = Array(repeating: "?", count: chatRowIDs.count).joined(separator: ", ")
        let sql = """
        WITH ranked AS (
            SELECT
                cmj.chat_id AS chat_id,
                m.text AS text,
                m.attributedBody AS attributed_body,
                m.date AS message_date,
                COALESCE(m.cache_has_attachments, 0) AS has_attachments,
                ROW_NUMBER() OVER (
                    PARTITION BY cmj.chat_id
                    ORDER BY m.date DESC, m.ROWID DESC
                ) AS rn
            FROM chat_message_join AS cmj
            JOIN message AS m ON m.ROWID = cmj.message_id
            WHERE cmj.chat_id IN (\(placeholders))
              AND \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
        )
        SELECT
            chat_id,
            text,
            attributed_body,
            message_date,
            has_attachments
        FROM ranked
        WHERE rn = 1
        """

        var latestByChat: [Int64: LatestConversationRecord] = [:]
        try database.readRows(sql: sql, bind: { statement in
            for (index, chatRowID) in chatRowIDs.enumerated() {
                try database.bind(int64: chatRowID, at: Int32(index + 1), in: statement)
            }
        }) { row in
            guard let chatRowID = row.int64(0) else { return }
            latestByChat[chatRowID] = LatestConversationRecord(
                text: row.string(1),
                attributedBody: row.data(2),
                lastActivityAt: Self.appleMessageDate(from: row.int64(3)),
                hasAttachments: row.bool(4)
            )
        }

        return latestByChat
    }

    private func fetchMessageIndex(
        chatRowID: Int64,
        capabilities: MessageTableCapabilities,
        database: MessagesDatabase
    ) throws -> [SourceMessageEntry] {
        let sql = """
        SELECT m.ROWID, m.guid, m.date
        FROM chat_message_join AS cmj
        JOIN message AS m ON m.ROWID = cmj.message_id
        WHERE cmj.chat_id = ?
          AND \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
        ORDER BY m.date ASC, m.ROWID ASC
        """

        var entries: [SourceMessageEntry] = []
        try database.readRows(sql: sql, bind: { statement in
            try database.bind(int64: chatRowID, at: 1, in: statement)
        }) { row in
            guard let rowID = row.int64(0) else { return }
            let guid = row.string(1)
            entries.append(
                SourceMessageEntry(
                    id: stableUUID(for: "message:\(guid ?? String(rowID))"),
                    guid: guid,
                    rowID: rowID,
                    sentAt: Self.appleMessageDate(from: row.int64(2))
                )
            )
        }
        return entries
    }

    private func fetchAttachmentItems(
        chatRowID: Int64,
        conversationID: UUID,
        messageIDsByRowID: [Int64: UUID],
        capabilities: MessageTableCapabilities,
        database: MessagesDatabase
    ) throws -> [AttachmentItem] {
        let sql = """
        SELECT
            m.ROWID,
            m.guid,
            m.text,
            m.attributedBody,
            COALESCE(m.cache_has_attachments, 0),
            m.date,
            COALESCE(m.is_from_me, 0),
            h.id,
            a.ROWID,
            a.guid,
            a.filename,
            a.transfer_name,
            a.mime_type,
            a.uti,
            a.total_bytes
        FROM chat_message_join AS cmj
        JOIN message AS m ON m.ROWID = cmj.message_id
        JOIN message_attachment_join AS maj ON maj.message_id = m.ROWID
        JOIN attachment AS a ON a.ROWID = maj.attachment_id
        LEFT JOIN handle AS h ON h.ROWID = m.handle_id
        WHERE cmj.chat_id = ?
          AND \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
        ORDER BY m.date ASC, m.ROWID ASC, a.ROWID ASC
        """

        var items: [AttachmentItem] = []
        try database.readRows(sql: sql, bind: { statement in
            try database.bind(int64: chatRowID, at: 1, in: statement)
        }) { row in
            guard let messageRowID = row.int64(0),
                  let attachmentRowID = row.int64(8),
                  let messageID = messageIDsByRowID[messageRowID] else {
                return
            }

            let sentAt = Self.appleMessageDate(from: row.int64(5))
            let body = resolvedVisibleBody(
                text: row.string(2),
                attributedBody: row.data(3),
                hasAttachments: true,
                context: .attachmentContext
            )
            let sender = participant(handle: row.string(7), isFromMe: row.bool(6))
            let attachment = buildAttachment(
                attachmentRowID: attachmentRowID,
                attachmentGUID: row.string(9),
                rawFilename: row.string(10),
                transferName: row.string(11),
                mimeType: row.string(12),
                utiString: row.string(13),
                byteSize: row.int64(14) ?? 0,
                sentAt: sentAt
            )

            items.append(
                AttachmentItem(
                    id: stableUUID(for: "attachment-item:\(attachment.id.uuidString):\(messageID.uuidString)"),
                    conversationID: conversationID,
                    messageID: messageID,
                    attachment: attachment,
                    sender: sender,
                    sentAt: sentAt,
                    contextSnippet: body
                )
            )
        }
        return items
    }

    private func fetchMessages(
        rowIDs: [Int64],
        conversationID: UUID,
        capabilities: MessageTableCapabilities,
        messageIDsByRowID: [Int64: UUID],
        database: MessagesDatabase
    ) throws -> [Message] {
        let placeholders = Array(repeating: "?", count: rowIDs.count).joined(separator: ", ")
        let sql = """
        SELECT
            m.ROWID,
            m.guid,
            m.text,
            m.attributedBody,
            COALESCE(m.cache_has_attachments, 0),
            m.date,
            COALESCE(m.is_from_me, 0),
            h.id,
            \(messageColumnExpression(column: "thread_originator_guid", capabilities: capabilities)),
            \(messageColumnExpression(column: "thread_originator_part", capabilities: capabilities, defaultExpression: "0")),
            a.ROWID,
            a.guid,
            a.filename,
            a.transfer_name,
            a.mime_type,
            a.uti,
            a.total_bytes
        FROM message AS m
        LEFT JOIN handle AS h ON h.ROWID = m.handle_id
        LEFT JOIN message_attachment_join AS maj ON maj.message_id = m.ROWID
        LEFT JOIN attachment AS a ON a.ROWID = maj.attachment_id
        WHERE m.ROWID IN (\(placeholders))
        ORDER BY m.date ASC, m.ROWID ASC, a.ROWID ASC
        """

        var accumulators: [Int64: MessageAccumulator] = [:]
        var orderedRowIDs: [Int64] = []

        try database.readRows(sql: sql, bind: { statement in
            for (index, rowID) in rowIDs.enumerated() {
                try database.bind(int64: rowID, at: Int32(index + 1), in: statement)
            }
        }) { row in
            guard let messageRowID = row.int64(0),
                  let messageID = messageIDsByRowID[messageRowID] else {
                return
            }

            if accumulators[messageRowID] == nil {
                orderedRowIDs.append(messageRowID)
                let sentAt = Self.appleMessageDate(from: row.int64(5))
                let isFromMe = row.bool(6)
                let sender = participant(handle: row.string(7), isFromMe: isFromMe)
                let direction: MessageDirection = isFromMe ? .outgoing : (row.string(7) == nil ? .system : .incoming)

                accumulators[messageRowID] = MessageAccumulator(
                    id: messageID,
                    guid: row.string(1),
                    conversationID: conversationID,
                    sender: sender,
                    body: resolvedVisibleBody(
                        text: row.string(2),
                        attributedBody: row.data(3),
                        hasAttachments: row.bool(4),
                        context: .transcript
                    ),
                    sentAt: sentAt,
                    direction: direction,
                    attachments: [],
                    replyReferenceGUID: row.string(8)
                )
            }

            guard let attachmentRowID = row.int64(10) else { return }
            let attachment = buildAttachment(
                attachmentRowID: attachmentRowID,
                attachmentGUID: row.string(11),
                rawFilename: row.string(12),
                transferName: row.string(13),
                mimeType: row.string(14),
                utiString: row.string(15),
                byteSize: row.int64(16) ?? 0,
                sentAt: Self.appleMessageDate(from: row.int64(5))
            )
            accumulators[messageRowID]?.attachments.append(attachment)
        }

        let replyTargets = try fetchReplyTargets(
            referencedGUIDs: Set(accumulators.values.compactMap(\.replyReferenceGUID)),
            capabilities: capabilities,
            database: database
        )

        let reactionsByMessageGUID = try fetchReactions(
            targetMessageGUIDs: Set(accumulators.values.compactMap(\.guid)),
            capabilities: capabilities,
            database: database
        )

        return orderedRowIDs.compactMap { rowID in
            guard let accumulator = accumulators[rowID] else { return nil }
            return Message(
                id: accumulator.id,
                guid: accumulator.guid,
                conversationID: accumulator.conversationID,
                sender: accumulator.sender,
                body: accumulator.body,
                sentAt: accumulator.sentAt,
                direction: accumulator.direction,
                attachments: accumulator.attachments,
                replyContext: accumulator.replyReferenceGUID.flatMap { replyTargets[$0] },
                reactions: accumulator.guid.flatMap { reactionsByMessageGUID[$0] } ?? []
            )
        }
    }

    private func fetchReplyTargets(
        referencedGUIDs: Set<String>,
        capabilities: MessageTableCapabilities,
        database: MessagesDatabase
    ) throws -> [String: MessageReplyContext] {
        guard !referencedGUIDs.isEmpty else { return [:] }

        let sortedGUIDs = referencedGUIDs.sorted()
        let placeholders = Array(repeating: "?", count: sortedGUIDs.count).joined(separator: ", ")
        let sql = """
        SELECT
            m.guid,
            m.text,
            m.attributedBody,
            COALESCE(m.cache_has_attachments, 0),
            COALESCE(m.is_from_me, 0),
            h.id
        FROM message AS m
        LEFT JOIN handle AS h ON h.ROWID = m.handle_id
        WHERE m.guid IN (\(placeholders))
          AND \(visibleMessagePredicate(alias: "m", capabilities: capabilities))
        """

        var contexts: [String: MessageReplyContext] = [:]
        try database.readRows(sql: sql, bind: { statement in
            for (index, guid) in sortedGUIDs.enumerated() {
                try database.bind(string: guid, at: Int32(index + 1), in: statement)
            }
        }) { row in
            guard let guid = row.string(0) else { return }
            let sender = participant(handle: row.string(5), isFromMe: row.bool(4))
            contexts[guid] = MessageReplyContext(
                referencedMessageGUID: guid,
                quotedText: resolvedVisibleBody(
                    text: row.string(1),
                    attributedBody: row.data(2),
                    hasAttachments: row.bool(3),
                    context: .quotedReply
                ),
                quotedSender: sender?.displayName
            )
        }
        return contexts
    }

    private func fetchReactions(
        targetMessageGUIDs: Set<String>,
        capabilities: MessageTableCapabilities,
        database: MessagesDatabase
    ) throws -> [String: [MessageReaction]] {
        guard !targetMessageGUIDs.isEmpty,
              capabilities.columns.contains("associated_message_guid"),
              capabilities.columns.contains("associated_message_type") else {
            return [:]
        }

        let sql = """
        SELECT
            m.guid,
            COALESCE(m.is_from_me, 0),
            h.id,
            m.associated_message_guid,
            COALESCE(m.associated_message_type, 0),
            \(messageColumnExpression(column: "associated_message_emoji", capabilities: capabilities))
        FROM message AS m
        LEFT JOIN handle AS h ON h.ROWID = m.handle_id
        WHERE m.associated_message_guid IS NOT NULL
          AND COALESCE(m.associated_message_type, 0) != 0
        ORDER BY m.date ASC, m.ROWID ASC
        """

        var activeReactions: [String: (messageGUID: String, reaction: MessageReaction)] = [:]
        try database.readRows(sql: sql) { row in
            guard let rawTarget = row.string(3),
                  let target = parseAssociatedMessageGUID(rawTarget),
                  targetMessageGUIDs.contains(target.guid),
                  let kind = reactionKind(
                    type: row.int(4) ?? 0,
                    emoji: row.string(5)
                  ) else {
                return
            }

            let sender = participant(handle: row.string(2), isFromMe: row.bool(1))
            let senderHandle = sender?.handle ?? (row.bool(1) ? selfParticipant.handle : "unknown")
            let key = "\(target.guid)|\(senderHandle)|\(reactionStorageKey(kind))"

            if isReactionRemoval(type: row.int(4) ?? 0) {
                activeReactions.removeValue(forKey: key)
            } else {
                activeReactions[key] = (
                    messageGUID: target.guid,
                    reaction: MessageReaction(
                        id: stableUUID(for: "reaction:\(target.guid):\(senderHandle):\(row.int(4) ?? 0):\(row.string(5) ?? "")"),
                        sender: sender,
                        kind: kind
                    )
                )
            }
        }

        var grouped: [String: [MessageReaction]] = [:]
        for storedReaction in activeReactions.values {
            grouped[storedReaction.messageGUID, default: []].append(storedReaction.reaction)
        }
        return grouped
    }

    private func resolvedConversationParticipants(handles: [String]) -> [Participant] {
        let uniqueHandles = Array(NSOrderedSet(array: handles)) as? [String] ?? handles
        var participants = [selfParticipant]
        participants.append(contentsOf: uniqueHandles.compactMap { participant(handle: $0, isFromMe: false) })
        return participants
    }

    private func conversationTitle(displayName: String?, chatIdentifier: String?, participants: [Participant]) -> String {
        if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let otherParticipants = participants.filter { $0.handle != selfParticipant.handle }
        if !otherParticipants.isEmpty {
            return otherParticipants.map(\.displayName).joined(separator: ", ")
        }

        if let chatIdentifier, !chatIdentifier.isEmpty {
            return chatIdentifier
        }

        return "Conversation"
    }

    private func buildAttachment(
        attachmentRowID: Int64,
        attachmentGUID: String?,
        rawFilename: String?,
        transferName: String?,
        mimeType: String?,
        utiString: String?,
        byteSize: Int64,
        sentAt: Date
    ) -> Attachment {
        let resolvedURL = resolveAttachmentURL(from: rawFilename)
        let displayName = transferName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = if let displayName, !displayName.isEmpty {
            displayName
        } else if let resolvedURL {
            resolvedURL.lastPathComponent
        } else if let rawFilename, !rawFilename.isEmpty {
            URL(filePath: rawFilename.replacingOccurrences(of: "~", with: NSHomeDirectory())).lastPathComponent
        } else {
            "Attachment \(attachmentRowID)"
        }

        let uti = (utiString?.isEmpty == false ? utiString : mimeType) ?? "public.data"
        return Attachment(
            id: stableUUID(for: "attachment:\(attachmentGUID ?? String(attachmentRowID))"),
            kind: attachmentKind(filename: filename, utiString: utiString, mimeType: mimeType),
            filename: filename,
            uti: uti,
            byteSize: max(0, Int(byteSize)),
            sentAt: sentAt,
            fileURL: resolvedURL,
            isAvailableLocally: resolvedURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        )
    }

    private func resolveAttachmentURL(from rawFilename: String?) -> URL? {
        guard let rawFilename, !rawFilename.isEmpty else { return nil }

        if rawFilename.hasPrefix("~/") {
            return URL(filePath: rawFilename.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        }

        if rawFilename.hasPrefix("/") {
            return URL(filePath: rawFilename)
        }

        if rawFilename.hasPrefix("Library/") {
            return FileManager.default.homeDirectoryForCurrentUser.appending(path: rawFilename)
        }

        if rawFilename.hasPrefix("Attachments/") {
            return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Messages").appending(path: rawFilename)
        }

        return attachmentsURL.appending(path: rawFilename)
    }

    private func attachmentKind(filename: String, utiString: String?, mimeType: String?) -> AttachmentKind {
        if let utiString, let type = UTType(utiString) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .url) || type.conforms(to: .urlBookmarkData) { return .link }
        }

        if let mimeType {
            if mimeType.hasPrefix("image/") { return .image }
            if mimeType.hasPrefix("video/") { return .video }
            if mimeType == "text/uri-list" { return .link }
        }

        if let fileExtension = filename.split(separator: ".").last.map(String.init),
           let type = UTType(filenameExtension: fileExtension) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .url) { return .link }
        }

        if filename.localizedCaseInsensitiveContains("link") {
            return .link
        }

        return .file
    }

    private func messageColumnExpression(
        column: String,
        capabilities: MessageTableCapabilities,
        defaultExpression: String = "NULL"
    ) -> String {
        if capabilities.columns.contains(column) {
            return "m.\(column)"
        }
        return "\(defaultExpression) AS \(column)"
    }

    private func visibleMessagePredicate(alias: String, capabilities: MessageTableCapabilities) -> String {
        guard capabilities.columns.contains("associated_message_type") else {
            return "1 = 1"
        }
        return "COALESCE(\(alias).associated_message_type, 0) = 0"
    }

    private func parseAssociatedMessageGUID(_ rawValue: String?) -> AssociatedMessageReference? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        let components = rawValue.split(separator: "/")
        guard let guid = components.last.map(String.init), !guid.isEmpty else { return nil }

        let partIndex: Int?
        if let prefix = components.first,
           let numericPart = prefix.split(separator: ":").last.flatMap({ Int($0) }) {
            partIndex = numericPart
        } else {
            partIndex = nil
        }

        return AssociatedMessageReference(guid: guid, partIndex: partIndex)
    }

    private func reactionKind(type: Int, emoji: String?) -> MessageReactionKind? {
        let normalizedType = type >= 3000 ? type - 1000 : type

        switch normalizedType {
        case 2000: return .loved
        case 2001: return .liked
        case 2002: return .disliked
        case 2003: return .laughed
        case 2004: return .emphasized
        case 2005: return .questioned
        case 2006:
            if let emoji, !emoji.isEmpty {
                return .emoji(emoji)
            }
            return .sticker
        default:
            return nil
        }
    }

    private func isReactionRemoval(type: Int) -> Bool {
        type >= 3000 && type < 4000
    }

    private func reactionStorageKey(_ kind: MessageReactionKind) -> String {
        switch kind {
        case .loved: return "loved"
        case .liked: return "liked"
        case .disliked: return "disliked"
        case .laughed: return "laughed"
        case .emphasized: return "emphasized"
        case .questioned: return "questioned"
        case .emoji(let emoji): return "emoji:\(emoji)"
        case .sticker: return "sticker"
        }
    }

    private func participant(handle: String?, isFromMe: Bool) -> Participant? {
        if isFromMe {
            return selfParticipant
        }

        guard let handle else { return nil }
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHandle.isEmpty else { return nil }
        return Participant(
            id: stableUUID(for: "participant:\(trimmedHandle)"),
            displayName: displayName(for: trimmedHandle),
            handle: trimmedHandle,
            accentColorName: accentColorName(for: trimmedHandle)
        )
    }

    private var selfParticipant: Participant {
        Participant(id: stableUUID(for: "participant:self"), displayName: "You", handle: "me", accentColorName: "blue")
    }

    private func displayName(for handle: String) -> String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            return trimmed
        }

        let digits = trimmed.filter(\.isNumber)
        guard digits.count >= 10 else { return trimmed }

        let suffix = digits.suffix(10)
        return "\(suffix.prefix(3))-\(suffix.dropFirst(3).prefix(3))-\(suffix.suffix(4))"
    }

    private func accentColorName(for handle: String) -> String {
        let colors = ["blue", "teal", "green", "orange", "pink", "indigo", "mint"]
        let digest = Array(SHA256.hash(data: Data(handle.utf8)))
        let firstByte = Int(digest[0])
        return colors[firstByte % colors.count]
    }

    private func resolvedVisibleBody(
        text: String?,
        attributedBody: Data?,
        hasAttachments: Bool,
        context: MessageBodyContext
    ) -> String {
        if let text = cleanVisibleBody(text), !text.isEmpty {
            return text
        }

        if let attributedBody, let decoded = decodedAttributedBodyText(from: attributedBody), !decoded.isEmpty {
            return decoded
        }

        if hasAttachments {
            switch context {
            case .transcript:
                return ""
            case .conversationPreview:
                return "Shared attachment"
            case .attachmentContext:
                return "Attachment"
            case .quotedReply:
                return "Attachment"
            }
        }

        if attributedBody != nil {
            switch context {
            case .transcript:
                return "Unsupported message content"
            case .conversationPreview:
                return "Unsupported content"
            case .attachmentContext:
                return "Unsupported content"
            case .quotedReply:
                return "Unsupported message"
            }
        }

        switch context {
        case .transcript:
            return ""
        case .conversationPreview:
            return "No visible message body"
        case .attachmentContext:
            return "No visible context"
        case .quotedReply:
            return "Quoted message unavailable"
        }
    }

    private func decodedAttributedBodyText(from data: Data) -> String? {
        if let attributedString = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            let string = cleanVisibleBody(attributedString.string)
            if let string, !string.isEmpty {
                return string
            }
        }

        if let typedstream = decodedTypedstreamText(from: data), !typedstream.isEmpty {
            return typedstream
        }

        let extracted = scanReadableStrings(in: data)
        guard !extracted.isEmpty else { return nil }
        return extracted
    }

    private func decodedTypedstreamText(from data: Data) -> String? {
        let bytes = [UInt8](data)
        guard let streamtypedRange = data.range(of: Data("streamtyped".utf8)),
              let nsStringRange = data.range(of: Data("NSString".utf8)),
              streamtypedRange.lowerBound < nsStringRange.lowerBound else {
            return nil
        }

        var candidates: [String] = []
        var searchIndex = nsStringRange.upperBound

        while searchIndex < bytes.count {
            if let payload = typedstreamNSStringPayload(in: bytes, searchIndex: searchIndex) {
                if let decoded = decodeTypedstreamPayload(payload, in: bytes),
                   let cleaned = cleanVisibleBody(decoded),
                   isLikelyUserVisibleExtractedText(cleaned) {
                    candidates.append(cleaned)
                }
                searchIndex = payload.endIndex
                continue
            }

            let remainingData = Data(bytes[searchIndex...])
            guard let nextNSString = remainingData.range(of: Data("NSString".utf8)) else {
                break
            }
            searchIndex += nextNSString.upperBound
        }

        let unique = Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
        let joined = unique.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    private func typedstreamNSStringPayload(in bytes: [UInt8], searchIndex: Int) -> Range<Int>? {
        let maxPrefixScan = min(searchIndex + 8, bytes.count - 2)
        guard searchIndex < maxPrefixScan else { return nil }

        for index in searchIndex..<maxPrefixScan where bytes[index] == 0x2B {
            guard index + 1 < bytes.count else { continue }

            let prefix = bytes[index + 1]
            let payloadStart: Int
            let byteCount: Int

            if prefix & 0x80 == 0 {
                byteCount = Int(prefix)
                payloadStart = index + 2
            } else {
                let lengthByteCount = Int(prefix & 0x7F)
                let lengthStart = index + 2
                let lengthEnd = lengthStart + lengthByteCount

                guard lengthByteCount > 0, lengthEnd <= bytes.count else {
                    continue
                }

                byteCount = bytes[lengthStart..<lengthEnd]
                    .enumerated()
                    .reduce(0) { partial, entry in
                        partial | (Int(entry.element) << (entry.offset * 8))
                    }
                payloadStart = lengthEnd
            }

            let payloadEnd = payloadStart + byteCount

            guard byteCount > 0,
                  payloadEnd <= bytes.count else {
                continue
            }

            return payloadStart..<payloadEnd
        }

        return nil
    }

    private func decodeTypedstreamPayload(_ payload: Range<Int>, in bytes: [UInt8]) -> String? {
        let payloadBytes = Data(bytes[payload])

        if let utf8 = longestValidUTF8Prefix(in: payloadBytes), utf8.contains("\u{FFFD}") == false {
            return utf8
        }

        if let macOSRoman = String(data: payloadBytes, encoding: .macOSRoman) {
            return macOSRoman
        }

        if let windows1252 = String(data: payloadBytes, encoding: .windowsCP1252) {
            return windows1252
        }

        return String(data: payloadBytes, encoding: .utf8)
    }

    private func longestValidUTF8Prefix(in data: Data) -> String? {
        for end in stride(from: data.count, through: 1, by: -1) {
            let candidate = data.prefix(end)
            if let decoded = String(data: candidate, encoding: .utf8) {
                return decoded
            }
        }

        return nil
    }

    private func cleanVisibleBody(_ body: String?) -> String? {
        guard let body else { return nil }
        let cleaned = normalizedVisibleBody(body)
            .replacingOccurrences(of: "\\p{C}+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\u{FFFC}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "^\\+[0-9A-Za-z](?=\\p{L})", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty,
              !looksLikeArchivedMetadata(cleaned),
              !looksLikeAttachmentTokenStream(cleaned) else {
            return nil
        }

        return cleaned
    }

    private func normalizedVisibleBody(_ body: String) -> String {
        let repaired = repairMojibakeIfNeeded(in: body)
        return repaired.replacingOccurrences(of: "\u{00AC}", with: " ")
    }

    private func repairMojibakeIfNeeded(in value: String) -> String {
        guard containsMojibakeMarker(value) else { return value }

        let pieces = value.components(separatedBy: .whitespacesAndNewlines)
        guard !pieces.isEmpty else { return value }

        return pieces
            .map(repairMojibakeToken)
            .joined(separator: " ")
    }

    private func repairMojibakeToken(_ token: String) -> String {
        guard containsMojibakeMarker(token) else { return token }

        let candidates = [token, repairedToken(token, sourceEncoding: .macOSRoman), repairedToken(token, sourceEncoding: .windowsCP1252)]
            .compactMap { $0 }

        return candidates.min { lhs, rhs in
            mojibakeScore(lhs) < mojibakeScore(rhs)
        } ?? token
    }

    private func repairedToken(_ token: String, sourceEncoding: String.Encoding) -> String? {
        guard let data = token.data(using: sourceEncoding),
              let repaired = String(data: data, encoding: .utf8) else {
            return nil
        }
        return repaired
    }

    private func containsMojibakeMarker(_ value: String) -> Bool {
        let markers = ["√", "Ôø", "", "â€", "Ã", "ðŸ", "Â", "\u{00AC}"]
        return markers.contains { value.contains($0) }
    }

    private func mojibakeScore(_ value: String) -> Int {
        let suspiciousCharacters = ["√", "Ô", "ø", "", "â", "Ã", "ð", "Â", "\u{FFFD}", "\u{00AC}"]
        let suspiciousCount = suspiciousCharacters.reduce(0) { partial, marker in
            partial + value.components(separatedBy: marker).count - 1
        }
        let replacementPenalty = value.contains("\u{FFFC}") ? 1 : 0
        return suspiciousCount + replacementPenalty
    }

    private func scanReadableStrings(in data: Data) -> String {
        let bytes = [UInt8](data)
        var chunks: [String] = []
        var current: [UInt8] = []

        func flush() {
            guard current.count >= 4, let string = String(bytes: current, encoding: .utf8) else {
                current.removeAll(keepingCapacity: true)
                return
            }

            if let cleaned = cleanVisibleBody(string), isLikelyUserVisibleExtractedText(cleaned) {
                chunks.append(cleaned)
            }
            current.removeAll(keepingCapacity: true)
        }

        for byte in bytes {
            switch byte {
            case 32...126, 10, 13, 9:
                current.append(byte)
            default:
                flush()
            }
        }
        flush()

        let joined = Array(NSOrderedSet(array: chunks)) as? [String] ?? chunks
        return joined
            .sorted { $0.count > $1.count }
            .prefix(3)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeArchivedMetadata(_ value: String) -> Bool {
        let metadataMarkers = [
            "__kIM",
            "NSAttributedString",
            "NSMutableAttributedString",
            "NSObject",
            "AttributeName",
            "GUIDAttributeName",
            "WritingDirection",
            "NSNumber",
            "NSDictionary",
            "NSMutable",
            "NSMutableString",
            "NSFont",
            "NSColor",
            "IMFileTransfer",
            "NSString",
            "NSKeyedArchiver",
            "typedstream",
            "streamtyped",
            "bplist00",
            "$version",
            "$objects",
            "DDScannerResult",
            "RelativeDay",
            "DayOfWeek",
            "at_0_"
        ]

        if metadataMarkers.contains(where: { value.localizedCaseInsensitiveContains($0) }) {
            return true
        }

        let underscoreCount = value.filter { $0 == "_" }.count
        if underscoreCount >= 4 && value.contains("__") {
            return true
        }

        let slashSegments = value.split(separator: "/")
        if slashSegments.count > 6 && value.contains("Attachments/") {
            return true
        }

        return false
    }

    private func looksLikeAttachmentTokenStream(_ value: String) -> Bool {
        let pattern = #"\$?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, range: range)
        guard !matches.isEmpty else { return false }

        if matches.count > 1 {
            return true
        }

        let stripped = regex.stringByReplacingMatches(in: value, range: range, withTemplate: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty
    }

    private func isLikelyUserVisibleExtractedText(_ value: String) -> Bool {
        guard !looksLikeArchivedMetadata(value) else {
            return false
        }

        let letterCount = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letterCount >= 3 {
            return true
        }

        let words = value.split(whereSeparator: \.isWhitespace)
        if words.count >= 2 {
            return true
        }

        return value.count >= 3 && !value.contains("=")
    }

    nonisolated static func appleMessageDate(from rawValue: Int64?) -> Date {
        guard let rawValue else { return .distantPast }

        let absolute = abs(Double(rawValue))
        let seconds: Double

        switch absolute {
        case 10_000_000_000_000_000...:
            seconds = Double(rawValue) / 1_000_000_000
        case 10_000_000_000_000...:
            seconds = Double(rawValue) / 1_000_000
        case 10_000_000_000...:
            seconds = Double(rawValue) / 1_000
        default:
            seconds = Double(rawValue)
        }

        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    private func stableUUID(for value: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        let bytes = Array(digest)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

private struct ConversationLocator {
    let chatRowID: Int64
    let guid: String?
}

private struct ChatDirectoryEntry {
    let chatRowID: Int64
    let guid: String?
    let displayName: String?
    let chatIdentifier: String?
}

private struct LatestConversationRecord {
    let text: String?
    let attributedBody: Data?
    let lastActivityAt: Date
    let hasAttachments: Bool
}

private struct ConversationSummary {
    let chatRowID: Int64
    let guid: String?
    let displayName: String?
    let chatIdentifier: String?
    let latestText: String?
    let latestAttributedBody: Data?
    let lastActivityAt: Date
    let latestHasAttachments: Bool
}

private struct SourceMessageEntry {
    let id: UUID
    let guid: String?
    let rowID: Int64
    let sentAt: Date
}

private struct LoadedConversationCache {
    let chatRowID: Int64
    let detail: ConversationDetail
    let messageEntries: [SourceMessageEntry]
    let capabilities: MessageTableCapabilities

    nonisolated var messageIDsByRowID: [Int64: UUID] {
        Dictionary(uniqueKeysWithValues: messageEntries.map { ($0.rowID, $0.id) })
    }
}

private struct MessageAccumulator {
    let id: UUID
    let guid: String?
    let conversationID: UUID
    let sender: Participant?
    let body: String
    let sentAt: Date
    let direction: MessageDirection
    var attachments: [Attachment]
    let replyReferenceGUID: String?
}

private struct MessageTableCapabilities: Sendable {
    let columns: Set<String>
}

private struct AssociatedMessageReference: Sendable {
    let guid: String
    let partIndex: Int?
}

private enum MessageBodyContext {
    case transcript
    case conversationPreview
    case attachmentContext
    case quotedReply
}
