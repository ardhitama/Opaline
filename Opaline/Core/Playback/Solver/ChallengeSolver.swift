import Foundation
import JavaScriptCore

/// Answers the challenges a player sets on its media URLs, on the device.
///
/// A googlevideo URL can carry an `n` (throttling) value and, when it arrives
/// as a `signatureCipher`, an `s` value. The server serves nothing until both
/// are replaced by what the player's own functions return for them, and only
/// the player that the request's signature timestamp names gives the right
/// answers.
///
/// The solver is yt-dlp's EJS (`yt.solver.lib.min.js` and
/// `yt.solver.core.min.js`, Unlicense; bundles meriyah, ISC, and astring,
/// MIT). It is built from yt-dlp/ejs pull request 77 at 51f1856: the 0.8.0
/// release cannot parse the TV `tv-player-ias-tcl` player. It runs in
/// JavaScriptCore rather than a web view because it sets
/// `globalThis.location`.
///
/// Parsing a player takes about 1.6 s, so the context keeps the last parsed
/// player (EJS's preprocessed form) and later challenges against the same
/// player take about 10 ms.
final class ChallengeSolver {
    enum Kind: String {
        case nThrottle = "n"
        case signature = "sig"
    }

    enum SolveError: LocalizedError {
        case unsupportedSystem
        case solverMissing
        case playerUnreadable
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedSystem:
                return "Solving challenges needs iOS 14 or later."
            case .solverMissing:
                return "The challenge solver is missing from the app bundle."
            case .playerUnreadable:
                return "The cached player script could not be read."
            case .failed(let reason):
                return "The challenge solver failed: \(reason)"
            }
        }
    }

    static let shared = ChallengeSolver()

    /// Solved values are tied to the player, so the cache is cleared rather
    /// than trimmed when it fills.
    private static let answerLimit = 256

    /// JavaScript calls into EJS. `player` is null when the preprocessed
    /// player kept from the previous call is the one to use.
    private static let entryPoint = """
    var __preprocessed = null;
    function __solve(player, requests) {
      try {
        var request = { requests: JSON.parse(requests) };
        if (player === null) {
          request.type = 'preprocessed';
          request.preprocessed_player = __preprocessed;
        } else {
          request.type = 'player';
          request.player = player;
          request.output_preprocessed = true;
        }
        var result = jsc(request);
        if (player !== null) {
          __preprocessed = (result && result.preprocessed_player) || null;
        }
        if (result) {
          delete result.preprocessed_player;
        }
        return JSON.stringify(result);
      } catch (e) {
        return JSON.stringify({ type: 'error', error: String(e) });
      }
    }
    """

    /// JSContext is not thread-safe: everything below runs on this queue.
    private let queue = DispatchQueue(
        label: "com.ardvis.opaline.challenge-solver", qos: .userInitiated
    )
    private var context: JSContext?
    /// The player whose preprocessed form `__preprocessed` holds.
    private var preparedPlayerPath: String?
    private var answers: [String: String] = [:]

    private init() {}

    /// Solves every challenge in `challenges` with `player`. The result has
    /// an answer for each kind asked, or the call fails as a whole.
    func solve(
        _ challenges: [Kind: String],
        with player: TVPlayer,
        completion: @escaping (Result<[Kind: String], Error>) -> Void
    ) {
        queue.async { [self] in
            completion(Result { try solveNow(challenges, with: player) })
        }
    }

    private func solveNow(
        _ challenges: [Kind: String], with player: TVPlayer
    ) throws -> [Kind: String] {
        var solved: [Kind: String] = [:]
        var pending: [Kind: String] = [:]
        for (kind, challenge) in challenges {
            if let known = answers[Self.answerKey(kind, challenge, player)] {
                solved[kind] = known
            } else {
                pending[kind] = challenge
            }
        }
        guard !pending.isEmpty else {
            return solved
        }
        let started = Date()
        let fresh = try run(pending, with: player)
        let ms = Int(Date().timeIntervalSince(started) * 1_000)
        AppLog.player("solver: \(pending.keys.map(\.rawValue).sorted()) in \(ms)ms")
        if answers.count + fresh.count > Self.answerLimit {
            answers.removeAll()
        }
        for (kind, answer) in fresh {
            answers[Self.answerKey(kind, pending[kind] ?? "", player)] = answer
            solved[kind] = answer
        }
        return solved
    }

    private func run(
        _ challenges: [Kind: String], with player: TVPlayer
    ) throws -> [Kind: String] {
        // The players use syntax JavaScriptCore only parses from iOS 14.
        guard #available(iOS 14.0, *) else {
            throw SolveError.unsupportedSystem
        }
        let context = try sharedContext()
        let kinds = Array(challenges.keys)
        let requests = kinds.map { kind -> [String: Any] in
            ["type": kind.rawValue, "challenges": [challenges[kind] ?? ""]]
        }
        guard let requestJSON = String(
            bytes: try JSONSerialization.data(withJSONObject: requests), encoding: .utf8
        ) else {
            throw SolveError.failed("request not encodable")
        }
        let playerArgument: Any
        if preparedPlayerPath == player.path {
            playerArgument = NSNull()
        } else if let text = try? String(contentsOf: player.file, encoding: .utf8) {
            playerArgument = text
        } else {
            throw SolveError.playerUnreadable
        }
        // Set again only once this call has answered: a failed call may have
        // left the context without a usable preprocessed player.
        preparedPlayerPath = nil
        let output = context.objectForKeyedSubscript("__solve")?
            .call(withArguments: [playerArgument, requestJSON])?
            .toString()
        // A raw parse leaves megabytes of syntax tree behind.
        JSGarbageCollect(context.jsGlobalContextRef)
        let answers = try Self.answers(from: output, kinds: kinds, challenges: challenges)
        preparedPlayerPath = player.path
        return answers
    }

    private func sharedContext() throws -> JSContext {
        if let context {
            return context
        }
        guard let lib = Self.bundledScript("yt.solver.lib.min"),
              let core = Self.bundledScript("yt.solver.core.min"),
              let context = JSContext() else {
            throw SolveError.solverMissing
        }
        context.exceptionHandler = { _, value in
            AppLog.player("solver: JS exception \(value?.toString() ?? "")")
        }
        context.evaluateScript(lib)
        // The core is an esbuild bundle: it loads meriyah and astring through
        // `require` and exports `jsc` as `{ default }`.
        context.evaluateScript(
            "var require = function (name) { var m = (lib.lib || lib)[name];"
                + " if (!m) { throw new Error('no module ' + name); } return m; };"
        )
        context.evaluateScript(core)
        context.evaluateScript(
            "if (typeof jsc !== 'function' && jsc && typeof jsc.default === 'function')"
                + " { jsc = jsc.default; }"
        )
        context.evaluateScript(Self.entryPoint)
        self.context = context
        return context
    }
}

private extension ChallengeSolver {
    static func answerKey(
        _ kind: Kind, _ challenge: String, _ player: TVPlayer
    ) -> String {
        "\(kind.rawValue)|\(player.path)|\(challenge)"
    }

    /// Reads EJS's reply: one response per request, in request order, each
    /// mapping the challenge to its answer.
    static func answers(
        from output: String?,
        kinds: [Kind],
        challenges: [Kind: String]
    ) throws -> [Kind: String] {
        guard let data = output?.data(using: .utf8),
              let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SolveError.failed("no reply")
        }
        guard reply["type"] as? String == "result",
              let responses = reply["responses"] as? [[String: Any]],
              responses.count == kinds.count else {
            throw SolveError.failed(reply["error"] as? String ?? "unexpected reply")
        }
        var answers: [Kind: String] = [:]
        for (kind, response) in zip(kinds, responses) {
            let challenge = challenges[kind] ?? ""
            guard let answer = (response["data"] as? [String: Any])?[challenge] as? String,
                  !answer.isEmpty else {
                let reason = (response["error"] as? String)?.prefix(200) ?? "no answer"
                throw SolveError.failed("\(kind.rawValue): \(reason)")
            }
            answers[kind] = answer
        }
        return answers
    }

    static func bundledScript(_ name: String) -> String? {
        Bundle.main.url(forResource: name, withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}
