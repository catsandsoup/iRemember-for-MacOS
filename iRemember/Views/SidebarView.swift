import SwiftUI

struct SidebarView: View {
    @Bindable var appModel: AppModel

    private var pinnedConversations: [Conversation] {
        appModel.conversations.filter(\.isPinned)
    }

    private var standardConversations: [Conversation] {
        appModel.conversations.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppChrome.spacing12) {
                    if !pinnedConversations.isEmpty {
                        SidebarSectionLabel(title: "Pinned")

                        ForEach(pinnedConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: appModel.selectedConversationID == conversation.id
                            ) {
                                Task { await appModel.selectConversation(conversation.id) }
                            }
                        }
                    }

                    if !standardConversations.isEmpty {
                        SidebarSectionLabel(title: pinnedConversations.isEmpty ? "Conversations" : "All Conversations")

                        ForEach(standardConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: appModel.selectedConversationID == conversation.id
                            ) {
                                Task { await appModel.selectConversation(conversation.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppChrome.spacing12)
                .padding(.vertical, AppChrome.spacing12)
            }
        }
        .background(AppTheme.sidebarBackground)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Conversations")
                .font(.headline.weight(.semibold))

            Spacer()

            Text(appModel.conversations.count.groupedCount)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppChrome.spacing16)
        .padding(.top, AppChrome.spacing16)
        .padding(.bottom, AppChrome.spacing8)
    }
}

private struct SidebarSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.4)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(conversation.lastActivityAt.sidebarLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? .secondary : .tertiary)
                        .monospacedDigit()
                }

                Text(conversation.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppChrome.spacing12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectionBackground)
            .overlay(selectionOutline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: AppChrome.rowRadius, style: .continuous)
            .fill(isSelected ? AppTheme.sidebarSelectionFill : (isHovered ? AppTheme.sidebarHoverFill : Color.clear))
    }

    @ViewBuilder
    private var selectionOutline: some View {
        RoundedRectangle(cornerRadius: AppChrome.rowRadius, style: .continuous)
            .stroke(isSelected ? AppTheme.sidebarSelectionStroke : Color.clear, lineWidth: 1)
    }
}
