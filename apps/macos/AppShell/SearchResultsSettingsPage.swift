import SwiftUI

struct SearchResultsSettingsPage: View {
    let sections: [SettingsPageSection]

    var body: some View {
        SettingsFormPage(sections: sections)
    }
}
