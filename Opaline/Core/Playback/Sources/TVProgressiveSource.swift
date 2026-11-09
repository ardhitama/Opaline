import Foundation

/// The TV client's muxed 360p stream, played under the account: the step for
/// age-restricted and account-only videos that no anonymous client is served.
///
/// Before `/player` it reads the current TV player, which the request is
/// paired with; after it, `ChallengeSolver` answers the URL's `n` (and `s`,
/// when the format is ciphered) with that same player. The stream is handed
/// over only once the response's pre-roll has run out: googlevideo refuses
/// it until then.
final class TVProgressiveSource: VideoSource {
    let name = "tv.progressive"
    let supportsQualitySelection = true
    let availableQualities: [VideoQuality] = [ProgressiveSource.quality360]
    let currentQuality: VideoQuality? = ProgressiveSource.quality360

    private let apiClient: WatchService
    private let players: TVPlayerStore
    private let solver: ChallengeSolver

    init(
        apiClient: WatchService,
        players: TVPlayerStore = .shared,
        solver: ChallengeSolver = .shared
    ) {
        self.apiClient = apiClient
        self.players = players
        self.solver = solver
    }

    func loadPlayback(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        players.current { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let player):
                self?.fetch(
                    videoId: videoId,
                    client: TVClient(player: player),
                    cancellation: cancellation,
                    completion: completion
                )
            }
        }
    }

    func selectQuality(
        _ quality: VideoQuality,
        resumeAt: Double?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        completion(.failure(NSError(domain: "TVProgressiveSource", code: 0)))
    }

    private func fetch(
        videoId: String,
        client: TVClient,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        apiClient.fetchDirectPlayback(
            videoId: videoId,
            client: client,
            poToken: nil,
            cancellationToken: cancellation
        ) { [weak self] result in
            guard cancellation?.isCancelled != true else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let info):
                let opensAt = Date().addingTimeInterval(info.preRollSeconds)
                self?.solve(info, client: client) { result in
                    guard case .success = result else {
                        completion(result)
                        return
                    }
                    Self.wait(until: opensAt) {
                        guard cancellation?.isCancelled != true else {
                            return
                        }
                        completion(result)
                    }
                }
            }
        }
    }

    private func solve(
        _ info: DirectPlaybackInfo,
        client: TVClient,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        guard let url = info.progressiveURL else {
            completion(.failure(ProgressiveSource.noStream))
            return
        }
        var challenges: [ChallengeSolver.Kind: String] = [:]
        challenges[.nThrottle] = StreamURLParams.nValue(of: url)
        challenges[.signature] = info.progressiveSigChallenge
        solver.solve(challenges, with: client.player) { result in
            completion(result.map { answers in
                let playable = Self.answering(
                    url, answers: answers, sigParam: info.progressiveSigParam
                )
                return ProgressiveSource.prepared(
                    url: client.directURL(baseURL: playable, poToken: nil),
                    info: info,
                    client: client
                )
            })
        }
    }
}

private extension TVProgressiveSource {
    static func wait(until date: Date, then work: @escaping () -> Void) {
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else {
            work()
            return
        }
        AppLog.player("tv: holding the stream \(Int(delay * 1_000))ms for the pre-roll")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + delay, execute: work
        )
    }

    static func answering(
        _ url: URL, answers: [ChallengeSolver.Kind: String], sigParam: String?
    ) -> URL {
        var playable = url
        if let solved = answers[.nThrottle] {
            playable = StreamURLParams.replacingN(in: playable, solved: solved)
        }
        if let solved = answers[.signature] {
            playable = StreamURLParams.setting(sigParam ?? "signature", to: solved, in: playable)
        }
        return playable
    }
}
