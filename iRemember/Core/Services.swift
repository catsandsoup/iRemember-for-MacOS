import AppKit
import Contacts
import Foundation
import Observation
import OSLog
import UniformTypeIdentifiers

public enum SourceStrategy: String, Sendable {
    case liveBrowse
    case derivedIndex
    case hybrid

    public var label: String {
        switch self {
        case .liveBrowse: "Live Browse"
        case .derivedIndex: "Derived Index"
        case .hybrid: "Hybrid"
        }
    }
}

public enum ContactIdentityAccessState: String, Sendable {
    case unavailable
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited

    public var label: String {
        switch self {
        case .unavailable:
            "Archive Names"
        case .notDetermined:
            "Contacts Not Requested"
        case .restricted:
            "Contacts Restricted"
        case .denied:
            "Contacts Off"
        case .authorized, .limited:
            "macOS Contacts"
        }
    }

    public var symbolName: String {
        switch self {
        case .unavailable:
            "text.quote"
        case .notDetermined:
            "person.crop.circle.badge.questionmark"
        case .restricted, .denied:
            "person.crop.circle.badge.xmark"
        case .authorized, .limited:
            "person.crop.circle.badge.checkmark"
        }
    }

    public var usesContacts: Bool {
        switch self {
        case .authorized, .limited:
            true
        case .unavailable, .notDetermined, .restricted, .denied:
            false
        }
    }
}

public protocol MessagesLoadErrorPresentable {
    var failureTitle: String { get }
    var failureCode: String { get }
    var failureDescription: String { get }
    var recoverySteps: [String] { get }
}

public struct SourceLocation: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let url: URL

    public nonisolated init(label: String, url: URL) {
        self.id = label
        self.label = label
        self.url = url
    }

    public nonisolated var displayPath: String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

public enum SetupRequirementState: String, Sendable {
    case complete
    case actionRequired
    case informational
}

public struct SetupRequirement: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let state: SetupRequirementState

    public nonisolated init(id: String, title: String, detail: String, state: SetupRequirementState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct SourceSetupSnapshot: Sendable {
    public let title: String
    public let detail: String
    public let requirements: [SetupRequirement]
    public let locations: [SourceLocation]

    public nonisolated init(
        title: String,
        detail: String,
        requirements: [SetupRequirement],
        locations: [SourceLocation]
    ) {
        self.title = title
        self.detail = detail
        self.requirements = requirements
        self.locations = locations
    }

    public nonisolated var isReady: Bool {
        requirements.allSatisfy { $0.state.rawValue != SetupRequirementState.actionRequired.rawValue }
    }
}

public struct LibraryLoadProgress: Equatable, Sendable {
    public let step: Int
    public let totalSteps: Int
    public let title: String
    public let detail: String
    public let completedUnitCount: Int?
    public let totalUnitCount: Int?
    public let unitLabel: String?

    public nonisolated init(
        step: Int,
        totalSteps: Int,
        title: String,
        detail: String,
        completedUnitCount: Int? = nil,
        totalUnitCount: Int? = nil,
        unitLabel: String? = nil
    ) {
        self.step = step
        self.totalSteps = totalSteps
        self.title = title
        self.detail = detail
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.unitLabel = unitLabel
    }

    public nonisolated var fractionCompleted: Double? {
        if let completedUnitCount, let totalUnitCount, totalUnitCount > 0 {
            return Double(completedUnitCount) / Double(totalUnitCount)
        }

        guard totalSteps > 0 else { return nil }
        return Double(step) / Double(totalSteps)
    }

    public nonisolated var unitDescription: String? {
        guard let completedUnitCount, let totalUnitCount, let unitLabel else { return nil }
        return "\(unitLabel) \(completedUnitCount.formatted()) of \(totalUnitCount.formatted())"
    }
}

public protocol MessagesSource: Sendable {
    var strategy: SourceStrategy { get }
    var libraryModeName: String { get }
    var libraryModeDescription: String { get }
    var sourceLocations: [SourceLocation] { get }

    func inspectSetup() async -> SourceSetupSnapshot
    func bootstrapLibrary(progressHandler: (@Sendable (LibraryLoadProgress) -> Void)?) async throws -> LibrarySnapshot
    func loadConversationDetail(id: UUID) async throws -> ConversationDetail
    func loadMessages(conversationID: UUID, range: Range<Int>) async throws -> TranscriptSlice
    func searchLibrary(query: String, scope: SearchScope, limit: Int) async throws -> [ArchiveSearchResult]
}

public extension MessagesSource {
    func bootstrapLibrary() async throws -> LibrarySnapshot {
        try await bootstrapLibrary(progressHandler: nil)
    }

    func searchLibrary(query: String, scope: SearchScope, limit: Int = 32) async throws -> [ArchiveSearchResult] {
        []
    }
}

public enum AccessState: Equatable, Sendable {
    case onboarding
    case loading
    case ready
    case failed(String)
}

public enum ContentMode: String, CaseIterable, Identifiable, Sendable {
    case transcript
    case media

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .transcript: "Messages"
        case .media: "Shared Media"
        }
    }

    public var symbolName: String {
        switch self {
        case .transcript: "message"
        case .media: "photo.on.rectangle.angled"
        }
    }
}

public struct DaySection: Identifiable, Hashable, Sendable {
    public let id: Date
    public let title: String
    public let messages: [Message]
}

public struct ConversationSessionState: Sendable {
    public let transcriptWindow: Range<Int>
    public let selectedMessageID: UUID?
    public let timelineAnchorDate: Date
    public let activeAnchor: TranscriptAnchor

    public init(
        transcriptWindow: Range<Int>,
        selectedMessageID: UUID?,
        timelineAnchorDate: Date,
        activeAnchor: TranscriptAnchor
    ) {
        self.transcriptWindow = transcriptWindow
        self.selectedMessageID = selectedMessageID
        self.timelineAnchorDate = timelineAnchorDate
        self.activeAnchor = activeAnchor
    }
}

private struct ArchiveNavigationOrigin: Sendable {
    let archiveID: String
    let state: ConversationSessionState
}

public struct TimelineMonthMarker: Identifiable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let startDate: Date
    public let messageCount: Int

    public var id: String {
        "\(year)-\(month)"
    }

    public var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: startDate)
    }
}

private struct TimelineNavigationSnapshot: Sendable {
    let years: [Int]
    let monthsByYear: [Int: [TimelineMonthMarker]]

    init(messageIndex: [MessageIndexEntry], calendar: Calendar) {
        var monthCountsByYear: [Int: [Int: Int]] = [:]

        for entry in messageIndex {
            let year = calendar.component(.year, from: entry.sentAt)
            let month = calendar.component(.month, from: entry.sentAt)
            monthCountsByYear[year, default: [:]][month, default: 0] += 1
        }

        years = monthCountsByYear.keys.sorted(by: >)
        monthsByYear = monthCountsByYear.reduce(into: [:]) { result, pair in
            let year = pair.key
            let monthCounts = pair.value

            result[year] = monthCounts.keys.sorted(by: >).compactMap { month in
                guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                    return nil
                }

                return TimelineMonthMarker(
                    year: year,
                    month: month,
                    startDate: startDate,
                    messageCount: monthCounts[month, default: 0]
                )
            }
        }
    }
}

@MainActor
@Observable
public final class AppModel {
    public private(set) var accessState: AccessState = .onboarding
    public private(set) var conversations: [Conversation] = []
    public private(set) var detailCache: [UUID: ConversationDetail] = [:]
    public private(set) var transcriptMessages: [Message] = []
    public private(set) var failureTitle = "Unable to Load Library"
    public private(set) var failureCode = "IRM-APP-000"
    public private(set) var failureDescription = "The library could not be opened."
    public private(set) var failureRecoverySteps: [String] = []
    public private(set) var setupSnapshot = SourceSetupSnapshot(
        title: "Set up access to Messages",
        detail: "iRemember reads your local Messages library without changing it.",
        requirements: [],
        locations: []
    )
    public private(set) var loadingProgress = LibraryLoadProgress(
        step: 0,
        totalSteps: 0,
        title: "Preparing library access",
        detail: "Checking what is available on this Mac."
    )
    public private(set) var loadingStartedAt = Date.now

    public var selectedConversationID: UUID?
    public private(set) var selectedPersonArchiveID: String?
    public var selectedMessageID: UUID?
    public var selectedMediaAssetID: UUID?
    public var sidebarMode: SidebarMode = .people
    public var searchText = ""
    public var searchScope: SearchScope = .all
    public var contentMode: ContentMode = .transcript
    public var mediaFilter: MediaFilter = .all
    public var timelineRange: TimelineRange = .month
    public var timelineHeight: Double = 80
    public var dateJumpTarget = Date.now
    public var timelineAnchorDate = Date.now
    public var activeTranscriptAnchor: TranscriptAnchor = .latest
    public var expandedTimelineYear: Int?
    public var hoveredTimelineYear: Int?
    public var isDateJumpPresented = false
    public var isExportSheetPresented = false
    public var isMediaViewerPresented = false
    public var isSidebarVisible = true
    public var isInspectorVisible = true
    public private(set) var transcriptWindow: Range<Int> = 0..<0
    public var scrollTargetMessageID: UUID?
    public private(set) var highlightedMessageID: UUID?
    public private(set) var searchResults: [ArchiveSearchResult] = []
    public private(set) var isSearching = false
    public private(set) var pendingTimelineDate: Date?
    public private(set) var isTimelineScrubbing = false
    public private(set) var didBootstrap = false
    public var exportFormat: ExportFormat = .pdf
    public var exportScope: ExportScope = .entireConversation
    public var exportIncludesMessages = true
    public var exportIncludesPhotos = true
    public var exportIncludesLinks = true
    public var exportIncludesAttachments = true
    public var exportIncludesReactions = true
    public var exportIncludesTimestamps = true
    public var exportIncludesParticipants = true
    public var exportRangeStart = Date.now
    public var exportRangeEnd = Date.now
    public private(set) var lastExportDescription: String?
    public private(set) var jumpOriginDescription: String?
    public private(set) var jumpOriginArchiveID: String?
    public private(set) var jumpOriginState: ConversationSessionState?

    public private(set) var sourceStrategy: SourceStrategy
    public private(set) var sourceModeName: String
    public private(set) var sourceModeDescription: String
    public private(set) var sourceLocations: [SourceLocation]

    private let transcriptWindowSize = 160
    private let calendar = Calendar.autoupdatingCurrent

    private let primarySource: any MessagesSource
    private let sampleFallback: (any MessagesSource)?
    private let contactIdentityResolver: any ContactIdentityResolving
    private var source: any MessagesSource
    private var archiveDetailCache: [String: ArchiveDetail] = [:]
    private var archiveSessionStates: [String: ConversationSessionState] = [:]
    private var timelineNavigationSnapshots: [String: TimelineNavigationSnapshot] = [:]
    private var mergeDecisions: [UUID: (personArchiveID: String, action: MergeDecisionAction)] = [:]
    private var pendingRestoredSession: RestoredAppSession?
    private var persistenceCoordinator: AppPersistenceCoordinator?
    private var didConfigurePersistence = false

    public convenience init(source: any MessagesSource, sampleFallback: (any MessagesSource)? = nil) {
        self.init(
            source: source,
            sampleFallback: sampleFallback,
            contactIdentityResolver: SystemContactIdentityResolver()
        )
    }

    init(
        source: any MessagesSource,
        sampleFallback: (any MessagesSource)? = nil,
        contactIdentityResolver: any ContactIdentityResolving
    ) {
        self.primarySource = source
        self.sampleFallback = sampleFallback
        self.contactIdentityResolver = contactIdentityResolver
        self.source = source
        self.sourceStrategy = source.strategy
        self.sourceModeName = source.libraryModeName
        self.sourceModeDescription = source.libraryModeDescription
        self.sourceLocations = source.sourceLocations
        self.setupSnapshot = SourceSetupSnapshot(
            title: "Set up access to Messages",
            detail: "iRemember reads your local Messages library without changing it.",
            requirements: [
                SetupRequirement(
                    id: "read-only",
                    title: "Read-only by design",
                    detail: "Messages and attachments stay untouched.",
                    state: .informational
                )
            ],
            locations: source.sourceLocations
        )
    }

    public var selectedConversation: Conversation? {
        guard let summary = selectedArchiveSummary else { return nil }
        return conversations.first(where: { $0.id == summary.representativeConversationID })
    }

    public var selectedArchiveSummary: ArchiveSummary? {
        switch sidebarMode {
        case .threads:
            guard let id = selectedConversationID else { return nil }
            return threadArchives.first(where: { $0.representativeConversationID == id })
        case .people:
            guard let personArchiveID = selectedPersonArchiveID ?? selectedConversationID.flatMap(personArchiveID(for:)) else {
                return nil
            }
            return personArchives.first(where: { $0.id == personArchiveID })
        }
    }

    public var selectedArchiveDetail: ArchiveDetail? {
        guard let summary = selectedArchiveSummary else { return nil }
        return archiveDetailCache[summary.id]
    }

    public var selectedMessage: Message? {
        guard let id = selectedMessageID else { return nil }
        return transcriptMessages.first(where: { $0.id == id })
    }

    public var threadArchives: [ArchiveSummary] {
        conversations.map { conversation in
            ArchiveSummary(
                id: threadArchiveID(for: conversation.id),
                kind: .thread,
                title: conversation.title,
                secondaryText: conversation.snippet,
                lastActivityAt: conversation.lastActivityAt,
                representativeConversationID: conversation.id,
                conversationIDs: [conversation.id],
                participants: conversation.participants,
                linkedHandles: linkedHandles(for: conversation.participants),
                messageCount: conversation.messageCount,
                mediaCount: conversation.mediaCount,
                isPinned: conversation.isPinned
            )
        }
    }

    public var personArchives: [ArchiveSummary] {
        let grouped = Dictionary(grouping: conversations, by: personArchiveID(for:))

        return grouped.compactMap { archiveID, groupedConversations in
            guard let latestConversation = groupedConversations.max(by: { $0.lastActivityAt < $1.lastActivityAt }) else {
                return nil
            }

            let participants = mergeParticipants(from: groupedConversations)
            let handles = linkedHandles(for: participants)
            let totalMessages = groupedConversations.compactMap(\.messageCount)
            let totalMedia = groupedConversations.compactMap(\.mediaCount)

            return ArchiveSummary(
                id: archiveID,
                kind: .person,
                title: personArchiveTitle(for: groupedConversations),
                secondaryText: latestConversation.snippet,
                lastActivityAt: latestConversation.lastActivityAt,
                representativeConversationID: latestConversation.id,
                conversationIDs: groupedConversations.map(\.id).sorted { lhs, rhs in
                    guard let lhsConversation = conversations.first(where: { $0.id == lhs }),
                          let rhsConversation = conversations.first(where: { $0.id == rhs }) else {
                        return lhs.uuidString < rhs.uuidString
                    }
                    return lhsConversation.lastActivityAt > rhsConversation.lastActivityAt
                },
                participants: participants,
                linkedHandles: handles,
                messageCount: totalMessages.isEmpty ? nil : totalMessages.reduce(0, +),
                mediaCount: totalMedia.isEmpty ? nil : totalMedia.reduce(0, +),
                isPinned: groupedConversations.contains(where: \.isPinned)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }

    public var visibleSidebarArchives: [ArchiveSummary] {
        switch sidebarMode {
        case .threads:
            return threadArchives
        case .people:
            return personArchives
        }
    }

    public var visibleMessages: [Message] {
        transcriptMessages
    }

    public var canLoadEarlierMessages: Bool {
        transcriptWindow.lowerBound > 0
    }

    public var canLoadLaterMessages: Bool {
        guard let detail = selectedArchiveDetail else { return false }
        return transcriptWindow.upperBound < detail.messageIndex.count
    }

    public var daySections: [DaySection] {
        let formatter = DateFormatter()
        formatter.dateStyle = .full

        let grouped = Dictionary(grouping: visibleMessages) { message in
            calendar.startOfDay(for: message.sentAt)
        }

        return grouped.keys.sorted().map { day in
            DaySection(
                id: day,
                title: formatter.string(from: day),
                messages: grouped[day, default: []].sorted { $0.sentAt < $1.sentAt }
            )
        }
    }

    public var filteredMediaAssets: [MediaAsset] {
        guard let detail = selectedArchiveDetail else { return [] }
        switch mediaFilter {
        case .all:
            return detail.mediaAssets
        case .images:
            return detail.mediaAssets.filter { $0.attachment.kind == .image }
        case .videos:
            return detail.mediaAssets.filter { $0.attachment.kind == .video }
        }
    }

    public var linkAttachmentItems: [AttachmentItem] {
        guard let detail = selectedArchiveDetail else { return [] }
        return detail.attachmentItems.filter { $0.attachment.kind == .link }
    }

    public var selectedMediaAsset: MediaAsset? {
        guard let id = selectedMediaAssetID else { return nil }
        return selectedArchiveDetail?.mediaAssets.first(where: { $0.id == id })
    }

    public var previewableMediaAssets: [MediaAsset] {
        let assets = if contentMode == .media {
            filteredMediaAssets
        } else {
            selectedArchiveDetail?.mediaAssets ?? []
        }

        return assets.sorted {
            if $0.sentAt == $1.sentAt {
                return $0.attachment.filename.localizedCaseInsensitiveCompare($1.attachment.filename) == .orderedAscending
            }
            return $0.sentAt < $1.sentAt
        }
    }

    public var selectedMediaAssetIndex: Int? {
        guard let asset = selectedMediaAsset else { return nil }
        return previewableMediaAssets.firstIndex(where: { $0.id == asset.id })
    }

    public var canSelectPreviousMedia: Bool {
        guard let selectedMediaAssetIndex else { return false }
        return selectedMediaAssetIndex > 0
    }

    public var canSelectNextMedia: Bool {
        guard let selectedMediaAssetIndex else { return false }
        return selectedMediaAssetIndex < previewableMediaAssets.count - 1
    }

    public var timelineYears: [Int] {
        guard let id = selectedArchiveSummary?.id else { return [] }
        return timelineSnapshot(for: id)?.years ?? []
    }

    public var canReturnToPreviousPosition: Bool {
        jumpOriginArchiveID != nil && jumpOriginState != nil
    }

    public var currentArchiveSubtitle: String {
        guard let summary = selectedArchiveSummary else { return "" }
        let firstYear = selectedArchiveDetail?.messageIndex.first.map { calendar.component(.year, from: $0.sentAt) }
        let lastYear = selectedArchiveDetail?.messageIndex.last.map { calendar.component(.year, from: $0.sentAt) }
        let descriptor: String

        switch summary.kind {
        case .person:
            descriptor = summary.conversationIDs.count > 1 ? "Combined conversation history" : "Conversation history"
        case .thread:
            descriptor = summary.participants.count > 2 ? "Group conversation" : "Conversation history"
        }

        if let firstYear, let lastYear {
            return "\(descriptor) • \(firstYear)-\(lastYear)"
        }

        return summary.secondaryText
    }

    public var archiveRangeSummary: String {
        guard let detail = selectedArchiveDetail,
              let first = detail.messageIndex.first?.sentAt,
              let last = detail.messageIndex.last?.sentAt else {
            return "Archive not loaded"
        }

        return "\(first.compactDateLabel) to \(last.compactDateLabel)"
    }

    public var linkedHandleSummary: String {
        guard let summary = selectedArchiveSummary else { return "" }
        let handles = summary.linkedHandles

        switch handles.count {
        case 0:
            return "No addresses"
        case 1:
            return "1 address"
        default:
            return "\(handles.count) addresses"
        }
    }

    public var archiveHandles: [String] {
        selectedArchiveSummary?.linkedHandles ?? []
    }

    public var contactIdentityAccessState: ContactIdentityAccessState {
        contactIdentityResolver.accessState
    }

    public var selectedArchiveUsesContactIdentity: Bool {
        guard let summary = selectedArchiveSummary else { return false }
        return summary.linkedHandles.contains { handle in
            contactIdentityResolver.contactIdentityKey(for: handle) != nil
        }
    }

    public var archiveIdentitySourceSummary: String {
        switch contactIdentityAccessState {
        case .authorized, .limited:
            return selectedArchiveUsesContactIdentity ? "Using names from macOS Contacts" : "No matching card in Contacts"
        case .denied:
            return "Contacts access is turned off"
        case .restricted:
            return "Contacts access is restricted on this Mac"
        case .notDetermined:
            return "Contacts access has not been requested yet"
        case .unavailable:
            return "Showing archived names only"
        }
    }

    public var mergeSuggestionHandles: [String] {
        suggestedMergedArchive?.linkedHandles ?? selectedArchiveSummary?.linkedHandles ?? []
    }

    public var suggestedMergedArchive: ArchiveSummary? {
        guard let selectedConversationID else { return nil }
        return personArchives.first {
            $0.conversationIDs.contains(selectedConversationID) && $0.conversationIDs.count > 1
        }
    }

    public var showsMergeSuggestion: Bool {
        guard sidebarMode == .threads,
              let _ = selectedConversationID else { return false }
        return suggestedMergedArchive != nil
    }

    public var mergeStateLabel: String {
        switch sidebarMode {
        case .threads:
            guard let selectedConversationID else { return "No merge state" }
            if let decision = mergeDecisions[selectedConversationID] {
                switch decision.action {
                case .keepSeparate:
                    return "Kept separate"
                case .alwaysMerge:
                    return "Always merge"
                }
            }

            if let suggestedMergedArchive {
                let relatedCount = suggestedMergedArchive.conversationIDs.count
                return relatedCount == 2 ? "Merge candidate with 2 threads" : "Merge candidate with \(relatedCount) threads"
            }

            return "Single thread"
        case .people:
            guard let summary = selectedArchiveSummary else { return "No merge state" }
            let threadCount = summary.conversationIDs.count
            return threadCount == 1 ? "Single thread archive" : "Merged from \(threadCount) threads"
        }
    }

    public var timelineBuckets: [TimelineBucket] {
        guard let detail = selectedArchiveDetail, !detail.messageIndex.isEmpty else { return [] }
        let entries = detail.messageIndex

        switch timelineRange {
        case .week:
            return makeDayBuckets(in: weekInterval(containing: timelineAnchorDate), entries: entries)
        case .month:
            return makeWeekBuckets(in: monthInterval(containing: timelineAnchorDate), entries: entries)
        case .year:
            return makeMonthBuckets(in: yearInterval(containing: timelineAnchorDate), entries: entries)
        }
    }

    public var dateScrubberDays: [Date] {
        let week = weekInterval(containing: timelineAnchorDate)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start)
        }
    }

    public var timelineSummaryTitle: String {
        let formatter = DateFormatter()

        switch timelineRange {
        case .week:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: timelineAnchorDate)
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: timelineAnchorDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: timelineAnchorDate)
        }
    }

    public func timelineMonths(for year: Int) -> [TimelineMonthMarker] {
        guard let id = selectedArchiveSummary?.id else { return [] }
        return timelineSnapshot(for: id)?.monthsByYear[year] ?? []
    }

    public var visibleMessageRangeDescription: String {
        guard let first = transcriptMessages.first?.sentAt, let last = transcriptMessages.last?.sentAt else {
            return "No messages loaded"
        }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let rangeText = formatter.string(from: first, to: last)

        guard let detail = selectedArchiveDetail else { return rangeText }
        let lower = transcriptWindow.lowerBound + 1
        let upper = transcriptWindow.upperBound
        return "\(rangeText) • \(lower)-\(upper) of \(detail.messageIndex.count)"
    }

    public var canUseSampleFallback: Bool {
        sampleFallback != nil
    }

    func configurePersistence(with coordinator: AppPersistenceCoordinator) {
        guard !didConfigurePersistence else { return }
        didConfigurePersistence = true
        persistenceCoordinator = coordinator

        do {
            mergeDecisions = try coordinator.loadMergeDecisions()
            pendingRestoredSession = try coordinator.loadSession()
            if let pendingRestoredSession {
                sidebarMode = pendingRestoredSession.sidebarMode
                isInspectorVisible = pendingRestoredSession.inspectorVisible
                contentMode = pendingRestoredSession.contentMode
                searchText = pendingRestoredSession.searchText
                searchScope = pendingRestoredSession.searchScope
            }
            AppTelemetry.session.info("Loaded persistence state")
        } catch {
            AppTelemetry.session.error("Failed to load persistence state: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        setupSnapshot = await primarySource.inspectSetup()
        await contactIdentityResolver.prepare(for: primarySource.strategy)
    }

    public func persistSessionIfPossible() {
        guard let coordinator = persistenceCoordinator,
              let summary = selectedArchiveSummary,
              transcriptWindow.isEmpty == false else {
            return
        }

        do {
            try coordinator.saveSession(
                archiveSummary: summary,
                sidebarMode: sidebarMode,
                transcriptWindow: transcriptWindow,
                selectedMessageID: selectedMessageID,
                timelineAnchorDate: timelineAnchorDate,
                activeAnchor: activeTranscriptAnchor,
                inspectorVisible: isInspectorVisible,
                contentMode: contentMode,
                searchText: searchText,
                searchScope: searchScope
            )
        } catch {
            AppTelemetry.session.error("Failed to persist session: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func loadPrimaryLibrary() async {
        await loadLibrary(using: primarySource)
    }

    public func loadSampleLibrary() async {
        guard let sampleFallback else {
            await loadPrimaryLibrary()
            return
        }
        await loadLibrary(using: sampleFallback)
    }

    public func retryCurrentLibrary() async {
        await loadLibrary(using: source)
    }

    public func loadSelectedConversationIfNeeded() async {
        guard let summary = selectedArchiveSummary else { return }

        do {
            let detail = try await loadArchiveDetail(for: summary)
            archiveDetailCache[summary.id] = detail
            updateTimelineSnapshot(for: detail)
            expandedTimelineYear = calendar.component(.year, from: detail.summary.lastActivityAt)
            exportRangeStart = detail.messageIndex.first?.sentAt ?? detail.summary.lastActivityAt
            exportRangeEnd = detail.messageIndex.last?.sentAt ?? detail.summary.lastActivityAt
            await restoreOrLoadTranscriptWindow(for: detail)
            persistSessionIfPossible()
        } catch {
            await applyLoadFailure(error)
        }
    }

    public func ensureTranscriptWindow() async {
        guard let detail = selectedArchiveDetail else {
            transcriptWindow = 0..<0
            transcriptMessages = []
            return
        }

        let count = detail.messageIndex.count
        guard count > 0 else {
            transcriptWindow = 0..<0
            transcriptMessages = []
            return
        }

        if let cached = selectedArchiveSummary.flatMap({ archiveSessionStates[$0.id] }),
           cached.transcriptWindow.upperBound <= count {
            timelineAnchorDate = cached.timelineAnchorDate
            dateJumpTarget = cached.timelineAnchorDate
            activeTranscriptAnchor = cached.activeAnchor
            await loadTranscriptWindow(range: cached.transcriptWindow)
            selectedMessageID = cached.selectedMessageID
            highlightedMessageID = cached.selectedMessageID
            scrollTargetMessageID = cached.selectedMessageID
            return
        }

        if transcriptWindow.isEmpty || transcriptWindow.upperBound > count {
            let lower = max(0, count - transcriptWindowSize)
            timelineAnchorDate = detail.summary.lastActivityAt
            dateJumpTarget = detail.summary.lastActivityAt
            activeTranscriptAnchor = .latest
            await loadTranscriptWindow(range: lower..<count)
        } else if transcriptMessages.isEmpty {
            await loadTranscriptWindow(range: transcriptWindow)
        }
    }

    public func loadEarlierMessages() async {
        guard selectedArchiveDetail != nil else { return }
        let newLower = max(0, transcriptWindow.lowerBound - transcriptWindowSize / 2)
        let range = newLower..<transcriptWindow.upperBound
        await loadTranscriptWindow(range: range)
        scrollTargetMessageID = transcriptMessages.first?.id
    }

    public func loadLaterMessages() async {
        guard let detail = selectedArchiveDetail else { return }
        let newUpper = min(detail.messageIndex.count, transcriptWindow.upperBound + transcriptWindowSize / 2)
        let range = transcriptWindow.lowerBound..<newUpper
        await loadTranscriptWindow(range: range)
        scrollTargetMessageID = transcriptMessages.last?.id
    }

    public func performDateJump(rememberOrigin: Bool = true) async {
        guard let detail = selectedArchiveDetail, !detail.messageIndex.isEmpty else { return }

        if rememberOrigin {
            saveJumpOrigin(label: "Back to previous position")
        }

        let target = detail.messageIndex.min { lhs, rhs in
            abs(lhs.sentAt.timeIntervalSince(dateJumpTarget)) < abs(rhs.sentAt.timeIntervalSince(dateJumpTarget))
        }

        guard let target else { return }
        activeTranscriptAnchor = .date(dateJumpTarget)
        await focusTranscript(on: target.id, anchor: .date(dateJumpTarget))
    }

    public func focusTranscript(
        on messageID: UUID,
        anchor: TranscriptAnchor? = nil,
        rememberOrigin: Bool = false
    ) async {
        guard let detail = selectedArchiveDetail else { return }
        guard let index = detail.messageIndex.firstIndex(where: { $0.id == messageID }) else { return }

        if rememberOrigin {
            saveJumpOrigin(label: "Back to previous position")
        }

        let range = transcriptRange(around: index, totalCount: detail.messageIndex.count)
        await loadTranscriptWindow(range: range)

        if let message = transcriptMessages.first(where: { $0.id == messageID }) {
            activeTranscriptAnchor = anchor ?? .message(messageID)
            selectMessage(message, preserveHighlight: true)
            highlightedMessageID = messageID
            scrollTargetMessageID = messageID
            contentMode = .transcript
            persistSessionIfPossible()
        }
    }

    public func revealMediaInTranscript(_ asset: MediaAsset) async {
        selectedMediaAssetID = asset.id
        timelineAnchorDate = asset.sentAt
        dateJumpTarget = asset.sentAt
        AppTelemetry.archive.info("Reveal media in transcript")
        await focusTranscript(on: asset.messageID, anchor: .timeline(asset.sentAt), rememberOrigin: true)
    }

    public func presentMediaViewer(for asset: MediaAsset) {
        selectedMediaAssetID = asset.id
        isMediaViewerPresented = true
    }

    public func dismissMediaViewer() {
        isMediaViewerPresented = false
    }

    public func selectAdjacentMedia(offset: Int) {
        guard let selectedMediaAssetIndex else { return }
        let assets = previewableMediaAssets
        let targetIndex = selectedMediaAssetIndex + offset
        guard assets.indices.contains(targetIndex) else { return }
        selectedMediaAssetID = assets[targetIndex].id
    }

    public func selectConversation(_ id: UUID?) async {
        if id == selectedConversationID {
            contentMode = .transcript
            return
        }

        persistCurrentArchiveState()
        selectedConversationID = id
        selectedPersonArchiveID = nil
        selectedMessageID = nil
        selectedMediaAssetID = nil
        isMediaViewerPresented = false
        highlightedMessageID = nil
        transcriptWindow = 0..<0
        transcriptMessages = []
        AppTelemetry.archive.info("Selected thread archive")
        await loadSelectedConversationIfNeeded()
    }

    public func selectArchive(_ summary: ArchiveSummary?) async {
        guard let summary else { return }

        if summary.kind == .person {
            if selectedPersonArchiveID == summary.id, sidebarMode == .people {
                contentMode = .transcript
                return
            }
            persistCurrentArchiveState()
            selectedPersonArchiveID = summary.id
            selectedConversationID = summary.representativeConversationID
        } else {
            selectedPersonArchiveID = nil
            await selectConversation(summary.representativeConversationID)
            return
        }

        selectedMessageID = nil
        selectedMediaAssetID = nil
        isMediaViewerPresented = false
        highlightedMessageID = nil
        transcriptWindow = 0..<0
        transcriptMessages = []
        AppTelemetry.archive.info("Selected merged archive")
        await loadSelectedConversationIfNeeded()
    }

    public func selectMessage(_ message: Message, preserveHighlight: Bool = false) {
        selectedMessageID = message.id
        timelineAnchorDate = message.sentAt
        dateJumpTarget = message.sentAt
        expandedTimelineYear = calendar.component(.year, from: message.sentAt)
        if !preserveHighlight {
            highlightedMessageID = nil
        }
        persistSessionIfPossible()
    }

    public func jumpToDay(_ date: Date, rememberOrigin: Bool = true) async {
        guard let detail = selectedArchiveDetail, !detail.messageIndex.isEmpty else { return }

        if rememberOrigin {
            saveJumpOrigin(label: "Back to previous position")
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        if let target = detail.messageIndex.first(where: { $0.sentAt >= start && $0.sentAt < end }) {
            timelineAnchorDate = target.sentAt
            dateJumpTarget = target.sentAt
            activeTranscriptAnchor = .timeline(target.sentAt)
            await focusTranscript(on: target.id, anchor: .timeline(target.sentAt))
            return
        }

        dateJumpTarget = date
        timelineAnchorDate = date
        activeTranscriptAnchor = .timeline(date)
        await performDateJump(rememberOrigin: false)
    }

    public func moveTimelineSelection(byDays dayOffset: Int) async {
        guard let newDate = calendar.date(byAdding: .day, value: dayOffset, to: timelineAnchorDate) else { return }
        await jumpToDay(newDate)
    }

    public func moveTimelineRange(by offset: Int) {
        let component: Calendar.Component

        switch timelineRange {
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

        guard let newDate = calendar.date(byAdding: component, value: offset, to: timelineAnchorDate) else { return }
        timelineAnchorDate = newDate
        dateJumpTarget = newDate
        expandedTimelineYear = calendar.component(.year, from: newDate)
    }

    public func jumpToTimelineBucket(_ bucket: TimelineBucket) async {
        timelineAnchorDate = bucket.startDate
        dateJumpTarget = bucket.startDate
        await jumpToDay(bucket.startDate)
    }

    public func jumpToTimelineYear(_ year: Int) async {
        guard let detail = selectedArchiveDetail else { return }
        guard let target = detail.messageIndex.first(where: { calendar.component(.year, from: $0.sentAt) == year }) else { return }
        expandedTimelineYear = year
        hoveredTimelineYear = year
        timelineAnchorDate = target.sentAt
        dateJumpTarget = target.sentAt
        saveJumpOrigin(label: "Back to previous position")
        await focusTranscript(on: target.id, anchor: .timeline(target.sentAt))
    }

    public func jumpToTimelineMonth(_ marker: TimelineMonthMarker) async {
        await jumpToDay(marker.startDate)
        expandedTimelineYear = marker.year
    }

    public func jumpToReplyContext(from message: Message) async {
        guard let replyContext = message.replyContext,
              let detail = selectedArchiveDetail,
              let target = detail.messageIndex.first(where: { $0.guid == replyContext.referencedMessageGUID }) else {
            return
        }

        saveJumpOrigin(label: "Back to reply")
        await focusTranscript(on: target.id, anchor: .reply(message.id))
    }

    public func returnToPreviousPosition() async {
        guard let archiveID = jumpOriginArchiveID,
              let state = jumpOriginState else { return }

        if selectedArchiveSummary?.id != archiveID {
            guard let targetArchive = archiveSummary(for: archiveID) else {
                clearJumpOrigin()
                return
            }
            await selectArchive(targetArchive)
        }

        timelineAnchorDate = state.timelineAnchorDate
        dateJumpTarget = state.timelineAnchorDate
        activeTranscriptAnchor = state.activeAnchor
        await loadTranscriptWindow(range: state.transcriptWindow)
        applyLoadedMessageSelection(state.selectedMessageID)
        contentMode = .transcript
        clearJumpOrigin()
        persistSessionIfPossible()
    }

    public func setTimelineHeight(_ proposedHeight: Double) {
        timelineHeight = min(max(proposedHeight, 68), 220)
    }

    public func toggleSidebarVisibility() {
        isSidebarVisible.toggle()
        persistSessionIfPossible()
    }

    public func toggleInspectorVisibility() {
        isInspectorVisible.toggle()
        persistSessionIfPossible()
    }

    public func presentExport(scope: ExportScope? = nil, format: ExportFormat? = nil) {
        if let scope {
            exportScope = scope
        }
        if let format {
            exportFormat = format
        }

        if let detail = selectedArchiveDetail {
            exportRangeStart = detail.messageIndex.first?.sentAt ?? detail.summary.lastActivityAt
            exportRangeEnd = detail.messageIndex.last?.sentAt ?? detail.summary.lastActivityAt
        }

        isExportSheetPresented = true
    }

    public func presentSharedContentExport(format: ExportFormat = .pdf) {
        exportIncludesMessages = false
        exportIncludesPhotos = true
        exportIncludesLinks = true
        exportIncludesAttachments = true
        exportIncludesReactions = false
        exportIncludesTimestamps = true
        exportIncludesParticipants = true
        presentExport(scope: .entireConversation, format: format)
    }

    public func performExport() async {
        guard let archive = selectedArchiveSummary else { return }

        do {
            let messages = try await messagesForExport()
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = suggestedExportFilename(for: archive)
            savePanel.allowedContentTypes = [utType(for: exportFormat)]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false

            guard savePanel.runModal() == .OK, let destination = savePanel.url else { return }

            let data = try exportData(for: messages, archive: archive)
            try data.write(to: destination, options: .atomic)
            lastExportDescription = "Exported \(messages.count.groupedCount) items to \(destination.lastPathComponent)"
            isExportSheetPresented = false
        } catch {
            lastExportDescription = "Export failed: \(error.localizedDescription)"
        }
    }

    private func loadLibrary(using newSource: any MessagesSource) async {
        accessState = .loading
        loadingStartedAt = .now
        loadingProgress = LibraryLoadProgress(
            step: 0,
            totalSteps: 0,
            title: "Preparing library access",
            detail: "Checking what is available on this Mac."
        )
        source = newSource
        sourceStrategy = newSource.strategy
        sourceModeName = newSource.libraryModeName
        sourceModeDescription = newSource.libraryModeDescription
        sourceLocations = newSource.sourceLocations
        failureTitle = "Unable to Load Library"
        failureCode = "IRM-APP-000"
        failureDescription = "The library could not be opened."
        failureRecoverySteps = []

        selectedConversationID = nil
        selectedPersonArchiveID = nil
        selectedMessageID = nil
        selectedMediaAssetID = nil
        archiveDetailCache = [:]
        archiveSessionStates = [:]
        clearJumpOrigin()
        detailCache = [:]
        timelineNavigationSnapshots = [:]
        transcriptMessages = []
        transcriptWindow = 0..<0

        do {
            let snapshot = try await source.bootstrapLibrary(progressHandler: { progress in
                Task { @MainActor [weak self] in
                    self?.loadingProgress = progress
                }
            })
            await contactIdentityResolver.prepare(for: newSource.strategy)
            conversations = resolvedConversations(from: snapshot.conversations)
            setupSnapshot = await source.inspectSetup()

            applyInitialArchiveSelection()

            if selectedArchiveSummary != nil {
                loadingProgress = LibraryLoadProgress(
                    step: 4,
                    totalSteps: 4,
                    title: "Opening archive",
                    detail: "Preparing the first transcript window before showing the archive."
                )
                await loadSelectedConversationIfNeeded()
            }

            accessState = .ready
            await refreshSearchResults()
        } catch {
            conversations = []
            await applyLoadFailure(error)
        }
    }

    private func resolvedConversations(from sourceConversations: [Conversation]) -> [Conversation] {
        sourceConversations.map { conversation in
            let participants = conversation.participants.map(contactIdentityResolver.resolvedParticipant(_:))
            return Conversation(
                id: conversation.id,
                title: contactIdentityResolver.resolvedConversationTitle(for: conversation, participants: participants),
                participants: participants,
                snippet: conversation.snippet,
                lastActivityAt: conversation.lastActivityAt,
                messageCount: conversation.messageCount,
                mediaCount: conversation.mediaCount,
                isPinned: conversation.isPinned
            )
        }
    }

    private func loadTranscriptWindow(range: Range<Int>) async {
        guard let detail = selectedArchiveDetail else { return }
        let count = detail.messageIndex.count
        guard count > 0 else {
            transcriptWindow = 0..<0
            transcriptMessages = []
            return
        }

        let lower = max(0, min(range.lowerBound, count))
        let upper = max(lower, min(range.upperBound, count))

        do {
            if detail.summary.kind == .thread, let conversationID = selectedConversationID {
                let slice = try await source.loadMessages(conversationID: conversationID, range: lower..<upper)
                transcriptWindow = slice.range
                transcriptMessages = slice.messages
            } else {
                let sliceEntries = Array(detail.messageIndex[lower..<upper])
                let orderedIDs = sliceEntries.map(\.id)
                let entriesByConversation = Dictionary(grouping: sliceEntries, by: \.conversationID)
                var mergedMessages: [Message] = []

                for (conversationID, entries) in entriesByConversation {
                    let indexes = entries.map(\.sourceIndex)
                    guard let first = indexes.min(), let last = indexes.max() else { continue }
                    let slice = try await source.loadMessages(conversationID: conversationID, range: first..<(last + 1))
                    let neededIDs = Set(entries.map(\.id))
                    mergedMessages.append(contentsOf: slice.messages.filter { neededIDs.contains($0.id) })
                }

                let ordering = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
                transcriptWindow = lower..<upper
                transcriptMessages = mergedMessages.sorted {
                    (ordering[$0.id] ?? 0) < (ordering[$1.id] ?? 0)
                }
            }
        } catch {
            await applyLoadFailure(error)
        }
    }

    private func restoreOrLoadTranscriptWindow(for detail: ArchiveDetail) async {
        let count = detail.messageIndex.count
        guard count > 0 else {
            transcriptWindow = 0..<0
            transcriptMessages = []
            activeTranscriptAnchor = .latest
            return
        }

        if let cached = archiveSessionStates[detail.summary.id],
           isRestorableTranscriptWindow(cached.transcriptWindow, totalCount: count) {
            await applySessionState(cached, for: detail.summary)
            contentMode = .transcript
            return
        }

        let lower = max(0, count - transcriptWindowSize)
        timelineAnchorDate = detail.summary.lastActivityAt
        dateJumpTarget = detail.summary.lastActivityAt
        activeTranscriptAnchor = .latest
        selectedMessageID = nil
        highlightedMessageID = nil
        await loadTranscriptWindow(range: lower..<count)
    }

    private func persistCurrentArchiveState() {
        guard let archiveID = selectedArchiveSummary?.id,
              let detail = selectedArchiveDetail,
              detail.messageIndex.isEmpty == false,
              transcriptWindow.isEmpty == false else {
            return
        }

        let state = ConversationSessionState(
            transcriptWindow: transcriptWindow,
            selectedMessageID: selectedMessageID,
            timelineAnchorDate: timelineAnchorDate,
            activeAnchor: activeTranscriptAnchor
        )
        archiveSessionStates[archiveID] = state
    }

    private func saveJumpOrigin(label: String) {
        guard let origin = currentArchiveOrigin() else {
            return
        }

        restoreJumpOrigin(origin, label: label)
    }

    private func clearJumpOrigin() {
        jumpOriginArchiveID = nil
        jumpOriginState = nil
        jumpOriginDescription = nil
    }

    private func messagesForExport() async throws -> [Message] {
        guard let detail = selectedArchiveDetail else { return [] }

        switch exportScope {
        case .entireConversation:
            if detail.summary.kind == .thread, let conversationID = selectedConversationID {
                let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<detail.messageIndex.count)
                return slice.messages
            }
            return try await allMessages(for: detail)
        case .currentLoadedRange:
            return transcriptMessages
        case .customDateRange:
            let allMessages = try await allMessages(for: detail)
            return allMessages.filter { message in
                message.sentAt >= exportRangeStart && message.sentAt <= exportRangeEnd
            }
        }
    }

    private func suggestedExportFilename(for archive: ArchiveSummary) -> String {
        let safeTitle = archive.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safeTitle)-archive.\(exportFormat.fileExtension)"
    }

    private func utType(for format: ExportFormat) -> UTType {
        switch format {
        case .pdf:
            return .pdf
        case .json:
            return .json
        case .docx:
            return UTType(filenameExtension: "docx") ?? .data
        }
    }

    private func exportData(for messages: [Message], archive: ArchiveSummary) throws -> Data {
        switch exportFormat {
        case .json:
            return try jsonExportData(for: messages, archive: archive)
        case .pdf:
            return pdfExportData(for: messages, archive: archive)
        case .docx:
            return try docxExportData(for: messages, archive: archive)
        }
    }

    private func jsonExportData(for messages: [Message], archive: ArchiveSummary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let payload = ConversationExportPayload(
            conversationTitle: archive.title,
            exportedAt: .now,
            scope: exportScope.label,
            format: exportFormat.label,
            participants: exportIncludesParticipants ? archive.participants.map(\.displayName) : [],
            messages: messages.map { message in
                ConversationExportMessage(
                    sender: message.sender?.displayName ?? "System",
                    sentAt: exportIncludesTimestamps ? message.sentAt : nil,
                    body: exportIncludesMessages ? message.body : "",
                    attachments: exportedAttachmentNames(for: message),
                    reactions: exportIncludesReactions ? message.reactions.map { $0.kind.symbol } : []
                )
            }
        )

        return try encoder.encode(payload)
    }

    private func pdfExportData(for messages: [Message], archive: ArchiveSummary) -> Data {
        let attributed = transcriptAttributedString(for: messages, archive: archive)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.isEditable = false
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.textContainer?.containerSize = NSSize(width: 556, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textStorage?.setAttributedString(attributed)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedHeight = (textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 736) + 56
        textView.frame = NSRect(x: 0, y: 0, width: 612, height: max(792, usedHeight))
        return textView.dataWithPDF(inside: textView.bounds)
    }

    private func docxExportData(for messages: [Message], archive: ArchiveSummary) throws -> Data {
        let attributed = transcriptAttributedString(for: messages, archive: archive)
        return try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
    }

    private func transcriptAttributedString(for messages: [Message], archive: ArchiveSummary) -> NSAttributedString {
        let body = NSMutableAttributedString()
        let title = "\(archive.title)\n"
        body.append(NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold)
        ]))

        body.append(NSAttributedString(string: "\(currentArchiveSubtitle)\n\(archiveRangeSummary)\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))

        for message in messages {
            let sender = message.sender?.displayName ?? "System"
            let timestamp = exportIncludesTimestamps ? "  \(message.sentAt.compactDateTimeLabel)" : ""
            body.append(NSAttributedString(string: "\(sender)\(timestamp)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))

            if exportIncludesMessages, !message.body.isEmpty {
                body.append(NSAttributedString(string: "\(message.body)\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 13)
                ]))
            }

            let attachments = exportedAttachmentNames(for: message)
            if !attachments.isEmpty {
                body.append(NSAttributedString(string: "Attachments: \(attachments.joined(separator: ", "))\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
            }

            if exportIncludesReactions, !message.reactions.isEmpty {
                let reactionSummary = message.reactions.map { $0.kind.symbol }.joined(separator: " ")
                body.append(NSAttributedString(string: "Reactions: \(reactionSummary)\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
            }

            body.append(NSAttributedString(string: "\n"))
        }

        return body
    }

    private func exportedAttachmentNames(for message: Message) -> [String] {
        message.attachments.compactMap { attachment in
            switch attachment.kind {
            case .image, .video:
                return exportIncludesPhotos ? attachment.filename : nil
            case .link:
                return exportIncludesLinks ? attachment.filename : nil
            case .file:
                return exportIncludesAttachments ? attachment.filename : nil
            }
        }
    }

    private func transcriptRange(around index: Int, totalCount: Int) -> Range<Int> {
        let half = transcriptWindowSize / 2
        let lower = max(0, index - half)
        let upper = min(totalCount, lower + transcriptWindowSize)
        return lower..<upper
    }

    private func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
    }

    private func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 24 * 60 * 60)
    }

    private func yearInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 24 * 60 * 60)
    }

    private func makeDayBuckets(in interval: DateInterval, entries: [ArchiveMessageIndexEntry]) -> [TimelineBucket] {
        (0..<7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: interval.start),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }

            let count = entries.lazy.filter { $0.sentAt >= start && $0.sentAt < end }.count
            return TimelineBucket(startDate: start, endDate: end, messageCount: count)
        }
    }

    private func makeWeekBuckets(in interval: DateInterval, entries: [ArchiveMessageIndexEntry]) -> [TimelineBucket] {
        var buckets: [TimelineBucket] = []
        var current = interval.start

        while current < interval.end {
            let next = min(calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? interval.end, interval.end)
            let count = entries.lazy.filter { $0.sentAt >= current && $0.sentAt < next }.count
            buckets.append(TimelineBucket(startDate: current, endDate: next, messageCount: count))
            current = next
        }

        return buckets
    }

    private func makeMonthBuckets(in interval: DateInterval, entries: [ArchiveMessageIndexEntry]) -> [TimelineBucket] {
        var buckets: [TimelineBucket] = []
        var current = interval.start

        while current < interval.end {
            let next = min(calendar.date(byAdding: .month, value: 1, to: current) ?? interval.end, interval.end)
            let count = entries.lazy.filter { $0.sentAt >= current && $0.sentAt < next }.count
            buckets.append(TimelineBucket(startDate: current, endDate: next, messageCount: count))
            current = next
        }

        return buckets
    }

    private func updateConversationMetrics(from detail: ConversationDetail) {
        guard let index = conversations.firstIndex(where: { $0.id == detail.conversation.id }) else { return }
        let updated = conversations[index].updatingCounts(
            messageCount: detail.messageIndex.count,
            mediaCount: detail.mediaAssets.count
        )
        conversations[index] = updated
        detailCache[detail.conversation.id] = ConversationDetail(
            conversation: updated,
            messageIndex: detail.messageIndex,
            attachmentItems: detail.attachmentItems
        )
    }

    private func updateTimelineSnapshot(for detail: ArchiveDetail) {
        timelineNavigationSnapshots[detail.summary.id] = TimelineNavigationSnapshot(
            messageIndex: detail.messageIndex.map { MessageIndexEntry(id: $0.id, guid: $0.guid, sentAt: $0.sentAt) },
            calendar: calendar
        )
    }

    private func timelineSnapshot(for archiveID: String) -> TimelineNavigationSnapshot? {
        if let snapshot = timelineNavigationSnapshots[archiveID] {
            return snapshot
        }

        guard let detail = archiveDetailCache[archiveID] else { return nil }
        return TimelineNavigationSnapshot(
            messageIndex: detail.messageIndex.map { MessageIndexEntry(id: $0.id, guid: $0.guid, sentAt: $0.sentAt) },
            calendar: calendar
        )
    }

    private func threadArchiveID(for conversationID: UUID) -> String {
        "thread:\(conversationID.uuidString)"
    }

    private func personArchiveID(for conversationID: UUID) -> String? {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else { return nil }
        return personArchiveID(for: conversation)
    }

    private func defaultPersonArchiveID(for conversation: Conversation) -> String {
        "person:\(personIdentityKey(for: conversation))"
    }

    private func personArchiveID(for conversation: Conversation) -> String {
        if let decision = mergeDecisions[conversation.id] {
            return decision.personArchiveID
        }

        return defaultPersonArchiveID(for: conversation)
    }

    private func personArchiveTitle(for conversations: [Conversation]) -> String {
        let names = conversations.flatMap { conversation in
            conversation.participants
                .map(\.displayName)
                .filter { $0 != "You" && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if let first = names.first {
            let unique = Array(NSOrderedSet(array: names)) as? [String] ?? names
            return unique.count == 1 ? first : unique.joined(separator: ", ")
        }

        return conversations.first?.title ?? "Person Archive"
    }

    private func linkedHandles(for participants: [Participant]) -> [String] {
        let handles = participants
            .map(\.handle)
            .filter { normalizedIdentityToken($0) != nil && $0 != "me" }

        return Array(NSOrderedSet(array: handles)) as? [String] ?? handles
    }

    private func mergeParticipants(from conversations: [Conversation]) -> [Participant] {
        let flattened = conversations.flatMap(\.participants)
        var seenHandles = Set<String>()
        var merged: [Participant] = []

        for participant in flattened {
            let key = participant.handle.isEmpty ? participant.displayName : participant.handle
            if seenHandles.insert(key).inserted {
                merged.append(participant)
            }
        }

        return merged
    }

    private func archiveSummary(for archiveID: String) -> ArchiveSummary? {
        visibleSidebarArchives.first(where: { $0.id == archiveID }) ??
        threadArchives.first(where: { $0.id == archiveID }) ??
        personArchives.first(where: { $0.id == archiveID })
    }

    private func applyInitialArchiveSelection() {
        if let pendingRestoredSession {
            sidebarMode = pendingRestoredSession.sidebarMode
            switch pendingRestoredSession.archiveKind {
            case .thread:
                let restoredConversationID = pendingRestoredSession.representativeConversationID
                    ?? UUID(uuidString: pendingRestoredSession.archiveID.replacingOccurrences(of: "thread:", with: ""))
                if let restoredConversationID,
                   conversations.contains(where: { $0.id == restoredConversationID }) {
                    selectedConversationID = restoredConversationID
                    selectedPersonArchiveID = nil
                    applyRestoredArchiveSession(
                        archiveID: threadArchiveID(for: restoredConversationID),
                        session: pendingRestoredSession
                    )
                }
            case .person:
                let restoredArchive = personArchives.first(where: { $0.id == pendingRestoredSession.archiveID }) ??
                    pendingRestoredSession.representativeConversationID
                    .flatMap(personArchiveID(for:))
                    .flatMap { archiveID in personArchives.first(where: { $0.id == archiveID }) }
                if let summary = restoredArchive {
                    selectedPersonArchiveID = summary.id
                    selectedConversationID = summary.representativeConversationID
                    applyRestoredArchiveSession(archiveID: summary.id, session: pendingRestoredSession)
                }
            }
        }

        if selectedConversationID == nil, let firstArchive = visibleSidebarArchives.first {
            selectedConversationID = firstArchive.representativeConversationID
            selectedPersonArchiveID = firstArchive.kind == .person ? firstArchive.id : nil
            timelineAnchorDate = firstArchive.lastActivityAt
            dateJumpTarget = firstArchive.lastActivityAt
        }

        pendingRestoredSession = nil
    }

    private func loadArchiveDetail(for summary: ArchiveSummary) async throws -> ArchiveDetail {
        switch summary.kind {
        case .thread:
            let detail = try await cachedConversationDetail(summary.representativeConversationID)
            updateConversationMetrics(from: detail)
            return ArchiveDetail(
                summary: summary,
                messageIndex: detail.messageIndex.enumerated().map { index, entry in
                    ArchiveMessageIndexEntry(
                        id: entry.id,
                        guid: entry.guid,
                        conversationID: summary.representativeConversationID,
                        sourceIndex: index,
                        sentAt: entry.sentAt
                    )
                },
                attachmentItems: detail.attachmentItems
            )
        case .person:
            var messageIndex: [ArchiveMessageIndexEntry] = []
            var attachmentItems: [AttachmentItem] = []

            for conversationID in summary.conversationIDs {
                let detail = try await cachedConversationDetail(conversationID)
                updateConversationMetrics(from: detail)
                messageIndex.append(contentsOf: detail.messageIndex.enumerated().map { index, entry in
                    ArchiveMessageIndexEntry(
                        id: entry.id,
                        guid: entry.guid,
                        conversationID: conversationID,
                        sourceIndex: index,
                        sentAt: entry.sentAt
                    )
                })
                attachmentItems.append(contentsOf: detail.attachmentItems)
            }

            messageIndex.sort { lhs, rhs in
                if lhs.sentAt == rhs.sentAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.sentAt < rhs.sentAt
            }
            attachmentItems.sort { lhs, rhs in
                if lhs.sentAt == rhs.sentAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.sentAt < rhs.sentAt
            }

            return ArchiveDetail(summary: summary, messageIndex: messageIndex, attachmentItems: attachmentItems)
        }
    }

    private func cachedConversationDetail(_ conversationID: UUID) async throws -> ConversationDetail {
        if let cached = detailCache[conversationID] {
            return cached
        }

        let detail = try await source.loadConversationDetail(id: conversationID)
        detailCache[conversationID] = detail
        return detail
    }

    private func allMessages(for detail: ArchiveDetail) async throws -> [Message] {
        if detail.summary.kind == .thread, let conversationID = selectedConversationID {
            let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<detail.messageIndex.count)
            return slice.messages
        }

        var messages: [Message] = []
        for conversationID in detail.summary.conversationIDs {
            let conversationDetail = try await cachedConversationDetail(conversationID)
            let slice = try await source.loadMessages(conversationID: conversationID, range: 0..<conversationDetail.messageIndex.count)
            messages.append(contentsOf: slice.messages)
        }

        return messages.sorted {
            if $0.sentAt == $1.sentAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.sentAt < $1.sentAt
        }
    }

    public func refreshSearchResults() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        let archiveResults = visibleSidebarArchives
            .filter { archive in
                archive.title.localizedCaseInsensitiveContains(query) ||
                archive.secondaryText.localizedCaseInsensitiveContains(query) ||
                archive.linkedHandles.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            }
            .prefix(8)
            .map { archive in
                ArchiveSearchResult(
                    id: "conversation:\(archive.id)",
                    kind: .conversation,
                    conversationID: archive.representativeConversationID,
                    archiveTitle: archive.title,
                    title: archive.title,
                    subtitle: archive.secondaryText,
                    sentAt: archive.lastActivityAt
                )
            }

        do {
            let contentResults = try await source.searchLibrary(query: query, scope: searchScope, limit: 28)
            let normalizedResults = (archiveResults + contentResults).map(normalizedSearchResult(_:))
            searchResults = deduplicatedSearchResults(normalizedResults).sorted(by: searchResultOrder(_:_:))
            isSearching = false
            AppTelemetry.search.info("Updated search results for scope \(self.searchScope.rawValue, privacy: .public)")
        } catch {
            searchResults = deduplicatedSearchResults(archiveResults.map(normalizedSearchResult(_:)))
            isSearching = false
            AppTelemetry.search.error("Search failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func activateSearchResult(_ result: ArchiveSearchResult) async {
        let origin = currentArchiveOrigin()
        let archive = preferredArchive(for: result)
        await selectArchive(archive)

        AppTelemetry.search.info("Activated \(result.kind.rawValue, privacy: .public) search result")

        switch result.kind {
        case .conversation:
            selectedMediaAssetID = nil
            contentMode = .transcript
        case .message:
            selectedMediaAssetID = nil
            if let messageID = result.messageID {
                await focusTranscript(on: messageID, anchor: .search(messageID), rememberOrigin: false)
            }
        case .media, .link, .attachment:
            selectedMediaAssetID = nil
            if let messageID = result.messageID {
                await focusTranscript(on: messageID, anchor: .search(messageID), rememberOrigin: false)
                if let attachmentID = result.attachmentID {
                    selectedMediaAssetID = selectedArchiveDetail?.mediaAssets.first(where: { $0.attachment.id == attachmentID })?.id
                }
            }
        }

        if let origin,
           origin.archiveID != selectedArchiveSummary?.id || result.kind != .conversation {
            restoreJumpOrigin(origin, label: "Back to search result origin")
        }
    }

    public func setSidebarMode(_ mode: SidebarMode) async {
        guard sidebarMode != mode else { return }
        persistCurrentArchiveState()
        sidebarMode = mode

        switch mode {
        case .threads:
            selectedPersonArchiveID = nil
        case .people:
            selectedPersonArchiveID = selectedConversationID.flatMap(personArchiveID(for:))
        }

        AppTelemetry.archive.info("Switched sidebar mode to \(mode.rawValue, privacy: .public)")
        await loadSelectedConversationIfNeeded()
        await refreshSearchResults()
        persistSessionIfPossible()
    }

    public func previewTimelineJump(to date: Date) {
        pendingTimelineDate = date
        isTimelineScrubbing = true
    }

    public func commitTimelineJump() async {
        guard let pendingTimelineDate else {
            isTimelineScrubbing = false
            return
        }

        AppTelemetry.timeline.info("Committed timeline jump")
        self.pendingTimelineDate = nil
        isTimelineScrubbing = false
        await jumpToDay(pendingTimelineDate)
    }

    public func cancelTimelineJumpPreview() {
        pendingTimelineDate = nil
        isTimelineScrubbing = false
    }

    public func applyMergeDecision(_ action: MergeDecisionAction) async {
        guard let selectedConversationID,
              let persistenceCoordinator else { return }

        let personArchiveID: String
        switch action {
        case .keepSeparate:
            personArchiveID = "person:separate:\(selectedConversationID.uuidString)"
        case .alwaysMerge:
            if let conversation = conversations.first(where: { $0.id == selectedConversationID }) {
                personArchiveID = defaultPersonArchiveID(for: conversation)
            } else {
                personArchiveID = "person:\(selectedConversationID.uuidString)"
            }
        }

        do {
            try persistenceCoordinator.saveMergeDecision(
                conversationID: selectedConversationID,
                personArchiveID: personArchiveID,
                action: action
            )
            mergeDecisions[selectedConversationID] = (personArchiveID, action)
            archiveDetailCache = [:]
            timelineNavigationSnapshots = [:]
            AppTelemetry.merge.info("Saved merge decision \(action.rawValue, privacy: .public)")
            if action == .alwaysMerge {
                sidebarMode = .people
                selectedPersonArchiveID = personArchiveID
            }
            await loadSelectedConversationIfNeeded()
            persistSessionIfPossible()
        } catch {
            AppTelemetry.merge.error("Failed to save merge decision: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyLoadFailure(_ error: Error) async {
        if let presentable = error as? MessagesLoadErrorPresentable {
            failureTitle = presentable.failureTitle
            failureCode = presentable.failureCode
            failureDescription = presentable.failureDescription
            failureRecoverySteps = presentable.recoverySteps
        } else {
            failureTitle = "Unable to Load Library"
            failureCode = "IRM-APP-000"
            failureDescription = error.localizedDescription
            failureRecoverySteps = []
        }

        setupSnapshot = await source.inspectSetup()
        accessState = .failed(failureDescription)
    }

    private func preferredArchive(for result: ArchiveSearchResult) -> ArchiveSummary? {
        if sidebarMode == .people,
           let personArchiveID = personArchiveID(for: result.conversationID),
           let personArchive = personArchives.first(where: { $0.id == personArchiveID }) {
            return personArchive
        }

        return threadArchives.first(where: { $0.representativeConversationID == result.conversationID })
    }

    private func searchResultOrder(_ lhs: ArchiveSearchResult, _ rhs: ArchiveSearchResult) -> Bool {
        if lhs.kind != rhs.kind {
            return searchResultPriority(lhs.kind) < searchResultPriority(rhs.kind)
        }

        switch (lhs.sentAt, rhs.sentAt) {
        case let (.some(left), .some(right)):
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.title < rhs.title
        }
    }

    private func currentArchiveOrigin() -> ArchiveNavigationOrigin? {
        guard let archiveID = selectedArchiveSummary?.id,
              let detail = selectedArchiveDetail,
              detail.messageIndex.isEmpty == false,
              transcriptWindow.isEmpty == false else {
            return nil
        }

        return ArchiveNavigationOrigin(
            archiveID: archiveID,
            state: ConversationSessionState(
                transcriptWindow: transcriptWindow,
                selectedMessageID: selectedMessageID,
                timelineAnchorDate: timelineAnchorDate,
                activeAnchor: activeTranscriptAnchor
            )
        )
    }

    private func restoreJumpOrigin(_ origin: ArchiveNavigationOrigin, label: String) {
        jumpOriginArchiveID = origin.archiveID
        jumpOriginState = origin.state
        jumpOriginDescription = label
    }

    private func isRestorableTranscriptWindow(_ window: Range<Int>, totalCount: Int) -> Bool {
        window.lowerBound >= 0 &&
        window.upperBound > window.lowerBound &&
        window.upperBound <= totalCount
    }

    private func applySessionState(_ state: ConversationSessionState, for summary: ArchiveSummary) async {
        timelineAnchorDate = state.timelineAnchorDate
        dateJumpTarget = state.timelineAnchorDate
        activeTranscriptAnchor = state.activeAnchor
        await loadTranscriptWindow(range: state.transcriptWindow)
        applyLoadedMessageSelection(state.selectedMessageID)
        archiveSessionStates[summary.id] = state
    }

    private func applyLoadedMessageSelection(_ messageID: UUID?) {
        guard let messageID,
              transcriptMessages.contains(where: { $0.id == messageID }) else {
            selectedMessageID = nil
            highlightedMessageID = nil
            scrollTargetMessageID = nil
            return
        }

        selectedMessageID = messageID
        highlightedMessageID = messageID
        scrollTargetMessageID = messageID
    }

    private func applyRestoredArchiveSession(archiveID: String, session: RestoredAppSession) {
        timelineAnchorDate = session.timelineAnchorDate
        dateJumpTarget = session.timelineAnchorDate
        activeTranscriptAnchor = session.activeAnchor
        transcriptWindow = session.transcriptWindow
        selectedMessageID = session.selectedMessageID
        archiveSessionStates[archiveID] = ConversationSessionState(
            transcriptWindow: session.transcriptWindow,
            selectedMessageID: session.selectedMessageID,
            timelineAnchorDate: session.timelineAnchorDate,
            activeAnchor: session.activeAnchor
        )
    }

    private func normalizedSearchResult(_ result: ArchiveSearchResult) -> ArchiveSearchResult {
        guard let archive = preferredArchive(for: result) else { return result }

        if result.kind == .conversation {
            return ArchiveSearchResult(
                id: "conversation:\(archive.id)",
                kind: result.kind,
                conversationID: archive.representativeConversationID,
                messageID: result.messageID,
                attachmentID: result.attachmentID,
                archiveTitle: archive.title,
                title: archive.title,
                subtitle: archive.secondaryText,
                sentAt: archive.lastActivityAt
            )
        }

        return ArchiveSearchResult(
            id: result.id,
            kind: result.kind,
            conversationID: result.conversationID,
            messageID: result.messageID,
            attachmentID: result.attachmentID,
            archiveTitle: archive.title,
            title: result.title,
            subtitle: result.subtitle,
            sentAt: result.sentAt
        )
    }

    private func deduplicatedSearchResults(_ results: [ArchiveSearchResult]) -> [ArchiveSearchResult] {
        var seen = Set<String>()
        var deduplicated: [ArchiveSearchResult] = []

        for result in results {
            let key: String
            switch result.kind {
            case .conversation:
                key = "conversation:\(preferredArchive(for: result)?.id ?? threadArchiveID(for: result.conversationID))"
            case .message:
                key = "message:\(result.messageID?.uuidString ?? result.id)"
            case .media, .link, .attachment:
                key = "\(result.kind.rawValue):\(result.attachmentID?.uuidString ?? result.messageID?.uuidString ?? result.id)"
            }

            if seen.insert(key).inserted {
                deduplicated.append(result)
            }
        }

        return Array(deduplicated.prefix(36))
    }

    private func searchResultPriority(_ kind: SearchResultKind) -> Int {
        switch kind {
        case .conversation:
            return 0
        case .message:
            return 1
        case .media:
            return 2
        case .link:
            return 3
        case .attachment:
            return 4
        }
    }

    private func personIdentityKey(for conversation: Conversation) -> String {
        let remoteParticipants = conversation.participants.filter { participant in
            participant.handle != "me" && participant.displayName != "You"
        }

        if remoteParticipants.count == 1,
           let contactKey = contactIdentityResolver.contactIdentityKey(for: remoteParticipants[0].handle) {
            return "contact:\(contactKey)"
        }

        if remoteParticipants.count == 1, let component = participantIdentityComponent(for: remoteParticipants[0]) {
            return "contact:\(component)"
        }

        let participantComponents = remoteParticipants.compactMap { participant in
            participantIdentityComponent(for: participant)
        }
        if !participantComponents.isEmpty {
            return "group:\(participantComponents.sorted().joined(separator: "|"))"
        }

        if let normalizedTitle = normalizedIdentityToken(conversation.title) {
            return "title:\(normalizedTitle)"
        }

        return "conversation:\(conversation.id.uuidString.lowercased())"
    }

    private func participantIdentityComponent(for participant: Participant) -> String? {
        if let contactKey = contactIdentityResolver.contactIdentityKey(for: participant.handle) {
            return "contact:\(contactKey)"
        }

        if let normalizedName = normalizedIdentityToken(participant.displayName), normalizedName != "you" {
            return normalizedName
        }

        return normalizedIdentityToken(participant.handle)
    }

    private func normalizedIdentityToken(_ value: String) -> String? {
        normalizedIdentityLookupToken(value)
    }
}

@MainActor
protocol ContactIdentityResolving: AnyObject {
    var accessState: ContactIdentityAccessState { get }
    func prepare(for strategy: SourceStrategy) async
    func resolvedParticipant(_ participant: Participant) -> Participant
    func resolvedConversationTitle(for conversation: Conversation, participants: [Participant]) -> String
    func contactIdentityKey(for handle: String) -> String?
}

@MainActor
final class SystemContactIdentityResolver: ContactIdentityResolving {
    private struct Match {
        let contactKey: String
        let displayName: String
    }

    private(set) var accessState: ContactIdentityAccessState = .notDetermined
    private var matchesByHandle: [String: Match] = [:]

    func prepare(for strategy: SourceStrategy) async {
        guard strategy == .liveBrowse else {
            accessState = .unavailable
            matchesByHandle = [:]
            return
        }

        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            accessState = .authorized
            break
        case .limited:
            accessState = .limited
            break
        case .notDetermined:
            accessState = .notDetermined
            let granted = await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                accessState = .denied
                matchesByHandle = [:]
                return
            }
            accessState = .authorized
        case .denied:
            accessState = .denied
            matchesByHandle = [:]
            return
        case .restricted:
            accessState = .restricted
            matchesByHandle = [:]
            return
        @unknown default:
            accessState = .unavailable
            matchesByHandle = [:]
            return
        }

        matchesByHandle = loadMatches(from: store)
    }

    func resolvedParticipant(_ participant: Participant) -> Participant {
        guard participant.handle != "me" else {
            return participant
        }

        if let match = match(for: participant.handle),
           participant.displayName != match.displayName {
            return Participant(
                id: participant.id,
                displayName: match.displayName,
                handle: participant.handle,
                accentColorName: participant.accentColorName
            )
        }

        let fallbackDisplayName = fallbackDisplayName(for: participant.handle)
        guard let fallbackDisplayName,
              participant.displayName == participant.handle || looksLikeRawHandle(participant.displayName) else {
            return participant
        }

        return Participant(
            id: participant.id,
            displayName: fallbackDisplayName,
            handle: participant.handle,
            accentColorName: participant.accentColorName
        )
    }

    func resolvedConversationTitle(for conversation: Conversation, participants: [Participant]) -> String {
        let remoteParticipants = participants.filter { $0.handle != "me" && $0.displayName != "You" }
        let trimmedTitle = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedTitle.isEmpty, shouldPreserveConversationTitle(trimmedTitle, for: conversation) {
            return trimmedTitle
        }

        if !remoteParticipants.isEmpty {
            return remoteParticipants.map(\.displayName).joined(separator: ", ")
        }

        return trimmedTitle.isEmpty ? "Conversation" : trimmedTitle
    }

    func contactIdentityKey(for handle: String) -> String? {
        match(for: handle)?.contactKey
    }

    private func loadMatches(from store: CNContactStore) -> [String: Match] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        var matches: [String: Match] = [:]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true

        try? store.enumerateContacts(with: request) { contact, _ in
            let displayName = resolvedContactDisplayName(for: contact)
            guard !displayName.isEmpty else { return }

            let match = Match(contactKey: contact.identifier.lowercased(), displayName: displayName)
            for email in contact.emailAddresses {
                register(handle: String(email.value), match: match, into: &matches)
            }
            for phone in contact.phoneNumbers {
                register(handle: phone.value.stringValue, match: match, into: &matches)
            }
        }

        return matches
    }

    private func register(handle: String, match: Match, into matches: inout [String: Match]) {
        for key in contactLookupKeys(for: handle) where matches[key] == nil {
            matches[key] = match
        }
    }

    private func match(for handle: String) -> Match? {
        for key in contactLookupKeys(for: handle) {
            if let match = matchesByHandle[key] {
                return match
            }
        }

        return nil
    }

    private func resolvedContactDisplayName(for contact: CNContact) -> String {
        if let formatted = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !formatted.isEmpty {
            return formatted
        }

        let organization = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return organization
    }

    private func shouldPreserveConversationTitle(_ title: String, for conversation: Conversation) -> Bool {
        let remoteParticipants = conversation.participants.filter { $0.handle != "me" && $0.displayName != "You" }
        guard remoteParticipants.count == 1 else { return true }

        let normalizedTitle = normalizedIdentityLookupToken(title)
        let matchesOriginalIdentity = remoteParticipants.contains { participant in
            normalizedIdentityLookupToken(participant.handle) == normalizedTitle ||
            normalizedIdentityLookupToken(participant.displayName) == normalizedTitle
        }

        if matchesOriginalIdentity {
            return false
        }

        return !looksLikeRawHandle(title)
    }

    private func looksLikeRawHandle(_ value: String) -> Bool {
        if value.contains("@") {
            return true
        }

        let digits = value.filter(\.isNumber)
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return digits.count >= 7 && letters == 0
    }

    private func fallbackDisplayName(for handle: String) -> String? {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let emailLocalPart = trimmed.split(separator: "@", maxSplits: 1).first, trimmed.contains("@") {
            let formatted = emailLocalPart
                .split(whereSeparator: { [".", "_", "-", "+"].contains($0) })
                .map { token in
                    token.prefix(1).uppercased() + token.dropFirst().lowercased()
                }
                .joined(separator: " ")

            return formatted.isEmpty ? nil : formatted
        }

        return nil
    }
}

private func contactLookupKeys(for value: String) -> [String] {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return [] }

    if trimmed.contains("@") {
        return ["email:\(trimmed)"]
    }

    let digits = trimmed.filter(\.isNumber)
    if !digits.isEmpty {
        return phoneLookupKeys(for: digits)
    }

    return ["id:\(normalizedIdentityLookupToken(trimmed) ?? trimmed)"]
}

private func phoneLookupKeys(for digits: String) -> [String] {
    guard !digits.isEmpty else { return [] }

    var variants: [String] = []
    func append(_ candidate: String) {
        guard !candidate.isEmpty else { return }
        let key = "phone:\(candidate)"
        if !variants.contains(key) {
            variants.append(key)
        }
    }

    append(digits)

    let strippedIDD: String
    if digits.hasPrefix("0011"), digits.count > 4 {
        strippedIDD = String(digits.dropFirst(4))
        append(strippedIDD)
    } else if digits.hasPrefix("00"), digits.count > 2 {
        strippedIDD = String(digits.dropFirst(2))
        append(strippedIDD)
    } else {
        strippedIDD = digits
    }

    if strippedIDD.hasPrefix("61"), strippedIDD.count > 2 {
        let national = String(strippedIDD.dropFirst(2))
        append("0" + national)
    }

    if strippedIDD.hasPrefix("0"), strippedIDD.count > 1 {
        append("61" + strippedIDD.dropFirst())
    }

    return variants
}

private func normalizedIdentityLookupToken(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let lowered = trimmed.lowercased()
    let allowed = lowered.unicodeScalars.filter { scalar in
        CharacterSet.alphanumerics.contains(scalar)
    }
    let normalized = String(String.UnicodeScalarView(allowed))
    return normalized.isEmpty ? nil : normalized
}

private struct ConversationExportPayload: Codable {
    let conversationTitle: String
    let exportedAt: Date
    let scope: String
    let format: String
    let participants: [String]
    let messages: [ConversationExportMessage]
}

private struct ConversationExportMessage: Codable {
    let sender: String
    let sentAt: Date?
    let body: String
    let attachments: [String]
    let reactions: [String]
}

public struct SampleMessagesSource: MessagesSource {
    public let strategy: SourceStrategy = .hybrid
    public let libraryModeName = "Sample Library"
    public let libraryModeDescription = "Bundled sample data for UI development and tests."
    public let sourceLocations: [SourceLocation] = []

    private let records: [UUID: SampleConversationRecord]

    public init() {
        self.records = SampleLibraryFactory.makeLibrary()
    }

    public func inspectSetup() async -> SourceSetupSnapshot {
        SourceSetupSnapshot(
            title: "Explore the sample library",
            detail: "Use bundled sample data when the live Messages library is unavailable.",
            requirements: [
                SetupRequirement(
                    id: "sample-ready",
                    title: "Sample library is ready",
                    detail: "No additional setup is required.",
                    state: .complete
                )
            ],
            locations: []
        )
    }

    public func bootstrapLibrary(progressHandler: (@Sendable (LibraryLoadProgress) -> Void)?) async throws -> LibrarySnapshot {
        progressHandler?(
            LibraryLoadProgress(
                step: 1,
                totalSteps: 2,
                title: "Preparing sample library",
                detail: "Loading bundled conversations."
            )
        )
        try await Task.sleep(for: .milliseconds(120))
        progressHandler?(
            LibraryLoadProgress(
                step: 2,
                totalSteps: 2,
                title: "Finishing setup",
                detail: "The sample library is ready."
            )
        )
        return LibrarySnapshot(conversations: records.values.map(\.detail.conversation))
    }

    public func loadConversationDetail(id: UUID) async throws -> ConversationDetail {
        try await Task.sleep(for: .milliseconds(60))
        guard let record = records[id] else {
            throw NSError(domain: "iRemember.SampleSource", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Conversation not found."
            ])
        }
        return record.detail
    }

    public func loadMessages(conversationID: UUID, range: Range<Int>) async throws -> TranscriptSlice {
        try await Task.sleep(for: .milliseconds(40))
        guard let record = records[conversationID] else {
            throw NSError(domain: "iRemember.SampleSource", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Conversation not found."
            ])
        }

        let lower = max(0, min(range.lowerBound, record.messages.count))
        let upper = max(lower, min(range.upperBound, record.messages.count))
        return TranscriptSlice(messages: Array(record.messages[lower..<upper]), range: lower..<upper, totalCount: record.messages.count)
    }

    public func searchLibrary(query: String, scope: SearchScope, limit: Int) async throws -> [ArchiveSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [ArchiveSearchResult] = []

        for record in records.values {
            let conversation = record.detail.conversation

            if results.count < limit &&
                (
                    conversation.title.localizedCaseInsensitiveContains(trimmed) ||
                    conversation.snippet.localizedCaseInsensitiveContains(trimmed)
                ) {
                results.append(
                    ArchiveSearchResult(
                        id: "conversation:\(conversation.id.uuidString)",
                        kind: .conversation,
                        conversationID: conversation.id,
                        archiveTitle: conversation.title,
                        title: conversation.title,
                        subtitle: conversation.snippet,
                        sentAt: conversation.lastActivityAt
                    )
                )
            }

            for message in record.messages where results.count < limit {
                let messageMatches = switch scope {
                case .all, .messages:
                    message.body.localizedCaseInsensitiveContains(trimmed)
                case .people:
                    message.sender?.displayName.localizedCaseInsensitiveContains(trimmed) == true
                case .media:
                    false
                case .links:
                    false
                case .attachments:
                    false
                }

                if messageMatches {
                    results.append(
                        ArchiveSearchResult(
                            id: "message:\(message.id.uuidString)",
                            kind: .message,
                            conversationID: conversation.id,
                            messageID: message.id,
                            archiveTitle: conversation.title,
                            title: message.sender?.displayName ?? conversation.title,
                            subtitle: message.body,
                            sentAt: message.sentAt
                        )
                    )
                }

                for attachment in message.attachments where results.count < limit {
                    let kind = switch attachment.kind {
                    case .image, .video: SearchResultKind.media
                    case .link: SearchResultKind.link
                    case .file: SearchResultKind.attachment
                    }

                    let attachmentMatches = switch scope {
                    case .all:
                        attachment.filename.localizedCaseInsensitiveContains(trimmed)
                    case .messages, .people:
                        false
                    case .media:
                        kind == .media && attachment.filename.localizedCaseInsensitiveContains(trimmed)
                    case .links:
                        kind == .link && attachment.filename.localizedCaseInsensitiveContains(trimmed)
                    case .attachments:
                        kind == .attachment && attachment.filename.localizedCaseInsensitiveContains(trimmed)
                    }

                    if attachmentMatches {
                        results.append(
                            ArchiveSearchResult(
                                id: "\(kind.rawValue):\(attachment.id.uuidString)",
                                kind: kind,
                                conversationID: conversation.id,
                                messageID: message.id,
                                attachmentID: attachment.id,
                                archiveTitle: conversation.title,
                                title: attachment.filename,
                                subtitle: message.body,
                                sentAt: message.sentAt
                            )
                        )
                    }
                }
            }

            if results.count >= limit {
                break
            }
        }

        return Array(results.prefix(limit))
    }
}

struct SampleConversationRecord {
    let detail: ConversationDetail
    let messages: [Message]
}

enum SampleLibraryFactory {
    static func makeLibrary() -> [UUID: SampleConversationRecord] {
        let me = Participant(displayName: "You", handle: "me", accentColorName: "blue")
        let alex = Participant(displayName: "Alex Chen", handle: "alex@example.com", accentColorName: "teal")
        let alexMobile = Participant(displayName: "Alex Chen", handle: "+61 412 555 010", accentColorName: "teal")
        let mom = Participant(displayName: "Mum", handle: "mum@example.com", accentColorName: "pink")
        let dad = Participant(displayName: "Dad", handle: "dad@example.com", accentColorName: "orange")
        let casey = Participant(displayName: "Casey", handle: "casey@example.com", accentColorName: "green")

        let direct = buildConversation(
            title: "Alex Chen",
            participants: [me, alex],
            daysBack: 320,
            baseMessages: [
                "Do you still have the photo from the coast trip?",
                "I found the reservation email, but not the screenshots.",
                "Let’s keep the receipts together in case we need them later.",
                "This one belongs in the annual memory archive.",
                "I can export the images tonight if you want."
            ],
            attachmentEvery: 7,
            pinned: true
        )

        let alexFollowUp = buildConversation(
            title: "Alex Chen",
            participants: [me, alexMobile],
            daysBack: 470,
            baseMessages: [
                "I switched numbers, but I still have the old trip photos.",
                "Can you keep this thread merged with the other Alex archive?",
                "The migration receipt is in the file attachment here.",
                "This should land in the same person archive as the earlier conversation.",
                "I’m sending another export-friendly screenshot."
            ],
            attachmentEvery: 8,
            pinned: false
        )

        let family = buildConversation(
            title: "Family",
            participants: [me, mom, dad],
            daysBack: 540,
            baseMessages: [
                "Uploading the birthday photos now.",
                "Can someone save the recipe notes from this thread?",
                "The appointment confirmation is in the attachment above.",
                "We should keep a clean archive for family records.",
                "Adding the scanned copy here for later."
            ],
            attachmentEvery: 5,
            pinned: false
        )

        let project = buildConversation(
            title: "Casey",
            participants: [me, casey],
            daysBack: 210,
            baseMessages: [
                "The contractor sent another site photo.",
                "Let’s pin the quote and invoice references somewhere else too.",
                "I need the message context around that video before sending it on.",
                "This is why time-based browsing matters.",
                "We’ll want all media grouped by month."
            ],
            attachmentEvery: 6,
            pinned: false
        )

        return [
            direct.detail.conversation.id: direct,
            alexFollowUp.detail.conversation.id: alexFollowUp,
            family.detail.conversation.id: family,
            project.detail.conversation.id: project
        ]
    }

    private static func buildConversation(
        title: String,
        participants: [Participant],
        daysBack: Int,
        baseMessages: [String],
        attachmentEvery: Int,
        pinned: Bool
    ) -> SampleConversationRecord {
        let conversationID = UUID()
        let me = participants[0]
        let others = Array(participants.dropFirst())
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: .now) ?? .now

        var messages: [Message] = []
        var attachmentItems: [AttachmentItem] = []

        for index in 0..<max(180, daysBack / 2) {
            let dayOffset = index * 2
            let sentAt = calendar.date(
                byAdding: .minute,
                value: (index * 43) % 1000,
                to: calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            ) ?? startDate

            let isOutgoing = index.isMultiple(of: 2)
            let sender = isOutgoing ? me : others[index % max(1, others.count)]
            let direction: MessageDirection = isOutgoing ? .outgoing : .incoming
            let body = "\(baseMessages[index % baseMessages.count]) [\(index + 1)]"

            var attachments: [Attachment] = []
            if index.isMultiple(of: attachmentEvery) {
                let kind: AttachmentKind = index.isMultiple(of: attachmentEvery * 2) ? .image : .video
                attachments.append(
                    Attachment(
                        kind: kind,
                        filename: "\(title.replacingOccurrences(of: " ", with: "_").lowercased())_\(index).\(kind == .image ? "jpg" : "mov")",
                        uti: kind == .image ? "public.jpeg" : "public.movie",
                        byteSize: 420_000 + (index * 23_100),
                        sentAt: sentAt
                    )
                )
            }

            if index.isMultiple(of: attachmentEvery + 4) {
                attachments.append(
                    Attachment(
                        kind: .link,
                        filename: "archive-reference-\(index).link",
                        uti: "public.url",
                        byteSize: 2_048,
                        sentAt: sentAt
                    )
                )
            }

            if index.isMultiple(of: attachmentEvery + 9) {
                attachments.append(
                    Attachment(
                        kind: .file,
                        filename: "notes-\(index).pdf",
                        uti: "com.adobe.pdf",
                        byteSize: 95_000 + (index * 200),
                        sentAt: sentAt
                    )
                )
            }

            let message = Message(
                guid: "sample-\(conversationID.uuidString)-\(index)",
                conversationID: conversationID,
                sender: sender,
                body: body,
                sentAt: sentAt,
                direction: direction,
                attachments: attachments
            )

            messages.append(message)

            for attachment in attachments {
                attachmentItems.append(
                    AttachmentItem(
                        conversationID: conversationID,
                        messageID: message.id,
                        attachment: attachment,
                        sender: sender,
                        sentAt: sentAt,
                        contextSnippet: body
                    )
                )
            }
        }

        if messages.count > 20 {
            let base = messages[8]
            let reply = messages[14]
            messages[14] = Message(
                id: reply.id,
                guid: reply.guid,
                conversationID: reply.conversationID,
                sender: reply.sender,
                body: reply.body,
                sentAt: reply.sentAt,
                direction: reply.direction,
                attachments: reply.attachments,
                replyContext: MessageReplyContext(
                    referencedMessageGUID: base.guid ?? "",
                    quotedText: base.body,
                    quotedSender: base.sender?.displayName
                ),
                reactions: reply.reactions
            )

            let reacted = messages[11]
            messages[11] = Message(
                id: reacted.id,
                guid: reacted.guid,
                conversationID: reacted.conversationID,
                sender: reacted.sender,
                body: reacted.body,
                sentAt: reacted.sentAt,
                direction: reacted.direction,
                attachments: reacted.attachments,
                replyContext: reacted.replyContext,
                reactions: [
                    MessageReaction(sender: others.first, kind: .liked),
                    MessageReaction(sender: me, kind: .loved)
                ]
            )
        }

        messages.sort { $0.sentAt < $1.sentAt }
        attachmentItems.sort { $0.sentAt < $1.sentAt }

        let conversation = Conversation(
            id: conversationID,
            title: title,
            participants: participants,
            snippet: messages.last?.body ?? "",
            lastActivityAt: messages.last?.sentAt ?? .now,
            messageCount: messages.count,
            mediaCount: attachmentItems.compactMap(\.mediaAsset).count,
            isPinned: pinned
        )

        return SampleConversationRecord(
            detail: ConversationDetail(
                conversation: conversation,
                messageIndex: messages.map { MessageIndexEntry(id: $0.id, guid: $0.guid, sentAt: $0.sentAt) },
                attachmentItems: attachmentItems
            ),
            messages: messages
        )
    }
}
