import Foundation

/// The TV player a TV `/player` request is paired with.
///
/// YouTube signs a TV media URL for the player that the request's signature
/// timestamp names, and only that player's functions answer its challenges.
/// The timestamp is read out of the same file the solver runs, so the two
/// cannot disagree.
struct TVPlayer {
    /// `/s/player/<id>/tv-player-ias-tcl.vflset/tv-player-ias-tcl.js`.
    let path: String
    /// The downloaded script, in Caches.
    let file: URL
    let signatureTimestamp: Int
    /// The TV client version `youtube.com/tv` runs. googlevideo refuses a URL
    /// whose `cver` names a version it no longer serves, and the version
    /// carries a date, so it is scraped instead of pinned.
    let clientVersion: String
}

/// Finds the current TV player and keeps a copy of it on the device.
final class TVPlayerStore {
    enum StoreError: LocalizedError {
        case pageUnreadable
        case downloadFailed(Int)
        case noTimestamp

        var errorDescription: String? {
            switch self {
            case .pageUnreadable:
                return "youtube.com/tv did not name its player or client version."
            case .downloadFailed(let status):
                return "The TV player could not be downloaded (HTTP \(status))."
            case .noTimestamp:
                return "The TV player has no signature timestamp."
            }
        }
    }

    static let shared = TVPlayerStore()

    /// The player id rotates about weekly. A day-old player is still served,
    /// so re-reading the page a few times a day is enough.
    private static let maxAge: TimeInterval = 6 * 3_600
    private static let defaultsKey = UserDefaultsKeys.Playback.tvPlayer

    private static let directory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("TVPlayer", isDirectory: true)
    }()

    private let transport: HTTPTransport
    private let queue = DispatchQueue(label: "com.ardvis.opaline.tv-player")
    private var waiting: [(Result<TVPlayer, Error>) -> Void] = []

    init(transport: HTTPTransport = ServiceContainer.transport) {
        self.transport = transport
    }

    /// The player to pair the next TV request with. Concurrent callers share
    /// one refresh.
    func current(completion: @escaping (Result<TVPlayer, Error>) -> Void) {
        queue.async { [self] in
            if let stored = Self.stored(), Date().timeIntervalSince(stored.date) < Self.maxAge {
                completion(.success(stored.player))
                return
            }
            waiting.append(completion)
            guard waiting.count == 1 else {
                return
            }
            refresh { result in
                self.queue.async {
                    let callers = self.waiting
                    self.waiting = []
                    callers.forEach { $0(result) }
                }
            }
        }
    }

    // MARK: - Refresh

    private func refresh(completion: @escaping (Result<TVPlayer, Error>) -> Void) {
        scrapePage { [self] page in
            guard let page else {
                completion(Self.fallback(for: StoreError.pageUnreadable))
                return
            }
            download(page.path) { result in
                let fresh = result.flatMap { file in
                    Self.player(path: page.path, file: file, clientVersion: page.version)
                }
                if case .failure(let error) = fresh {
                    completion(Self.fallback(for: error))
                } else {
                    completion(fresh)
                }
            }
        }
    }

    private func scrapePage(completion: @escaping ((path: String, version: String)?) -> Void) {
        guard let url = URL(string: AppURLs.YouTube.base + "/tv") else {
            completion(nil)
            return
        }
        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: [HTTPHeader.userAgent: UserAgent.cobaltFireTV],
            isPlayback: true
        )
        transport.send(request, cancellationToken: nil) { result in
            guard case .success(let response) = result,
                  let html = String(data: response.data, encoding: .utf8),
                  let advertised = Self.playerPath(in: html),
                  let version = Self.clientVersion(in: html) else {
                completion(nil)
                return
            }
            completion((Self.tclVariant(of: advertised), version))
        }
    }

    private func download(_ path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let file = Self.directory.appendingPathComponent(Self.fileName(for: path))
        if FileManager.default.fileExists(atPath: file.path) {
            completion(.success(file))
            return
        }
        guard let url = URL(string: AppURLs.YouTube.base + path) else {
            completion(.failure(StoreError.downloadFailed(0)))
            return
        }
        let request = HTTPRequest(method: .get, url: url, isPlayback: true)
        transport.send(request, cancellationToken: nil) { result in
            completion(result.flatMap { response in
                guard response.status == 200, !response.data.isEmpty else {
                    return .failure(StoreError.downloadFailed(response.status))
                }
                return Result { try Self.replaceCachedPlayers(with: response.data, at: file) }
            })
        }
    }
}

private extension TVPlayerStore {
    /// An older player beats none: YouTube keeps serving one for a while
    /// after it rotates.
    static func fallback(for error: Error) -> Result<TVPlayer, Error> {
        guard let stored = stored() else {
            return .failure(error)
        }
        AppLog.player("tv player: \(error.localizedDescription) Keeping \(stored.player.path)")
        return .success(stored.player)
    }

    /// Only the current player is kept: an old one is never solved with again.
    static func replaceCachedPlayers(with data: Data, at file: URL) throws -> URL {
        let manager = FileManager.default
        try? manager.removeItem(at: directory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }

    static func player(
        path: String, file: URL, clientVersion: String
    ) -> Result<TVPlayer, Error> {
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let sts = signatureTimestamp(in: text) else {
            try? FileManager.default.removeItem(at: file)
            return .failure(StoreError.noTimestamp)
        }
        let player = TVPlayer(
            path: path, file: file, signatureTimestamp: sts, clientVersion: clientVersion
        )
        store(player)
        AppLog.player("tv player \(path) sts=\(sts) cver=\(clientVersion)")
        return .success(player)
    }

    static func stored() -> (player: TVPlayer, date: Date)? {
        guard let entry = UserDefaults.standard.dictionary(forKey: defaultsKey),
              let path = entry["path"] as? String,
              let sts = entry["sts"] as? Int,
              let version = entry["clientVersion"] as? String,
              let date = entry["date"] as? Date else {
            return nil
        }
        let file = directory.appendingPathComponent(fileName(for: path))
        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }
        let player = TVPlayer(
            path: path, file: file, signatureTimestamp: sts, clientVersion: version
        )
        return (player, date)
    }

    static func store(_ player: TVPlayer) {
        UserDefaults.standard.set(
            [
                "path": player.path,
                "sts": player.signatureTimestamp,
                "clientVersion": player.clientVersion,
                "date": Date()
            ],
            forKey: defaultsKey
        )
    }

    /// `/s/player/a5c2aafe/tv-player-ias-tcl.vflset/…` becomes
    /// `a5c2aafe-tv-player-ias-tcl.js`.
    static func fileName(for path: String) -> String {
        let parts = path.split(separator: "/")
        let id = parts.count > 2 ? String(parts[2]) : "player"
        return "\(id)-\(parts.last ?? "player.js")"
    }

    /// The `/tv` page advertises `tv-player-es6`, but what a television runs,
    /// and what signs its URLs, is the `tv-player-ias-tcl` build of the same
    /// player id.
    static func tclVariant(of path: String) -> String {
        guard let idRange = path.range(of: "/s/player/[^/]+/", options: .regularExpression) else {
            return path
        }
        return String(path[idRange]) + "tv-player-ias-tcl.vflset/tv-player-ias-tcl.js"
    }

    static func playerPath(in html: String) -> String? {
        guard let range = html.range(
            of: "\"(PLAYER_JS_URL|jsUrl)\":\"(\\\\?/s\\\\?/player[^\"]+\\.js)\"",
            options: .regularExpression
        ) else {
            return nil
        }
        let match = String(html[range])
        guard let pathRange = match.range(
            of: "\\\\?/s\\\\?/player[^\"]+\\.js", options: .regularExpression
        ) else {
            return nil
        }
        return String(match[pathRange]).replacingOccurrences(of: "\\/", with: "/")
    }

    static func clientVersion(in html: String) -> String? {
        guard let range = html.range(
            of: "\"INNERTUBE_CLIENT_VERSION\":\"[^\"]+\"", options: .regularExpression
        ) else {
            return nil
        }
        return String(html[range]).components(separatedBy: "\"").dropLast().last
    }

    static func signatureTimestamp(in script: String) -> Int? {
        guard let range = script.range(
            of: "signatureTimestamp:[0-9]+", options: .regularExpression
        ) else {
            return nil
        }
        return Int(script[range].dropFirst("signatureTimestamp:".count))
    }
}
