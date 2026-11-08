import Foundation

/// Centralised API base-URL namespace.
/// Actual endpoint paths are built locally in each service, but base URLs live here.
enum AppURLs {
    enum YouTube {
        static let base      = "https://www.youtube.com"
        static let innertube = "https://www.youtube.com/youtubei/v1"
        static let tv        = "https://www.youtube.com/tv"

        /// Stable fallback thumbnail URL for a given video ID. The thumbnail
        /// loader adds higher-resolution candidates when this is used.
        static func thumbnailURL(videoId: String) -> String {
            "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
        }

        /// Public per-channel Atom feed (unauthenticated, last ~15
        /// uploads with exact publish dates). Powers the new-content
        /// dots without touching the relevance-ranked subscriptions feed.
        static func channelRSSFeedURL(channelId: String) -> URL? {
            URL(string: base + "/feeds/videos.xml?channel_id=" + channelId)
        }

        /// Same Atom feed restricted to long-form uploads via the
        /// undocumented `UULF` system playlist (Shorts excluded). nil
        /// for non-`UC` channel ids — callers fall back to the full feed.
        static func channelLongFormRSSFeedURL(channelId: String) -> URL? {
            guard channelId.hasPrefix("UC") else {
                return nil
            }
            let playlistId = "UULF" + channelId.dropFirst(2)
            return URL(
                string: base + "/feeds/videos.xml?playlist_id=" + playlistId
            )
        }

        /// The mirror image: the undocumented `UUSH` system playlist holds
        /// the channel's Shorts and nothing else. nil for non-`UC` ids.
        static func channelShortsRSSFeedURL(channelId: String) -> URL? {
            guard channelId.hasPrefix("UC") else {
                return nil
            }
            let playlistId = "UUSH" + channelId.dropFirst(2)
            return URL(
                string: base + "/feeds/videos.xml?playlist_id=" + playlistId
            )
        }
    }

    enum YouTubeOAuth {
        static let deviceCode = "https://www.youtube.com/o/oauth2/device/code"
        static let token      = "https://www.youtube.com/o/oauth2/token"
    }
}
