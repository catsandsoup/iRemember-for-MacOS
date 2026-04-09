import SwiftUI

struct ConversationTimelineView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        let timelineYears = appModel.timelineYears
        let displayedDate = appModel.pendingTimelineDate ?? appModel.timelineAnchorDate
        let focusedYear = Calendar.autoupdatingCurrent.component(.year, from: displayedDate)

        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: AppChrome.spacing12) {
                timelineToolbar

                Divider()

                if timelineYears.isEmpty {
                    TimelineEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .trailing, spacing: 10) {
                            ForEach(timelineYears, id: \.self) { year in
                                TimelineYearGroup(
                                    year: year,
                                    months: appModel.timelineMonths(for: year),
                                    focusedDate: displayedDate,
                                    isFocused: year == focusedYear,
                                    onSelectYear: {
                                        Task { await appModel.jumpToTimelineYear(year) }
                                    },
                                    onPreviewYear: { previewDate in
                                        appModel.previewTimelineJump(to: previewDate)
                                    },
                                    onCommitPreview: {
                                        Task { await appModel.commitTimelineJump() }
                                    },
                                    onSelectMonth: { marker in
                                        Task { await appModel.jumpToTimelineMonth(marker) }
                                    },
                                    onPreviewMonth: { marker in
                                        appModel.previewTimelineJump(to: marker.startDate)
                                    },
                                    onCommitMonthPreview: {
                                        Task { await appModel.commitTimelineJump() }
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.hidden)
                }

                TimelineFocusBadge(date: displayedDate, isPending: appModel.pendingTimelineDate != nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, AppChrome.spacing16)
            .frame(width: 96)
            .frame(maxHeight: .infinity, alignment: .topTrailing)
        }
        .background(AppTheme.chromeBackground)
        .overlay(alignment: .leading) {
            Divider()
        }
        .accessibilityIdentifier("timeline-rail")
    }

    private var timelineToolbar: some View {
        VStack(alignment: .trailing, spacing: AppChrome.spacing12) {
            Button {
                appModel.isDateJumpPresented = true
            } label: {
                Image(systemName: "calendar")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .help("Jump to date")
            .accessibilityLabel("Jump to date")

            if appModel.canReturnToPreviousPosition {
                Button {
                    Task { await appModel.returnToPreviousPosition() }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .help(appModel.jumpOriginDescription ?? "Back to previous position")
                .accessibilityLabel(appModel.jumpOriginDescription ?? "Back to previous position")
            }
        }
        .controlSize(.small)
    }
}

private struct TimelineYearGroup: View {
    let year: Int
    let months: [TimelineMonthMarker]
    let focusedDate: Date
    let isFocused: Bool
    let onSelectYear: () -> Void
    let onPreviewYear: (Date) -> Void
    let onCommitPreview: () -> Void
    let onSelectMonth: (TimelineMonthMarker) -> Void
    let onPreviewMonth: (TimelineMonthMarker) -> Void
    let onCommitMonthPreview: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button(action: onSelectYear) {
                Text(String(year))
                    .font(.system(size: isFocused ? 14 : 13, weight: isFocused ? .semibold : .medium))
                    .foregroundStyle(isFocused ? Color.primary : AppTheme.metadataText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isFocused ? AppTheme.sidebarSelectionFill : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { _ in
                        if let previewDate = months.first?.startDate {
                            onPreviewYear(previewDate)
                        }
                    }
                    .onEnded { _ in
                        onCommitPreview()
                    }
            )
            .accessibilityLabel("Jump to \(year)")

            VStack(alignment: .trailing, spacing: 4) {
                ForEach(months) { marker in
                    Button {
                        onSelectMonth(marker)
                    } label: {
                        Text(marker.shortLabel)
                            .font(.caption.weight(isFocusedMonth(marker) ? .semibold : .medium))
                            .foregroundStyle(isFocusedMonth(marker) ? Color.primary : AppTheme.tertiaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isFocusedMonth(marker) ? AppTheme.sidebarSelectionFill : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { _ in
                                onPreviewMonth(marker)
                            }
                            .onEnded { _ in
                                onCommitMonthPreview()
                            }
                    )
                    .accessibilityLabel("Jump to \(marker.startDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func isFocusedMonth(_ marker: TimelineMonthMarker) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.component(.year, from: focusedDate) == marker.year &&
            calendar.component(.month, from: focusedDate) == marker.month
    }
}

private struct TimelineEmptyStateView: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("No timeline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.metadataText)

            Text("The archive index has not loaded enough history to show year and month anchors yet.")
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No timeline anchors available yet")
    }
}

private struct TimelineFocusBadge: View {
    let date: Date
    let isPending: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(date, format: .dateTime.month(.abbreviated))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.metadataText)

            Text(date, format: .dateTime.year())
                .font(.caption.weight(.semibold))

            if isPending {
                Text("Release to jump")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
