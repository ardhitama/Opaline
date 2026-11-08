import Foundation

/// One-shot upgrades of stored defaults, run once per launch from
/// `application(_:didFinishLaunchingWithOptions:)`.
extension AppDelegate {
    /// What Return YouTube Dislike, SponsorBlock, the update inbox and the
    /// solver server left behind. The RYD user id identified this install to
    /// a third party, so it must not outlive the feature.
    private static let removedServiceKeys = [
        "ryd_enabled", "ryd_userId_v2", "ryd_registered_v2",
        "sponsorblock_enabled",
        "playback_livingRoomPoTokenId", "debug_serverBaseURL",
        "notifications_appUpdates", "notifications_lastUpdateCheck",
        "notifications_featureInstallDate",
        "SignatureTimestamp.jsPath", "SignatureTimestamp.tvValue",
        "SignatureTimestamp.tvValuePath", "SignatureTimestamp.tvJsPath.v2",
        "SignatureTimestamp.tvJsPathSTS", "SignatureTimestamp.tvClientVersion"
    ]

    func runMigrations() {
        OAuthClient.shared.migrateKeychainAccessibilityIfNeeded()
        migratePlaybackSourceToChain()
        dropRemovedPlaybackSteps()
        forgetRemovedServices()
    }

    /// The old picker stored one source: `auto`, `android_vr`, `mweb_pot`,
    /// `tv` or `progressive`. Everyone lands on the default chain: the clients
    /// behind those values are gone (Opaline#76).
    private func migratePlaybackSourceToChain() {
        let defaults = UserDefaults.standard
        let key = UserDefaultsKeys.Migration.playbackSourceAuto
        guard !defaults.bool(forKey: key) else {
            return
        }
        defaults.set(true, forKey: key)
        defaults.removeObject(forKey: "debug_playbackSource")
        defaults.removeObject(forKey: "debug_streamDelivery")
    }

    /// Forgets steps the app no longer has, such as `tv.sabr`, which needed
    /// the remote solver. A chain that had only those switched on would play
    /// nothing, so it goes back to the default.
    private func dropRemovedPlaybackSteps() {
        let known = Set(PlaybackChainSettings.defaultOrder)
        let enabled = PlaybackChainSettings.enabled
        let kept = enabled.intersection(known)
        guard kept != enabled else {
            return
        }
        PlaybackChainSettings.enabled = kept.isEmpty
            ? Set(PlaybackChainSettings.defaultEnabled) : kept
        PlaybackChainSettings.order = PlaybackChainSettings.order.filter(known.contains)
    }

    private func forgetRemovedServices() {
        let defaults = UserDefaults.standard
        let key = UserDefaultsKeys.Migration.removedExternalServices
        guard !defaults.bool(forKey: key) else {
            return
        }
        defaults.set(true, forKey: key)
        let perCategory = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("sb_behavior_") }
        for stale in Self.removedServiceKeys + perCategory {
            defaults.removeObject(forKey: stale)
        }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.removeItem(
            at: support.appendingPathComponent("notifications.json")
        )
    }
}
