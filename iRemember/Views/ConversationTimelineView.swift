import Charts
import SwiftUI

struct ConversationTimelineView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppChrome.spacing12) {
                header

                if appModel.isTimelineCollapsed {
                    collapsedState
                } else {
                    VStack(alignment: .leading, spacing: AppChrome.spacing12) {
                        timelineChart
                        scrubber
                    }
                    .padding(AppChrome.spacing12)
                    .background(
                        RoundedRectangle(cornerRadius: AppChrome.cardRadius, style: .continuous)
                            .fill(AppTheme.secondarySurface)
                    )
                }
            }
            .padding(.horizontal, AppChrome.panePadding)
            .padding(.top, AppChrome.spacing12)
            .padding(.bottom, AppChrome.spacing12)
        }
        .background(AppTheme.chromeBackground)
        .accessibilityIdentifier("timeline-panel")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppChrome.spacing16) {
            VStack(alignment: .leading, spacing: AppChrome.spacing4) {
                Text("Timeline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.metadataText)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(appModel.timelineSummaryTitle)
                        .font(.title3.weight(.semibold))

                    Text(appModel.timelineAnchorDate.compactDateLabel)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.metadataText)
                }
            }

            Spacer()

            HStack(spacing: AppChrome.spacing8) {
                Picker("Range", selection: $appModel.timelineRange) {
                    ForEach(TimelineRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 204)
                .accessibilityIdentifier("timeline-range-picker")

                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        appModel.toggleTimelineVisibility()
                    }
                } label: {
                    Image(systemName: appModel.isTimelineCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .help(appModel.isTimelineCollapsed ? "Expand timeline" : "Collapse timeline")
                .accessibilityIdentifier("timeline-toggle")
            }
        }
    }

    private var collapsedState: some View {
        HStack(spacing: 10) {
            Image(systemName: "timeline.selection")
                .foregroundStyle(.secondary)

            Text("Timeline hidden. Expand to jump across weeks, months, and years.")
                .font(.callout)
                .foregroundStyle(AppTheme.metadataText)

            Spacer()
        }
        .padding(AppChrome.spacing16)
        .background(
            RoundedRectangle(cornerRadius: AppChrome.cardRadius, style: .continuous)
                .fill(AppTheme.secondarySurface)
        )
    }

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                Chart(appModel.timelineBuckets) { bucket in
                    BarMark(
                        xStart: .value("Start", bucket.startDate),
                        xEnd: .value("End", bucket.endDate),
                        y: .value("Messages", bucket.messageCount)
                    )
                    .foregroundStyle(isActive(bucket) ? AppTheme.activeFill : AppTheme.timelineInactiveFill)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: appModel.timelineRange == .year ? 6 : 5)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(AppTheme.metadataText)
                    }
                }
                .frame(width: timelineContentWidth, height: max(appModel.timelineHeight, 88))
                .overlay {
                    bucketHitTargetOverlay
                }
                .padding(.horizontal, 2)
                .padding(.vertical, AppChrome.spacing8)
                .accessibilityLabel("Conversation activity timeline")
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("timeline-scroll-surface")
        }
    }

    private var scrubber: some View {
        HStack(spacing: AppChrome.spacing12) {
            Button {
                appModel.moveTimelineRange(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)

            TimelineAnchorBadge(date: appModel.timelineAnchorDate)

            DayScrubberView(appModel: appModel)

            Button {
                appModel.moveTimelineRange(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
        }
    }

    private var bucketHitTargetOverlay: some View {
        GeometryReader { geometry in
            let buckets = appModel.timelineBuckets
            let width = geometry.size.width / CGFloat(max(buckets.count, 1))

            HStack(spacing: 0) {
                ForEach(buckets) { bucket in
                    Button {
                        Task { await appModel.jumpToTimelineBucket(bucket) }
                    } label: {
                        Color.clear
                            .frame(width: width)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bucketAccessibilityLabel(bucket))
                    .help("Jump to \(bucket.startDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var timelineContentWidth: CGFloat {
        let bucketWidth: CGFloat

        switch appModel.timelineRange {
        case .week:
            bucketWidth = 104
        case .month:
            bucketWidth = 148
        case .year:
            bucketWidth = 136
        }

        let minimumWidth: CGFloat = 760
        return max(CGFloat(max(appModel.timelineBuckets.count, 1)) * bucketWidth, minimumWidth)
    }

    private func isActive(_ bucket: TimelineBucket) -> Bool {
        bucket.startDate <= appModel.timelineAnchorDate && appModel.timelineAnchorDate < bucket.endDate
    }

    private func bucketAccessibilityLabel(_ bucket: TimelineBucket) -> String {
        "\(bucket.startDate.formatted(date: .abbreviated, time: .omitted)), \(bucket.messageCount) messages"
    }
}

private struct TimelineAnchorBadge: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Focused")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(date.compactDateLabel)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.activeTint)
        )
    }
}

private struct DayScrubberView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(appModel.dateScrubberDays, id: \.self) { day in
                        Button {
                            Task { await appModel.jumpToDay(day) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(day, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(day, format: .dateTime.day())
                                    .font(.headline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 68)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected(day) ? AppTheme.activeTint : Color.clear)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected(day) ? AppTheme.sidebarSelectionStroke : Color.clear, lineWidth: 1)
                            }
                        }
                        .id(day)
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(isSelected(day) ? "Selected timeline day" : "")
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("timeline-day-scrubber")
            .onAppear {
                scrollToSelection(with: proxy, animated: false)
            }
            .onChange(of: appModel.timelineAnchorDate) { _, _ in
                scrollToSelection(with: proxy, animated: true)
            }
        }
    }

    private func scrollToSelection(with proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedDay = appModel.dateScrubberDays.first(where: isSelected(_:)) else { return }

        if animated {
            withAnimation(.smooth(duration: 0.18)) {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedDay, anchor: .center)
        }
    }

    private func isSelected(_ day: Date) -> Bool {
        Calendar.autoupdatingCurrent.isDate(day, inSameDayAs: appModel.timelineAnchorDate)
    }
}
