import Foundation
import SwiftUI

struct AppChangelogEntry: Identifiable, Hashable {
    let date: Date
    let category: String
    let title: String
    let highlights: [String]

    var id: String {
        "\(date.timeIntervalSince1970)-\(category)-\(title)"
    }

    var dateText: String {
        Self.dateFormatter.string(from: date)
    }

    func categoryDisplayName(language: AppLanguage) -> String {
        switch category.lowercased() {
        case "features":
            return language.text("Funktionen", "Features")
        case "fixes":
            return language.text("Fehlerbehebungen", "Fixes")
        case "breaking changes":
            return language.text("Breaking Changes", "Breaking Changes")
        case "docs":
            return language.text("Doku", "Docs")
        case "chore":
            return language.text("Chore", "Chore")
        default:
            return category
        }
    }

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum AppChangelogCatalog {
    static let latestEntries = load(limit: 5)

    static func load(limit: Int? = nil) -> [AppChangelogEntry] {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let lines = raw.components(separatedBy: .newlines)
        var currentCategory = "Features"
        var entries: [AppChangelogEntry] = []
        var currentTitle: String?
        var currentDate: Date?
        var currentHighlights: [String] = []

        func finalizeCurrentEntry() {
            guard let currentTitle, let currentDate else { return }
            entries.append(
                AppChangelogEntry(
                    date: currentDate,
                    category: currentCategory,
                    title: currentTitle,
                    highlights: currentHighlights
                )
            )
            currentHighlights.removeAll(keepingCapacity: true)
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("## ") {
                finalizeCurrentEntry()
                currentTitle = nil
                currentDate = nil

                let heading = line.dropFirst(3)
                if heading.localizedCaseInsensitiveContains("Features") {
                    currentCategory = "Features"
                } else if heading.localizedCaseInsensitiveContains("Fixes") {
                    currentCategory = "Fixes"
                } else if heading.localizedCaseInsensitiveContains("Breaking") {
                    currentCategory = "Breaking Changes"
                } else if heading.localizedCaseInsensitiveContains("Docs") {
                    currentCategory = "Docs"
                } else if heading.localizedCaseInsensitiveContains("Chore") {
                    currentCategory = "Chore"
                } else {
                    currentCategory = String(heading)
                }
                continue
            }

            if let parsedEntry = parseEntryLine(rawLine) {
                finalizeCurrentEntry()
                currentTitle = parsedEntry.title
                currentDate = parsedEntry.date
                currentHighlights = []
                continue
            }

            if currentTitle != nil {
                if let detail = parseHighlightLine(rawLine) {
                    currentHighlights.append(detail)
                } else if line.isEmpty {
                    continue
                }
            }
        }

        finalizeCurrentEntry()

        let ordered = entries.sorted { $0.date > $1.date }
        guard let limit else {
            return ordered
        }
        return Array(ordered.prefix(limit))
    }

    private static func parseEntryLine(_ rawLine: String) -> (date: Date, title: String)? {
        let pattern = #"^\-\s*(\d{4}-\d{2}-\d{2}):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine)),
              result.numberOfRanges == 3,
              let dateRange = Range(result.range(at: 1), in: rawLine),
              let titleRange = Range(result.range(at: 2), in: rawLine) else {
            return nil
        }

        let dateString = String(rawLine[dateRange])
        let title = String(rawLine[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let date = AppChangelogEntry.dateFormatter.date(from: dateString) else {
            return nil
        }
        return (date, title)
    }

    private static func parseHighlightLine(_ rawLine: String) -> String? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") else { return nil }
        let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : String(text)
    }
}

struct ChangelogSectionView: View {
    let entries: [AppChangelogEntry]
    let language: AppLanguage

    private func text(_ german: String, _ english: String) -> String {
        language.text(german, english)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text(
                "Die neuesten Änderungen aus `changelog.md`.",
                "The latest changes from `changelog.md`."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)

            if entries.isEmpty {
                Text(text(
                    "Noch keine Changelog-Einträge verfügbar.",
                    "No changelog entries available yet."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                FeaturedChangelogCard(entry: entries[0], language: language)

                if entries.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(text("Ältere Einträge", "Earlier entries"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(Array(entries.dropFirst())) { entry in
                            ChangelogEntryCard(entry: entry, language: language)
                        }
                    }
                }
            }
        }
    }
}

private struct FeaturedChangelogCard: View {
    let entry: AppChangelogEntry
    let language: AppLanguage

    private func text(_ german: String, _ english: String) -> String {
        language.text(german, english)
    }

    private var categoryColor: Color {
        switch entry.category.lowercased() {
        case "features":
            return .cyan
        case "fixes":
            return .mint
        case "breaking changes":
            return .red
        case "docs":
            return .orange
        case "chore":
            return .secondary
        default:
            return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(text("Neueste Version", "Latest release"), systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text(entry.dateText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.categoryDisplayName(language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.14), in: Capsule())

                Text(entry.title)
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if !entry.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.highlights.prefix(4), id: \.self) { highlight in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Circle()
                                .fill(categoryColor.opacity(0.8))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 2)
            }

            Text(text(
                "Diese Karte hebt den aktuellsten Release besonders hervor.",
                "This card highlights the most recent release."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.16),
                            Color.accentColor.opacity(0.06),
                            Color.secondary.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct ChangelogEntryCard: View {
    let entry: AppChangelogEntry
    let language: AppLanguage

    private func text(_ german: String, _ english: String) -> String {
        language.text(german, english)
    }

    private var categoryColor: Color {
        switch entry.category.lowercased() {
        case "features":
            return .blue
        case "fixes":
            return .green
        case "breaking changes":
            return .red
        case "docs":
            return .orange
        case "chore":
            return .secondary
        default:
            return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.dateText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text(entry.categoryDisplayName(language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.12), in: Capsule())

                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if !entry.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.highlights, id: \.self) { highlight in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(highlight)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 2)
            } else {
                Text(text(
                    "Keine weiteren Details erfasst.",
                    "No additional details captured."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        )
    }
}
