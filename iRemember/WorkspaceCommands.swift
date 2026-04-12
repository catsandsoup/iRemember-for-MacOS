import SwiftUI

extension FocusedValues {
    @Entry var workspaceTimelineVisibility: Binding<Bool>?
    @Entry var workspaceContentMode: ContentMode?
}

struct WorkspaceTimelineCommands: Commands {
    @FocusedValue(\.workspaceTimelineVisibility) private var timelineVisibility
    @FocusedValue(\.workspaceContentMode) private var contentMode

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button(timelineCommandTitle) {
                timelineVisibility?.wrappedValue.toggle()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(!canToggleTimeline)
        }
    }

    private var canToggleTimeline: Bool {
        timelineVisibility != nil && contentMode == .transcript
    }

    private var timelineCommandTitle: String {
        (timelineVisibility?.wrappedValue ?? false) ? "Hide Timeline" : "Show Timeline"
    }
}
