import AppKit
import SwiftUI

struct SetupAssistantContainer<Header: View, Content: View, Actions: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            AppTheme.chromeBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                content
                actions
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
    }
}

struct SetupCard<Content: View>: View {
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
                    .font(.headline)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SetupRequirementRow: View {
    let requirement: SetupRequirement

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(iconColor)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(requirement.title)
                    .font(.body.weight(.semibold))

                Text(requirement.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        DisclosureGroup("Show file details") {
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
        }
        .disclosureGroupStyle(.automatic)
    }
}

struct OpenPrivacySettingsButton: View {
    var body: some View {
        Button("Open Privacy & Security") {
            openPrivacySettings()
        }
        .buttonStyle(.bordered)
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
