import UIKit

class SearchViewController: UIViewController {
    let service: SearchService
    let channelViewControllerFactory: (
        String,
        String
    ) -> UIViewController
    let videoRouter: VideoRouter
    var results: [Video] = []
    var filters = SearchFilters()
    let filtersButton = UIBarButtonItem(
        title: "search.filters".localized, style: .plain, target: nil, action: nil
    )
    /// Also the bar's title: on iOS 26 the field folds into a button once
    /// results are up, and the query is what they are results for.
    var lastQuery: String = "" {
        didSet {
            navigationItem.title = lastQuery.isEmpty ? "search.title".localized : lastQuery
        }
    }
    var activeSearchQuery: String?
    var searchCancellationToken = CancellationToken()
    var continuationToken: String?
    var isLoadingNextPage = false
    var panelMode: PanelMode = .hidden
    /// What the panel offers while typing: matching past searches, then the
    /// device's own word completions (`SearchCompletions`).
    var suggestions: [String] = []
    let searchHistory = SearchHistoryStore.shared

    /// The system search controller, in the navigation bar. Results and the
    /// suggestions panel stay in this screen's table, so it presents nothing
    /// of its own.
    let searchController = UISearchController(searchResultsController: nil)
    var searchBar: UISearchBar { searchController.searchBar }
    let tableView = UITableView()
    let refreshControl = UIRefreshControl()
    lazy var topBarHider = TopBarAutoHider(owner: self)

    init(
        service: SearchService,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
        self.channelViewControllerFactory = channelViewControllerFactory
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = lastQuery.isEmpty ? "search.title".localized : lastQuery
        setupFiltersButton()
        setupSearchBar()
        setupTableView()
        applyTheme()
        showHistoryIfIdle()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Only on a fresh screen: coming back from a video should leave
        // the results where they were, without the keyboard covering them.
        if results.isEmpty {
            searchBar.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        topBarHider.showBars()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // The same table renders the history panel — keep the top
        // bar while the user is picking a query.
        guard scrollView === tableView, panelMode == .hidden else {
            return
        }
        topBarHider.handleScroll(scrollView)
    }

    private func setupSearchBar() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.delegate = self
        searchBar.delegate = self
        searchBar.placeholder = "search.placeholder".localized
        searchBar.text = lastQuery.isEmpty ? nil : lastQuery
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            // In the bar's own row, between Back and Filters: the field is
            // the screen's title, and a row of its own is height the results
            // could have.
            navigationItem.preferredSearchBarPlacement = .integrated
        }
        definesPresentationContext = true
    }

    private func setupTableView() {
        tableView.register(
            SubscriptionVideoCell.self,
            forCellReuseIdentifier: SubscriptionVideoCell.reuseId
        )
        tableView.dataSource = self
        tableView.delegate = self
        // Heights come from `heightForRowAt`; the estimate keeps the table
        // asking only for visible rows instead of all of them on reload.
        tableView.estimatedRowHeight = 320
        tableView.separatorInset = UIEdgeInsets(
            top: 0, left: 12, bottom: 0, right: 12
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .onDrag
        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)
        activateTableConstraints()
    }

    private func activateTableConstraints() {
        NSLayoutConstraint.activate([
            // Under the bar, so the list scrolls beneath its glass.
            tableView.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            tableView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    @objc
    private func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        if #unavailable(iOS 13.0) {
            // No dark appearance before iOS 13 to give the field.
            searchBar.barStyle = theme.barStyle
        }
        searchBar.keyboardAppearance = .dark
        tableView.reloadData()
    }

    @objc
    private func handleRefresh() {
        guard !lastQuery.isEmpty else {
            refreshControl.endRefreshing()
            return
        }
        search(query: lastQuery)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else {
            return
        }
        search(query: query)
        // Results get the whole bar back: Back, the query and Filters.
        searchController.isActive = false
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        topBarHider.showBars()
        updatePanel(for: searchBar.text ?? "")
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        showHistoryIfIdle()
    }

    /// While the field is active the bar shows only the field and this
    /// button, so it is the way out: with nothing searched it leaves the
    /// screen, the one tap Back would have been. With results it puts the
    /// keyboard away and keeps them (see `didDismissSearchController`).
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        if results.isEmpty {
            navigationController?.popViewController(animated: true)
        }
    }

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        // Only the user's own clearing drops the results: the controller
        // empties the field on its way out too.
        if searchText.isEmpty, searchBar.isFirstResponder {
            clearSearchResults()
        }
        updatePanel(for: searchText)
    }
}

// MARK: - UISearchControllerDelegate

extension SearchViewController: UISearchControllerDelegate {
    /// Leaving the field brings Back and Filters back to the bar, and the
    /// query stays in it for as long as its results are on screen.
    func didDismissSearchController(_ searchController: UISearchController) {
        searchBar.text = lastQuery.isEmpty ? nil : lastQuery
        showHistoryIfIdle()
    }
}
