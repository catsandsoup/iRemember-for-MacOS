import SwiftUI

@main
struct IRememberApp: App {
    @State private var appModel = AppModel(
        source: SQLiteMessagesSource(),
        sampleFallback: SampleMessagesSource()
    )

    var body: some Scene {
        WindowGroup("iRemember for Messages") {
            RootView(appModel: appModel)
                .frame(minWidth: 1120, minHeight: 760)
                .task {
                    await SnapshotExportController.exportIfRequested(appModel: appModel)
                }
        }
        .defaultSize(width: 1320, height: 860)

        Settings {
            SettingsView(appModel: appModel)
                .frame(width: 620, height: 460)
        }
        .commands {
            SidebarCommands()

            CommandMenu("Display") {
                Button(appModel.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    appModel.toggleInspectorVisibility()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(appModel.accessState != .ready)

                Button(appModel.isTimelineCollapsed ? "Show Timeline" : "Hide Timeline") {
                    appModel.toggleTimelineVisibility()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(appModel.selectedConversation == nil)
            }

            CommandMenu("Navigate") {
                Button("Jump to Date") {
                    appModel.isDateJumpPresented = true
                }
                .keyboardShortcut("j", modifiers: [.command])
                .disabled(appModel.selectedConversation == nil)

                Divider()

                Button("Show Transcript") {
                    appModel.contentMode = .transcript
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(appModel.accessState != .ready)

                Button("Show Media Browser") {
                    appModel.contentMode = .media
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(appModel.accessState != .ready)

                Divider()

                Button("Previous Day") {
                    Task { await appModel.moveTimelineSelection(byDays: -1) }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(appModel.selectedConversation == nil)

                Button("Next Day") {
                    Task { await appModel.moveTimelineSelection(byDays: 1) }
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(appModel.selectedConversation == nil)
            }
        }
    }
}
