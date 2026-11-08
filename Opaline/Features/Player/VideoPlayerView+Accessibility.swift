import UIKit

// MARK: - VoiceOver names

// The player's controls show only icons, so each gets the name VoiceOver and
// Voice Control use for it. CC and the speed read their own text.
extension VideoPlayerView {
    func applyAccessibilityNames() {
        settingsButton.accessibilityLabel = "settings.title".localized
        pipButton.accessibilityLabel = "settings.row.pip".localized
        rewindButton.accessibilityLabel = "a11y.previous".localized
        forwardButton.accessibilityLabel = "a11y.next".localized
        updatePlayPauseName()
        updateFullscreenName()
    }

    func updatePlayPauseName() {
        if isAtEnd {
            playPauseButton.accessibilityLabel = "a11y.replay".localized
        } else {
            let isPlaying = (player?.rate ?? 0) > 0
            playPauseButton.accessibilityLabel = (isPlaying ? "a11y.pause" : "a11y.play").localized
        }
    }

    func updateFullscreenName() {
        fullscreenButton.accessibilityLabel = (
            isFullscreen ? "a11y.exitFullScreen" : "a11y.fullScreen"
        ).localized
    }
}
