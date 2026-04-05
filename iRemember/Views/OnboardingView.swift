import SwiftUI

struct OnboardingView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        SetupAssistantContainer {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                Text("Open your Messages library")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                Text(appModel.setupSnapshot.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                SetupCard(
                    title: "Before you start",
                    subtitle: "The app checks only what is needed for live access on this Mac."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(appModel.setupSnapshot.requirements) { requirement in
                            SetupRequirementRow(requirement: requirement)
                        }
                    }
                }

                SetupCard(
                    title: appModel.setupSnapshot.isReady ? "Ready to browse" : "If access is still blocked",
                    subtitle: appModel.setupSnapshot.isReady
                        ? "Live conversation metadata loads first. Full transcripts and media stay on demand."
                        : "macOS does not show an in-app consent sheet for Full Disk Access. Turn it on in Privacy & Security, then reopen the app."
                ) {
                    SourceLocationsDisclosure(locations: appModel.setupSnapshot.locations, technicalDetails: nil)
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button("Open Messages Library") {
                        Task { await appModel.loadPrimaryLibrary() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-messages-library")

                    OpenPrivacySettingsButton()

                    if appModel.canUseSampleFallback {
                        Button("Use Sample Library") {
                            Task { await appModel.loadSampleLibrary() }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("open-sample-library")
                    }
                }

                HStack(spacing: 12) {
                    SettingsLink {
                        Label("App Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.link)

                    Text("If you launch from Xcode during development, Xcode also needs Full Disk Access.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
