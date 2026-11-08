import AVFoundation
import UIKit

// The minimized player. Tap anywhere → expand.
//
// `.floating`: a small card in the bottom-right corner, [video 16:9] over
// [title + ✕]; iPad, and iPhone before iOS 26.
// `.accessory`: a row in the tab bar's accessory on iPhone with iOS 26 —
// [video] [title / channel] [play-pause] [✕]. The system places it above
// the tab bar, so it never covers the content, and folds it in beside the
// tab bar when the bar minimizes.
final class MiniPlayerBar: UIView {
    enum Style {
        case floating
        case accessory
    }

    let style: Style

    // MARK: - Subviews

    let videoContainer = UIView()
    let thumbnailFallback = ThumbnailImageView(frame: .zero)
    private let infoBar = UIView()
    let titleLabel = UILabel()
    let closeButton = UIButton(type: .custom)
    let channelLabel = UILabel()
    let playPauseButton = UIButton(type: .system)

    // MARK: - State

    var onClose: (() -> Void)?
    var onTap: (() -> Void)?
    var onPlayPause: (() -> Void)?

    var playStateObservation: NSKeyValueObservation?
    var isShowingPlaying = false

    private var playerLayer: AVPlayerLayer?
    private weak var player: AVPlayer?

    // MARK: - Init

    init(style: Style = .floating) {
        self.style = style
        super.init(frame: .zero)
        if style == .accessory, #available(iOS 26.0, *) {
            setupAccessory()
        } else {
            setupCard()
            setupSubviews()
        }
        setupGestures()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = videoContainer.bounds
        guard style == .accessory else {
            return
        }
        // Beside a minimized tab bar the accessory turns inline and narrow;
        // the title alone is enough to recognise the video there.
        let isNarrow = bounds.width < 300
        if channelLabel.isHidden != isNarrow {
            channelLabel.isHidden = isNarrow
        }
    }

    // MARK: - Public API

    func attachPlayer(_ player: AVPlayer?) {
        // A new layer for the same player would blank the picture for a frame.
        if let player, player === self.player, playerLayer != nil {
            return
        }
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        self.player = player
        observePlayState(of: player)
        guard let newPlayer = player else {
            return
        }
        let layer = AVPlayerLayer(player: newPlayer)
        layer.videoGravity = .resizeAspectFill
        videoContainer.layer.insertSublayer(layer, at: 1)
        playerLayer = layer
        setNeedsLayout()
    }

    /// iOS pauses a backgrounded player that still drives a layer; detach
    /// on real backgrounding (not on Control Center's resignActive, which
    /// would hiccup audio) so background audio keeps running when the
    /// panel is minimized. The main player view does the same.
    @objc
    private func appDidEnterBackground() {
        playerLayer?.player = nil
    }

    @objc
    private func appDidBecomeActive() {
        if let player, playerLayer?.player == nil {
            playerLayer?.player = player
        }
    }

    func update(title: String, channel: String, isPlaying: Bool, thumbnailURL: String) {
        titleLabel.text = title
        channelLabel.text = channel
        updatePlayPause(isPlaying: isPlaying)
        if let url = URL(string: thumbnailURL) {
            thumbnailFallback.setImage(url: url)
        }
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        titleLabel.textColor = theme.primaryText
        if style == .accessory {
            // On the accessory's glass, in the colours of the bar it sits on.
            titleLabel.textColor = theme.barContent
            channelLabel.textColor = theme.barContentInactive
            playPauseButton.tintColor = theme.barContent
            closeButton.tintColor = theme.barContent
            return
        }
        infoBar.backgroundColor = theme.surface
        closeButton.setImage(closeIcon(color: theme.primaryText), for: .normal)
    }

    // MARK: - Card setup

    private func setupCard() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        layer.roundCorners(10)
    }

    // MARK: - Subview setup

    private func setupSubviews() {
        setupVideoContainer()
        setupInfoBar()
        activateConstraints()
    }

    func setupVideoContainer() {
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.backgroundColor = .black
        videoContainer.clipsToBounds = true

        thumbnailFallback.translatesAutoresizingMaskIntoConstraints = false
        thumbnailFallback.contentMode = .scaleAspectFill
        thumbnailFallback.clipsToBounds = true

        videoContainer.addSubview(thumbnailFallback)
        addSubview(videoContainer)

        NSLayoutConstraint.activate([
            thumbnailFallback.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            thumbnailFallback.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            thumbnailFallback.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            thumbnailFallback.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor)
        ])
    }

    private func setupInfoBar() {
        infoBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoBar)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        infoBar.addSubview(titleLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = "common.close".localized
        closeButton.addTapFeedback()
        infoBar.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: infoBar.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: infoBar.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: infoBar.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(
                equalTo: closeButton.leadingAnchor, constant: -4
            ),
            titleLabel.centerYAnchor.constraint(equalTo: infoBar.centerYAnchor)
        ])
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            // 16:9 aspect ratio
            videoContainer.heightAnchor.constraint(
                equalTo: videoContainer.widthAnchor, multiplier: 9.0 / 16.0
            ),

            infoBar.topAnchor.constraint(equalTo: videoContainer.bottomAnchor),
            infoBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            infoBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            infoBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            infoBar.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
}

// MARK: - Icon drawing + gestures

extension MiniPlayerBar {
    private func closeIcon(color: UIColor) -> UIImage {
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            color.setStroke()
            let path = UIBezierPath()
            let inset: CGFloat = 7
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            path.move(to: CGPoint(x: size.width - inset, y: inset))
            path.addLine(to: CGPoint(x: inset, y: size.height - inset))
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.stroke()
        }
        return img.withRenderingMode(.alwaysOriginal)
    }

    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(barTapped))
        addGestureRecognizer(tap)
    }

    @objc
    func closeTapped() { onClose?() }

    @objc
    func playPauseTapped() { onPlayPause?() }

    @objc
    func barTapped() { onTap?() }
}
