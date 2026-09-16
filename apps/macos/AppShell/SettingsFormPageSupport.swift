import SwiftUI

struct SettingsPageSection: Identifiable {
    let id: String
    let title: String?
    let content: AnyView
}

struct SettingsFormPage: View {
    let sections: [SettingsPageSection]

    var body: some View {
        Form {
            ForEach(sections) { section in
                SettingsFormSection(section: section)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct SettingsFormSection: View {
    let section: SettingsPageSection

    var body: some View {
        if let title = section.title {
            Section(title) {
                section.content
            }
        } else {
            Section {
                section.content
            }
        }
    }
}
