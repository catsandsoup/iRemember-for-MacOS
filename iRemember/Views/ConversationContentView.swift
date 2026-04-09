import SwiftUI

struct ConversationContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Group {
            if appModel.selectedArchiveSummary != nil {
                contentView
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a contact or conversation from the sidebar to browse messages, shared media, and details.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
