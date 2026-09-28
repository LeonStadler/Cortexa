import Foundation
import SwiftUI

struct LicensesSettingsPage: View {
    let language: AppLanguage

    @State private var cortexaLicense = CortexaLicenseText.load()
    @State private var notices = ThirdPartyLicenseNotices.load()

    private func text(_ german: String, _ english: String) -> String {
        language.text(german, english)
    }

    var body: some View {
        Form {
            Section(text("Cortexa · Apache License 2.0", "Cortexa · Apache License 2.0")) {
                Text(
                    text(
                        "Cortexa steht unter der Apache License 2.0. © 2026 Leon Stadler. Nutzung, Änderung und Weitergabe sind nach den Bedingungen dieser Lizenz erlaubt; Lizenz- und Copyright-Hinweise müssen erhalten bleiben.",
                        "Cortexa is licensed under the Apache License 2.0. © 2026 Leon Stadler. Use, modification, and redistribution are permitted under its terms; license and copyright notices must be preserved."
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

                Link(
                    text("Offiziellen Apache-2.0-Lizenztext öffnen", "Open the official Apache-2.0 license text"),
                    destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0.html")!
                )

                DisclosureGroup(text("Vollständigen Cortexa-Lizenztext anzeigen", "Show the full Cortexa license")) {
                    switch cortexaLicense {
                    case .loaded(let content):
                        Text(content)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .unavailable:
                        Text(
                            text(
                                "Der mitgelieferte Apache-2.0-Lizenztext konnte nicht geladen werden. Bitte installiere Cortexa erneut.",
                                "The bundled Apache-2.0 license could not be loaded. Please reinstall Cortexa."
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section(text("Drittanbieter-Lizenzen", "Third-party licenses")) {
                licenseSummary(
                    title: "whisper.cpp",
                    detail: "MIT License · gebündelte Spracherkennung · ggml authors",
                    englishDetail: "MIT License · bundled speech recognition · ggml authors",
                    licenseURL: URL(string: "https://github.com/ggml-org/whisper.cpp/blob/9453b4b9be9b73adfc35051083f37cefa039acee/LICENSE")!
                )
                licenseSummary(
                    title: "Sparkle",
                    detail: "MIT License und zusätzliche Drittanbieterhinweise · optionaler Updater",
                    englishDetail: "MIT License and additional third-party notices · optional updater",
                    licenseURL: URL(string: "https://github.com/sparkle-project/Sparkle/blob/eef1a539a373c1f1a320624b1130fc5de7b2e100/LICENSE")!
                )
                licenseSummary(
                    title: "NVIDIA NeMo-Speech.cpp",
                    detail: "Apache-2.0 und separate Drittanbieterbedingungen · Runtime wird bei Bedarf geladen",
                    englishDetail: "Apache-2.0 and separate third-party terms · runtime is downloaded when needed",
                    licenseURL: URL(string: "https://github.com/NVIDIA/NeMo-Speech.cpp/blob/v0.1.0/LICENSE")!
                )
                licenseSummary(
                    title: "NVIDIA Parakeet TDT 0.6B v3",
                    detail: "CC-BY-4.0 · NVIDIA · Modell wird bei Bedarf geladen",
                    englishDetail: "CC-BY-4.0 · NVIDIA · model is downloaded when needed",
                    licenseURL: URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode")!
                )
                Link(
                    text("Parakeet-Modellseite und Lizenz", "Parakeet model page and license"),
                    destination: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")!
                )
            }

            Section(text("Lizenztexte und Hinweise", "License texts and notices")) {
                DisclosureGroup(text("Vollständige Drittanbieter-Lizenztexte anzeigen", "Show full third-party license texts")) {
                    switch notices {
                    case .loaded(let content):
                        if let formatted = try? AttributedString(markdown: content) {
                            Text(formatted)
                                .font(.footnote)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(content)
                                .font(.footnote)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    case .unavailable:
                        Text(
                            text(
                                "Die mitgelieferten Drittanbieterhinweise konnten nicht geladen werden. Bitte installiere Cortexa erneut.",
                                "The bundled third-party notices could not be loaded. Please reinstall Cortexa."
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private func licenseSummary(
        title: String,
        detail: String,
        englishDetail: String,
        licenseURL: URL
    ) -> some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(text(detail, englishDetail))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Link(text("Lizenz öffnen", "Open license"), destination: licenseURL)
                    .font(.footnote)
            }
        }
    }
}

private enum ThirdPartyLicenseNotices {
    case loaded(String)
    case unavailable

    static func load() -> Self {
        guard let url = Bundle.main.url(forResource: "third-party-notices", withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return .unavailable
        }
        return .loaded(contents)
    }
}

private enum CortexaLicenseText {
    case loaded(String)
    case unavailable

    static func load() -> Self {
        guard let url = Bundle.main.url(forResource: "Apache-2.0", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return .unavailable
        }
        return .loaded(contents)
    }
}
