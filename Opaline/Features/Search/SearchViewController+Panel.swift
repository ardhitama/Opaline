import UIKit

// MARK: - History panel

extension SearchViewController {
    enum PanelMode {
        case hidden
        case history
        /// Past searches narrowed to what is typed. Local only: nothing typed
        /// leaves the device before the search itself.
        case matches
    }

    var panelItems: [String] {
        switch panelMode {
        case .hidden:
            return []
        case .history:
            return searchHistory.queries
        case .matches:
            return historyMatches
        }
    }

    /// A trailing row under the history entries, offered only when there
    /// is something to clear.
    var showsClearHistoryRow: Bool {
        panelMode == .history && !searchHistory.queries.isEmpty
    }

    func setPanel(_ mode: PanelMode) {
        guard panelMode != mode else {
            if mode != .hidden {
                tableView.reloadData()
            }
            return
        }
        panelMode = mode
        tableView.reloadData()
    }

    /// Derives the panel from the current input: history for an empty
    /// query, the past searches that contain it otherwise.
    func updatePanel(for text: String) {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmed.isEmpty {
            // Clearing the field is how the user asks for history back,
            // whether or not the keyboard is still up.
            historyMatches = []
            showHistoryIfIdle()
        } else if searchBar.isFirstResponder {
            historyMatches = searchHistory.queries.filter {
                $0.localizedCaseInsensitiveContains(trimmed)
            }
            setPanel(historyMatches.isEmpty ? .hidden : .matches)
        }
    }

    /// History is the resting state of an empty search screen: it shows
    /// without waiting for the field to take focus, and comes back when the
    /// user dismisses the keyboard without searching.
    func showHistoryIfIdle() {
        guard results.isEmpty else {
            setPanel(.hidden)
            return
        }
        setPanel(searchHistory.queries.isEmpty ? .hidden : .history)
    }

    /// Row tap in the panel: fill the bar and run the search.
    func executePanelQuery(_ query: String) {
        searchBar.text = query
        searchBar.resignFirstResponder()
        search(query: query)
    }

    func isClearHistoryRow(_ index: Int) -> Bool {
        showsClearHistoryRow && index == searchHistory.queries.count
    }

    /// Clearing cannot be undone, so it asks first. An alert, not a sheet:
    /// the official app asks with one, and a sheet becomes a popover on
    /// iPad that floats over the list with its cancel button dropped.
    func confirmClearHistory() {
        let alert = UIAlertController(
            title: "search.clearHistory.title".localized,
            message: "search.clearHistory.message".localized,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: "search.clearHistory.confirm".localized,
                style: .destructive
            ) { [weak self] _ in
                self?.searchHistory.clear()
                self?.setPanel(.hidden)
            }
        )
        alert.addAction(
            UIAlertAction(title: "common.cancel".localized, style: .cancel)
        )
        present(alert, animated: true)
    }

    func removeHistoryItem(at index: Int) {
        let queries = searchHistory.queries
        guard queries.indices.contains(index) else {
            return
        }
        searchHistory.remove(queries[index])
        if searchHistory.queries.isEmpty {
            setPanel(.hidden)
        } else {
            tableView.reloadData()
        }
    }
}
