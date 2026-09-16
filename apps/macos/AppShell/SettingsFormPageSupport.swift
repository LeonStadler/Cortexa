import SwiftUI

struct SettingsPageSection: Identifiable {
    let id: String
    let title: String?
    let content: AnyView
}

struct SettingsFormPage: View {
    let sections: [SettingsPageSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(sections) { section in
                SettingsFormSection(section: section)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct SettingsFormSection: View {
    let section: SettingsPageSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = section.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            section.content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
