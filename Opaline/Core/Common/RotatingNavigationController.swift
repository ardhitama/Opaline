import UIKit

/// The app-wide navigation controller: forwards rotation queries to the top
/// view controller and shows the system back button as a bare chevron.
final class RotatingNavigationController: UINavigationController {
    override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? super.shouldAutorotate
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations
            ?? super.supportedInterfaceOrientations
    }
    override var prefersStatusBarHidden: Bool {
        topViewController?.prefersStatusBarHidden ?? super.prefersStatusBarHidden
    }
    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }
    /// Style stays with the themed bar, not the top screen: with the
    /// bar auto-hidden on scroll the system would fall back to the
    /// screen's default (dark text), which vanishes on dark content.
    override var childForStatusBarStyle: UIViewController? {
        nil
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.statusBarStyle
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        topViewController?.prefersHomeIndicatorAutoHidden ?? super.prefersHomeIndicatorAutoHidden
    }
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Screens that hide the bar (watch, Shorts) lose the edge-swipe pop
        // with the default delegate; keep it, guarded so the root never pops.
        interactivePopGestureRecognizer?.delegate = self
        applyBarTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyBarTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    /// One bar configuration for every navigation bar in the app — bars
    /// with differing appearance setups use different item-layout metrics
    /// (visibly different chevron insets), so the bar styles itself here
    /// instead of per screen. The bar keeps the system's own background
    /// (Liquid Glass on iOS 26+) over the screen's colour, and its icons and
    /// title the colour the system draws bar items in. iOS 12 has neither,
    /// so it keeps an opaque bar.
    @objc
    private func applyBarTheme() {
        let theme = ThemeManager.shared
        navigationBar.tintColor = theme.barContent
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.titleTextAttributes = [.foregroundColor: theme.barContent]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        } else {
            navigationBar.barTintColor = theme.background
            navigationBar.isTranslucent = false
            navigationBar.barStyle = theme.barStyle
            navigationBar.titleTextAttributes = [.foregroundColor: theme.barContent]
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    /// The system back button with no title: the previous screen's name
    /// repeats what the person just left and widens the glass capsule.
    override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        if let previous = topViewController {
            if #available(iOS 14.0, *) {
                previous.navigationItem.backButtonDisplayMode = .minimal
            } else {
                previous.navigationItem.backBarButtonItem = UIBarButtonItem(
                    title: "", style: .plain, target: nil, action: nil
                )
            }
        }
        super.pushViewController(viewController, animated: animated)
    }
}

extension RotatingNavigationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
