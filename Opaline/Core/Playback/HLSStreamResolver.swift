import Foundation

// MARK: - HLS Stream Resolver
//
// Small HTTP/regex helpers for live HLS playback: `fetchText` loads a
// playlist, `firstMatch` reads an attribute out of it.

final class HLSStreamResolver {
    enum ResolverError: Error {
        case badResponse
    }

    static let shared = HLSStreamResolver()

    let desktopSafariUA = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "AppleWebKit/605.1.15 (KHTML, like Gecko)",
        "Version/17.5 Safari/605.1.15"
    ].joined(separator: " ")

    let transport: HTTPTransport

    init(transport: HTTPTransport = ServiceContainer.transport) {
        self.transport = transport
    }

    static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let group = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[group])
    }

    func fetchText(
        url: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // A fixed English request profile, not the content-language setting:
        // the playlists are parsed, never shown.
        let headers = [
            HTTPHeader.userAgent: desktopSafariUA,
            "Cookie": "SOCS=CAI",
            HTTPHeader.acceptLanguage: "en-US,en;q=0.9"
        ]
        transport.send(
            HTTPRequest(
                method: .get, url: url, headers: headers, isPlayback: true
            ),
            cancellationToken: nil
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                if let text = String(data: response.data, encoding: .utf8) {
                    completion(.success(text))
                } else {
                    completion(.failure(ResolverError.badResponse))
                }
            }
        }
    }
}
