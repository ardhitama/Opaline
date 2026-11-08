import QuartzCore

extension CALayer {
    /// Rounds the corners on the continuous curve Apple's own shapes use, so
    /// a rounded rectangle eases into its corners instead of meeting a
    /// circular arc at a visible seam. iOS 12 has only circular corners.
    func roundCorners(_ radius: CGFloat) {
        cornerRadius = radius
        if #available(iOS 13.0, *) {
            cornerCurve = .continuous
        }
    }
}
