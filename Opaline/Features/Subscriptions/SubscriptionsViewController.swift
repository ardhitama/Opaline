import UIKit

class SubscriptionsViewController: UIViewController, ScrollableToTop {
    static let skeletonCount = 6
    let service: FeedService
    let channelTabsService: ChannelTabService
    let channelsService: SubscribedChannelsService
    let historyService: HistoryService
    let channelRSSService: ChannelRSSFeedService
    let cache: AppCache
    let channelViewControllerFactory: (
        String,
        String
    ) -> UIViewController
    let videoRouter: VideoRouter
    /// Long-form videos only while grouping is on — shorts are then pulled
    /// out into `shortsShelf`.
    var videos: [Video] = [] {
        didSet { rebuildRows() }
    }
    /// The feed's shorts, shown in the shelf row rather than the list.
    var shortsShelf: [Video] = [] {
        didSet { rebuildRows() }
    }
    /// `shortsShelf` + `videos` flattened into table rows.
    var rows: [FeedRow] = []
    var continuationToken: String?
    var isLoadingMore = false
    var seenVideoIds: Set<String> = []
    var sortDatesByVideoId: [String: Date] = [:]
    let tableView = UITableView()
    let channelBar = ChannelAvatarBarView()
    var subscribedChannels: [SubscribedChannel] = []
    var selectedChannel: SubscribedChannel?
    var stashedVideos: [Video] = []
    var stashedShorts: [Video] = []
    var stashedContinuation: String?
    var stashedSeenVideoIds: Set<String> = []
    var isLoadingInitial = true
    var signInPrompt: EmptyStateView?
    /// The bar's leading item (the notifications bell) while a channel
    /// filter puts its back chevron there; put back when the filter ends.
    var itemBehindFilterBack: UIBarButtonItem?
    var isFilterBackInstalled = false
    lazy var topBarHider = TopBarAutoHider(owner: self)
    // New-content dots (issue #13): derived state, never persisted.
    var newContentChannelIds: Set<String> = []
    var newContentUploads: [String: [RSSVideoEntry]] = [:]
    var newContentHistoryIds: Set<String>?
    var newContentHistoryFetchedAt: Date?
    var isLoadingNewContentHistory = false
    var isLoadingNewContentRSS = false
    var locallyWatchedVideoIds: Set<String> = []
    /// Once per session — mirrors `HomeViewController`'s guard so a dead
    /// cached continuation triggers exactly one lazy revalidation.
    var didRevalidateAfterStaleToken = false

    init(
        dependencies: AppDependencies,
        cache: AppCache = .shared,
        videoRouter: VideoRouter = .shared
    ) {
        service = dependencies.feedService
        channelTabsService = dependencies.channelTabService
        channelsService = dependencies.subscribedChannelsService
        historyService = dependencies.historyService
        channelRSSService = dependencies.channelRSSService
        channelViewControllerFactory = dependencies.makeChannelViewController
        self.cache = cache
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // No bar title until a channel is picked: the selected tab already
        // says where this is.
        AppLog.subs("viewDidLoad")
        setupTableView()
        setupSignInPrompt()
        setupChannelBar()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowShortsChange),
            name: .showShortsSettingDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowShortsChange),
            name: .shortsGroupingSettingDidChange,
            object: nil
        )
        ToolbarManager.shared.install(in: self)
        observeTokenRefresh()
        loadInitialContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateChannelBarFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNewContentDots()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        topBarHider.showBars()
    }

    func scrollToTop() {
        topBarHider.showBars()
        tableView.setContentOffset(
            CGPoint(x: 0, y: -tableView.adjustedContentInset.top),
            animated: true
        )
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        channelBar.applyTheme()
        tableView.reloadData()
    }

    @objc
    func handleRefresh() {
        if let channel = selectedChannel {
            loadChannelVideos(channel)
            return
        }
        cache.clearSubscriptionsFeed()
        cache.clearSubscribedChannels()
        loadFeed()
        loadSubscribedChannels(force: true)
    }

    @objc
    func handleShowShortsChange() {
        cache.clearSubscriptionsFeed()
        loadFeed()
        newContentUploads = [:]
        refreshNewContentDots()
    }
}
