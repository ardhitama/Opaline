import UIKit

/// What a screen shows in place of a list it has nothing for: a symbol, one
/// line saying why, and, when there is one, the action that fills the
/// screen, such as signing in or trying again.
///
/// `text` and `isHidden` are all a screen changes, so it can stand where a
/// plain label used to.
final class EmptyStateView: UIView {
    var onAction: (() -> Void)?

    var text: String? {
        get { messageLabel.text }
        set { messageLabel.text = newValue }
    }

    private let iconView = UIImageView()
    private let messageLabel = UILabel()
    private let actionButton = CapsuleButton(type: .system)

    init(symbol: String, text: String? = nil, actionTitle: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupIcon(symbol: symbol)
        setupMessage(text)
        setupAction(title: actionTitle)

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel, actionButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(24, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupIcon(symbol: String) {
        if #available(iOS 13.0, *) {
            iconView.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(textStyle: .largeTitle)
            )
        }
        iconView.isHidden = iconView.image == nil
        iconView.tintColor = ThemeManager.shared.tertiaryText
        iconView.contentMode = .scaleAspectFit
    }

    private func setupMessage(_ text: String?) {
        messageLabel.text = text
        messageLabel.textColor = ThemeManager.shared.secondaryText
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
    }

    private func setupAction(title: String?) {
        let theme = ThemeManager.shared
        actionButton.setTitle(title, for: .normal)
        actionButton.titleLabel?.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.backgroundColor = theme.accent
        actionButton.setTitleColor(theme.accentText, for: .normal)
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 11, left: 32, bottom: 11, right: 32)
        actionButton.isHidden = title == nil
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.addTapFeedback()
    }

    @objc
    private func actionTapped() {
        onAction?()
    }
}

/// A capsule at any text size. Rounds in its own layout pass: the stack
/// view sizes it after its parent's `layoutSubviews` has already run.
private final class CapsuleButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.roundCorners(bounds.height / 2)
    }
}
