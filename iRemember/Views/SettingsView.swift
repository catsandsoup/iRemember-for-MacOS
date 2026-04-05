import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        TabView {
            Form {
                LabeledContent("Current strategy") {
                    Text(appModel.sourceStrategy.label)
                }

                LabeledContent("Current source") {
                    Text(appModel.sourceModeName)
                }

                LabeledContent("Transcript policy") {
                    Text("Windowed around active focus")
                }

                LabeledContent("Current library mode") {
                    Text(appModel.sourceModeDescription)
                }

                LabeledContent("Messages paths") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appModel.sourceLocations) { location in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(location.displayPath)
                                    .font(.callout.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Toggle("Enable local index encryption when available", isOn: .constant(true))
                Toggle("Exclude message bodies from logs", isOn: .constant(true))
                Toggle("Require confirmation before export", isOn: .constant(true))

                Text("The live Messages source reads only local files. Future derived indexes and caches should remain local, transparent, and opt-in.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }

            Form {
                LabeledContent("Warm launch target") {
                    Text("< 2 seconds")
                }

                LabeledContent("Date jump target") {
                    Text("< 300 ms median")
                }

                LabeledContent("Media grid open target") {
                    Text("< 500 ms")
                }
            }
            .padding()
            .tabItem {
                Label("Performance", systemImage: "speedometer")
            }
        }
        .padding(20)
    }
}
