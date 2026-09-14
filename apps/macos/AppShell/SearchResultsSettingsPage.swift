import SwiftUI

struct SearchResultsSettingsPage: View {
    let results: [SettingsSearchDestination]
    let language: AppLanguage
    let onSelect: (SettingsSearchDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if results.isEmpty {
                ContentUnavailableView(
                    language.text("Keine passenden Einstellungen", "No matching settings"),
                    systemImage: "magnifyingglass",
                    description: Text(language.text("Versuche einen anderen Suchbegriff.", "Try another search term."))
                )
            } else {
                Text(language.text("Einstellungen", "Settings"))
                    .font(.headline)
                List(results) { result in
                    Button { onSelect(result) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: result.tab.symbolName).frame(width: 18).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                Text("\(result.tab.title(language: language)) · \(result.subtitle)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(language.text("Öffnet diese Einstellung", "Opens this setting"))
                }
                .listStyle(.inset)
                .frame(minHeight: 180, idealHeight: 360)
            }
        }
    }
}
