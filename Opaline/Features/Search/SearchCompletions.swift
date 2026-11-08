import UIKit

/// Whole queries that finish the word being typed, from the device's own
/// dictionaries. `UITextChecker` reads the system lexicon on the device, so
/// nothing typed leaves it before the search itself.
///
/// The keyboard's predictive bar already fills in the word; a completion
/// here is one tap to run the finished query.
enum SearchCompletions {
    private static let limit = 4
    /// One letter completes to most of the dictionary.
    private static let minimumPartialLength = 2

    static func queries(completing text: String, inputLanguage: String?) -> [String] {
        guard let last = text.last, !last.isWhitespace,
              let language = checkerLanguage(for: inputLanguage)
        else {
            return []
        }
        let start = text.rangeOfCharacter(
            from: .whitespacesAndNewlines, options: .backwards
        )?.upperBound ?? text.startIndex
        let typed = text[start...]
        guard typed.count >= minimumPartialLength else {
            return []
        }
        let words = UITextChecker().completions(
            forPartialWordRange: NSRange(start..., in: text),
            in: text,
            language: language
        ) ?? []
        // Keep what was typed as typed; only the rest of the word is added.
        let head = text[..<start]
        return Array(
            words.lazy
                .filter { $0.count > typed.count }
                .map { String(head + typed + $0.dropFirst(typed.count)) }
                .prefix(limit)
        )
    }

    /// The checker names languages `en_US`; the keyboard says `en-US`, and
    /// may name one the checker has no lexicon for.
    private static func checkerLanguage(for inputLanguage: String?) -> String? {
        let available = UITextChecker.availableLanguages
        let wanted = [inputLanguage, Locale.preferredLanguages.first]
            .compactMap { $0?.replacingOccurrences(of: "-", with: "_") }
        for code in wanted {
            if available.contains(code) {
                return code
            }
            let base = code.split(separator: "_").first.map(String.init) ?? code
            if let match = available.first(where: {
                $0 == base || $0.hasPrefix(base + "_")
            }) {
                return match
            }
        }
        return nil
    }
}
