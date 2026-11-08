import UIKit

// MARK: - Minimize

extension VideoPlayerView {
    /// Top left, across from the settings row. The watch screen has no
    /// navigation bar, so the video starts right under the status bar and
    /// the chevron that puts it away rides on the player's own controls.
    func configureMinimizeButton() {
        minimizeButton.setImage(
            NavChevron.image(kind: .minimize)?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        minimizeButton.tintColor = .white
        minimizeButton.accessibilityLabel = "a11y.minimize".localized
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.addTarget(self, action: #selector(minimizeTapped), for: .touchUpInside)
        controlsView.addSubview(minimizeButton)
        NSLayoutConstraint.activate([
            minimizeButton.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            minimizeButton.leadingAnchor.constraint(
                equalTo: controlsView.safeAreaLayoutGuide.leadingAnchor, constant: 12
            ),
            minimizeButton.widthAnchor.constraint(equalToConstant: 44),
            minimizeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc
    private func minimizeTapped() {
        onMinimize?()
    }
}
