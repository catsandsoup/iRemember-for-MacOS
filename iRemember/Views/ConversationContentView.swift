import SwiftUI

struct ConversationContentView: View {
    @Bindable var appModel: AppModel
    @Binding var isTimelineVisible: Bool

    var body: some View {
        Group {
            if appModel.accessState == .onboarding {
                ArchiveStarterView(appModel: appModel)
            } else if appModel.selectedArchiveSummary != nil {
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
            TranscriptWorkspaceView(appModel: appModel, isTimelineVisible: $isTimelineVisible)
        case .media:
            MediaBrowserView(appModel: appModel)
        }
    }
}

private struct TranscriptWorkspaceView: View {
    @Bindable var appModel: AppModel
    @Binding var isTimelineVisible: Bool

    var body: some View {
        Group {
            if isTimelineVisible {
                HSplitView {
                    TranscriptView(appModel: appModel)
                        .frame(minWidth: AppChrome.transcriptMinWidth, maxWidth: .infinity, maxHeight: .infinity)

                    ConversationTimelineView(appModel: appModel)
                        .frame(
                            minWidth: AppChrome.timelineMinWidth,
                            idealWidth: AppChrome.timelineIdealWidth,
                            maxWidth: AppChrome.timelineMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                }
            } else {
                TranscriptView(appModel: appModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy(duration: 0.22), value: isTimelineVisible)
    }
}

private struct ArchiveStarterView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Open your Messages archive")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))

                    Text("Your conversations stay on this Mac. iRemember reads the local Messages library in read-only mode and opens the archive workspace when you’re ready.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button("Open Messages Library") {
                        Task { await appModel.loadPrimaryLibrary() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .setupPrimaryActionStyle()
                    .accessibilityIdentifier("open-messages-library")
                }

                if appModel.canUseSampleFallback {
                    Button("Use Sample Library") {
                        Task { await appModel.loadSampleLibrary() }
                    }
                    .setupSecondaryActionStyle()
                    .accessibilityIdentifier("open-sample-library")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Nothing is uploaded or modified.", systemImage: "lock.shield")
                    Label("Search, timeline, and export tools appear after the archive opens.", systemImage: "sparkles.rectangle.stack")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: 560, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 28))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}
