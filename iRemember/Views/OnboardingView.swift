import AppKit
import SwiftUI

struct OnboardingView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        SetupAssistantContainer {
            PermissionSetupHero(detail: appModel.setupSnapshot.detail)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                SetupCard(
                    title: "Before the archive can open",
                    subtitle: "iRemember needs the same local file access that Messages uses on this Mac."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(appModel.setupSnapshot.requirements) { requirement in
                            SetupRequirementRow(requirement: requirement)
                        }
                    }
                }

                SetupCard(
                    title: "Library details",
                    subtitle: "Technical paths stay available here if you need to verify what the app is reading."
                ) {
                    SourceLocationsDisclosure(locations: appModel.setupSnapshot.locations, technicalDetails: nil)
                }
            }
        } actions: {
            PermissionRecoveryActions(appModel: appModel)
        }
    }
}

private struct PermissionSetupHero: View {
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Allow access to your local Messages library")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Nothing is uploaded or modified.", systemImage: "lock.shield")
                Label("This permission only lets the app read the local archive already on your Mac.", systemImage: "externaldrive.badge.checkmark")
                Label("After access is granted, the app opens directly into the archive workspace.", systemImage: "sparkles.rectangle.stack")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionRecoveryActions: View {
    @Bindable var appModel: AppModel

    var body: some View {
        SetupCard(
            title: "Next step",
            subtitle: "Open Privacy & Security, allow access, then return here."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Button("Open Privacy & Security") {
                    openPrivacySettings()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .setupPrimaryActionStyle()
                .accessibilityIdentifier("open-privacy-settings")

                HStack(spacing: 12) {
                    Button("Try Again") {
                        Task { await appModel.loadPrimaryLibrary() }
                    }
                    .setupSecondaryActionStyle()
                    .accessibilityIdentifier("open-messages-library")

                    if appModel.canUseSampleFallback {
                        Button("Use Sample Library") {
                            Task { await appModel.loadSampleLibrary() }
                        }
                        .setupSecondaryActionStyle()
                        .accessibilityIdentifier("open-sample-library")
                    }
                }

                Text("If you launch from Xcode during development, Xcode also needs Full Disk Access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
