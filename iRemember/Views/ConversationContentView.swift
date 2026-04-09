import SwiftUI

struct ConversationContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Group {
            if appModel.selectedArchiveSummary != nil {
                contentView
            } else {
                ContentUnavailableView(
                    "Select an Archive",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a thread or person archive from the sidebar to browse messages, media, and context.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.contentBackground)
    }

    @ViewBuilder
    private var contentView: some View {
        switch appModel.contentMode {
        case .transcript:
            HStack(spacing: 0) {
                TranscriptView(appModel: appModel)
                ConversationTimelineView(appModel: appModel)
            }
        case .media:
            MediaBrowserView(appModel: appModel)
        }
    }
}
