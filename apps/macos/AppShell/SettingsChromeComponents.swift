import AppKit
import Carbon
import SwiftUI

struct SettingsRichTooltipAnchor: View {
    let helpText: String
    /// Wenn `true`, übernimmt das umgebende `accessibilityElement(children: .combine)` die Ansage.
    var suppressIndividualAccessibility: Bool = false
    @State private var isPresented = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        // Kein `.help(helpText)`: würde den nativen System-Tooltip zeigen — parallel zum Hover-Popover.
        .accessibilityHidden(suppressIndividualAccessibility)
        .accessibilityLabel(Text(verbatim: helpText))
        .onDisappear {
            hoverTask?.cancel()
            isPresented = false
        }
        .onHover { inside in
            if inside {
                hoverTask?.cancel()
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    guard !Task.isCancelled else { return }
                    isPresented = true
                }
            } else {
                hoverTask?.cancel()
                hoverTask = nil
                isPresented = false
            }
        }
        .popover(isPresented: $isPresented) {
            Text(helpText)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 220, idealWidth: 300, maxWidth: 380, alignment: .leading)
                .padding(14)
                .settingsTooltipPanelBackground()
        }
    }
}

struct SettingsFieldLabel: View {
    let title: String
    var helpText: String? = nil

    var body: some View {
        let accessibilityCombined: String = {
            guard let helpText, !helpText.isEmpty else { return title }
            return "\(title). \(helpText)"
        }()
        return HStack(spacing: 6) {
            Text(title)
            if let helpText, !helpText.isEmpty {
                SettingsRichTooltipAnchor(helpText: helpText, suppressIndividualAccessibility: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCombined)
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
    let actionTitle: String?
    let actionHint: String?
    let action: (() -> Void)?

    init(
        title: String,
        status: PermissionStatus,
        detail: String,
        actionTitle: String? = nil,
        actionHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.status = status
        self.detail = detail
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
                Text(status.label)
                    .foregroundStyle(status.color)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .wisprSecondaryButtonStyle()
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
