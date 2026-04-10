import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Section("Library") {
                        LabeledContent("Source") {
                            Text(appModel.sourceModeName)
                        }

                        LabeledContent("Access") {
                            Text("Read-only")
                        }

                        Text(appModel.sourceModeDescription)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Section("Contacts") {
                        LabeledContent("Status") {
                            Text(appModel.contactIdentityAccessState.label)
                        }

                        Text(appModel.archiveIdentitySourceSummary)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ContactsAccessActions(appModel: appModel)
                    }
                }
                .formStyle(.grouped)
                .padding(20)
                .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
            }

            Tab("Privacy", systemImage: "hand.raised") {
                Form {
                    Section("How iRemember works") {
                        Label("Messages stay on this Mac.", systemImage: "lock.shield")
                        Label("The live archive opens in read-only mode.", systemImage: "externaldrive.badge.checkmark")
                        Label("Names from Contacts are optional and can be enabled later.", systemImage: "person.crop.circle")
                    }

                    Section("Library Locations") {
                        ForEach(appModel.sourceLocations) { location in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(location.displayPath)
                                    .font(.callout.monospaced())
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding(20)
                .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
            }
        }
        .padding(12)
    }
}

private struct ContactsAccessActions: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appModel.canRequestContactsAccess {
                Button("Use Contacts for Names") {
                    Task { await appModel.requestContactsAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else if appModel.canOpenContactsSettings {
                OpenContactsSettingsButton()
                    .buttonStyle(.bordered)
            } else if appModel.canRefreshContactsIdentity {
                Button("Refresh Contact Matching") {
                    Task { await appModel.refreshContactsIdentity() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
