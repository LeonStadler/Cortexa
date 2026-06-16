import AppKit
import SwiftUI

final class SettingsWindowPresenter {
    private let appState: MacAppState
    private weak var window: NSWindow?

    init(appState: MacAppState) {
        self.appState = appState
    }

    func show() {
        let window = existingWindow ?? makeWindow()
        let app = NSApplication.shared
        if !app.isActive {
            app.activate(ignoringOtherApps: true)
        }
        if window.isKeyWindow && window.isVisible {
            window.orderFront(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
        Task { @MainActor in
            appState.refreshPermissionStatesWithStabilization()
        }
    }

    private var existingWindow: NSWindow? {
        guard let window, !window.isReleasedWhenClosed else {
            return nil
        }
        return window
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: SettingsView().environmentObject(appState))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WisprLocal"
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        // Standard-Titelzeile: mit fullSizeContentView + transparenter Bar sitzt der Titel optisch falsch
        // und überlappt leicht mit dem SwiftUI-Inhalt.
        window.titlebarAppearsTransparent = false
        window.backgroundColor = .windowBackgroundColor
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 1000, height: 640))
        window.contentMinSize = NSSize(
            width: MacNativeDesign.SettingsSplitView.windowMinWidth,
            height: 620
        )
        window.contentMaxSize = NSSize(width: 4_000, height: 1_200)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("WisprLocalSettingsWindow")
        self.window = window
        return window
    }
}
