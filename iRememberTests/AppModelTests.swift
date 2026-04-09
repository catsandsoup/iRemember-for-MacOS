import SwiftData
import XCTest
@testable import iRemember

@MainActor
final class AppModelTests: XCTestCase {
    func testSampleSearchReturnsTypedResults() async throws {
        let source = SampleMessagesSource()

        let results = try await source.searchLibrary(query: "archive", scope: .all, limit: 20)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.kind == .conversation }))
        XCTAssertTrue(results.contains(where: { $0.kind == .message || $0.kind == .media || $0.kind == .attachment }))
    }

    func testMergeDecisionKeepSeparateCreatesSingleConversationPersonArchive() async throws {
        let appModel = makeAppModel()

        await appModel.loadSampleLibrary()
        let mergeableArchive = try XCTUnwrap(appModel.threadArchives.first(where: { $0.title == "Alex Chen" }))
        await appModel.selectArchive(mergeableArchive)
        let originalConversationID = try XCTUnwrap(appModel.selectedConversationID)

        await appModel.applyMergeDecision(.keepSeparate)
        await appModel.setSidebarMode(.people)

        let archive = try XCTUnwrap(appModel.selectedArchiveSummary)
        XCTAssertEqual(archive.kind, .person)
        XCTAssertEqual(archive.conversationIDs, [originalConversationID])
    }

    func testPeopleModeMergesRelatedThreadsByContactIdentity() async throws {
        let appModel = makeAppModel()

        await appModel.loadSampleLibrary()

        let alexArchive = try XCTUnwrap(appModel.personArchives.first(where: {
            $0.title == "Alex Chen" && $0.conversationIDs.count == 2
        }))

        XCTAssertEqual(alexArchive.kind, .person)
        XCTAssertEqual(alexArchive.conversationIDs.count, 2)
        XCTAssertEqual(alexArchive.linkedHandles.count, 2)
    }

    func testReplyJumpPreservesReturnPath() async throws {
        let source = SampleMessagesSource()
        let snapshot = try await source.bootstrapLibrary()
        let conversationID = try XCTUnwrap(snapshot.conversations.first?.id)
        let appModel = makeAppModel(source: source)

        await appModel.loadSampleLibrary()
        let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<30)
        let replyMessage = try XCTUnwrap(slice.messages.first(where: { $0.replyContext != nil }))

        await appModel.focusTranscript(on: replyMessage.id)
        let loadedReply = try XCTUnwrap(appModel.transcriptMessages.first(where: { $0.id == replyMessage.id }))

        await appModel.jumpToReplyContext(from: loadedReply)

        XCTAssertTrue(appModel.canReturnToPreviousPosition)

        await appModel.returnToPreviousPosition()

        XCTAssertEqual(appModel.selectedMessageID, replyMessage.id)
    }

    func testPersistenceCoordinatorRoundTripsSession() throws {
        let container = try makeInMemoryContainer()
        let coordinator = AppPersistenceCoordinator(modelContext: ModelContext(container))
        let archive = ArchiveSummary(
            id: "thread:123",
            kind: .thread,
            title: "Test",
            secondaryText: "Snippet",
            lastActivityAt: .now,
            representativeConversationID: UUID(),
            conversationIDs: [],
            participants: [],
            linkedHandles: [],
            messageCount: 10,
            mediaCount: 2,
            isPinned: false
        )

        try coordinator.saveSession(
            archiveSummary: archive,
            sidebarMode: .threads,
            transcriptWindow: 20..<40,
            selectedMessageID: UUID(),
            timelineAnchorDate: .now,
            activeAnchor: .latest,
            inspectorVisible: true,
            contentMode: .transcript,
            searchText: "archive",
            searchScope: .messages
        )

        let restored = try XCTUnwrap(coordinator.loadSession())
        XCTAssertEqual(restored.sidebarMode, .threads)
        XCTAssertEqual(restored.archiveID, archive.id)
        XCTAssertEqual(restored.searchText, "archive")
        XCTAssertEqual(restored.searchScope, .messages)
    }

    func testSearchJumpAcrossArchivesPreservesReturnPath() async throws {
        let appModel = makeAppModel()

        await appModel.loadSampleLibrary()

        let originArchive = try XCTUnwrap(appModel.threadArchives.first(where: { $0.title == "Family" }))
        let targetArchive = try XCTUnwrap(appModel.threadArchives.first(where: { $0.title == "Casey" }))

        await appModel.selectArchive(originArchive)
        let originMessageID = try XCTUnwrap(appModel.transcriptMessages.last?.id)
        await appModel.focusTranscript(on: originMessageID)

        let result = ArchiveSearchResult(
            id: "conversation:\(targetArchive.id)",
            kind: .conversation,
            conversationID: targetArchive.representativeConversationID,
            archiveTitle: targetArchive.title,
            title: targetArchive.title,
            subtitle: targetArchive.secondaryText,
            sentAt: targetArchive.lastActivityAt
        )

        await appModel.activateSearchResult(result)
        XCTAssertEqual(appModel.selectedArchiveSummary?.id, targetArchive.id)
        XCTAssertTrue(appModel.canReturnToPreviousPosition)

        await appModel.returnToPreviousPosition()

        XCTAssertEqual(appModel.selectedArchiveSummary?.id, originArchive.id)
        XCTAssertEqual(appModel.selectedMessageID, originMessageID)
    }

    func testAppModelRestoresSavedSessionOnReload() async throws {
        let source = SampleMessagesSource()
        let container = try makeInMemoryContainer()

        let appModel = makeAppModel(source: source, container: container)
        await appModel.loadSampleLibrary()

        let mergedArchive = try XCTUnwrap(appModel.personArchives.first(where: { $0.conversationIDs.count > 1 }))
        await appModel.selectArchive(mergedArchive)
        let focusedMessageID = try XCTUnwrap(appModel.transcriptMessages.dropFirst(20).first?.id)
        await appModel.focusTranscript(on: focusedMessageID)
        let savedWindow = appModel.transcriptWindow
        appModel.persistSessionIfPossible()

        let restoredModel = makeAppModel(source: source, container: container)
        await restoredModel.loadSampleLibrary()

        XCTAssertEqual(restoredModel.selectedArchiveSummary?.id, mergedArchive.id)
        XCTAssertEqual(restoredModel.transcriptWindow, savedWindow)
        XCTAssertEqual(restoredModel.selectedMessageID, focusedMessageID)
    }

    private func makeAppModel(
        source: SampleMessagesSource = SampleMessagesSource(),
        container: ModelContainer? = nil
    ) -> AppModel {
        let appModel = AppModel(source: source, sampleFallback: source)
        let resolvedContainer: ModelContainer
        if let container {
            resolvedContainer = container
        } else {
            resolvedContainer = try! makeInMemoryContainer()
        }
        appModel.configurePersistence(with: AppPersistenceCoordinator(modelContext: ModelContext(resolvedContainer)))
        return appModel
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            PersistedAppSession.self,
            PersistedMergeDecision.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
