import ASRCore
import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case permissions = 1
    case standardModel = 2
    case basics = 3
    case done = 4

    var id: Int { rawValue }

    var stepNumber: Int { rawValue + 1 }

    static var totalSteps: Int { allCases.count }
}

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .welcome

    var onFinished: (() -> Void)?

    func goToNextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goToPreviousStep() {
        guard currentStep.rawValue > 0,
            let previous = OnboardingStep(rawValue: currentStep.rawValue - 1)
        else { return }
        currentStep = previous
    }

    func canProceed(appState: MacAppState) -> Bool {
        switch currentStep {
        case .welcome:
            return true
        case .permissions:
            return Self.canProceedFromPermissions(
                microphoneStatus: appState.microphonePermissionStatus)
        case .standardModel:
            return Self.canProceedFromStandardModel(
                isInstalled: appState.isStandardModelInstalled,
                isDownloadBusy: appState.isStandardModelDownloadBusy)
        case .basics, .done:
            return true
        }
    }

    static func canProceedFromPermissions(microphoneStatus: PermissionStatus) -> Bool {
        microphoneStatus == .granted
    }

    static func canProceedFromStandardModel(isInstalled: Bool, isDownloadBusy: Bool) -> Bool {
        isInstalled && !isDownloadBusy
    }

    func finish(onboardingStore: OnboardingStore, appState: MacAppState) {
        onboardingStore.markComplete()
        appState.onboardingDidComplete()
        onFinished?()
    }
}
