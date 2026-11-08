import UIKit

/// Legacy background fetch: a single code path for iOS 12…latest (see
/// `configureLegacyBackgroundFetch`).
extension AppDelegate {
    /// `@objc` is explicit: this is an optional protocol requirement
    /// implemented in an extension, and UIKit finds it through the ObjC
    /// runtime — without the attribute a silent miss is very hard to spot.
    @objc
    @available(iOS, deprecated: 13.0, message: "Single code path for iOS 12+.")
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler:
            @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AppLog.log("BackgroundFetch", "woke the app")
        BackgroundRefreshService.shared.refresh { refreshed in
            DispatchQueue.main.async {
                AppLog.log("BackgroundFetch", "finished: newData=\(refreshed)")
                completionHandler(refreshed ? .newData : .noData)
            }
        }
    }
}
