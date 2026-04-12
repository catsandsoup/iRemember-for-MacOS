import SwiftUI
import SwiftData

@main
struct IRememberApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PersistedAppSession.self,
            PersistedMergeDecision.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
        }
    }()

    @State private var appModel = AppModel(
        source: SQLiteMessagesSource(),
        sampleFallback: SampleMessagesSource()
    )

    var body: some Scene {
        WindowGroup("iRemember for Messages") {
            RootView(appModel: appModel)
                .frame(minWidth: AppChrome.workspaceMinWidth, minHeight: AppChrome.workspaceMinHeight)
                .task {
                    await SnapshotExportController.exportIfRequested(appModel: appModel)
                }
        }
        .defaultSize(width: 1380, height: 860)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultWindowPlacement { _, context in
            let displayBounds = context.defaultDisplay.visibleRect
            let size = fittedMainWindowSize(
                for: CGSize(width: 1380, height: 860),
                in: displayBounds
            )
            return WindowPlacement(size: size)
        }
        .windowIdealPlacement { _, context in
            let displayBounds = context.defaultDisplay.visibleRect
            let size = fittedMainWindowSize(
                for: CGSize(
                    width: min(displayBounds.width * 0.94, 1480),
                    height: min(displayBounds.height * 0.92, 980)
                ),
                in: displayBounds
            )
            return WindowPlacement(size: size)
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView(appModel: appModel)
                .frame(width: 620, height: 460)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            SidebarCommands()
            InspectorCommands()
            WorkspaceTimelineCommands()

            CommandGroup(after: .sidebar) {
                Button("Browse by Conversation") {
                    Task { await appModel.setSidebarMode(.threads) }
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)

                Button("Browse by Contact") {
                    Task { await appModel.setSidebarMode(.people) }
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)
            }

            CommandGroup(after: .importExport) {
                Button("Export Conversation…") {
                    appModel.presentExport(scope: .entireConversation)
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(appModel.selectedArchiveSummary == nil)

                Button("Export Loaded Range…") {
                    appModel.presentExport(scope: .currentLoadedRange)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(appModel.selectedArchiveSummary == nil)
            }

            CommandMenu("Archive") {
                Button("Export PDF Archive…") {
                    appModel.presentExport(scope: .entireConversation, format: .pdf)
                }
                .disabled(appModel.selectedArchiveSummary == nil)

                Button("Export JSON Archive…") {
                    appModel.presentExport(scope: .entireConversation, format: .json)
                }
                .disabled(appModel.selectedArchiveSummary == nil)

                Button("Export DOCX Archive…") {
                    appModel.presentExport(scope: .entireConversation, format: .docx)
                }
                .disabled(appModel.selectedArchiveSummary == nil)

                Button("Export Shared Content…") {
                    appModel.presentSharedContentExport()
                }
                .disabled(appModel.selectedArchiveSummary == nil)
            }

            CommandMenu("Navigate") {
                Button("Jump to Date") {
                    appModel.isDateJumpPresented = true
                }
                .keyboardShortcut("j", modifiers: [.command])
                .disabled(appModel.selectedArchiveSummary == nil)

                Divider()

                Button("Show Messages") {
                    appModel.contentMode = .transcript
                }
                .keyboardShortcut("3", modifiers: [.command])
                .disabled(appModel.accessState != .ready)

                Button("Show Shared Media") {
                    appModel.contentMode = .media
                }
                .keyboardShortcut("4", modifiers: [.command])
                .disabled(appModel.accessState != .ready)

                Divider()

                Button("Previous Day") {
                    Task { await appModel.moveTimelineSelection(byDays: -1) }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(appModel.selectedArchiveSummary == nil)

                Button("Next Day") {
                    Task { await appModel.moveTimelineSelection(byDays: 1) }
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(appModel.selectedArchiveSummary == nil)
            }
        }
    }
}

private func fittedMainWindowSize(for proposedSize: CGSize, in displayBounds: CGRect) -> CGSize {
    CGSize(
        width: min(max(proposedSize.width, AppChrome.workspaceMinWidth), min(displayBounds.width * 0.95, 1560)),
        height: min(max(proposedSize.height, AppChrome.workspaceMinHeight), min(displayBounds.height * 0.92, 980))
    )
}
