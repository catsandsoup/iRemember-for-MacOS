import SwiftUI

struct ConversationTimelineView: View {
    @Bindable var appModel: AppModel

    private var displayedDate: Date {
        appModel.pendingTimelineDate ?? appModel.timelineAnchorDate
    }

    private var focusedMarkerID: String {
        let calendar = Calendar.autoupdatingCurrent
        let year = calendar.component(.year, from: displayedDate)
        let month = calendar.component(.month, from: displayedDate)
        return "month-\(year)-\(month)"
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader(
                date: displayedDate,
                showsReturnButton: appModel.canReturnToPreviousPosition,
                returnLabel: appModel.jumpOriginDescription ?? "Back to previous position",
                onReturn: {
                    Task { await appModel.returnToPreviousPosition() }
                }
            )

            Divider()

            if appModel.timelineYears.isEmpty {
                TimelineEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(appModel.timelineYears, id: \.self) { year in
                                TimelineYearSection(
                                    year: year,
                                    months: appModel.timelineMonths(for: year),
                                    focusedDate: displayedDate,
                                    onSelectYear: {
                                        Task { await appModel.jumpToTimelineYear(year) }
                                    },
                                    onSelectMonth: { marker in
                                        Task { await appModel.jumpToTimelineMonth(marker) }
                                    }
                                )
                                .id("year-\(year)")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                    }
                    .scrollIndicators(.visible)
                    .onAppear {
                        proxy.scrollTo(focusedMarkerID, anchor: .center)
                    }
                    .onChange(of: focusedMarkerID, initial: true) { _, newValue in
                        withAnimation(.smooth(duration: 0.22)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("timeline-rail")
    }
}

private struct TimelineHeader: View {
    let date: Date
    let showsReturnButton: Bool
    let returnLabel: String
    let onReturn: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.month(.wide))
                    .font(.headline)
                    .lineLimit(1)

                Text(date, format: .dateTime.year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            if showsReturnButton {
                Button(returnLabel, systemImage: "arrow.uturn.backward") {
                    onReturn()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(returnLabel)
                .accessibilityLabel(returnLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct TimelineYearSection: View {
    let year: Int
    let months: [TimelineMonthMarker]
    let focusedDate: Date
    let onSelectYear: () -> Void
    let onSelectMonth: (TimelineMonthMarker) -> Void

    private var isFocusedYear: Bool {
        Calendar.autoupdatingCurrent.component(.year, from: focusedDate) == year
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelectYear) {
                Text(String(year))
                    .font(.title3.weight(isFocusedYear ? .semibold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isFocusedYear ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(selectionFill(isFocused: isFocusedYear))
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Jump to \(year)")

            VStack(alignment: .leading, spacing: 4) {
                ForEach(months) { marker in
                    TimelineMonthButton(
                        marker: marker,
                        isFocused: isFocusedMonth(marker),
                        action: {
                            onSelectMonth(marker)
                        }
                    )
                }
            }
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isFocusedMonth(_ marker: TimelineMonthMarker) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.component(.year, from: focusedDate) == marker.year &&
            calendar.component(.month, from: focusedDate) == marker.month
    }

    @ViewBuilder
    private func selectionFill(isFocused: Bool) -> some View {
        if isFocused {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clear)
        }
    }
}

private struct TimelineMonthButton: View {
    let marker: TimelineMonthMarker
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(marker.shortLabel)
                    .font(.subheadline.weight(isFocused ? .semibold : .regular))
                    .foregroundStyle(isFocused ? Color.primary : Color.secondary)

                Spacer(minLength: 8)

                Text(marker.messageCount.groupedCount)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.secondary.opacity(0.08) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .id("month-\(marker.year)-\(marker.month)")
        .accessibilityLabel("Jump to \(marker.startDate.formatted(date: .abbreviated, time: .omitted))")
    }
}

private struct TimelineEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No timeline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("The archive index has not loaded enough history to show year and month anchors yet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No timeline anchors available yet")
    }
}
