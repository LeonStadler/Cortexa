#if canImport(XCTest)
import ASRCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testPermissionsStepRequiresMicrophoneGrant() {
        let coordinator = OnboardingCoordinator()
        coordinator.goToNextStep()

        XCTAssertFalse(
            OnboardingCoordinator.canProceedFromPermissions(microphoneStatus: .notDetermined))
        XCTAssertTrue(
            OnboardingCoordinator.canProceedFromPermissions(microphoneStatus: .granted))
    }

    func testStandardModelStepRequiresInstalledModel() {
        let coordinator = OnboardingCoordinator()
        coordinator.goToNextStep()
        coordinator.goToNextStep()

        XCTAssertFalse(
            OnboardingCoordinator.canProceedFromStandardModel(
                isInstalled: false,
                isDownloadBusy: false
            )
        )
        XCTAssertFalse(
            OnboardingCoordinator.canProceedFromStandardModel(
                isInstalled: true,
                isDownloadBusy: true
            )
        )
        XCTAssertTrue(
            OnboardingCoordinator.canProceedFromStandardModel(
                isInstalled: true,
                isDownloadBusy: false
            )
        )
    }
}
#endif
