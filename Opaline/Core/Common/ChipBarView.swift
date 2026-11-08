import UIKit

/// Horizontal scrollable chip bar with a single selected chip.
/// Feature-agnostic sibling of ChannelFilterBarView (which is typed
/// to channel filter chips) — takes plain labels and reports taps
/// by index.
final class ChipBarView: UIView {
    static let preferredHeight: CGFloat = 44

    var onSelect: ((Int) -> Void)?
    /// On Liquid Glass the bar has no fill of its own: it rides in the
    /// scroll view's top edge effect, which blurs the content under it the
    /// way it does under the navigation bar (`floatOverEdge(of:)`).
    private var floatsOverContent = false

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var buttons: [UIButton] = []
    private var placeholderIndices: IndexSet = []
    private(set) var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Indices in `placeholders` render as still, non-tappable
    /// skeleton capsules instead of labeled chips.
    func setLabels(
        _ labels: [String],
        selected: Int = 0,
        placeholders: IndexSet = []
    ) {
        selectedIndex = selected
        placeholderIndices = placeholders
        let rebuild = {
            self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.buttons = labels.enumerated().map { idx, label in
                placeholders.contains(idx)
                    ? self.makePlaceholderChip(tag: idx)
                    : self.makeChipButton(label: label, tag: idx)
            }
            self.buttons.forEach { self.stack.addArrangedSubview($0) }
            self.applyTheme()
        }
        // On screen, the new chips (say, the real ones replacing the
        // placeholders) dissolve in instead of popping.
        guard window != nil, !buttons.isEmpty else {
            rebuild()
            return
        }
        UIView.transition(
            with: stack,
            duration: 0.2,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: rebuild
        )
    }

    func setSelected(_ index: Int) {
        guard index < buttons.count else {
            return
        }
        selectedIndex = index
        applyTheme()
    }

    /// Joins the bar to `scrollView`'s top edge effect on iOS 26+, so the bar
    /// and the navigation bar above it read as one glass top bar instead of
    /// a solid band with content showing between the two.
    func floatOverEdge(of scrollView: UIScrollView) {
        guard #available(iOS 26.0, *) else {
            return
        }
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.scrollView = scrollView
        interaction.edge = .top
        addInteraction(interaction)
        floatsOverContent = true
        applyTheme()
    }

    @objc
    func applyTheme() {
        backgroundColor = floatsOverContent ? .clear : ThemeManager.shared.background
        for (idx, btn) in buttons.enumerated() {
            if placeholderIndices.contains(idx) {
                stylePlaceholder(btn)
            } else {
                styleButton(btn, selected: idx == selectedIndex)
            }
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -16)
        ])
        heightAnchor.constraint(
            equalToConstant: Self.preferredHeight
        ).isActive = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    private func makeChipButton(label: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(label, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(
            top: 6, left: 14, bottom: 6, right: 14
        )
        btn.tag = tag
        btn.addTarget(
            self, action: #selector(chipTapped(_:)), for: .touchUpInside
        )
        return btn
    }

    private func makePlaceholderChip(tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.isEnabled = false
        btn.layer.cornerRadius = 14
        btn.tag = tag
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 64),
            btn.heightAnchor.constraint(equalToConstant: 28)
        ])
        return btn
    }

    private func stylePlaceholder(_ btn: UIButton) {
        btn.backgroundColor = ThemeManager.shared.surface
    }

    @objc
    private func chipTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx != selectedIndex, idx < buttons.count else {
            return
        }
        Feedback.select()
        Feedback.pop(sender)
        setSelected(idx)
        onSelect?(idx)
    }

    /// A chip parts from the bar by its fill, never an outline; the chosen
    /// one takes the selection fill and the primary text (Ardvis theming).
    private func styleButton(_ btn: UIButton, selected: Bool) {
        let theme = ThemeManager.shared
        btn.backgroundColor = selected ? theme.selection : theme.surface
        btn.setTitleColor(
            selected ? theme.primaryText : theme.secondaryText, for: .normal
        )
    }
}
