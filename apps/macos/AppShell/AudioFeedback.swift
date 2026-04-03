import AppKit
import Foundation

struct SoundFeedbackConfiguration: Sendable, Codable, Equatable {
    var enabled: Bool
    var volume: Double

    init(enabled: Bool = false, volume: Double = 50) {
        self.enabled = enabled
        self.volume = volume
    }
}

enum SoundFeedbackEvent {
    case started
    case stopped
    case failed
}

final class SoundFeedbackPlayer {
    private var retainedSound: NSSound?

    func play(event: SoundFeedbackEvent, volume: Double) {
        let clampedVolume = max(0, min(100, volume)) / 100.0
        guard clampedVolume > 0 else { return }

        let fileName: String
        switch event {
        case .started:
            fileName = "Ping"
        case .stopped:
            fileName = "Pop"
        case .failed:
            fileName = "Basso"
        }

        let soundPath = URL(fileURLWithPath: "/System/Library/Sounds")
            .appendingPathComponent(fileName)
            .appendingPathExtension("aiff")

        DispatchQueue.main.async { [weak self] in
            if let sound = NSSound(contentsOfFile: soundPath.path, byReference: false) {
                sound.volume = Float(clampedVolume)
                self?.retainedSound = sound
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}
