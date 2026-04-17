import Foundation

struct DictationRuntimeEventHandlers {
    let handleStatus: @MainActor (String) -> Void
    let handleDiagnostic: @MainActor (String) -> Void
    let handleDebugEvent: @MainActor (String) -> Void
    let handleTranscript: @MainActor (String) -> Void
    let handleFinalTranscript: @MainActor (FinalTranscriptEvent) -> Void
    let handleSessionActivityChanged: @MainActor (Bool) -> Void
    let handlePermissionInteractionFinished: @MainActor () -> Void
}

protocol DictationRuntimeEventBridging: AnyObject {
    @MainActor
    func connect(
        runtime: DictationRuntimeControlling,
        handlers: DictationRuntimeEventHandlers
    )
}

final class DictationRuntimeEventBridge: DictationRuntimeEventBridging {
    @MainActor
    func connect(
        runtime: DictationRuntimeControlling,
        handlers: DictationRuntimeEventHandlers
    ) {
        runtime.onStatus = { status in
            Self.deliver {
                handlers.handleStatus(status)
            }
        }
        runtime.onDiagnostic = { diagnostic in
            Self.deliver {
                handlers.handleDiagnostic(diagnostic)
            }
        }
        runtime.onDebugEvent = { diagnostic in
            Self.deliver {
                handlers.handleDebugEvent(diagnostic)
            }
        }
        runtime.onTranscript = { transcript in
            Self.deliver {
                handlers.handleTranscript(transcript)
            }
        }
        runtime.onFinalTranscript = { event in
            Self.deliver {
                handlers.handleFinalTranscript(event)
            }
        }
        runtime.onSessionActivityChanged = { isActive in
            Self.deliver {
                handlers.handleSessionActivityChanged(isActive)
            }
        }
        runtime.onPermissionInteractionFinished = {
            Self.deliver {
                handlers.handlePermissionInteractionFinished()
            }
        }
    }

    private static func deliver(_ action: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                action()
            }
            return
        }

        Task {
            await MainActor.run {
                action()
            }
        }
    }
}
