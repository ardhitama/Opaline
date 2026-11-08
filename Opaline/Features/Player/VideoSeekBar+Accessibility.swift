import UIKit

// MARK: - VoiceOver

extension VideoSeekBar {
    /// VoiceOver reads times in words ("2 minutes, 5 seconds"), not digits.
    private static let spokenTime: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter
    }()

    override var accessibilityValue: String? {
        get {
            guard duration > 0,
                  let elapsed = Self.spokenTime.string(from: progress * duration),
                  let total = Self.spokenTime.string(from: duration) else {
                return nil
            }
            return "a11y.position.value".localized(with: elapsed, total)
        }
        set {}
    }

    /// Swipe up or down: ten seconds, through the same scrub steps a finger
    /// on the track takes, so the seek and the auto-hide behave the same.
    override func accessibilityIncrement() {
        step(seconds: 10)
    }

    override func accessibilityDecrement() {
        step(seconds: -10)
    }

    private func step(seconds: Double) {
        guard duration > 0 else {
            return
        }
        beginExternalScrub()
        updateExternalScrub(to: progress + seconds / duration)
        endExternalScrub()
    }
}
