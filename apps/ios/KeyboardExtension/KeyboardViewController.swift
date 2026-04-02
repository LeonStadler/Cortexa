import UIKit
import SnippetCore

final class KeyboardViewController: UIInputViewController {
    private let dictationButton = UIButton(type: .system)
    private let languageLabel = UILabel()
    private let latestTranscriptLabel = UILabel()
    private let snippetsStackView = UIStackView()
    private let containerStackView = UIStackView()
    private let storage = IOSSharedStorage()
    private var snippetRules: [SnippetRule] = []
    private var latestInsertionState: IOSKeyboardInsertionState?
    private var storageErrorDescription: String?
    private var foregroundObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        try? storage.clearLicenseCache()
        setupViews()
        registerObservers()
        reloadSharedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSharedState()
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @objc
    private func insertLatestTranscript() {
        guard storageErrorDescription == nil else { return }
        guard let latestTranscript = latestInsertionState?.text, !latestTranscript.isEmpty else { return }
        textDocumentProxy.insertText(latestTranscript)
        try? storage.appendAudit("keyboard.insert_latest chars=\(latestTranscript.count)")
    }

    private func setupViews() {
        dictationButton.setTitle("Insert Latest Transcript", for: .normal)
        dictationButton.addTarget(self, action: #selector(insertLatestTranscript), for: .touchUpInside)
        dictationButton.translatesAutoresizingMaskIntoConstraints = false

        languageLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        languageLabel.textColor = .secondaryLabel
        languageLabel.textAlignment = .center

        latestTranscriptLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        latestTranscriptLabel.textColor = .secondaryLabel
        latestTranscriptLabel.numberOfLines = 2

        snippetsStackView.axis = .vertical
        snippetsStackView.spacing = 8

        containerStackView.axis = .vertical
        containerStackView.spacing = 12
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(dictationButton)
        containerStackView.addArrangedSubview(latestTranscriptLabel)
        containerStackView.addArrangedSubview(languageLabel)
        containerStackView.addArrangedSubview(snippetsStackView)

        view.addSubview(containerStackView)
        NSLayoutConstraint.activate([
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            containerStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func registerObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSharedState()
        }
    }

    private func reloadSharedState() {
        do {
            snippetRules = try storage.loadSnippets()
            latestInsertionState = try storage.loadKeyboardInsertionState()
            storageErrorDescription = nil
        } catch {
            storageErrorDescription = error.localizedDescription
        }
        rebuildSnippetsUI()
        updateLatestTranscriptUI()
        updateLanguageLabel()
    }

    private func rebuildSnippetsUI() {
        snippetsStackView.arrangedSubviews.forEach { subview in
            snippetsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        guard storageErrorDescription == nil else { return }

        for rule in snippetRules.prefix(5) {
            let button = UIButton(type: .system)
            button.setTitle(rule.trigger, for: .normal)
            button.contentHorizontalAlignment = .left
            button.addAction(UIAction { [weak self] _ in
                self?.textDocumentProxy.insertText(rule.replacement)
                try? self?.storage.appendAudit("keyboard.snippet_insert chars=\(rule.replacement.count)")
            }, for: .touchUpInside)
            snippetsStackView.addArrangedSubview(button)
        }
    }

    private func updateLatestTranscriptUI() {
        if let storageErrorDescription {
            latestTranscriptLabel.text = "Shared storage unavailable: \(storageErrorDescription)"
            dictationButton.isEnabled = false
        } else if let latestTranscript = latestInsertionState?.text, !latestTranscript.isEmpty {
            latestTranscriptLabel.text = "Latest transcript: \(previewText(for: latestTranscript))"
            dictationButton.isEnabled = true
        } else {
            latestTranscriptLabel.text = "Latest transcript: none available"
            dictationButton.isEnabled = false
        }
    }

    private func updateLanguageLabel() {
        if storageErrorDescription != nil {
            languageLabel.text = "Shared App Group is required for transcript insertion."
        } else {
            languageLabel.text = "Language: \(languageDisplayName(for: activeLanguageCode))"
        }
    }

    private var activeLanguageCode: String {
        (try? storage.sharedDefaults().string(forKey: SharedDefaultsKeys.languageCode)) ?? "de"
    }

    private func previewText(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "None" }
        let maxLength = 120
        if trimmed.count > maxLength {
            return "\(trimmed.prefix(maxLength))…"
        }
        return trimmed
    }

    private func languageDisplayName(for code: String) -> String {
        switch code {
        case "de":
            return "Deutsch"
        case "en":
            return "English"
        default:
            return "Auto"
        }
    }
}
