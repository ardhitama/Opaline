import UIKit

/// The app's colours: Ardvis Dark, the one theme of the Ardvis products
/// (Ardvis `docs/design/theming.md`), which is Atom One Dark at 12%
/// brightness. The app is dark only: `UIUserInterfaceStyle` is `Dark` in
/// Info.plist, so every system-drawn element matches.
///
/// The theme fills only the content layer. Bars, menus, alerts and sheets are
/// the system's, so `applyGlobal` sets nothing on them but their tint. The
/// theme is flat: it has no border or divider colour, and regions part by a
/// step in tone. Text roles read at 4.5:1 and icon roles at 3:1 on every
/// surface here, `selection` included.
///
/// Under Increase Contrast the roles that Ardvis lifts take their twins. The
/// palette is rebuilt when the setting changes, and `didChangeNotification`
/// tells views to apply it again.
final class ThemeManager {
    static let shared = ThemeManager()
    static let didChangeNotification = Notification.Name("ThemeManagerDidChange")

    // Surfaces, from the screen up. A container takes one step above its
    // parent and never repeats its tone.
    /// Screens, lists and the window: Ardvis's `window`.
    private(set) var background = UIColor()
    /// A cell, card or control on the screen: Ardvis's `surface` (`canvas`).
    private(set) var surface = UIColor()
    /// A control on a surface.
    private(set) var elevatedSurface = UIColor()
    /// A selected row or control, the lightest fill text sits on.
    private(set) var selection = UIColor()

    // Text, never faded with opacity: take a weaker role instead.
    private(set) var primaryText = UIColor()
    private(set) var secondaryText = UIColor()
    private(set) var tertiaryText = UIColor()

    /// The one accent, a neutral grey: the primary action, links and text
    /// actions.
    private(set) var accent = UIColor()
    /// Text and icons on `accent`, and on the status fills.
    private(set) var accentText = UIColor()
    /// The accent dimmed to 75% for marks that ask nothing of the person:
    /// switches, active rings and progress (Ardvis's `chromeAccent`, 3:1).
    private(set) var chromeAccent = UIColor()

    // Status.
    private(set) var positive = UIColor()
    private(set) var warning = UIColor()
    private(set) var destructive = UIColor()
    private(set) var info = UIColor()

    // Plates over artwork, which must read on any image.
    private(set) var durationBackground = UIColor()
    private(set) var liveBadgeBackground = UIColor()
    private(set) var thumbnailPlaceholder = UIColor()
    private(set) var newContentDot = UIColor()

    private(set) var skeletonBase = UIColor()
    private(set) var skeletonBlock = UIColor()

    /// Icons and titles on the bars and the selected tab. Bars are the
    /// system's, and on Liquid Glass the system draws its own items in
    /// `label`, so items the app draws itself take the same colour. iOS 12
    /// has an opaque bar on `background` and takes the text colour.
    let barContent: UIColor
    /// The tabs that are not selected, a step below `barContent` so the
    /// selected tab is the brightest. Ardvis puts the accent on the selected
    /// tab, but its grey reads dimmer than the system's white tabs on glass,
    /// which made the selection look disabled.
    let barContentInactive: UIColor

    let statusBarStyle: UIStatusBarStyle = .lightContent
    /// For iOS 12, which has no dark appearance to give bars and keyboards.
    let barStyle: UIBarStyle = .black

    private init() {
        if #available(iOS 13.0, *) {
            barContent = .label
            barContentInactive = .secondaryLabel
        } else {
            barContent = Self.hex(0xABB2BF)
            barContentInactive = Self.hex(0x9398A1)
        }
        rebuildCache()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contrastSettingChanged),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }

    /// The chevron style for buttons the system does not draw (see
    /// `NavChevron`).
    @available(iOS 13.0, *)
    static func navChevron(systemName: String) -> UIImage? {
        let cfg = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        return UIImage(systemName: systemName, withConfiguration: cfg)
    }

    /// An sRGB colour as CSS writes it, `0xRRGGBB`.
    private static func hex(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    @objc
    private func contrastSettingChanged() {
        rebuildCache()
        applyGlobal()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Ardvis Dark's values, with the Increase Contrast twins Ardvis Kit
    /// defines in `ArdvisThemePalettes.swift`.
    private func rebuildCache() {
        let high = UIAccessibility.isDarkerSystemColorsEnabled
        func pick(_ standard: UInt32, _ increased: UInt32) -> UIColor {
            Self.hex(high ? increased : standard)
        }
        background = pick(0x14161A, 0x0D0F11)
        surface = Self.hex(0x1B1D23)
        elevatedSurface = Self.hex(0x282C34)
        selection = Self.hex(0x2C313A)

        primaryText = pick(0xABB2BF, 0xC8CDD5)
        secondaryText = pick(0x9DA5B4, 0xBAC0CA)
        tertiaryText = pick(0x9398A1, 0xAEB2B9)

        accent = pick(0xA3A3A3, 0xBCBCBC)
        accentText = Self.hex(0x14161A)
        chromeAccent = accent.withAlphaComponent(0.75)

        positive = pick(0x73C990, 0x98D7AD)
        warning = pick(0xE2C08D, 0xECD6B6)
        destructive = pick(0xFF664A, 0xFF917D)
        info = pick(0x6897ED, 0x96B6F2)

        // The window's tone, translucent enough to show it's on the image and
        // dark enough that the text reads at 4.5:1 over white.
        durationBackground = background.withAlphaComponent(0.85)
        liveBadgeBackground = destructive
        thumbnailPlaceholder = surface
        newContentDot = info

        skeletonBase = surface
        skeletonBlock = elevatedSurface
    }

    func applyGlobal() {
        // Bars draw their own Liquid Glass and their items in the system's
        // colour; the selected tab is the brightest of the tabs.
        let nav = UINavigationBar.appearance()
        nav.tintColor = barContent
        nav.titleTextAttributes = [.foregroundColor: barContent]
        UITabBar.appearance().tintColor = barContent
        UITabBar.appearance().unselectedItemTintColor = barContentInactive
        UISwitch.appearance().onTintColor = chromeAccent
        UITextField.appearance().keyboardAppearance = .dark
    }
}
