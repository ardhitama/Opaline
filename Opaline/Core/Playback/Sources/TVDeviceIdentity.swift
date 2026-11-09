import Foundation

/// The device identity a television presents to YouTube.
///
/// A real TV app makes up a short id once and keeps it for the life of the
/// install; it travels in the `/player` context as
/// `tvAppInfo.livingRoomPoTokenId`. Captured from a live TV session
/// 2026-08-16: the id is 12 base64 characters.
enum TVDeviceIdentity {
    /// The id this install presents, minted once and kept.
    static var livingRoomPoTokenId: String {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: UserDefaultsKeys.Playback.livingRoomPoTokenId),
           !stored.isEmpty {
            return stored
        }
        let generated = generate()
        defaults.set(generated, forKey: UserDefaultsKeys.Playback.livingRoomPoTokenId)
        return generated
    }

    /// Nine random bytes, base64 — exactly twelve characters, no padding.
    private static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 9)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: 0...255)
        }
        return Data(bytes).base64EncodedString()
    }
}
