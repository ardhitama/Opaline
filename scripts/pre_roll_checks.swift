// Checks for InnertubeClient.preRollSeconds. Not standalone —
// check_pre_roll.sh concatenates it with the real parser source.
//
// The fixtures keep the shape of a TVHTML5 /player response (2026-11-09),
// trimmed to the keys the parser reads.

func ad(skipMs: Int?, lengthSeconds: Int) -> [String: Any] {
    var renderer: [String: Any] = [
        "playerVars": "endscreen_ad_tracking_data=x&length_seconds=\(lengthSeconds)&video_id=y"
    ]
    renderer["skipOffsetMilliseconds"] = skipMs
    return ["instreamVideoAdRenderer": renderer]
}

func slot(trigger: String, content: [String: Any]) -> [String: Any] {
    [
        "adSlotRenderer": [
            "adSlotMetadata": ["triggerEvent": trigger],
            "fulfillmentContent": [
                "fulfilledLayout": [
                    "playerBytesAdLayoutRenderer": ["renderingContent": content]
                ]
            ]
        ]
    ]
}

func placement(kind: String, content: [String: Any]) -> [String: Any] {
    [
        "adPlacementRenderer": [
            "config": ["adPlacementConfig": ["kind": kind]],
            "renderer": content
        ]
    ]
}

func sequence(_ ads: [[String: Any]]) -> [String: Any] {
    let layouts = ads.map { ["playerBytesAdLayoutRenderer": ["renderingContent": $0]] }
    return ["playerBytesSequentialLayoutRenderer": ["sequentialLayouts": layouts]]
}

/// Round-trips the fixture through JSONSerialization, which is what hands
/// the parser its numbers (as NSNumber) in the app.
func check(_ fixture: [String: Any], expect: Double, line: UInt = #line) {
    let data = try! JSONSerialization.data(withJSONObject: fixture)
    let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let got = InnertubeClient.preRollSeconds(json)
    assert(got == expect, "line \(line): got \(got), expected \(expect)")
}

let before = "SLOT_TRIGGER_EVENT_BEFORE_CONTENT"

// The measured response: a 10 s ad skippable at 5 s, before the content; a
// mid-roll placement that does not hold the stream.
check([
    "adPlacements": [placement(kind: "AD_PLACEMENT_KIND_END", content: [:])],
    "adSlots": [slot(trigger: before, content: ad(skipMs: 5_000, lengthSeconds: 10))]
], expect: 5)

// No skip offset: the whole ad.
check(["adSlots": [slot(trigger: before, content: ad(skipMs: nil, lengthSeconds: 15))]], expect: 15)

// A sequence of pre-rolls adds up.
check([
    "adSlots": [slot(trigger: before, content: sequence([
        ad(skipMs: nil, lengthSeconds: 6), ad(skipMs: 5_000, lengthSeconds: 30)
    ]))]
], expect: 11)

// The older placement form.
check([
    "adPlacements": [placement(kind: "AD_PLACEMENT_KIND_START", content: ad(skipMs: 2_500, lengthSeconds: 20))]
], expect: 2.5)

// Ads that play later, and no ads at all, hold nothing.
check([
    "adSlots": [slot(trigger: "SLOT_TRIGGER_EVENT_LAYOUT_ID_EXITED", content: ad(skipMs: nil, lengthSeconds: 30))],
    "adPlacements": [placement(kind: "AD_PLACEMENT_KIND_MILLISECONDS", content: ad(skipMs: nil, lengthSeconds: 30))]
], expect: 0)
check([:], expect: 0)

print("pre-roll checks passed")
