import UIKit

/// The iOS 13+ owner of the app's single window. UIKit refuses to launch an
/// app linked against the iOS 27 SDK that has not adopted the scene
/// lifecycle. iOS 12 ignores the scene manifest, and `AppDelegate` builds the
/// window itself there.
///
/// The scene only supplies the window and forwards the callbacks that move
/// from the app delegate to the scene delegate under this lifecycle.
/// `AppDelegate` still owns the UI and the deep-link state.
@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene,
              let appDelegate
        else {
            return
        }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        appDelegate.installWindow(window)
        // A link that cold-launches the app arrives here, not in
        // `scene(_:openURLContexts:)`.
        if let url = connectionOptions.urlContexts.first?.url {
            appDelegate.handleIncomingURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        appDelegate?.handleIncomingURL(url)
    }

    /// Under the scene lifecycle UIKit stops calling the app delegate's
    /// `applicationDidBecomeActive(_:)`.
    func sceneDidBecomeActive(_ scene: UIScene) {
        appDelegate?.applicationDidBecomeActive(UIApplication.shared)
    }
}
