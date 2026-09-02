import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DiagnosticsController {
    private let auditLogger: AuditLogging
    private let debugLogger: AuditLogging
    private let currentRecordingStatus: () -> String
    private let currentPermissionSummary: () -> String
    private let currentCapabilitySummary: () -> String
    private let currentUpdaterStatusText: () -> String
    private let currentDebugModeEnabled: () -> Bool
    private let currentDiagnosticsText: () -> String
    private let currentDebugLogText: () -> String
    private let setDiagnosticsText: (String) -> Void
    private let setDebugLogText: (String) -> Void

    private var diagnosticLines: [String] = []
    private var debugLines: [String] = []

    init(
        auditLogger: AuditLogging,
        debugLogger: AuditLogging,
        currentRecordingStatus: @escaping () -> String,
        currentPermissionSummary: @escaping () -> String,
        currentCapabilitySummary: @escaping () -> String,
        currentUpdaterStatusText: @escaping () -> String,
        currentDebugModeEnabled: @escaping () -> Bool,
        currentDiagnosticsText: @escaping () -> String,
        currentDebugLogText: @escaping () -> String,
        setDiagnosticsText: @escaping (String) -> Void,
        setDebugLogText: @escaping (String) -> Void
    ) {
        self.auditLogger = auditLogger
        self.debugLogger = debugLogger
        self.currentRecordingStatus = currentRecordingStatus
        self.currentPermissionSummary = currentPermissionSummary
        self.currentCapabilitySummary = currentCapabilitySummary
        self.currentUpdaterStatusText = currentUpdaterStatusText
        self.currentDebugModeEnabled = currentDebugModeEnabled
        self.currentDiagnosticsText = currentDiagnosticsText
        self.currentDebugLogText = currentDebugLogText
        self.setDiagnosticsText = setDiagnosticsText
        self.setDebugLogText = setDebugLogText
    }

    func appendDiagnostic(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        diagnosticLines.append("[\(timestamp)] \(line)")
        if diagnosticLines.count > 200 {
            diagnosticLines = Array(diagnosticLines.suffix(200))
        }
        setDiagnosticsText(diagnosticLines.joined(separator: "\n"))
        appendAudit("diag \(line)")
    }

    func appendDebug(_ line: String) {
        guard currentDebugModeEnabled() else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(line)"
        debugLines.append(entry)
        if debugLines.count > 400 {
            debugLines = Array(debugLines.suffix(400))
        }
        setDebugLogText(debugLines.joined(separator: "\n"))
        debugLogger.append(line)
        appendAudit("debug \(line)")
    }

    func appendAudit(_ line: String) {
        auditLogger.append(line)
    }

    func exportDiagnosticsReport() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "cortexa-diagnostics.txt"
        Self.configureSavePanel(panel, titleKey: "filepanel.export.diagnostics.title")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let report = [
            "Cortexa Diagnostics",
            "Status: \(currentRecordingStatus())",
            "Permissions: \(currentPermissionSummary())",
            "Capability: \(currentCapabilitySummary())",
            "Updater: \(currentUpdaterStatusText())",
            "Technical logging: \(currentDebugModeEnabled() ? "enabled" : "disabled")",
            "",
            currentDiagnosticsText(),
            "",
            "Technical Diagnostic Log",
            currentDebugLogText().isEmpty ? "No technical diagnostic events captured." : currentDebugLogText(),
        ].joined(separator: "\n")

        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            appendDiagnostic("Diagnose exportiert")
            appendAudit("diagnostics.export path=\(url.path)")
        } catch {
            appendDiagnostic("Diagnose-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportAuditLog() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-audit.log"
        Self.configureSavePanel(panel, titleKey: "filepanel.export.audit.title")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try auditLogger.export(to: url)
            appendDiagnostic("Audit-Log exportiert")
            appendAudit("audit.export path=\(url.path)")
        } catch {
            appendDiagnostic("Audit-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func diagnosticsAndDebugCombinedForClipboard() -> String {
        [
            "=== Diagnostics ===",
            currentDiagnosticsText(),
            "",
            "=== Technical log ===",
            currentDebugLogText().isEmpty ? "(empty)" : currentDebugLogText(),
        ].joined(separator: "\n")
    }

    func exportDebugLog() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-diagnostic-log.txt"
        Self.configureSavePanel(panel, titleKey: "filepanel.export.debug_log.title")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try debugLogger.export(to: url)
            appendDiagnostic("Diagnoseprotokoll exportiert")
            appendAudit("diagnostic-log.export path=\(url.path)")
        } catch {
            appendDiagnostic(
                "Diagnoseprotokoll-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private static func localizedFilePanelString(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private static func configureSavePanel(_ panel: NSSavePanel, titleKey: String) {
        panel.title = localizedFilePanelString(titleKey)
        panel.prompt = localizedFilePanelString("filepanel.save.prompt")
    }
}
