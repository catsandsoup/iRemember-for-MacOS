import AppKit
import Foundation
import SQLite3
import Testing
@testable import iRemember

struct iRememberTests {

    @Test func sampleSourceBootstrapsAndLoadsTranscriptSlice() async throws {
        let source = SampleMessagesSource()
        let snapshot = try await source.bootstrapLibrary()

        #expect(snapshot.conversations.isEmpty == false)
        #expect(snapshot.conversations.first?.messageCount ?? 0 > 0)

        let conversationID = try #require(snapshot.conversations.first?.id)
        let detail = try await source.loadConversationDetail(id: conversationID)
        let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<20)

        #expect(detail.messageIndex.isEmpty == false)
        #expect(detail.mediaAssets.isEmpty == false)
        #expect(slice.messages.count == 20)
        #expect(slice.messages == slice.messages.sorted { $0.sentAt < $1.sentAt })
    }

    @Test @MainActor func appModelSupportsCollapsibleChromeAndClampsTimelineHeight() {
        let appModel = AppModel(source: SampleMessagesSource())

        #expect(appModel.timelineHeight == 80)
        #expect(appModel.isSidebarVisible)
        #expect(appModel.isInspectorVisible)
        #expect(appModel.isTimelineCollapsed == false)

        appModel.setTimelineHeight(40)
        #expect(appModel.timelineHeight == 68)

        appModel.setTimelineHeight(400)
        #expect(appModel.timelineHeight == 220)

        appModel.toggleSidebarVisibility()
        appModel.toggleInspectorVisibility()
        appModel.toggleTimelineVisibility()

        #expect(appModel.isSidebarVisible == false)
        #expect(appModel.isInspectorVisible == false)
        #expect(appModel.isTimelineCollapsed)
    }

    @Test func appleMessagesTimestampConversionHandlesSecondsAndNanoseconds() {
        let expected = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let seconds = SQLiteMessagesSource.appleMessageDate(from: 100)
        let nanoseconds = SQLiteMessagesSource.appleMessageDate(from: 800_000_000_000_000_000)

        #expect(abs(seconds.timeIntervalSince(Date(timeIntervalSinceReferenceDate: 100))) < 0.001)
        #expect(abs(nanoseconds.timeIntervalSince(expected)) < 0.001)
    }

    @Test func sqliteSourceLoadsConversationMetadataAndAttributedBodyFallback() async throws {
        let fixture = try TemporaryMessagesFixture()
        defer { fixture.cleanup() }

        let source = SQLiteMessagesSource(databaseURL: fixture.databaseURL, attachmentsURL: fixture.attachmentsURL)
        let snapshot = try await source.bootstrapLibrary()
        let conversation = try #require(snapshot.conversations.first)
        let detail = try await source.loadConversationDetail(id: conversation.id)
        let slice = try await source.loadMessages(conversationID: conversation.id, range: 0..<detail.messageIndex.count)

        #expect(snapshot.conversations.count == 1)
        #expect(conversation.title == "Casey")
        #expect(conversation.messageCount == nil)
        #expect(conversation.mediaCount == nil)
        #expect(detail.conversation.messageCount == 2)
        #expect(detail.conversation.mediaCount == 1)
        #expect(detail.messageIndex.count == 2)
        #expect(detail.mediaAssets.count == 1)
        #expect(slice.messages.count == 2)
        #expect(slice.messages.last?.body == "Archived only body")
    }

    @Test func sqliteSourceMarksMissingAttachmentFilesAsUnavailable() async throws {
        let fixture = try TemporaryMessagesFixture()
        defer { fixture.cleanup() }

        let source = SQLiteMessagesSource(databaseURL: fixture.databaseURL, attachmentsURL: fixture.attachmentsURL)
        let snapshot = try await source.bootstrapLibrary()
        let conversationID = try #require(snapshot.conversations.first?.id)
        let detail = try await source.loadConversationDetail(id: conversationID)
        let attachment = try #require(detail.mediaAssets.first?.attachment)

        #expect(attachment.isAvailableLocally == false)
        #expect(attachment.fileURL?.path.contains("missing-photo.jpg") == true)
    }

    @Test func sqliteSourceResolvesInlineRepliesAndAggregatesTapbacks() async throws {
        let fixture = try TemporaryMessagesFixture(includeRichMessageMetadata: true)
        defer { fixture.cleanup() }

        let source = SQLiteMessagesSource(databaseURL: fixture.databaseURL, attachmentsURL: fixture.attachmentsURL)
        let snapshot = try await source.bootstrapLibrary()
        let conversationID = try #require(snapshot.conversations.first?.id)
        let detail = try await source.loadConversationDetail(id: conversationID)
        let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<detail.messageIndex.count)

        #expect(detail.messageIndex.count == 3)
        #expect(slice.messages.count == 3)

        let archivedMessage = try #require(slice.messages.first(where: { $0.guid == "message-guid-2" }))
        #expect(archivedMessage.reactions.count == 1)
        #expect(archivedMessage.reactions.first?.kind == .liked)

        let replyMessage = try #require(slice.messages.first(where: { $0.guid == "message-guid-3" }))
        #expect(replyMessage.replyContext?.referencedMessageGUID == "message-guid-1")
        #expect(replyMessage.replyContext?.quotedText == "Visible text body")
        #expect(replyMessage.replyContext?.quotedSender == "casey@example.com")
    }

    @Test func sqliteSourceFailsWhenAttachmentsDirectoryIsMissing() async {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appending(path: "chat.db")
        let source = SQLiteMessagesSource(databaseURL: databaseURL, attachmentsURL: root.appending(path: "Attachments"))

        do {
            _ = try await source.bootstrapLibrary()
            Issue.record("Expected attachments directory failure.")
        } catch let error as MessagesSourceError {
            if case .attachmentsDirectoryMissing = error {
                #expect(true)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        try? FileManager.default.removeItem(at: root)
    }

    @Test func sqliteSourceFailsWhenDatabaseIsMissing() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let attachmentsURL = root.appending(path: "Attachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        let source = SQLiteMessagesSource(databaseURL: root.appending(path: "chat.db"), attachmentsURL: attachmentsURL)

        do {
            _ = try await source.bootstrapLibrary()
            Issue.record("Expected database missing failure.")
        } catch let error as MessagesSourceError {
            if case .databaseMissing = error {
                #expect(true)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        try? FileManager.default.removeItem(at: root)
    }
}

private struct TemporaryMessagesFixture {
    let rootURL: URL
    let databaseURL: URL
    let attachmentsURL: URL
    let includeRichMessageMetadata: Bool

    init(includeRichMessageMetadata: Bool = false) throws {
        rootURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        databaseURL = rootURL.appending(path: "chat.db")
        attachmentsURL = rootURL.appending(path: "Attachments", directoryHint: .isDirectory)
        self.includeRichMessageMetadata = includeRichMessageMetadata

        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        try buildDatabase()
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private func buildDatabase() throws {
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK, let db else {
            throw FixtureError.databaseCreationFailed
        }

        defer {
            sqlite3_close(db)
        }

        try exec(
            """
            CREATE TABLE chat (
                ROWID INTEGER PRIMARY KEY,
                guid TEXT,
                display_name TEXT,
                chat_identifier TEXT
            );
            CREATE TABLE handle (
                ROWID INTEGER PRIMARY KEY,
                id TEXT
            );
            CREATE TABLE chat_handle_join (
                chat_id INTEGER,
                handle_id INTEGER
            );
            CREATE TABLE message (
                ROWID INTEGER PRIMARY KEY,
                guid TEXT,
                text TEXT,
                attributedBody BLOB,
                date INTEGER,
                cache_has_attachments INTEGER,
                is_from_me INTEGER,
                handle_id INTEGER,
                associated_message_guid TEXT,
                associated_message_type INTEGER,
                associated_message_emoji TEXT,
                thread_originator_guid TEXT,
                thread_originator_part TEXT
            );
            CREATE TABLE chat_message_join (
                chat_id INTEGER,
                message_id INTEGER
            );
            CREATE TABLE attachment (
                ROWID INTEGER PRIMARY KEY,
                guid TEXT,
                filename TEXT,
                transfer_name TEXT,
                mime_type TEXT,
                uti TEXT,
                total_bytes INTEGER
            );
            CREATE TABLE message_attachment_join (
                message_id INTEGER,
                attachment_id INTEGER
            );
            """,
            in: db
        )

        let archivedBody = NSArchiver.archivedData(withRootObject: NSMutableAttributedString(string: "Archived only body"))
        let archivedHex = archivedBody.map { String(format: "%02x", $0) }.joined()
        let firstDate = Int64(Date(timeIntervalSinceReferenceDate: 100).timeIntervalSinceReferenceDate * 1_000_000_000)
        let secondDate = Int64(Date(timeIntervalSinceReferenceDate: 200).timeIntervalSinceReferenceDate * 1_000_000_000)
        let thirdDate = Int64(Date(timeIntervalSinceReferenceDate: 300).timeIntervalSinceReferenceDate * 1_000_000_000)
        let fourthDate = Int64(Date(timeIntervalSinceReferenceDate: 400).timeIntervalSinceReferenceDate * 1_000_000_000)
        let missingAttachmentPath = attachmentsURL.appending(path: "missing-photo.jpg").path

        try exec(
            """
            INSERT INTO chat (ROWID, guid, display_name, chat_identifier)
            VALUES (1, 'chat-guid-1', 'Casey', 'casey@example.com');

            INSERT INTO handle (ROWID, id)
            VALUES (1, 'casey@example.com');

            INSERT INTO chat_handle_join (chat_id, handle_id)
            VALUES (1, 1);

            INSERT INTO message (ROWID, guid, text, attributedBody, date, cache_has_attachments, is_from_me, handle_id, associated_message_guid, associated_message_type, associated_message_emoji, thread_originator_guid, thread_originator_part)
            VALUES
                (100, 'message-guid-1', 'Visible text body', NULL, \(firstDate), 0, 0, 1, NULL, 0, NULL, NULL, NULL),
                (101, 'message-guid-2', NULL, X'\(archivedHex)', \(secondDate), 1, 1, NULL, NULL, 0, NULL, NULL, NULL)
                \(includeRichMessageMetadata ? ",\n                (102, 'message-guid-3', 'Replying inline', NULL, \(thirdDate), 0, 1, NULL, NULL, 0, NULL, 'message-guid-1', '0'),\n                (103, 'message-guid-4', NULL, NULL, \(fourthDate), 0, 0, 1, 'p:0/message-guid-2', 2001, NULL, NULL, NULL)" : "");

            INSERT INTO chat_message_join (chat_id, message_id)
            VALUES
                (1, 100),
                (1, 101)
                \(includeRichMessageMetadata ? ",\n                (1, 102),\n                (1, 103)" : "");

            INSERT INTO attachment (ROWID, guid, filename, transfer_name, mime_type, uti, total_bytes)
            VALUES
                (200, 'attachment-guid-1', '\(escapeSQL(missingAttachmentPath))', 'missing-photo.jpg', 'image/jpeg', 'public.jpeg', 4096);

            INSERT INTO message_attachment_join (message_id, attachment_id)
            VALUES
                (101, 200);
            """,
            in: db
        )
    }

    private func exec(_ sql: String, in db: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        guard code == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw FixtureError.executionFailed(message)
        }
    }

    private func escapeSQL(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

private enum FixtureError: Error {
    case databaseCreationFailed
    case executionFailed(String)
}
