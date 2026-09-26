import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowPresenter: NSObject, NSWindowDelegate {
    private weak var window: NSWindow?
    private let appState: MacAppState
    private let onboardingStore: OnboardingStore
    private let coordinator: OnboardingCoordinator

    init(appState: MacAppState, onboardingStore: OnboardingStore) {
        self.appState = appState
        self.onboardingStore = onboardingStore
        self.coordinator = OnboardingCoordinator()
        super.init()
        coordinator.onFinished = { [weak self] in
            self?.close()
        }
    }

    func showIfNeeded() {
        guard !onboardingStore.isComplete else { return }
        show()
    }

    func show() {
        let window = existingWindow ?? makeWindow()
        let app = NSApplication.shared
        if !app.isActive {
            app.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        Task { @MainActor in
            appState.refreshPermissionStatesWithStabilization()
        }
    }

    func close() {
        window?.orderOut(nil)
    }

    private var existingWindow: NSWindow? {
        guard let window, !window.isReleasedWhenClosed else { return nil }
        return window
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: OnboardingView(
                appState: appState,
                onboardingStore: onboardingStore,
                coordinator: coordinator
            )
            .environmentObject(appState.voiceModelOperationStore)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Cortexa"
        window.styleMask = [.titled, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .windowBackgroundColor
        window.setContentSize(NSSize(width: 520, height: 640))
        window.contentMinSize = NSSize(width: 480, height: 580)
        window.contentMaxSize = NSSize(width: 720, height: 900)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onboardingStore.isComplete
    }
}
