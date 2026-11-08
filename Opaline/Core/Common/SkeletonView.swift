// swiftlint:disable:this file_name
import UIKit

/// Covers any view with a still placeholder in the skeleton tone while its
/// content loads. It does not shimmer: a loop says nothing a still shape
/// doesn't, and it keeps moving for people who asked for less motion. The
/// placeholder fades as the content arrives, so the swap reads as one
/// change rather than a jump.
extension UIView {
    private static let skeletonTag = 99_001

    func showSkeleton() {
        guard viewWithTag(UIView.skeletonTag) == nil
        else { return }
        let overlay = SkeletonOverlayView(frame: bounds)
        overlay.tag = UIView.skeletonTag
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        addSubview(overlay)
    }

    func hideSkeleton() {
        guard let overlay = viewWithTag(UIView.skeletonTag) else {
            return
        }
        // Untagged at once, so a skeleton shown again during the fade is a
        // new one rather than this one on its way out.
        overlay.tag = 0
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            overlay.alpha = 0
        } completion: { _ in
            overlay.removeFromSuperview()
        }
    }
}

// MARK: - Skeleton Overlay

private final class SkeletonOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ThemeManager.shared.skeletonBase
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not implemented") }
}

// MARK: - Skeleton placeholder shapes

/// A plain rounded rectangle used as a placeholder inside skeleton cells.
final class SkeletonBlockView: UIView {
    init(cornerRadius: CGFloat = 4) {
        super.init(frame: .zero)
        backgroundColor = ThemeManager.shared.skeletonBlock
        layer.roundCorners(cornerRadius)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not implemented") }
}
