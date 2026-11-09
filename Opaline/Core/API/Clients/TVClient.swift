import Foundation

/// The living-room client, played under the account.
///
/// The only client the device-code OAuth token is accepted by, so the only
/// one served what an anonymous session is refused: age-restricted and
/// account-only videos. Its adaptive formats are SABR-only, and partway into
/// many videos the server stops serving them until the session attests
/// itself, which a token minted with BotGuard did not satisfy (measured
/// 2026-11-09). The muxed `itag 18` stream played past that point, so it is
/// what this app plays. Its URL carries challenges set by `player`, which
/// `ChallengeSolver` answers.
struct TVClient: PlaybackClient {
    let name = "TVHTML5"
    let headerName = "7"
    let userAgent = UserAgent.webOSTV
    let playerURL = InnertubeEndpoint.player
    let authorization = PlaybackAuthorization.bearer
    /// Cookieless on purpose: this client authenticates with the bearer, and
    /// the shared jar belongs to whatever else has been on the wire. The app's
    /// mint with the jar came back marked `pcm2cms=yes` and was refused
    /// (measured 2026-08-18, same account, same public IP).
    let sendsCookies = false
    let needsSignatureSolver = true
    /// The player this request is paired with: it sets the signature
    /// timestamp and the client version, and answers the URL's challenges.
    let player: TVPlayer

    var version: String { player.clientVersion }

    var innertubeContext: [String: Any] { InnertubeContexts.tv }

    /// A television names itself in the player context, and its version and
    /// timestamp have to be the ones `player` gives, or the URL is signed for
    /// a player that does not answer its challenges.
    func decoratePlayerBody(_ body: inout [String: Any]) {
        guard var context = body["context"] as? [String: Any],
              var client = context["client"] as? [String: Any] else {
            return
        }
        client["tvAppInfo"] = [
            "livingRoomPoTokenId": TVDeviceIdentity.livingRoomPoTokenId,
            "signedInAccountCount": 1,
            "appQuality": "TV_APP_QUALITY_FULL_ANIMATION"
        ]
        client["clientVersion"] = version
        context["client"] = client
        body["context"] = context
        var playback = body["playbackContext"] as? [String: Any] ?? [:]
        var content = playback["contentPlaybackContext"] as? [String: Any] ?? [:]
        content["signatureTimestamp"] = player.signatureTimestamp
        playback["contentPlaybackContext"] = content
        body["playbackContext"] = playback
    }

    func apiHeaders(token: String, visitorData: String?) -> [String: String] {
        var headers = defaultAPIHeaders(token: token, visitorData: visitorData)
        headers[HTTPHeader.referer] = AppURLs.YouTube.base + "/tv"
        return headers
    }

    /// Never opens a SABR session (see the type's note), so the protobuf
    /// identity is only here to satisfy the protocol.
    func sabrClientInfo() -> Data {
        var info = Protobuf.int(16, 7)
        info += Protobuf.string(17, version)
        info += Protobuf.string(18, "Cobalt")
        info += Protobuf.string(19, "22.lts.3.306369-gold")
        return info + SABRClientInfo.commonTail()
    }

    func sabrAbrState(_ state: SABRPlayerState) -> Data {
        var body = Protobuf.int(28, state.playerMs)
        body += Protobuf.int(34, 0)                      // visibility
        body += Protobuf.int(40, state.wants.bitfield)   // enabledTrackTypes
        if let id = state.audioTrackId, !id.isEmpty {
            body += Protobuf.string(69, id)
        }
        return body
    }
}
