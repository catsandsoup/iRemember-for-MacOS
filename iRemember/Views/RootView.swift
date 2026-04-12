import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @SceneStorage("workspace.timelineVisibility") private var isTimelineVisible = true
    @Bindable var appModel: AppModel

    var body: some View {
        rootContent
        .task {
            appModel.configurePersistence(with: AppPersistenceCoordinator(modelContext: modelContext))
            await appModel.bootstrapIfNeeded()
        }
        .task(id: "\(appModel.searchText)|\(appModel.searchScope.rawValue)|\(appModel.sidebarMode.rawValue)") {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await appModel.refreshSearchResults()
        }
        .sheet(isPresented: $appModel.isDateJumpPresented) {
            DateJumpSheet(appModel: appModel)
        }
        .sheet(isPresented: $appModel.isExportSheetPresented) {
            ExportSheet(appModel: appModel)
        }
        .sheet(isPresented: mediaViewerPresented) {
            MediaViewerSheet(appModel: appModel)
        }
        .onChange(of: appModel.isInspectorVisible) { _, _ in
            appModel.persistSessionIfPossible()
        }
        .onChange(of: appModel.contentMode) { _, _ in
            appModel.persistSessionIfPossible()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch appModel.accessState {
        case .onboarding:
            if appModel.setupSnapshot.isReady {
                starterShell
            } else {
                OnboardingView(appModel: appModel)
            }
        case .loading:
            LibraryLoadingView(appModel: appModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            LibraryFailureView(appModel: appModel, message: message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            readyShell
        }
    }

    private var readyShell: some View {
        workspaceShell(isLibraryLoaded: true)
    }

    private var starterShell: some View {
        ConversationContentView(appModel: appModel, isTimelineVisible: $isTimelineVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func workspaceShell(isLibraryLoaded: Bool) -> some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            SidebarView(appModel: appModel)
                .modifier(SidebarSearchModifier(enabled: isLibraryLoaded, appModel: appModel))
                .accessibilityIdentifier("sidebar-pane")
        } detail: {
            workspaceDetail(isLibraryLoaded: isLibraryLoaded)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            if isLibraryLoaded {
                ReadyToolbar(appModel: appModel, isTimelineVisible: $isTimelineVisible)
            }
        }
        .toolbar(removing: .title)
        .focusedSceneValue(\.workspaceTimelineVisibility, $isTimelineVisible)
        .focusedSceneValue(\.workspaceContentMode, appModel.contentMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func workspaceDetail(isLibraryLoaded: Bool) -> some View {
        ConversationContentView(appModel: appModel, isTimelineVisible: $isTimelineVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(WorkspaceInspectorModifier(enabled: isLibraryLoaded, appModel: appModel))
            .accessibilityIdentifier("content-pane")
    }

    private var mediaViewerPresented: Binding<Bool> {
        Binding(
            get: {
                appModel.isMediaViewerPresented && appModel.selectedMediaAsset != nil
            },
            set: { newValue in
                if !newValue {
                    appModel.dismissMediaViewer()
                }
            }
        )
    }
}

private struct SidebarSearchModifier: ViewModifier {
    let enabled: Bool
    @Bindable var appModel: AppModel

    func body(content: Content) -> some View {
        if enabled {
            content.searchable(
                text: Binding(
                    get: { appModel.searchText },
                    set: { appModel.searchText = DisplayText.searchQuery($0) }
                ),
                placement: .sidebar,
                prompt: "Search messages, contacts, and files"
            )
        } else {
            content
        }
    }
}

private struct WorkspaceInspectorModifier: ViewModifier {
    let enabled: Bool
    @Bindable var appModel: AppModel

    func body(content: Content) -> some View {
        if enabled {
            content
                .inspector(isPresented: $appModel.isInspectorVisible) {
                    InspectorView(appModel: appModel)
                        .accessibilityIdentifier("inspector-pane")
                }
                .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
        } else {
            content
        }
    }
}

private struct ReadyToolbar: ToolbarContent {
    @Bindable var appModel: AppModel
    @Binding var isTimelineVisible: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ArchiveToolbarTitleView(appModel: appModel)
        }

        ToolbarItemGroup {
            if appModel.selectedArchiveSummary != nil {
                Picker("View", selection: $appModel.contentMode) {
                    ForEach(ContentMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityIdentifier("content-mode-picker")
                .help("Choose the main view")
            }

            Button("Jump to Date", systemImage: "calendar") {
                appModel.isDateJumpPresented = true
            }
            .labelStyle(.iconOnly)
            .disabled(appModel.selectedArchiveSummary == nil)
            .help("Jump to a date")
        }

        ToolbarItemGroup {
            if appModel.selectedArchiveSummary != nil, appModel.contentMode == .transcript {
                Button(isTimelineVisible ? "Hide Timeline" : "Show Timeline", systemImage: "clock") {
                    isTimelineVisible.toggle()
                }
                .labelStyle(.iconOnly)
                .help(isTimelineVisible ? "Hide the timeline panel" : "Show the timeline panel")
                .accessibilityLabel(isTimelineVisible ? "Hide timeline" : "Show timeline")
            }

            ExportToolbarMenu(appModel: appModel)

            Button(appModel.isInspectorVisible ? "Hide Details" : "Show Details", systemImage: "info.circle") {
                appModel.toggleInspectorVisibility()
            }
            .labelStyle(.iconOnly)
            .disabled(appModel.accessState != .ready)
            .help(appModel.isInspectorVisible ? "Hide conversation details" : "Show conversation details")
        }
    }
}

private struct ArchiveToolbarTitleView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        if let archive = appModel.selectedArchiveSummary {
            ViewThatFits {
                HStack(spacing: 8) {
                    Text(archive.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(appModel.currentArchiveSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                VStack(spacing: 1) {
                    Text(archive.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(appModel.currentArchiveSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: 240, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text("Conversations")
                .font(.headline)
        }
    }
}

private struct ExportToolbarMenu: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Menu {
            Button("Export Conversation") {
                appModel.presentExport(scope: .entireConversation, format: .pdf)
            }

            Button("Export Loaded Range") {
                appModel.presentExport(scope: .currentLoadedRange, format: .pdf)
            }

            Button("Export JSON Archive") {
                appModel.presentExport(scope: .entireConversation, format: .json)
            }

            Button("Export DOCX") {
                appModel.presentExport(scope: .entireConversation, format: .docx)
            }

            Button("Export Shared Content") {
                appModel.presentSharedContentExport()
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .labelStyle(.iconOnly)
        }
        .disabled(appModel.selectedArchiveSummary == nil)
        .help("Export this conversation")
    }
}

private struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Archive")
                .font(.title2.weight(.semibold))

            Picker("Format", selection: $appModel.exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Picker("Scope", selection: $appModel.exportScope) {
                ForEach(ExportScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }

            if appModel.exportScope == .customDateRange {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $appModel.exportRangeStart, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("To", selection: $appModel.exportRangeEnd, displayedComponents: [.date, .hourAndMinute])
                }
            }

            GroupBox("Include") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Messages", isOn: $appModel.exportIncludesMessages)
                    Toggle("Photos", isOn: $appModel.exportIncludesPhotos)
                    Toggle("Links", isOn: $appModel.exportIncludesLinks)
                    Toggle("Attachments", isOn: $appModel.exportIncludesAttachments)
                    Toggle("Reactions", isOn: $appModel.exportIncludesReactions)
                    Toggle("Timestamps", isOn: $appModel.exportIncludesTimestamps)
                    Toggle("Participants", isOn: $appModel.exportIncludesParticipants)
                }
                .padding(.top, 4)
            }

            if let lastExportDescription = appModel.lastExportDescription {
                Text(lastExportDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Export") {
                    Task {
                        await appModel.performExport()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.selectedArchiveSummary == nil)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

private struct LibraryLoadingView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        SetupAssistantContainer {
            VStack(alignment: .leading, spacing: 14) {
                ProgressView(value: appModel.loadingProgress.fractionCompleted ?? 0)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                Text(appModel.loadingProgress.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(appModel.loadingProgress.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } content: {
            SetupCard(
                title: "What the app is doing",
                subtitle: "Conversation metadata loads before full transcripts so large histories stay bounded."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Current step \(max(appModel.loadingProgress.step, 1)) of \(max(appModel.loadingProgress.totalSteps, 1))", systemImage: "list.number")
                    if let unitDescription = appModel.loadingProgress.unitDescription {
                        Label(unitDescription, systemImage: "text.magnifyingglass")
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(elapsedDescription(at: context.date), systemImage: "clock")
                            .foregroundStyle(.secondary)
                    }

                    Text("If your Mac keeps a very large Messages history, the conversation scan can take a while on first open.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } actions: {
            HStack(spacing: 12) {
                OpenPrivacySettingsButton()

                if appModel.canUseSampleFallback {
                    Button("Use Sample Library Instead") {
                        Task { await appModel.loadSampleLibrary() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func elapsedDescription(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(appModel.loadingStartedAt)))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "Elapsed %d:%02d", minutes, remainingSeconds)
    }
}

private struct DateJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Jump to Date")
                .font(.title2.weight(.semibold))

            DatePicker(
                "Target date",
                selection: $appModel.dateJumpTarget,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)

            Text("The transcript window is repositioned around the closest indexed message without preloading the full thread.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Jump") {
                    Task { await appModel.performDateJump() }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.selectedArchiveDetail == nil)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct LibraryFailureView: View {
    @Bindable var appModel: AppModel
    let message: String

    var body: some View {
        SetupAssistantContainer {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.orange)

                Text(appModel.failureTitle)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                SetupCard(
                    title: "Next step",
                    subtitle: "Use the checklist below to recover, then try the library again."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(appModel.setupSnapshot.requirements) { requirement in
                            SetupRequirementRow(requirement: requirement)
                        }
                    }
                }

                SetupCard(title: "Recovery", subtitle: "Code \(appModel.failureCode)") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appModel.failureRecoverySteps, id: \.self) { step in
                            Label(step, systemImage: "arrow.right")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SourceLocationsDisclosure(
                            locations: appModel.sourceLocations,
                            technicalDetails: appModel.failureDescription == message ? nil : appModel.failureDescription
                        )
                    }
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button("Try Again") {
                        Task { await appModel.retryCurrentLibrary() }
                    }
                    .buttonStyle(.borderedProminent)

                    OpenPrivacySettingsButton()

                    if appModel.canUseSampleFallback {
                        Button("Use Sample Library") {
                            Task { await appModel.loadSampleLibrary() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
