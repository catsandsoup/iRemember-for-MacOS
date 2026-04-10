import AppKit
import SwiftUI

struct SetupAssistantContainer<Hero: View, Content: View, Actions: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder let hero: Hero
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .overlay(alignment: .topLeading) {
                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 24,
                        endRadius: 420
                    )
                    .frame(width: 520, height: 420)
                }
                .overlay(alignment: .bottomTrailing) {
                    RadialGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 360
                    )
                    .frame(width: 460, height: 360)
                }
                .ignoresSafeArea()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 36) {
                    heroColumn
                    mainColumn
                }

                VStack(alignment: .leading, spacing: 32) {
                    heroColumn
                    mainColumn
                }
            }
            .padding(40)
            .frame(maxWidth: 1120, maxHeight: .infinity, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var heroColumn: some View {
        hero
            .frame(maxWidth: 340, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            content
            actions
        }
        .frame(maxWidth: 680, alignment: .leading)
    }
}

struct SetupCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.quaternary.opacity(colorScheme == .dark ? 0.9 : 0.6))
        }
    }
}

struct SetupRequirementRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let requirement: SetupRequirement

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconBackground, in: .circle)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(requirement.title)
                    .font(.body.weight(.semibold))

                Text(requirement.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconBackground: some ShapeStyle {
        iconColor.opacity(colorScheme == .dark ? 0.16 : 0.10)
    }

    private var iconName: String {
        switch requirement.state {
        case .complete:
            "checkmark.circle.fill"
        case .actionRequired:
            "exclamationmark.circle.fill"
        case .informational:
            "circle.dashed"
        }
    }

    private var iconColor: Color {
        switch requirement.state {
        case .complete:
            .green
        case .actionRequired:
            .orange
        case .informational:
            .secondary
        }
    }
}

struct SourceLocationsDisclosure: View {
    let locations: [SourceLocation]
    let technicalDetails: String?

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(locations) { location in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(location.displayPath)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                }

                if let technicalDetails, !technicalDetails.isEmpty {
                    Divider()

                    Text("Diagnostic details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(technicalDetails)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Library details", systemImage: "folder.badge.gearshape")
                .font(.headline)
        }
        .disclosureGroupStyle(.automatic)
    }
}

struct OpenPrivacySettingsButton: View {
    var body: some View {
        Button("Open Privacy & Security") {
            openPrivacySettings()
        }
        .accessibilityIdentifier("open-privacy-settings")
    }

    private func openPrivacySettings() {
        let workspace = NSWorkspace.shared

        if let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
           workspace.open(privacyURL) {
            return
        }

        if let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"),
           workspace.open(systemSettingsURL) {
            return
        }

        workspace.open(URL(filePath: "/System/Applications/System Settings.app"))
    }
}

struct OpenContactsSettingsButton: View {
    var body: some View {
        Button("Open Contacts Settings") {
            openContactsSettings()
        }
        .accessibilityIdentifier("open-contacts-settings")
    }

    private func openContactsSettings() {
        let workspace = NSWorkspace.shared

        if let contactsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"),
           workspace.open(contactsURL) {
            return
        }

        if let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"),
           workspace.open(systemSettingsURL) {
            return
        }

        workspace.open(URL(filePath: "/System/Applications/System Settings.app"))
    }
}

extension View {
    @ViewBuilder
    func setupPrimaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func setupSecondaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
