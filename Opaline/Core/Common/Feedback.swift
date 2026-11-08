import UIKit

/// Tap feedback for every control in the app: a haptic where there is a
/// Taptic Engine, and always a short visual press. iPads have no Taptic
/// Engine — the animation (and, for confirmations, the icon swap) is the
/// only signal that reaches every device.
enum Feedback {
    /// How far a pressed control sinks: enough to see on a small glyph,
    /// little enough to read as a press rather than a bounce.
    static let pressedScale: CGFloat = 0.95

    /// Fired on touch-down, where the finger expects the click.
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Moving between equivalent options — tabs, chips, menu selections.
    static func select() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// The system's success pattern: two short taps. For an action that
    /// completed, never for opening something.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// A settle for a control that changed without a finger still on it, such
    /// as a newly selected tab or chip or a confirmation checkmark: it dips
    /// and eases back without overshooting. Nothing moves under Reduce
    /// Motion. `.beginFromCurrentState` keeps repeated taps from stacking
    /// into a jitter.
    static func pop(_ view: UIView?) {
        guard let view, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        view.transform = CGAffineTransform(scaleX: pressedScale, y: pressedScale)
        release(view)
    }

    /// The press half of a tap: the control sinks while the finger is down.
    static func press(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: pressedScale, y: pressedScale)
        }
    }

    /// The release half: a critically damped spring back to rest.
    static func release(_ view: UIView) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = .identity
        }
    }

    /// Confirmation on the button that was pressed: success haptic plus the
    /// checkmark.
    static func confirm(on button: UIButton?) {
        success()
        checkmark(on: button)
    }

    /// The visual half of a confirmation — a checkmark stands in for the
    /// icon for a beat. Used on its own where a toast already carries the
    /// haptic, so the two don't fire twice.
    static func checkmark(on button: UIButton?) {
        guard let button,
              let image = button.image(for: .normal),
              let check = UIImage(named: "icon_checkmark") else {
            return
        }
        let size = image.size
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            check.draw(in: CGRect(origin: .zero, size: size))
        }
        button.setImage(rendered.withRenderingMode(.alwaysTemplate), for: .normal)
        pop(button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            button.setImage(image, for: .normal)
        }
    }
}

extension UIControl {
    /// Haptic on touch-down, and the control sinks while the finger is on it
    /// and settles back when it lifts. One call per button is the whole
    /// wiring.
    func addTapFeedback() {
        addTarget(
            TapFeedbackTarget.shared,
            action: #selector(TapFeedbackTarget.handle(_:)),
            for: .touchDown
        )
        addTarget(
            TapFeedbackTarget.shared,
            action: #selector(TapFeedbackTarget.handleRelease(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
    }
}

/// `addTarget` needs an ObjC object; one immortal singleton serves every
/// control instead of a per-control closure box.
private final class TapFeedbackTarget: NSObject {
    static let shared = TapFeedbackTarget()

    @objc
    func handle(_ sender: UIControl) {
        Feedback.tap()
        Feedback.press(sender)
    }

    @objc
    func handleRelease(_ sender: UIControl) {
        Feedback.release(sender)
    }
}
