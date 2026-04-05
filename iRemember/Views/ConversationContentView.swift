import SwiftUI

struct ConversationContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        Group {
            if let conversation = appModel.selectedConversation {
                VStack(spacing: 0) {
                    ConversationHeaderView(appModel: appModel, conversation: conversation)

                    if appModel.contentMode == .transcript {
                        ConversationTimelineView(appModel: appModel)
                        Divider()
                    }

                    switch appModel.contentMode {
                    case .transcript:
                        TranscriptView(appModel: appModel)
                    case .media:
                        MediaBrowserView(appModel: appModel)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a thread from the sidebar to browse messages, media, and context.")
                )
            }
        }
    }
}

private struct ConversationHeaderView: View {
    @Bindable var appModel: AppModel
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: AppChrome.spacing12) {
            HStack(alignment: .top, spacing: AppChrome.spacing16) {
                VStack(alignment: .leading, spacing: AppChrome.spacing4) {
                    Text(conversation.title)
                        .font(.system(size: 28, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(conversation.participantSummary)
                        .font(.callout)
                        .foregroundStyle(AppTheme.metadataText)
                        .lineLimit(1)

                    if let secondaryLine = conversation.secondaryParticipantSummary {
                        Text(secondaryLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)

                Spacer(minLength: 20)

                HStack(spacing: AppChrome.spacing8) {
                    Picker("Mode", selection: $appModel.contentMode) {
                        ForEach(ContentMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .accessibilityIdentifier("content-mode-picker")

                    Button("Jump to Date") {
                        appModel.isDateJumpPresented = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            HStack(spacing: AppChrome.spacing12) {
                Text(messageSummary)
                Text("•")
                Text(mediaSummary)
                Text("•")
                Text("Last active \(conversation.lastActivityAt.compactDateTimeLabel)")

                if !appModel.searchText.isEmpty {
                    Text("•")
                    Text("Searching \(appModel.searchScope.label.lowercased())")
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.metadataText)
            .lineLimit(1)
        }
        .padding(.horizontal, AppChrome.panePadding)
        .padding(.top, AppChrome.spacing16)
        .padding(.bottom, AppChrome.spacing12)
        .background(AppTheme.chromeBackground)
    }

    private var messageSummary: String {
        "\(conversation.messageCount.groupedCount) messages"
    }

    private var mediaSummary: String {
        "\(conversation.mediaCount.groupedCount) media"
    }
}
