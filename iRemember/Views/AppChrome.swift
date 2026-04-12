import Foundation
import SwiftUI

enum AppChrome {
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    static let panePadding: CGFloat = spacing24
    static let sectionSpacing: CGFloat = spacing16
    static let itemSpacing: CGFloat = spacing12
    static let compactSpacing: CGFloat = spacing8
    static let cardRadius: CGFloat = 18
    static let rowRadius: CGFloat = 14
    static let bubbleWidth: CGFloat = 470
    static let workspaceMinWidth: CGFloat = 1000
    static let workspaceMinHeight: CGFloat = 680
    static let sidebarMinWidth: CGFloat = 240
    static let sidebarIdealWidth: CGFloat = 280
    static let sidebarMaxWidth: CGFloat = 340
    static let transcriptMinWidth: CGFloat = 420
    static let timelineMinWidth: CGFloat = 168
    static let timelineIdealWidth: CGFloat = 196
    static let timelineMaxWidth: CGFloat = 260
}

enum AppTheme {
    private static func asset(_ name: String) -> Color {
        Color(name)
    }

    static let sidebarBackground = asset("SidebarBackground")
    static let contentBackground = asset("ContentBackground")
    static let chromeBackground = asset("ChromeBackground")
    static let inspectorBackground = asset("InspectorBackground")
    static let secondarySurface = asset("SecondarySurface")
    static let sidebarHoverFill = asset("SidebarHoverFill")
    static let sidebarSelectionFill = asset("SidebarSelectionFill")
    static let sidebarSelectionStroke = asset("SidebarSelectionStroke")
    static let activeFill = asset("AccentColor")
    static let activeTint = asset("ActiveTint")
    static let activeSelectionStroke = asset("ActiveSelectionStroke")
    static let timelineInactiveFill = asset("TimelineInactiveFill")
    static let incomingBubbleFill = asset("IncomingBubbleFill")
    static let outgoingBubbleFill = activeFill
    static let systemBubbleFill = asset("SystemBubbleFill")
    static let metadataText = asset("MetadataText")
    static let tertiaryText = asset("TertiaryText")
    static let bubbleStroke = asset("BubbleStroke")
    static let outgoingPrimaryText = asset("OutgoingPrimaryText")
    static let outgoingSecondaryText = asset("OutgoingSecondaryText")
    static let replyIncomingBar = activeFill
    static let replyOutgoingBar = asset("ReplyOutgoingBar")
    static let replyOutgoingSurface = asset("ReplyOutgoingSurface")
    static let replyOutgoingText = outgoingSecondaryText
    static let attachmentIncomingIconBackground = asset("AttachmentIncomingIconBackground")
    static let attachmentOutgoingIconBackground = asset("AttachmentOutgoingIconBackground")
    static let attachmentOutgoingSurface = asset("AttachmentOutgoingSurface")
    static let mediaCardFill = asset("MediaCardFill")
    static let mediaCardStroke = asset("MediaCardStroke")
    static let mediaCardSelectionStroke = asset("MediaCardSelectionStroke")
    static let videoPlayOverlay = asset("VideoPlayOverlay")
    static let videoAttachmentFill = asset("VideoAttachmentFill")
    static let linkAttachmentFill = asset("LinkAttachmentFill")
}

extension Int {
    var groupedCount: String {
        formatted(.number.grouping(.automatic))
    }
}

extension Optional where Wrapped == Int {
    var groupedCount: String {
        switch self {
        case .some(let value):
            value.groupedCount
        case .none:
            "..."
        }
    }
}

extension Date {
    var sidebarLabel: String {
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }

        if calendar.isDate(self, equalTo: .now, toGranularity: .year) {
            return formatted(.dateTime.day().month(.abbreviated))
        }

        return formatted(.dateTime.day().month(.abbreviated).year())
    }

    var compactDateLabel: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }

    var compactDateTimeLabel: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    var transcriptTimeLabel: String {
        formatted(date: .omitted, time: .shortened)
    }
}

extension Conversation {
    var participantSummary: String {
        let names = participants
            .map(\.displayName)
            .filter { $0 != "You" }

        switch names.count {
        case 0:
            return "Personal thread"
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            return "\(names[0]), \(names[1]), and \(names.count - 2) others"
        }
    }

    var secondaryParticipantSummary: String? {
        let handles = participants
            .map(\.handle)
            .filter { $0 != "me" }
            .filter { !$0.isEmpty }

        guard !handles.isEmpty else { return nil }

        let joined = handles.joined(separator: " · ")
        guard joined.caseInsensitiveCompare(title) != .orderedSame else {
            return nil
        }

        return joined
    }
}
