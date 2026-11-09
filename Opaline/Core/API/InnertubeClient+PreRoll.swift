import Foundation

// MARK: - The pre-roll wait

extension InnertubeClient {
    /// How long googlevideo withholds a `/player` response's media: until
    /// the pre-roll ad would have played, to its skip offset when it has
    /// one. A request before then is refused with 403 although every
    /// parameter is right. Measured on TVHTML5 (2026-11-09) with a 5 s
    /// skippable ad: 403 at 0 and 3 s, 206 from 6 s on. yt-dlp waits the
    /// same span before it downloads.
    static func preRollSeconds(_ json: [String: Any]) -> TimeInterval {
        preRollAds(json).reduce(0) { $0 + adSeconds($1) }
    }
}

private extension InnertubeClient {
    /// The ads set to play before the content, from both places a response
    /// can name them.
    static func preRollAds(_ json: [String: Any]) -> [[String: Any]] {
        var ads: [[String: Any]] = []
        for placement in json["adPlacements"] as? [[String: Any]] ?? [] {
            let renderer = placement["adPlacementRenderer"] as? [String: Any]
            let config = (renderer?["config"] as? [String: Any])?["adPlacementConfig"]
            guard (config as? [String: Any])?["kind"] as? String == "AD_PLACEMENT_KIND_START",
                  let content = renderer?["renderer"] as? [String: Any] else {
                continue
            }
            ads += instreamAds(in: content)
        }
        for slot in json["adSlots"] as? [[String: Any]] ?? [] {
            let renderer = slot["adSlotRenderer"] as? [String: Any]
            let metadata = renderer?["adSlotMetadata"] as? [String: Any]
            guard metadata?["triggerEvent"] as? String == "SLOT_TRIGGER_EVENT_BEFORE_CONTENT",
                  let content = renderingContent(
                    of: (renderer?["fulfillmentContent"] as? [String: Any])?["fulfilledLayout"]
                  ) else {
                continue
            }
            ads += instreamAds(in: content)
        }
        return ads
    }

    /// One ad, or a sequence of them.
    static func instreamAds(in content: [String: Any]) -> [[String: Any]] {
        if let ad = content["instreamVideoAdRenderer"] as? [String: Any] {
            return [ad]
        }
        let sequence = content["playerBytesSequentialLayoutRenderer"] as? [String: Any]
        let layouts = sequence?["sequentialLayouts"] as? [[String: Any]] ?? []
        return layouts.compactMap { layout in
            renderingContent(of: layout)?["instreamVideoAdRenderer"] as? [String: Any]
        }
    }

    static func renderingContent(of layout: Any?) -> [String: Any]? {
        let renderer = (layout as? [String: Any])?["playerBytesAdLayoutRenderer"]
        return (renderer as? [String: Any])?["renderingContent"] as? [String: Any]
    }

    static func adSeconds(_ ad: [String: Any]) -> TimeInterval {
        if let skip = ad["skipOffsetMilliseconds"] as? Double {
            return skip / 1_000
        }
        let vars = URLComponents(string: "?" + (ad["playerVars"] as? String ?? ""))
        let length = vars?.queryItems?.last { $0.name == "length_seconds" }?.value
        return length.flatMap(TimeInterval.init) ?? 0
    }
}
