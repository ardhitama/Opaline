import AVFoundation
import UIKit

// MARK: - Accessory

extension MiniPlayerBar {
    @available(iOS 26.0, *)
    func setupAccessory() {
        backgroundColor = .clear
        setupVideoContainer()
        videoContainer.layer.roundCorners(6)

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        channelLabel.font = UIFont.systemFont(ofSize: 12)
        let text = UIStackView(arrangedSubviews: [titleLabel, channelLabel])
        text.axis = .vertical
        text.translatesAutoresizingMaskIntoConstraints = false
        text.isUserInteractionEnabled = false
        addSubview(text)

        var close = UIButton.Configuration.plain()
        close.image = UIImage(systemName: "xmark")
        close.preferredSymbolConfigurationForImage = .init(pointSize: 15, weight: .bold)
        closeButton.configuration = close
        var playPause = UIButton.Configuration.plain()
        playPause.preferredSymbolConfigurationForImage = .init(pointSize: 19, weight: .semibold)
        // The system's play-pause morph whenever the image changes.
        playPause.symbolContentTransition = UISymbolContentTransition(ReplaceSymbolEffect.replace)
        playPauseButton.configuration = playPause
        for button in [playPauseButton, closeButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTapFeedback()
            addSubview(button)
        }
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = "common.close".localized
        activateAccessoryConstraints(text: text)
        // Swiping the bar up opens the player, as in Music.
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(barTapped))
        swipe.direction = .up
        addGestureRecognizer(swipe)
    }

    @available(iOS 26.0, *)
    func activateAccessoryConstraints(text: UIView) {
        NSLayoutConstraint.activate([
            videoContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            videoContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            videoContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            videoContainer.widthAnchor.constraint(
                equalTo: videoContainer.heightAnchor, multiplier: 16.0 / 9.0
            ),
            text.leadingAnchor.constraint(equalTo: videoContainer.trailingAnchor, constant: 12),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor),
            playPauseButton.topAnchor.constraint(equalTo: topAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }

    /// The button follows the player itself, so a pause from the lock
    /// screen, a headset or the end of the video shows here too.
    func observePlayState(of player: AVPlayer?) {
        playStateObservation = nil
        guard style == .accessory, let player else {
            return
        }
        playStateObservation = player.observe(
            \.timeControlStatus, options: [.initial, .new]
        ) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus != .paused
            DispatchQueue.main.async {
                self?.updatePlayPause(isPlaying: isPlaying)
            }
        }
    }

    func updatePlayPause(isPlaying: Bool) {
        guard #available(iOS 15.0, *), style == .accessory else {
            return
        }
        if playPauseButton.configuration?.image != nil, isShowingPlaying == isPlaying {
            return
        }
        isShowingPlaying = isPlaying
        playPauseButton.accessibilityLabel = (isPlaying ? "a11y.pause" : "a11y.play").localized
        playPauseButton.configuration?.image = UIImage(
            systemName: isPlaying ? "pause.fill" : "play.fill"
        )
    }
}
