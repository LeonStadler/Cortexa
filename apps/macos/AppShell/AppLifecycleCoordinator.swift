import AppKit
import Foundation

@MainActor
final class AppLifecycleCoordinator {
    private let workspaceNotificationCenter: NotificationCenter
    private let notificationCenter: NotificationCenter
    private let onRefreshPermissionStates: () -> Void
    private let onRefreshPermissionsAfterExternalEvent: (String) -> Void
    private let onRefreshOperationalState: (String) -> Void
    private var didActivateApplicationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didFinishLaunchingObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?
    private(set) var lastExternalApplication: NSRunningApplication?

    init(
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        notificationCenter: NotificationCenter = .default,
        onRefreshPermissionStates: @escaping () -> Void,
        onRefreshPermissionsAfterExternalEvent: @escaping (String) -> Void,
        onRefreshOperationalState: @escaping (String) -> Void
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.notificationCenter = notificationCenter
        self.onRefreshPermissionStates = onRefreshPermissionStates
        self.onRefreshPermissionsAfterExternalEvent = onRefreshPermissionsAfterExternalEvent
        self.onRefreshOperationalState = onRefreshOperationalState
    }

    func start() {
        stop()

        didActivateApplicationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleWorkspaceDidActivate(notification)
            }
        }

        didBecomeActiveObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidBecomeActive()
            }
        }

        didFinishLaunchingObserver = notificationCenter.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidFinishLaunching()
            }
        }

        didWakeObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidWake()
            }
        }
    }

    func stop() {
        if let didActivateApplicationObserver {
            workspaceNotificationCenter.removeObserver(didActivateApplicationObserver)
        }
        if let didBecomeActiveObserver {
            notificationCenter.removeObserver(didBecomeActiveObserver)
        }
        if let didFinishLaunchingObserver {
            notificationCenter.removeObserver(didFinishLaunchingObserver)
        }
        if let didWakeObserver {
            workspaceNotificationCenter.removeObserver(didWakeObserver)
        }

        didActivateApplicationObserver = nil
        didBecomeActiveObserver = nil
        didFinishLaunchingObserver = nil
        didWakeObserver = nil
    }

    func handleWorkspaceDidActivate(_ notification: Notification) {
        onRefreshPermissionsAfterExternalEvent("workspace-app-activated")
        if let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
            application.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            lastExternalApplication = application
        }
    }

    func handleDidBecomeActive() {
        onRefreshOperationalState("app-active")
    }

    func handleDidFinishLaunching() {
        onRefreshPermissionStates()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.onRefreshPermissionStates()
        }
    }

    func handleDidWake() {
        onRefreshOperationalState("system-wake")
    }
}
