import SwiftUI

struct SettingsViewShell: View {
    @Binding var splitColumnVisibility: NavigationSplitViewVisibility
    @Binding var searchText: String
    let storedLanguage: AppLanguage
    let selectedTabSelection: Binding<SettingsTab>
    let currentSelectedTab: SettingsTab
    let selectedForm: AnyView
    let searchResults: [SettingsSearchDestination]
    let onSelectSearchResult: (SettingsSearchDestination) -> Void
    let accessibilityReduceMotion: Bool
    let toolbarAccessoryContent: AnyView?
    let onRefreshPermissionStates: () -> Void

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
    }

    private func text(_ german: String, _ english: String) -> String {
        storedLanguage.text(german, english)
    }

    private var searchFieldSyncedAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.26)
    }

    private var searchResultsContentTransition: AnyTransition {
        if accessibilityReduceMotion {
            .opacity
        } else {
            .opacity.combined(with: .offset(y: 7))
        }
    }

    private var settingsNavigationTitle: String {
        isSearching
            ? text("Suchergebnisse", "Search Results")
            : currentSelectedTab.title(language: storedLanguage)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            SettingsSidebarView(
                selectedTabSelection: selectedTabSelection,
                storedLanguage: storedLanguage
            )
        } detail: {
            SettingsDetailContainerView(
                isSearching: isSearching,
                selectedForm: selectedForm,
                searchResults: searchResults,
                storedLanguage: storedLanguage,
                onSelectSearchResult: onSelectSearchResult,
                settingsNavigationTitle: settingsNavigationTitle,
                searchResultsContentTransition: searchResultsContentTransition,
                searchFieldSyncedAnimation: searchFieldSyncedAnimation
            )
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: text("Einstellungen durchsuchen", "Search settings")
        )
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    let next: NavigationSplitViewVisibility =
                        splitColumnVisibility == .detailOnly ? .all : .detailOnly
                    if accessibilityReduceMotion {
                        splitColumnVisibility = next
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            splitColumnVisibility = next
                        }
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel(
                    text("Seitenleiste ein- oder ausblenden", "Show or hide sidebar")
                )
                .help(text("Seitenleiste ein- oder ausblenden", "Show or hide sidebar"))
            }
            if let toolbarAccessoryContent {
                ToolbarItem(placement: .primaryAction) {
                    toolbarAccessoryContent
                }
            }
        }
        .environment(\.locale, storedLanguage.localeForFormatting)
        .frame(
            minWidth: MacNativeDesign.SettingsSplitView.windowMinWidth,
            idealWidth: 1020,
            minHeight: 600,
            idealHeight: 650
        )
        .onAppear {
            onRefreshPermissionStates()
        }
    }
}

struct SettingsSidebarView: View {
    let selectedTabSelection: Binding<SettingsTab>
    let storedLanguage: AppLanguage

    var body: some View {
        List(selection: selectedTabSelection) {
            ForEach(SettingsTab.Group.allCases, id: \.self) { group in
                Section(group.title(language: storedLanguage)) {
                    ForEach(SettingsTab.tabs(in: group), id: \.self) { tab in
                        Label(tab.title(language: storedLanguage), systemImage: tab.symbolName)
                            .tag(tab)
                            .imageScale(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.automatic)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .environment(\.defaultMinListRowHeight, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationSplitViewColumnWidth(
            min: MacNativeDesign.SettingsSplitView.sidebarMinWidth,
            ideal: MacNativeDesign.SettingsSplitView.sidebarIdealWidth,
            max: MacNativeDesign.SettingsSplitView.sidebarMaxWidth
        )
    }
}

struct SettingsDetailContainerView: View {
    let isSearching: Bool
    let selectedForm: AnyView
    let searchResults: [SettingsSearchDestination]
    let storedLanguage: AppLanguage
    let onSelectSearchResult: (SettingsSearchDestination) -> Void
    let settingsNavigationTitle: String
    let searchResultsContentTransition: AnyTransition
    let searchFieldSyncedAnimation: Animation?

    var body: some View {
        NavigationStack {
            if isSearching {
                ScrollView {
                    SearchResultsSettingsPage(
                        results: searchResults,
                        language: storedLanguage,
                        onSelect: onSelectSearchResult
                    )
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .transition(searchResultsContentTransition)
                    .contentTransition(.interpolate)
                }
            } else {
                selectedForm
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(searchResultsContentTransition)
                    .contentTransition(.interpolate)
            }
        }
        .navigationTitle(settingsNavigationTitle)
        // Gleiche Kurve für Titel (Toolbar) und Inhalt, damit die System-Suchfeld-Animation nicht „auseinanderläuft“.
        .animation(searchFieldSyncedAnimation, value: isSearching)
        // Nur Detail-Spalte: globales `.controlSize` am SplitView würde auch die Fenster-Toolbar verkleinern.
        .controlSize(.regular)
        .navigationSplitViewColumnWidth(
            min: MacNativeDesign.SettingsSplitView.detailMinWidth,
            ideal: 720
        )
    }
}
