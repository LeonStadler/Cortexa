import SwiftUI

struct SettingsViewShell: View {
    @Binding var splitColumnVisibility: NavigationSplitViewVisibility
    @Binding var showsTabInfoPopover: Bool
    @Binding var searchText: String
    let storedLanguage: AppLanguage
    let selectedTabSelection: Binding<SettingsTab>
    let currentSelectedTab: SettingsTab
    let selectedForm: AnyView
    let searchResultsForm: AnyView
    let accessibilityReduceMotion: Bool
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
                searchResultsForm: searchResultsForm,
                settingsNavigationTitle: settingsNavigationTitle,
                searchResultsContentTransition: searchResultsContentTransition,
                searchFieldSyncedAnimation: searchFieldSyncedAnimation
            )
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsTabInfoPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(
                    text("Informationen zu diesem Bereich", "Information about this section")
                )
                // Kein `.help`: vermeidet den nativen Tooltip neben dem Klick-Popover.
                .popover(isPresented: $showsTabInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentSelectedTab.title(language: storedLanguage))
                            .font(.headline)
                        Text(currentSelectedTab.details(language: storedLanguage))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(minWidth: 280, maxWidth: 320, alignment: .leading)
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
        .background(.windowBackground)
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
            Section {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Label(tab.title(language: storedLanguage), systemImage: tab.symbolName)
                        .tag(tab)
                        .imageScale(.medium)
                }
            }
        }
        .listStyle(.sidebar)
        .settingsSidebarBackgroundExtensionEffect()
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
    let searchResultsForm: AnyView
    let settingsNavigationTitle: String
    let searchResultsContentTransition: AnyTransition
    let searchFieldSyncedAnimation: Animation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if isSearching {
                            searchResultsForm
                        } else {
                            selectedForm
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    // Vertikaler Offset + Opacity: Material/Glass in `Form` wirkt bei purem Fade oft zerhackt.
                    .transition(searchResultsContentTransition)
                    .contentTransition(.interpolate)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(settingsNavigationTitle)
        }
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
