import ASRCore
import AppKit
import Carbon
import SwiftUI

struct SettingsRichTooltipAnchor: View {
    let helpText: String
    @State private var isPopoverPresented = false
    let accessibilityLabelText: String
    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            Text(helpText)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(14)
        }
        .accessibilityLabel(Text(verbatim: accessibilityLabelText))
        .accessibilityHint(Text(verbatim: helpText))
    }
}

struct SettingsFieldLabel: View {
    let title: String
    var helpText: String? = nil

    var body: some View {
        return HStack(spacing: 6) {
            Text(title)
            if let helpText, !helpText.isEmpty {
                SettingsRichTooltipAnchor(
                    helpText: helpText,
                    accessibilityLabelText: "\(title): Weitere Informationen"
                )
            }
        }
        // Attach the native macOS help tag to the complete label, not only the
        // tiny info glyph. This keeps the tooltip discoverable and reliable
        // when the glyph is difficult to hit at high display scaling.
        .help(helpText ?? "")
        .accessibilityElement(children: helpText == nil ? .combine : .contain)
        .accessibilityLabel(title)
    }
}

struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var hotkey: HotkeyBinding
    let label: String
    let language: AppLanguage

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let view = HotkeyRecorderButton()
        view.onChange = { newHotkey in
            hotkey = newHotkey
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.displayedHotkey = hotkey
        nsView.fieldLabel = label
        nsView.language = language
    }
}

struct HotkeyAdvisoryBox: View {
    let advisory: HotkeyAdvisory

    private var accentNSColor: NSColor {
        switch advisory.severity {
        case .critical:
            return .systemRed
        case .warning:
            return .systemOrange
        }
    }

    var body: some View {
        let accent = Color(nsColor: accentNSColor)
        VStack(alignment: .leading, spacing: 4) {
            Text(advisory.title)
                .font(.footnote.weight(.semibold))
            Text(advisory.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

final class HotkeyRecorderButton: NSButton {
    var onChange: ((HotkeyBinding) -> Void)?
    var displayedHotkey: HotkeyBinding = .optionSpace {
        didSet { updatePresentation() }
    }
    var fieldLabel: String = "Shortcut" {
        didSet { updatePresentation() }
    }
    var language: AppLanguage = .system {
        didSet { updatePresentation() }
    }

    private var isRecording = false {
        didSet { updatePresentation() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        updatePresentation()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape)
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
        {
            isRecording = false
            updatePresentation()
            return
        }

        guard let binding = HotkeyBinding.from(event: event) else {
            NSSound.beep()
            return
        }

        displayedHotkey = binding
        isRecording = false
        onChange?(binding)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updatePresentation()
        return true
    }

    private func updatePresentation() {
        title =
            isRecording
            ? language.text("Jetzt Tastenkombination drücken", "Press shortcut now")
            : displayedHotkey.displayName
        setAccessibilityLabel(fieldLabel)
        setAccessibilityValue(title)
        setAccessibilityHelp(
            language.text(
                "Leertaste oder Return zum Aufnehmen, Escape zum Abbrechen.",
                "Press Space or Return to start recording, Escape to cancel."
            ))
    }
}

struct PermissionStatusRow: View {
    let title: String
    let status: PermissionStatus
    let detail: String
    let statusLabel: String?
    let actionTitle: String?
    let actionHint: String?
    let action: (() -> Void)?

    init(
        title: String,
        status: PermissionStatus,
        detail: String,
        statusLabel: String? = nil,
        actionTitle: String? = nil,
        actionHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.status = status
        self.detail = detail
        self.statusLabel = statusLabel
        self.actionTitle = actionTitle
        self.actionHint = actionHint
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(statusLabel ?? status.label)
                    .foregroundStyle(status.color)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .liquidGlassSecondaryButtonStyle()
                        .controlSize(.small)
                        .accessibilityLabel(
                            actionHint.map { "\(actionTitle). \($0)" } ?? actionTitle
                        )
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct PermissionRecoveryBanner: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .liquidGlassSecondaryButtonStyle()
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

struct PermissionWarningTile: View {
    let title: String
    let message: String
    let status: PermissionStatus
    let actionTitle: String
    let actionHint: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status == .restricted ? "lock.trianglebadge.exclamationmark" : "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(actionHint)
                .accessibilityLabel(Text("\(actionTitle). \(actionHint)"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        }
    }
}

struct VoiceModelOperationProgressView: View {
    let operation: VoiceModelOperationKind
    let german: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch operation {
            case .installing(let progress):
                if progress.isIndeterminate || progress.phase == .downloading && progress.totalBytes == nil {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text(
                        german
                            ? "Verbindung wird aufgebaut …"
                            : "Establishing connection …"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(statusText(for: progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("\(progress.percentComplete)%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            case .removing:
                ProgressView()
                    .progressViewStyle(.linear)
                Text(
                    german
                        ? "Modell wird von der Festplatte entfernt …" : "Removing model from disk …"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func statusText(for progress: VoiceModelInstallProgress) -> String {
        switch progress.phase {
        case .preparing:
            return german ? "Download wird vorbereitet …" : "Preparing download …"
        case .downloading:
            if let receivedBytes = progress.receivedBytes,
                let totalBytes = progress.totalBytes,
                totalBytes > 0
            {
                let received = ByteCountFormatter.string(
                    fromByteCount: receivedBytes, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                return german
                    ? "Herunterladen: \(received) von \(total)"
                    : "Downloading: \(received) of \(total)"
            }
            return german ? "Herunterladen …" : "Downloading …"
        case .finalizing:
            return german ? "Modell wird installiert …" : "Installing model …"
        }
    }
}
