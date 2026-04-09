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
                .frame(minWidth: 1320, minHeight: 760)
                .task {
                    await SnapshotExportController.exportIfRequested(appModel: appModel)
                }
        }
        .defaultSize(width: 1320, height: 860)
        .defaultWindowPlacement { content, context in
            let displayBounds = context.defaultDisplay.visibleRect
            let size = fittedMainWindowSize(for: content.sizeThatFits(.unspecified), in: displayBounds)
            return WindowPlacement(size: size)
        }
        .windowIdealPlacement { content, context in
            let displayBounds = context.defaultDisplay.visibleRect
            let proposal = ProposedViewSize(
                width: min(displayBounds.width * 0.94, 1480),
                height: min(displayBounds.height * 0.92, 980)
            )
            let size = fittedMainWindowSize(for: content.sizeThatFits(proposal), in: displayBounds)
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

            CommandMenu("View") {
                Button(appModel.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    appModel.toggleInspectorVisibility()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)

                Divider()

                Button("View by Threads") {
                    Task { await appModel.setSidebarMode(.threads) }
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)

                Button("View by People") {
                    Task { await appModel.setSidebarMode(.people) }
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)
            }

            CommandMenu("File") {
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

            CommandMenu("iRemember") {
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

                Button("Show Transcript") {
                    appModel.contentMode = .transcript
                }
                .keyboardShortcut("3", modifiers: [.command])
                .disabled(appModel.accessState != .ready)

                Button("Show Media Browser") {
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
        width: min(max(proposedSize.width, 1320), min(displayBounds.width * 0.94, 1480)),
        height: min(max(proposedSize.height, 760), min(displayBounds.height * 0.92, 980))
    )
}
