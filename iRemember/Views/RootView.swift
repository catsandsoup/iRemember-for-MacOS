import SwiftUI

struct RootView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Group {
            switch appModel.accessState {
            case .onboarding:
                OnboardingView(appModel: appModel)
            case .loading:
                LibraryLoadingView(appModel: appModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                LibraryFailureView(appModel: appModel, message: message)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                mainShell
            }
        }
        .task {
            await appModel.bootstrapIfNeeded()
        }
        .sheet(isPresented: $appModel.isDateJumpPresented) {
            DateJumpSheet(appModel: appModel)
        }
    }

    private var mainShell: some View {
        HSplitView {
            if appModel.isSidebarVisible {
                SidebarView(appModel: appModel)
                    .frame(minWidth: 236, idealWidth: 268, maxWidth: 308, maxHeight: .infinity)
                    .accessibilityIdentifier("sidebar-pane")
            }

            ConversationContentView(appModel: appModel)
                .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("content-pane")

            if appModel.isInspectorVisible {
                InspectorView(appModel: appModel)
                    .frame(minWidth: 260, idealWidth: 292, maxWidth: 328, maxHeight: .infinity)
                    .accessibilityIdentifier("inspector-pane")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: "Search transcript or media")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        appModel.toggleSidebarVisibility()
                    }
                } label: {
                    Label(appModel.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                }
                .help(appModel.isSidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityIdentifier("sidebar-toggle")

                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        appModel.toggleInspectorVisibility()
                    }
                } label: {
                    Label(appModel.isInspectorVisible ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
                .help(appModel.isInspectorVisible ? "Hide inspector" : "Show inspector")
                .accessibilityIdentifier("inspector-toggle")
            }
        }
        .animation(.smooth(duration: 0.18), value: appModel.contentMode)
        .animation(.smooth(duration: 0.18), value: appModel.isSidebarVisible)
        .animation(.smooth(duration: 0.18), value: appModel.isInspectorVisible)
        .task(id: appModel.selectedConversationID) {
            await appModel.loadSelectedConversationIfNeeded()
        }
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
                .disabled(appModel.selectedDetail == nil)
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

                SettingsLink {
                    Label("App Settings", systemImage: "gearshape")
                }
                .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
