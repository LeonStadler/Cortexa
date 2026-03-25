import UIKit
import SnippetCore

final class KeyboardViewController: UIInputViewController {
    private let dictationButton = UIButton(type: .system)
    private let latestTranscriptButton = UIButton(type: .system)
    private let languageLabel = UILabel()
    private let latestTranscriptLabel = UILabel()
    private let snippetsStackView = UIStackView()
    private let containerStackView = UIStackView()
    private let storage = IOSSharedStorage()
    private var snippetRules: [SnippetRule] = []
    private var latestTranscript: String?
    private var isRecording = false
    private var foregroundObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

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
    private func toggleDictation() {
        isRecording.toggle()
        dictationButton.setTitle(isRecording ? "Stop" : "Dictate", for: .normal)

        if !isRecording {
            let insertion = (latestTranscript?.isEmpty == false)
                ? latestTranscript!
                : "iOS keyboard dictation placeholder"

            textDocumentProxy.insertText(insertion)
            persistInsertedTranscript(insertion)
        }
    }

    @objc
    private func insertLatestTranscript() {
        guard let latestTranscript, !latestTranscript.isEmpty else { return }
        textDocumentProxy.insertText(latestTranscript)
        persistInsertedTranscript(latestTranscript)
    }

    func applyCommittedPatch(text: String) {
        textDocumentProxy.insertText(text)
    }

    private func setupViews() {
        dictationButton.setTitle("Dictate", for: .normal)
        dictationButton.addTarget(self, action: #selector(toggleDictation), for: .touchUpInside)
        dictationButton.translatesAutoresizingMaskIntoConstraints = false

        latestTranscriptButton.setTitle("Insert Latest", for: .normal)
        latestTranscriptButton.addTarget(self, action: #selector(insertLatestTranscript), for: .touchUpInside)

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
        containerStackView.addArrangedSubview(latestTranscriptButton)
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
        snippetRules = storage.loadSnippets()
        latestTranscript = storage.loadLatestTranscriptEntry()?.text
        rebuildSnippetsUI()
        updateLatestTranscriptUI()
        updateLanguageLabel()
    }

    private func rebuildSnippetsUI() {
        snippetsStackView.arrangedSubviews.forEach { subview in
            snippetsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for rule in snippetRules.prefix(5) {
            let button = UIButton(type: .system)
            button.setTitle(rule.trigger, for: .normal)
            button.contentHorizontalAlignment = .left
            button.addAction(UIAction { [weak self] _ in
                self?.textDocumentProxy.insertText(rule.replacement)
                self?.persistInsertedTranscript(rule.replacement)
            }, for: .touchUpInside)
            snippetsStackView.addArrangedSubview(button)
        }
    }

    private func updateLatestTranscriptUI() {
        if let latestTranscript, !latestTranscript.isEmpty {
            latestTranscriptLabel.text = "Latest transcript: \(previewText(for: latestTranscript))"
            latestTranscriptButton.isEnabled = true
        } else {
            latestTranscriptLabel.text = "Latest transcript: none"
            latestTranscriptButton.isEnabled = false
        }
    }

    private func updateLanguageLabel() {
        languageLabel.text = "Language: \(languageDisplayName(for: activeLanguageCode))"
    }

    private var activeLanguageCode: String {
        storage.sharedDefaults().string(forKey: SharedDefaultsKeys.languageCode) ?? "de"
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

    private func persistInsertedTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var history = storage.loadTranscriptHistory()
        history.insert(IOSTranscriptHistoryEntry(text: trimmed, languageCode: activeLanguageCode), at: 0)
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        try? storage.saveTranscriptHistory(history)
        storage.appendAudit("keyboard.insert chars=\(trimmed.count)")
        latestTranscript = trimmed
        updateLatestTranscriptUI()
    }
}
