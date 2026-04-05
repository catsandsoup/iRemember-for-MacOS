import Foundation
import Observation

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
}

public extension MessagesSource {
    func bootstrapLibrary() async throws -> LibrarySnapshot {
        try await bootstrapLibrary(progressHandler: nil)
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
        case .transcript: "Transcript"
        case .media: "Media"
        }
    }
}

public struct DaySection: Identifiable, Hashable, Sendable {
    public let id: Date
    public let title: String
    public let messages: [Message]
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
    public var selectedMessageID: UUID?
    public var selectedMediaAssetID: UUID?
    public var searchText = ""
    public var searchScope: SearchScope = .all
    public var contentMode: ContentMode = .transcript
    public var mediaFilter: MediaFilter = .all
    public var timelineRange: TimelineRange = .month
    public var timelineHeight: Double = 80
    public var dateJumpTarget = Date.now
    public var timelineAnchorDate = Date.now
    public var isDateJumpPresented = false
    public var isSidebarVisible = true
    public var isInspectorVisible = true
    public var isTimelineCollapsed = false
    public private(set) var transcriptWindow: Range<Int> = 0..<0
    public var scrollTargetMessageID: UUID?
    public private(set) var didBootstrap = false

    public private(set) var sourceStrategy: SourceStrategy
    public private(set) var sourceModeName: String
    public private(set) var sourceModeDescription: String
    public private(set) var sourceLocations: [SourceLocation]

    private let transcriptWindowSize = 160
    private let calendar = Calendar.autoupdatingCurrent

    private let primarySource: any MessagesSource
    private let sampleFallback: (any MessagesSource)?
    private var source: any MessagesSource

    public init(source: any MessagesSource, sampleFallback: (any MessagesSource)? = nil) {
        self.primarySource = source
        self.sampleFallback = sampleFallback
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
        guard let id = selectedConversationID else { return nil }
        return conversations.first(where: { $0.id == id })
    }

    public var selectedDetail: ConversationDetail? {
        guard let id = selectedConversationID else { return nil }
        return detailCache[id]
    }

    public var selectedMessage: Message? {
        guard let id = selectedMessageID else { return nil }
        return transcriptMessages.first(where: { $0.id == id })
    }

    public var visibleMessages: [Message] {
        guard !searchText.isEmpty else { return transcriptMessages }
        return transcriptMessages.filter(matchesSearch(_:))
    }

    public var canLoadEarlierMessages: Bool {
        searchText.isEmpty && transcriptWindow.lowerBound > 0
    }

    public var canLoadLaterMessages: Bool {
        guard let detail = selectedDetail else { return false }
        return searchText.isEmpty && transcriptWindow.upperBound < detail.messageIndex.count
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
        guard let detail = selectedDetail else { return [] }
        let base: [MediaAsset]

        switch mediaFilter {
        case .all:
            base = detail.mediaAssets
        case .images:
            base = detail.mediaAssets.filter { $0.attachment.kind == .image }
        case .videos:
            base = detail.mediaAssets.filter { $0.attachment.kind == .video }
        }

        guard !searchText.isEmpty else { return base }
        return base.filter(matchesSearch(_:))
    }

    public var linkAttachmentItems: [AttachmentItem] {
        guard let detail = selectedDetail else { return [] }
        return detail.attachmentItems.filter { $0.attachment.kind == .link }
    }

    public var selectedMediaAsset: MediaAsset? {
        guard let id = selectedMediaAssetID else { return nil }
        return selectedDetail?.mediaAssets.first(where: { $0.id == id })
    }

    public var timelineBuckets: [TimelineBucket] {
        guard let detail = selectedDetail, !detail.messageIndex.isEmpty else { return [] }
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

    public var visibleMessageRangeDescription: String {
        guard let first = transcriptMessages.first?.sentAt, let last = transcriptMessages.last?.sentAt else {
            return "No messages loaded"
        }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let rangeText = formatter.string(from: first, to: last)

        guard let detail = selectedDetail else { return rangeText }
        let lower = transcriptWindow.lowerBound + 1
        let upper = transcriptWindow.upperBound
        return "\(rangeText) • \(lower)-\(upper) of \(detail.messageIndex.count)"
    }

    public var canUseSampleFallback: Bool {
        sampleFallback != nil
    }

    public func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        setupSnapshot = await primarySource.inspectSetup()
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
        guard let id = selectedConversationID else { return }

        do {
            let detail: ConversationDetail
            if let cached = detailCache[id] {
                detail = cached
            } else {
                detail = try await source.loadConversationDetail(id: id)
                detailCache[id] = detail
            }

            updateConversationMetrics(from: detail)

            timelineAnchorDate = detail.conversation.lastActivityAt
            dateJumpTarget = detail.conversation.lastActivityAt
            await ensureTranscriptWindow()
        } catch {
            await applyLoadFailure(error)
        }
    }

    public func ensureTranscriptWindow() async {
        guard let detail = selectedDetail else {
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

        if transcriptWindow.isEmpty || transcriptWindow.upperBound > count {
            let lower = max(0, count - transcriptWindowSize)
            await loadTranscriptWindow(range: lower..<count)
        } else if transcriptMessages.isEmpty {
            await loadTranscriptWindow(range: transcriptWindow)
        }
    }

    public func loadEarlierMessages() async {
        guard selectedDetail != nil else { return }
        let newLower = max(0, transcriptWindow.lowerBound - transcriptWindowSize / 2)
        let range = newLower..<transcriptWindow.upperBound
        await loadTranscriptWindow(range: range)
        scrollTargetMessageID = transcriptMessages.first?.id
    }

    public func loadLaterMessages() async {
        guard let detail = selectedDetail else { return }
        let newUpper = min(detail.messageIndex.count, transcriptWindow.upperBound + transcriptWindowSize / 2)
        let range = transcriptWindow.lowerBound..<newUpper
        await loadTranscriptWindow(range: range)
        scrollTargetMessageID = transcriptMessages.last?.id
    }

    public func performDateJump() async {
        guard let detail = selectedDetail, !detail.messageIndex.isEmpty else { return }

        let target = detail.messageIndex.min { lhs, rhs in
            abs(lhs.sentAt.timeIntervalSince(dateJumpTarget)) < abs(rhs.sentAt.timeIntervalSince(dateJumpTarget))
        }

        guard let target else { return }
        await focusTranscript(on: target.id)
    }

    public func focusTranscript(on messageID: UUID) async {
        guard let detail = selectedDetail else { return }
        guard let index = detail.messageIndex.firstIndex(where: { $0.id == messageID }) else { return }

        let range = transcriptRange(around: index, totalCount: detail.messageIndex.count)
        await loadTranscriptWindow(range: range)

        if let message = transcriptMessages.first(where: { $0.id == messageID }) {
            selectMessage(message)
            scrollTargetMessageID = messageID
            contentMode = .transcript
        }
    }

    public func revealMediaInTranscript(_ asset: MediaAsset) async {
        selectedMediaAssetID = asset.id
        timelineAnchorDate = asset.sentAt
        dateJumpTarget = asset.sentAt
        await focusTranscript(on: asset.messageID)
    }

    public func selectConversation(_ id: UUID?) async {
        selectedConversationID = id
        selectedMessageID = nil
        selectedMediaAssetID = nil
        transcriptWindow = 0..<0
        transcriptMessages = []
        await loadSelectedConversationIfNeeded()
    }

    public func selectMessage(_ message: Message) {
        selectedMessageID = message.id
        timelineAnchorDate = message.sentAt
        dateJumpTarget = message.sentAt
    }

    public func jumpToDay(_ date: Date) async {
        guard let detail = selectedDetail, !detail.messageIndex.isEmpty else { return }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        if let target = detail.messageIndex.first(where: { $0.sentAt >= start && $0.sentAt < end }) {
            timelineAnchorDate = target.sentAt
            dateJumpTarget = target.sentAt
            await focusTranscript(on: target.id)
            return
        }

        dateJumpTarget = date
        timelineAnchorDate = date
        await performDateJump()
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
    }

    public func jumpToTimelineBucket(_ bucket: TimelineBucket) async {
        timelineAnchorDate = bucket.startDate
        dateJumpTarget = bucket.startDate
        await jumpToDay(bucket.startDate)
    }

    public func setTimelineHeight(_ proposedHeight: Double) {
        timelineHeight = min(max(proposedHeight, 68), 220)
    }

    public func toggleSidebarVisibility() {
        isSidebarVisible.toggle()
    }

    public func toggleInspectorVisibility() {
        isInspectorVisible.toggle()
    }

    public func toggleTimelineVisibility() {
        isTimelineCollapsed.toggle()
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
        selectedMessageID = nil
        selectedMediaAssetID = nil
        detailCache = [:]
        transcriptMessages = []
        transcriptWindow = 0..<0

        do {
            let snapshot = try await source.bootstrapLibrary(progressHandler: { progress in
                Task { @MainActor [weak self] in
                    self?.loadingProgress = progress
                }
            })
            conversations = snapshot.conversations
            setupSnapshot = await source.inspectSetup()
            accessState = .ready

            if selectedConversationID == nil {
                selectedConversationID = conversations.first?.id
                timelineAnchorDate = conversations.first?.lastActivityAt ?? .now
                dateJumpTarget = timelineAnchorDate
            }

            await loadSelectedConversationIfNeeded()
        } catch {
            conversations = []
            await applyLoadFailure(error)
        }
    }

    private func loadTranscriptWindow(range: Range<Int>) async {
        guard let detail = selectedDetail, let conversationID = selectedConversationID else { return }
        let count = detail.messageIndex.count
        guard count > 0 else {
            transcriptWindow = 0..<0
            transcriptMessages = []
            return
        }

        let lower = max(0, min(range.lowerBound, count))
        let upper = max(lower, min(range.upperBound, count))

        do {
            let slice = try await source.loadMessages(conversationID: conversationID, range: lower..<upper)
            transcriptWindow = slice.range
            transcriptMessages = slice.messages
        } catch {
            await applyLoadFailure(error)
        }
    }

    private func transcriptRange(around index: Int, totalCount: Int) -> Range<Int> {
        let half = transcriptWindowSize / 2
        let lower = max(0, index - half)
        let upper = min(totalCount, lower + transcriptWindowSize)
        return lower..<upper
    }

    private func matchesSearch(_ message: Message) -> Bool {
        switch searchScope {
        case .all:
            return message.body.localizedCaseInsensitiveContains(searchText) ||
            message.sender?.displayName.localizedCaseInsensitiveContains(searchText) == true ||
            message.attachments.contains { $0.filename.localizedCaseInsensitiveContains(searchText) }
        case .text:
            return message.body.localizedCaseInsensitiveContains(searchText)
        case .people:
            return message.sender?.displayName.localizedCaseInsensitiveContains(searchText) == true
        case .attachments:
            return message.attachments.contains { attachment in
                attachment.filename.localizedCaseInsensitiveContains(searchText) ||
                attachment.kind.label.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func matchesSearch(_ asset: MediaAsset) -> Bool {
        switch searchScope {
        case .all:
            return asset.contextSnippet.localizedCaseInsensitiveContains(searchText) ||
            asset.sender?.displayName.localizedCaseInsensitiveContains(searchText) == true ||
            asset.attachment.filename.localizedCaseInsensitiveContains(searchText)
        case .text:
            return asset.contextSnippet.localizedCaseInsensitiveContains(searchText)
        case .people:
            return asset.sender?.displayName.localizedCaseInsensitiveContains(searchText) == true
        case .attachments:
            return asset.attachment.filename.localizedCaseInsensitiveContains(searchText) ||
            asset.attachment.kind.label.localizedCaseInsensitiveContains(searchText)
        }
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

    private func makeDayBuckets(in interval: DateInterval, entries: [MessageIndexEntry]) -> [TimelineBucket] {
        (0..<7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: interval.start),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }

            let count = entries.lazy.filter { $0.sentAt >= start && $0.sentAt < end }.count
            return TimelineBucket(startDate: start, endDate: end, messageCount: count)
        }
    }

    private func makeWeekBuckets(in interval: DateInterval, entries: [MessageIndexEntry]) -> [TimelineBucket] {
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

    private func makeMonthBuckets(in interval: DateInterval, entries: [MessageIndexEntry]) -> [TimelineBucket] {
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
}

struct SampleConversationRecord {
    let detail: ConversationDetail
    let messages: [Message]
}

enum SampleLibraryFactory {
    static func makeLibrary() -> [UUID: SampleConversationRecord] {
        let me = Participant(displayName: "You", handle: "me", accentColorName: "blue")
        let alex = Participant(displayName: "Alex Chen", handle: "alex@example.com", accentColorName: "teal")
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
                messageIndex: messages.map { MessageIndexEntry(id: $0.id, sentAt: $0.sentAt) },
                attachmentItems: attachmentItems
            ),
            messages: messages
        )
    }
}
