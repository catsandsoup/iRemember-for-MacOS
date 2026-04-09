import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "ActiveSelectionStroke" asset catalog color resource.
    static let activeSelectionStroke = DeveloperToolsSupport.ColorResource(name: "ActiveSelectionStroke", bundle: resourceBundle)

    /// The "ActiveTint" asset catalog color resource.
    static let activeTint = DeveloperToolsSupport.ColorResource(name: "ActiveTint", bundle: resourceBundle)

    /// The "AttachmentIncomingIconBackground" asset catalog color resource.
    static let attachmentIncomingIconBackground = DeveloperToolsSupport.ColorResource(name: "AttachmentIncomingIconBackground", bundle: resourceBundle)

    /// The "AttachmentOutgoingIconBackground" asset catalog color resource.
    static let attachmentOutgoingIconBackground = DeveloperToolsSupport.ColorResource(name: "AttachmentOutgoingIconBackground", bundle: resourceBundle)

    /// The "AttachmentOutgoingSurface" asset catalog color resource.
    static let attachmentOutgoingSurface = DeveloperToolsSupport.ColorResource(name: "AttachmentOutgoingSurface", bundle: resourceBundle)

    /// The "BubbleStroke" asset catalog color resource.
    static let bubbleStroke = DeveloperToolsSupport.ColorResource(name: "BubbleStroke", bundle: resourceBundle)

    /// The "ChromeBackground" asset catalog color resource.
    static let chromeBackground = DeveloperToolsSupport.ColorResource(name: "ChromeBackground", bundle: resourceBundle)

    /// The "ContentBackground" asset catalog color resource.
    static let contentBackground = DeveloperToolsSupport.ColorResource(name: "ContentBackground", bundle: resourceBundle)

    /// The "IncomingBubbleFill" asset catalog color resource.
    static let incomingBubbleFill = DeveloperToolsSupport.ColorResource(name: "IncomingBubbleFill", bundle: resourceBundle)

    /// The "InspectorBackground" asset catalog color resource.
    static let inspectorBackground = DeveloperToolsSupport.ColorResource(name: "InspectorBackground", bundle: resourceBundle)

    /// The "LinkAttachmentFill" asset catalog color resource.
    static let linkAttachmentFill = DeveloperToolsSupport.ColorResource(name: "LinkAttachmentFill", bundle: resourceBundle)

    /// The "MediaCardFill" asset catalog color resource.
    static let mediaCardFill = DeveloperToolsSupport.ColorResource(name: "MediaCardFill", bundle: resourceBundle)

    /// The "MediaCardSelectionStroke" asset catalog color resource.
    static let mediaCardSelectionStroke = DeveloperToolsSupport.ColorResource(name: "MediaCardSelectionStroke", bundle: resourceBundle)

    /// The "MediaCardStroke" asset catalog color resource.
    static let mediaCardStroke = DeveloperToolsSupport.ColorResource(name: "MediaCardStroke", bundle: resourceBundle)

    /// The "MetadataText" asset catalog color resource.
    static let metadataText = DeveloperToolsSupport.ColorResource(name: "MetadataText", bundle: resourceBundle)

    /// The "OutgoingPrimaryText" asset catalog color resource.
    static let outgoingPrimaryText = DeveloperToolsSupport.ColorResource(name: "OutgoingPrimaryText", bundle: resourceBundle)

    /// The "OutgoingSecondaryText" asset catalog color resource.
    static let outgoingSecondaryText = DeveloperToolsSupport.ColorResource(name: "OutgoingSecondaryText", bundle: resourceBundle)

    /// The "ReplyOutgoingBar" asset catalog color resource.
    static let replyOutgoingBar = DeveloperToolsSupport.ColorResource(name: "ReplyOutgoingBar", bundle: resourceBundle)

    /// The "ReplyOutgoingSurface" asset catalog color resource.
    static let replyOutgoingSurface = DeveloperToolsSupport.ColorResource(name: "ReplyOutgoingSurface", bundle: resourceBundle)

    /// The "SecondarySurface" asset catalog color resource.
    static let secondarySurface = DeveloperToolsSupport.ColorResource(name: "SecondarySurface", bundle: resourceBundle)

    /// The "SidebarBackground" asset catalog color resource.
    static let sidebarBackground = DeveloperToolsSupport.ColorResource(name: "SidebarBackground", bundle: resourceBundle)

    /// The "SidebarHoverFill" asset catalog color resource.
    static let sidebarHoverFill = DeveloperToolsSupport.ColorResource(name: "SidebarHoverFill", bundle: resourceBundle)

    /// The "SidebarSelectionFill" asset catalog color resource.
    static let sidebarSelectionFill = DeveloperToolsSupport.ColorResource(name: "SidebarSelectionFill", bundle: resourceBundle)

    /// The "SidebarSelectionStroke" asset catalog color resource.
    static let sidebarSelectionStroke = DeveloperToolsSupport.ColorResource(name: "SidebarSelectionStroke", bundle: resourceBundle)

    /// The "SystemBubbleFill" asset catalog color resource.
    static let systemBubbleFill = DeveloperToolsSupport.ColorResource(name: "SystemBubbleFill", bundle: resourceBundle)

    /// The "TertiaryText" asset catalog color resource.
    static let tertiaryText = DeveloperToolsSupport.ColorResource(name: "TertiaryText", bundle: resourceBundle)

    /// The "TimelineInactiveFill" asset catalog color resource.
    static let timelineInactiveFill = DeveloperToolsSupport.ColorResource(name: "TimelineInactiveFill", bundle: resourceBundle)

    /// The "VideoAttachmentFill" asset catalog color resource.
    static let videoAttachmentFill = DeveloperToolsSupport.ColorResource(name: "VideoAttachmentFill", bundle: resourceBundle)

    /// The "VideoPlayOverlay" asset catalog color resource.
    static let videoPlayOverlay = DeveloperToolsSupport.ColorResource(name: "VideoPlayOverlay", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "ActiveSelectionStroke" asset catalog color.
    static var activeSelectionStroke: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activeSelectionStroke)
#else
        .init()
#endif
    }

    /// The "ActiveTint" asset catalog color.
    static var activeTint: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activeTint)
#else
        .init()
#endif
    }

    /// The "AttachmentIncomingIconBackground" asset catalog color.
    static var attachmentIncomingIconBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .attachmentIncomingIconBackground)
#else
        .init()
#endif
    }

    /// The "AttachmentOutgoingIconBackground" asset catalog color.
    static var attachmentOutgoingIconBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .attachmentOutgoingIconBackground)
#else
        .init()
#endif
    }

    /// The "AttachmentOutgoingSurface" asset catalog color.
    static var attachmentOutgoingSurface: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .attachmentOutgoingSurface)
#else
        .init()
#endif
    }

    /// The "BubbleStroke" asset catalog color.
    static var bubbleStroke: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bubbleStroke)
#else
        .init()
#endif
    }

    /// The "ChromeBackground" asset catalog color.
    static var chromeBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .chromeBackground)
#else
        .init()
#endif
    }

    /// The "ContentBackground" asset catalog color.
    static var contentBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .contentBackground)
#else
        .init()
#endif
    }

    /// The "IncomingBubbleFill" asset catalog color.
    static var incomingBubbleFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .incomingBubbleFill)
#else
        .init()
#endif
    }

    /// The "InspectorBackground" asset catalog color.
    static var inspectorBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .inspectorBackground)
#else
        .init()
#endif
    }

    /// The "LinkAttachmentFill" asset catalog color.
    static var linkAttachmentFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .linkAttachmentFill)
#else
        .init()
#endif
    }

    /// The "MediaCardFill" asset catalog color.
    static var mediaCardFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .mediaCardFill)
#else
        .init()
#endif
    }

    /// The "MediaCardSelectionStroke" asset catalog color.
    static var mediaCardSelectionStroke: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .mediaCardSelectionStroke)
#else
        .init()
#endif
    }

    /// The "MediaCardStroke" asset catalog color.
    static var mediaCardStroke: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .mediaCardStroke)
#else
        .init()
#endif
    }

    /// The "MetadataText" asset catalog color.
    static var metadataText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .metadataText)
#else
        .init()
#endif
    }

    /// The "OutgoingPrimaryText" asset catalog color.
    static var outgoingPrimaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .outgoingPrimaryText)
#else
        .init()
#endif
    }

    /// The "OutgoingSecondaryText" asset catalog color.
    static var outgoingSecondaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .outgoingSecondaryText)
#else
        .init()
#endif
    }

    /// The "ReplyOutgoingBar" asset catalog color.
    static var replyOutgoingBar: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .replyOutgoingBar)
#else
        .init()
#endif
    }

    /// The "ReplyOutgoingSurface" asset catalog color.
    static var replyOutgoingSurface: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .replyOutgoingSurface)
#else
        .init()
#endif
    }

    /// The "SecondarySurface" asset catalog color.
    static var secondarySurface: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .secondarySurface)
#else
        .init()
#endif
    }

    /// The "SidebarBackground" asset catalog color.
    static var sidebarBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .sidebarBackground)
#else
        .init()
#endif
    }

    /// The "SidebarHoverFill" asset catalog color.
    static var sidebarHoverFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .sidebarHoverFill)
#else
        .init()
#endif
    }

    /// The "SidebarSelectionFill" asset catalog color.
    static var sidebarSelectionFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .sidebarSelectionFill)
#else
        .init()
#endif
    }

    /// The "SidebarSelectionStroke" asset catalog color.
    static var sidebarSelectionStroke: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .sidebarSelectionStroke)
#else
        .init()
#endif
    }

    /// The "SystemBubbleFill" asset catalog color.
    static var systemBubbleFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .systemBubbleFill)
#else
        .init()
#endif
    }

    /// The "TertiaryText" asset catalog color.
    static var tertiaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tertiaryText)
#else
        .init()
#endif
    }

    /// The "TimelineInactiveFill" asset catalog color.
    static var timelineInactiveFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .timelineInactiveFill)
#else
        .init()
#endif
    }

    /// The "VideoAttachmentFill" asset catalog color.
    static var videoAttachmentFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .videoAttachmentFill)
#else
        .init()
#endif
    }

    /// The "VideoPlayOverlay" asset catalog color.
    static var videoPlayOverlay: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .videoPlayOverlay)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "ActiveSelectionStroke" asset catalog color.
    static var activeSelectionStroke: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activeSelectionStroke)
#else
        .init()
#endif
    }

    /// The "ActiveTint" asset catalog color.
    static var activeTint: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activeTint)
#else
        .init()
#endif
    }

    /// The "AttachmentIncomingIconBackground" asset catalog color.
    static var attachmentIncomingIconBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .attachmentIncomingIconBackground)
#else
        .init()
#endif
    }

    /// The "AttachmentOutgoingIconBackground" asset catalog color.
    static var attachmentOutgoingIconBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .attachmentOutgoingIconBackground)
#else
        .init()
#endif
    }

    /// The "AttachmentOutgoingSurface" asset catalog color.
    static var attachmentOutgoingSurface: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .attachmentOutgoingSurface)
#else
        .init()
#endif
    }

    /// The "BubbleStroke" asset catalog color.
    static var bubbleStroke: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .bubbleStroke)
#else
        .init()
#endif
    }

    /// The "ChromeBackground" asset catalog color.
    static var chromeBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .chromeBackground)
#else
        .init()
#endif
    }

    /// The "ContentBackground" asset catalog color.
    static var contentBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .contentBackground)
#else
        .init()
#endif
    }

    /// The "IncomingBubbleFill" asset catalog color.
    static var incomingBubbleFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .incomingBubbleFill)
#else
        .init()
#endif
    }

    /// The "InspectorBackground" asset catalog color.
    static var inspectorBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .inspectorBackground)
#else
        .init()
#endif
    }

    /// The "LinkAttachmentFill" asset catalog color.
    static var linkAttachmentFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .linkAttachmentFill)
#else
        .init()
#endif
    }

    /// The "MediaCardFill" asset catalog color.
    static var mediaCardFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .mediaCardFill)
#else
        .init()
#endif
    }

    /// The "MediaCardSelectionStroke" asset catalog color.
    static var mediaCardSelectionStroke: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .mediaCardSelectionStroke)
#else
        .init()
#endif
    }

    /// The "MediaCardStroke" asset catalog color.
    static var mediaCardStroke: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .mediaCardStroke)
#else
        .init()
#endif
    }

    /// The "MetadataText" asset catalog color.
    static var metadataText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .metadataText)
#else
        .init()
#endif
    }

    /// The "OutgoingPrimaryText" asset catalog color.
    static var outgoingPrimaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .outgoingPrimaryText)
#else
        .init()
#endif
    }

    /// The "OutgoingSecondaryText" asset catalog color.
    static var outgoingSecondaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .outgoingSecondaryText)
#else
        .init()
#endif
    }

    /// The "ReplyOutgoingBar" asset catalog color.
    static var replyOutgoingBar: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .replyOutgoingBar)
#else
        .init()
#endif
    }

    /// The "ReplyOutgoingSurface" asset catalog color.
    static var replyOutgoingSurface: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .replyOutgoingSurface)
#else
        .init()
#endif
    }

    /// The "SecondarySurface" asset catalog color.
    static var secondarySurface: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .secondarySurface)
#else
        .init()
#endif
    }

    /// The "SidebarBackground" asset catalog color.
    static var sidebarBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .sidebarBackground)
#else
        .init()
#endif
    }

    /// The "SidebarHoverFill" asset catalog color.
    static var sidebarHoverFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .sidebarHoverFill)
#else
        .init()
#endif
    }

    /// The "SidebarSelectionFill" asset catalog color.
    static var sidebarSelectionFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .sidebarSelectionFill)
#else
        .init()
#endif
    }

    /// The "SidebarSelectionStroke" asset catalog color.
    static var sidebarSelectionStroke: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .sidebarSelectionStroke)
#else
        .init()
#endif
    }

    /// The "SystemBubbleFill" asset catalog color.
    static var systemBubbleFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .systemBubbleFill)
#else
        .init()
#endif
    }

    /// The "TertiaryText" asset catalog color.
    static var tertiaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .tertiaryText)
#else
        .init()
#endif
    }

    /// The "TimelineInactiveFill" asset catalog color.
    static var timelineInactiveFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .timelineInactiveFill)
#else
        .init()
#endif
    }

    /// The "VideoAttachmentFill" asset catalog color.
    static var videoAttachmentFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .videoAttachmentFill)
#else
        .init()
#endif
    }

    /// The "VideoPlayOverlay" asset catalog color.
    static var videoPlayOverlay: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .videoPlayOverlay)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "ActiveSelectionStroke" asset catalog color.
    static var activeSelectionStroke: SwiftUI.Color { .init(.activeSelectionStroke) }

    /// The "ActiveTint" asset catalog color.
    static var activeTint: SwiftUI.Color { .init(.activeTint) }

    /// The "AttachmentIncomingIconBackground" asset catalog color.
    static var attachmentIncomingIconBackground: SwiftUI.Color { .init(.attachmentIncomingIconBackground) }

    /// The "AttachmentOutgoingIconBackground" asset catalog color.
    static var attachmentOutgoingIconBackground: SwiftUI.Color { .init(.attachmentOutgoingIconBackground) }

    /// The "AttachmentOutgoingSurface" asset catalog color.
    static var attachmentOutgoingSurface: SwiftUI.Color { .init(.attachmentOutgoingSurface) }

    /// The "BubbleStroke" asset catalog color.
    static var bubbleStroke: SwiftUI.Color { .init(.bubbleStroke) }

    /// The "ChromeBackground" asset catalog color.
    static var chromeBackground: SwiftUI.Color { .init(.chromeBackground) }

    /// The "ContentBackground" asset catalog color.
    static var contentBackground: SwiftUI.Color { .init(.contentBackground) }

    /// The "IncomingBubbleFill" asset catalog color.
    static var incomingBubbleFill: SwiftUI.Color { .init(.incomingBubbleFill) }

    /// The "InspectorBackground" asset catalog color.
    static var inspectorBackground: SwiftUI.Color { .init(.inspectorBackground) }

    /// The "LinkAttachmentFill" asset catalog color.
    static var linkAttachmentFill: SwiftUI.Color { .init(.linkAttachmentFill) }

    /// The "MediaCardFill" asset catalog color.
    static var mediaCardFill: SwiftUI.Color { .init(.mediaCardFill) }

    /// The "MediaCardSelectionStroke" asset catalog color.
    static var mediaCardSelectionStroke: SwiftUI.Color { .init(.mediaCardSelectionStroke) }

    /// The "MediaCardStroke" asset catalog color.
    static var mediaCardStroke: SwiftUI.Color { .init(.mediaCardStroke) }

    /// The "MetadataText" asset catalog color.
    static var metadataText: SwiftUI.Color { .init(.metadataText) }

    /// The "OutgoingPrimaryText" asset catalog color.
    static var outgoingPrimaryText: SwiftUI.Color { .init(.outgoingPrimaryText) }

    /// The "OutgoingSecondaryText" asset catalog color.
    static var outgoingSecondaryText: SwiftUI.Color { .init(.outgoingSecondaryText) }

    /// The "ReplyOutgoingBar" asset catalog color.
    static var replyOutgoingBar: SwiftUI.Color { .init(.replyOutgoingBar) }

    /// The "ReplyOutgoingSurface" asset catalog color.
    static var replyOutgoingSurface: SwiftUI.Color { .init(.replyOutgoingSurface) }

    /// The "SecondarySurface" asset catalog color.
    static var secondarySurface: SwiftUI.Color { .init(.secondarySurface) }

    /// The "SidebarBackground" asset catalog color.
    static var sidebarBackground: SwiftUI.Color { .init(.sidebarBackground) }

    /// The "SidebarHoverFill" asset catalog color.
    static var sidebarHoverFill: SwiftUI.Color { .init(.sidebarHoverFill) }

    /// The "SidebarSelectionFill" asset catalog color.
    static var sidebarSelectionFill: SwiftUI.Color { .init(.sidebarSelectionFill) }

    /// The "SidebarSelectionStroke" asset catalog color.
    static var sidebarSelectionStroke: SwiftUI.Color { .init(.sidebarSelectionStroke) }

    /// The "SystemBubbleFill" asset catalog color.
    static var systemBubbleFill: SwiftUI.Color { .init(.systemBubbleFill) }

    /// The "TertiaryText" asset catalog color.
    static var tertiaryText: SwiftUI.Color { .init(.tertiaryText) }

    /// The "TimelineInactiveFill" asset catalog color.
    static var timelineInactiveFill: SwiftUI.Color { .init(.timelineInactiveFill) }

    /// The "VideoAttachmentFill" asset catalog color.
    static var videoAttachmentFill: SwiftUI.Color { .init(.videoAttachmentFill) }

    /// The "VideoPlayOverlay" asset catalog color.
    static var videoPlayOverlay: SwiftUI.Color { .init(.videoPlayOverlay) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "ActiveSelectionStroke" asset catalog color.
    static var activeSelectionStroke: SwiftUI.Color { .init(.activeSelectionStroke) }

    /// The "ActiveTint" asset catalog color.
    static var activeTint: SwiftUI.Color { .init(.activeTint) }

    /// The "AttachmentIncomingIconBackground" asset catalog color.
    static var attachmentIncomingIconBackground: SwiftUI.Color { .init(.attachmentIncomingIconBackground) }

    /// The "AttachmentOutgoingIconBackground" asset catalog color.
    static var attachmentOutgoingIconBackground: SwiftUI.Color { .init(.attachmentOutgoingIconBackground) }

    /// The "AttachmentOutgoingSurface" asset catalog color.
    static var attachmentOutgoingSurface: SwiftUI.Color { .init(.attachmentOutgoingSurface) }

    /// The "BubbleStroke" asset catalog color.
    static var bubbleStroke: SwiftUI.Color { .init(.bubbleStroke) }

    /// The "ChromeBackground" asset catalog color.
    static var chromeBackground: SwiftUI.Color { .init(.chromeBackground) }

    /// The "ContentBackground" asset catalog color.
    static var contentBackground: SwiftUI.Color { .init(.contentBackground) }

    /// The "IncomingBubbleFill" asset catalog color.
    static var incomingBubbleFill: SwiftUI.Color { .init(.incomingBubbleFill) }

    /// The "InspectorBackground" asset catalog color.
    static var inspectorBackground: SwiftUI.Color { .init(.inspectorBackground) }

    /// The "LinkAttachmentFill" asset catalog color.
    static var linkAttachmentFill: SwiftUI.Color { .init(.linkAttachmentFill) }

    /// The "MediaCardFill" asset catalog color.
    static var mediaCardFill: SwiftUI.Color { .init(.mediaCardFill) }

    /// The "MediaCardSelectionStroke" asset catalog color.
    static var mediaCardSelectionStroke: SwiftUI.Color { .init(.mediaCardSelectionStroke) }

    /// The "MediaCardStroke" asset catalog color.
    static var mediaCardStroke: SwiftUI.Color { .init(.mediaCardStroke) }

    /// The "MetadataText" asset catalog color.
    static var metadataText: SwiftUI.Color { .init(.metadataText) }

    /// The "OutgoingPrimaryText" asset catalog color.
    static var outgoingPrimaryText: SwiftUI.Color { .init(.outgoingPrimaryText) }

    /// The "OutgoingSecondaryText" asset catalog color.
    static var outgoingSecondaryText: SwiftUI.Color { .init(.outgoingSecondaryText) }

    /// The "ReplyOutgoingBar" asset catalog color.
    static var replyOutgoingBar: SwiftUI.Color { .init(.replyOutgoingBar) }

    /// The "ReplyOutgoingSurface" asset catalog color.
    static var replyOutgoingSurface: SwiftUI.Color { .init(.replyOutgoingSurface) }

    /// The "SecondarySurface" asset catalog color.
    static var secondarySurface: SwiftUI.Color { .init(.secondarySurface) }

    /// The "SidebarBackground" asset catalog color.
    static var sidebarBackground: SwiftUI.Color { .init(.sidebarBackground) }

    /// The "SidebarHoverFill" asset catalog color.
    static var sidebarHoverFill: SwiftUI.Color { .init(.sidebarHoverFill) }

    /// The "SidebarSelectionFill" asset catalog color.
    static var sidebarSelectionFill: SwiftUI.Color { .init(.sidebarSelectionFill) }

    /// The "SidebarSelectionStroke" asset catalog color.
    static var sidebarSelectionStroke: SwiftUI.Color { .init(.sidebarSelectionStroke) }

    /// The "SystemBubbleFill" asset catalog color.
    static var systemBubbleFill: SwiftUI.Color { .init(.systemBubbleFill) }

    /// The "TertiaryText" asset catalog color.
    static var tertiaryText: SwiftUI.Color { .init(.tertiaryText) }

    /// The "TimelineInactiveFill" asset catalog color.
    static var timelineInactiveFill: SwiftUI.Color { .init(.timelineInactiveFill) }

    /// The "VideoAttachmentFill" asset catalog color.
    static var videoAttachmentFill: SwiftUI.Color { .init(.videoAttachmentFill) }

    /// The "VideoPlayOverlay" asset catalog color.
    static var videoPlayOverlay: SwiftUI.Color { .init(.videoPlayOverlay) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

