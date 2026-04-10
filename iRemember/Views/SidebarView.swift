import SwiftUI

struct SidebarView: View {
    @Bindable var appModel: AppModel

    private var pinnedArchives: [ArchiveSummary] {
        appModel.visibleSidebarArchives.filter(\.isPinned)
    }

    private var standardArchives: [ArchiveSummary] {
        appModel.visibleSidebarArchives.filter { !$0.isPinned }
    }

    private var showsSearchResults: Bool {
        !appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List(selection: archiveSelection) {
            if showsSearchResults {
                searchResultsContent
            } else {
                archiveListContent
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appModel.searchText) { _, _ in
            appModel.persistSessionIfPossible()
        }
        .onChange(of: appModel.searchScope) { _, _ in
            appModel.persistSessionIfPossible()
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
    }

    @ViewBuilder
    private var archiveListContent: some View {
        if !pinnedArchives.isEmpty {
            Section("Pinned") {
                ForEach(pinnedArchives) { archive in
                    ArchiveRow(
                        archive: archive,
                        isSelected: appModel.selectedArchiveSummary?.id == archive.id,
                        onExport: {
                            Task {
                                await appModel.selectArchive(archive)
                                appModel.presentExport(scope: .entireConversation)
                            }
                        },
                        onExportRange: {
                            Task {
                                await appModel.selectArchive(archive)
                                appModel.presentExport(scope: .currentLoadedRange)
                            }
                        }
                    )
                    .tag(archive.id)
                }
            }
        }

        if !standardArchives.isEmpty {
            Section(primarySectionTitle) {
                ForEach(standardArchives) { archive in
                    ArchiveRow(
                        archive: archive,
                        isSelected: appModel.selectedArchiveSummary?.id == archive.id,
                        onExport: {
                            Task {
                                await appModel.selectArchive(archive)
                                appModel.presentExport(scope: .entireConversation)
                            }
                        },
                        onExportRange: {
                            Task {
                                await appModel.selectArchive(archive)
                                appModel.presentExport(scope: .currentLoadedRange)
                            }
                        }
                    )
                    .tag(archive.id)
                }
            }
        }
    }

    private var primarySectionTitle: String {
        switch appModel.sidebarMode {
        case .threads:
            "Recent Conversations"
        case .people:
            "Recent Contacts"
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        Section {
            if appModel.isSearching {
                ProgressView("Searching")
                    .padding(.vertical, AppChrome.spacing8)
            } else if appModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different phrase, or switch the search scope.")
                )
            } else {
                ForEach(appModel.searchResults) { result in
                    SearchResultRow(result: result) {
                        Task { await appModel.activateSearchResult(result) }
                    }
                }
            }
        } header: {
            SearchResultsHeader(searchScope: $appModel.searchScope)
        }
    }

    private var archiveSelection: Binding<String?> {
        Binding(
            get: { appModel.selectedArchiveSummary?.id },
            set: { newValue in
                guard let newValue,
                      let archive = appModel.visibleSidebarArchives.first(where: { $0.id == newValue }) else {
                    return
                }
                Task { await appModel.selectArchive(archive) }
            }
        )
    }
}

private struct SearchResultsHeader: View {
    @Binding var searchScope: SearchScope

    var body: some View {
        HStack {
            Text("Search Results")

            Spacer()

            Menu {
                Picker("Search In", selection: $searchScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
            } label: {
                Label("Search In", systemImage: "line.3.horizontal.decrease.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .help("Change search scope")
        }
    }
}

private struct ArchiveRow: View {
    let archive: ArchiveSummary
    let isSelected: Bool
    let onExport: () -> Void
    let onExportRange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(archive.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if archive.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(archive.lastActivityAt.sidebarLabel)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .secondary : .tertiary)
                    .monospacedDigit()
            }

            Text(archive.secondaryText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Export Archive…", action: onExport)
            Button("Export Loaded Range…", action: onExportRange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(archive.title), \(archive.secondaryText)")
    }
}

private struct SearchResultRow: View {
    let result: ArchiveSearchResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: result.kind.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(result.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(result.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(result.archiveTitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        if let sentAt = result.sentAt {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(sentAt.sidebarLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Jump in Context", action: action)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.kind.label). \(result.title). \(result.subtitle)")
    }
}
