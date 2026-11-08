import UIKit

/// Renders letter-on-color fallback avatars for channels and
/// comment authors that have no avatar image.
///
/// The hues are Ardvis Dark's syntax colours, and the letter takes the
/// window's tone, which reads at 4.5:1 or better on every one of them.
enum MonogramAvatar {
    private static let palette: [UIColor] = [
        0xC678DD, // keyword
        0x98C379, // string
        0xD19A66, // number
        0x61AFEF, // function
        0xE5C07B, // type
        0xE06C75, // variable
        0x56B6C2, // link
        0x828A99 // comment
    ].map { (rgb: UInt32) in
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    // ponytail: main-thread-only cache (no lock) — MonogramAvatar.image is
    // always called from UIView setup (ThumbnailImageView.setAvatar), never
    // off-thread. Add an NSLock if a background caller shows up.
    // swiftlint:disable:next legacy_objc_type
    private static let cache = NSCache<NSString, UIImage>()

    static func color(for name: String) -> UIColor {
        palette[Int(fnv1a(name) % UInt64(palette.count))]
    }

    static func letter(for name: String) -> String {
        let letters = CharacterSet.alphanumerics
        for scalar in name.unicodeScalars where letters.contains(scalar) {
            return String(scalar).uppercased()
        }
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.first.map(String.init) ?? "?"
    }

    /// Output is a pure function of `name` (letter + color) and `side`.
    /// Main-thread only — see cache note above.
    static func image(for name: String, side: CGFloat = 96) -> UIImage {
        // swiftlint:disable:next legacy_objc_type
        let key = "\(name)-\(side)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = renderImage(for: name, side: side)
        cache.setObject(image, forKey: key)
        return image
    }

    private static func renderImage(for name: String, side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        let text = NSAttributedString(
            string: letter(for: name),
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: side * 0.42,
                    weight: .semibold
                ),
                .foregroundColor: ThemeManager.shared.accentText
            ]
        )
        return UIGraphicsImageRenderer(size: size).image { ctx in
            color(for: name).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let textSize = text.size()
            text.draw(
                at: CGPoint(
                    x: (side - textSize.width) / 2,
                    y: (side - textSize.height) / 2
                )
            )
        }
    }

    /// Stable across launches — `String.hashValue` is seeded
    /// per process, which would reshuffle colors on every run.
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return hash
    }
}
