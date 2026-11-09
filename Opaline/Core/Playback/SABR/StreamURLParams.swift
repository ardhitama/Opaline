import Foundation

/// Reads and rewrites the query parameters of a signed googlevideo URL.
///
/// The challenge answers (`n`, and the deciphered signature) are the only
/// parts replaced after the URL is minted: the CDN checks them before it
/// serves a single byte.
enum StreamURLParams {
    static func nValue(of url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first { $0.name == "n" }?.value
    }

    static func replacingN(in url: URL, solved: String) -> URL {
        setting("n", to: solved, in: url)
    }

    /// Replaces `name` when the URL has it, and adds it otherwise.
    static func setting(_ name: String, to value: String, in url: URL) -> URL {
        guard var components = URLComponents(
            url: url, resolvingAgainstBaseURL: false
        ) else {
            return url
        }
        var items = components.queryItems ?? []
        let item = URLQueryItem(name: name, value: value)
        if let index = items.firstIndex(where: { $0.name == name }) {
            items[index] = item
        } else {
            items.append(item)
        }
        components.queryItems = items
        // `queryItems` leaves `+` bare, which the CDN reads as a space; a
        // signature can contain one, and an original `%2B` comes back bare.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url ?? url
    }
}
