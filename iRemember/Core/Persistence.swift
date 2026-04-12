import Foundation
import SwiftData

enum DisplayText {
    nonisolated static func conversationSnippet(_ text: String) -> String {
        preview(text, maxLength: 220)
    }

    nonisolated static func searchSubtitle(_ text: String) -> String {
        preview(text, maxLength: 280)
    }

    nonisolated static func searchQuery(_ text: String) -> String {
        let collapsed = collapsedWhitespace(in: text)
        let maxLength = 160

        guard collapsed.count > maxLength else {
            return collapsed
        }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func preview(_ text: String, maxLength: Int) -> String {
        let collapsed = collapsedWhitespace(in: text)

        guard collapsed.count > maxLength else {
            return collapsed
        }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        let prefix = collapsed[..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(prefix)…"
    }

    private nonisolated static func collapsedWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class PersistedAppSession {
    @Attribute(.unique) var key: String
    var sidebarModeRawValue: String
    var archiveKindRawValue: String
    var archiveID: String
    var representativeConversationID: UUID?
    var transcriptWindowLowerBound: Int
    var transcriptWindowUpperBound: Int
    var selectedMessageID: UUID?
    var timelineAnchorDate: Date
    var activeAnchorKind: String
    var activeAnchorMessageID: UUID?
    var activeAnchorDate: Date?
    var inspectorVisible: Bool
    var contentModeRawValue: String
    var searchText: String
    var searchScopeRawValue: String
    var updatedAt: Date

    init(
        key: String = "main",
        sidebarModeRawValue: String,
        archiveKindRawValue: String,
        archiveID: String,
        representativeConversationID: UUID?,
        transcriptWindowLowerBound: Int,
        transcriptWindowUpperBound: Int,
        selectedMessageID: UUID?,
        timelineAnchorDate: Date,
        activeAnchorKind: String,
        activeAnchorMessageID: UUID?,
        activeAnchorDate: Date?,
        inspectorVisible: Bool,
        contentModeRawValue: String,
        searchText: String,
        searchScopeRawValue: String,
        updatedAt: Date = .now
    ) {
        self.key = key
        self.sidebarModeRawValue = sidebarModeRawValue
        self.archiveKindRawValue = archiveKindRawValue
        self.archiveID = archiveID
        self.representativeConversationID = representativeConversationID
        self.transcriptWindowLowerBound = transcriptWindowLowerBound
        self.transcriptWindowUpperBound = transcriptWindowUpperBound
        self.selectedMessageID = selectedMessageID
        self.timelineAnchorDate = timelineAnchorDate
        self.activeAnchorKind = activeAnchorKind
        self.activeAnchorMessageID = activeAnchorMessageID
        self.activeAnchorDate = activeAnchorDate
        self.inspectorVisible = inspectorVisible
        self.contentModeRawValue = contentModeRawValue
        self.searchText = searchText
        self.searchScopeRawValue = searchScopeRawValue
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedMergeDecision {
    @Attribute(.unique) var conversationID: String
    var personArchiveID: String
    var actionRawValue: String
    var updatedAt: Date

    init(
        conversationID: String,
        personArchiveID: String,
        actionRawValue: String,
        updatedAt: Date = .now
    ) {
        self.conversationID = conversationID
        self.personArchiveID = personArchiveID
        self.actionRawValue = actionRawValue
        self.updatedAt = updatedAt
    }
}

struct RestoredAppSession: Sendable {
    let sidebarMode: SidebarMode
    let archiveKind: ArchiveKind
    let archiveID: String
    let representativeConversationID: UUID?
    let transcriptWindow: Range<Int>
    let selectedMessageID: UUID?
    let timelineAnchorDate: Date
    let activeAnchor: TranscriptAnchor
    let inspectorVisible: Bool
    let contentMode: ContentMode
    let searchText: String
    let searchScope: SearchScope
}

@MainActor
final class AppPersistenceCoordinator {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadSession() throws -> RestoredAppSession? {
        var descriptor = FetchDescriptor<PersistedAppSession>(
            predicate: #Predicate { $0.key == "main" }
        )
        descriptor.fetchLimit = 1
        guard let stored = try modelContext.fetch(descriptor).first else { return nil }
        guard let sidebarMode = SidebarMode(rawValue: stored.sidebarModeRawValue),
              let archiveKind = ArchiveKind(rawValue: stored.archiveKindRawValue),
              let contentMode = ContentMode(rawValue: stored.contentModeRawValue),
              let searchScope = SearchScope(rawValue: stored.searchScopeRawValue) else {
            return nil
        }

        let activeAnchor = decodeAnchor(
            kind: stored.activeAnchorKind,
            messageID: stored.activeAnchorMessageID,
            date: stored.activeAnchorDate
        )

        return RestoredAppSession(
            sidebarMode: sidebarMode,
            archiveKind: archiveKind,
            archiveID: stored.archiveID,
            representativeConversationID: stored.representativeConversationID,
            transcriptWindow: stored.transcriptWindowLowerBound..<stored.transcriptWindowUpperBound,
            selectedMessageID: stored.selectedMessageID,
            timelineAnchorDate: stored.timelineAnchorDate,
            activeAnchor: activeAnchor,
            inspectorVisible: stored.inspectorVisible,
            contentMode: contentMode,
            searchText: stored.searchText,
            searchScope: searchScope
        )
    }

    func saveSession(
        archiveSummary: ArchiveSummary,
        sidebarMode: SidebarMode,
        transcriptWindow: Range<Int>,
        selectedMessageID: UUID?,
        timelineAnchorDate: Date,
        activeAnchor: TranscriptAnchor,
        inspectorVisible: Bool,
        contentMode: ContentMode,
        searchText: String,
        searchScope: SearchScope
    ) throws {
        let encoded = encodedAnchor(activeAnchor)
        let stored: PersistedAppSession

        if let existing = try existingSession() {
            stored = existing
        } else {
            stored = PersistedAppSession(
                sidebarModeRawValue: sidebarMode.rawValue,
                archiveKindRawValue: archiveSummary.kind.rawValue,
                archiveID: archiveSummary.id,
                representativeConversationID: archiveSummary.representativeConversationID,
                transcriptWindowLowerBound: transcriptWindow.lowerBound,
                transcriptWindowUpperBound: transcriptWindow.upperBound,
                selectedMessageID: selectedMessageID,
                timelineAnchorDate: timelineAnchorDate,
                activeAnchorKind: encoded.kind,
                activeAnchorMessageID: encoded.messageID,
                activeAnchorDate: encoded.date,
                inspectorVisible: inspectorVisible,
                contentModeRawValue: contentMode.rawValue,
                searchText: searchText,
                searchScopeRawValue: searchScope.rawValue
            )
            modelContext.insert(stored)
        }

        stored.sidebarModeRawValue = sidebarMode.rawValue
        stored.archiveKindRawValue = archiveSummary.kind.rawValue
        stored.archiveID = archiveSummary.id
        stored.representativeConversationID = archiveSummary.representativeConversationID
        stored.transcriptWindowLowerBound = transcriptWindow.lowerBound
        stored.transcriptWindowUpperBound = transcriptWindow.upperBound
        stored.selectedMessageID = selectedMessageID
        stored.timelineAnchorDate = timelineAnchorDate
        stored.activeAnchorKind = encoded.kind
        stored.activeAnchorMessageID = encoded.messageID
        stored.activeAnchorDate = encoded.date
        stored.inspectorVisible = inspectorVisible
        stored.contentModeRawValue = contentMode.rawValue
        stored.searchText = searchText
        stored.searchScopeRawValue = searchScope.rawValue
        stored.updatedAt = .now

        try modelContext.save()
    }

    func loadMergeDecisions() throws -> [UUID: (personArchiveID: String, action: MergeDecisionAction)] {
        let decisions = try modelContext.fetch(FetchDescriptor<PersistedMergeDecision>())
        return decisions.reduce(into: [:]) { result, decision in
            guard let conversationID = UUID(uuidString: decision.conversationID),
                  let action = MergeDecisionAction(rawValue: decision.actionRawValue) else {
                return
            }
            result[conversationID] = (decision.personArchiveID, action)
        }
    }

    func saveMergeDecision(
        conversationID: UUID,
        personArchiveID: String,
        action: MergeDecisionAction
    ) throws {
        let stored: PersistedMergeDecision

        if let existing = try existingMergeDecision(for: conversationID) {
            stored = existing
        } else {
            stored = PersistedMergeDecision(
                conversationID: conversationID.uuidString,
                personArchiveID: personArchiveID,
                actionRawValue: action.rawValue
            )
            modelContext.insert(stored)
        }

        stored.personArchiveID = personArchiveID
        stored.actionRawValue = action.rawValue
        stored.updatedAt = .now

        try modelContext.save()
    }

    private func existingSession() throws -> PersistedAppSession? {
        var descriptor = FetchDescriptor<PersistedAppSession>(
            predicate: #Predicate { $0.key == "main" }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func existingMergeDecision(for conversationID: UUID) throws -> PersistedMergeDecision? {
        let rawID = conversationID.uuidString
        var descriptor = FetchDescriptor<PersistedMergeDecision>(
            predicate: #Predicate { $0.conversationID == rawID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func encodedAnchor(_ anchor: TranscriptAnchor) -> (kind: String, messageID: UUID?, date: Date?) {
        switch anchor {
        case .latest:
            return ("latest", nil, nil)
        case .message(let messageID):
            return ("message", messageID, nil)
        case .reply(let messageID):
            return ("reply", messageID, nil)
        case .search(let messageID):
            return ("search", messageID, nil)
        case .timeline(let date):
            return ("timeline", nil, date)
        case .date(let date):
            return ("date", nil, date)
        }
    }

    private func decodeAnchor(kind: String, messageID: UUID?, date: Date?) -> TranscriptAnchor {
        switch kind {
        case "message":
            return messageID.map(TranscriptAnchor.message) ?? .latest
        case "reply":
            return messageID.map(TranscriptAnchor.reply) ?? .latest
        case "search":
            return messageID.map(TranscriptAnchor.search) ?? .latest
        case "timeline":
            return date.map(TranscriptAnchor.timeline) ?? .latest
        case "date":
            return date.map(TranscriptAnchor.date) ?? .latest
        default:
            return .latest
        }
    }
}
