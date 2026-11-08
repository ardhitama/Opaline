import UIKit

extension UIButton {
    /// Marks an icon toggle as on with the selection fill behind it, leaving
    /// its tint alone. Under Ardvis theming the accent belongs to actions, so
    /// state is shown by a fill, never by a recoloured icon.
    ///
    /// The fill is the button's own bounds rounded by `cornerRadius`, so the
    /// caller gives the button a fixed size and passes half its height for a
    /// capsule.
    func setOnState(_ isOn: Bool, cornerRadius: CGFloat) {
        backgroundColor = isOn ? ThemeManager.shared.selection : .clear
        layer.cornerRadius = cornerRadius
        if isOn {
            accessibilityTraits.insert(.selected)
        } else {
            accessibilityTraits.remove(.selected)
        }
    }
}
