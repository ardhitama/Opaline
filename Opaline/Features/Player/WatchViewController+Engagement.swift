import UIKit

// MARK: - Engagement & Actions

extension WatchViewController {
    // MARK: - App Lifecycle

    @objc
    func appDidEnterBackground() {
        let bgEnabled = BackgroundPlaybackService.isEnabled
        AppLog.player(
            "appDidEnterBackground: bgEnabled=\(bgEnabled)"
        )
        backgroundEnteredAt = Date()
        // Layer/PiP background handling lives in VideoPlayerView.
        guard !bgEnabled else {
            return
        }
        // Auto-PiP may still be starting — pausing now would kill it, so the
        // decision waits a tick for the controller's real state.
        DispatchQueue.main.async { [weak self] in
            guard self?.videoPlayerView?.isPiPActive != true else {
                return
            }
            self?.videoPlayerView?.player?.pause()
        }
    }

    @objc
    func appWillEnterForeground() {
        AppLog.player("appWillEnterForeground")
        let elapsed = backgroundEnteredAt.map {
            Date().timeIntervalSince($0)
        } ?? 0
        backgroundEnteredAt = nil
        if elapsed > 120, hasSeenPlaybackError {
            AppLog.player(
                "foreground: URLs likely expired"
                    + " (\(Int(elapsed))s in bg), recovering"
            )
            recoverPlayback()
        }
    }

    // MARK: - Theming

    private func applyThemeToText(_ theme: ThemeManager) {
        for label in [titleLabel, channelNameLabel, commentsLabel] {
            label.textColor = theme.primaryText
        }
        for label in [metaLabel, channelMetaLabel, likeCountLabel, dislikeCountLabel] {
            label.textColor = theme.secondaryText
        }
        descriptionButton.setTitleColor(theme.secondaryText, for: .normal)
        applyDescriptionText()
    }

    /// Reaches every surface that can show a comment, including the panel
    /// (open or not — it may be off-screen but attached, or entirely
    /// detached) and the table's cells. Cells read `ThemeManager.shared` at
    /// `configure(_:linkDelegate:)` time (see `CommentContentView`), so a
    /// `reloadData()` here is enough to repaint both the currently visible
    /// rows and any already-dequeued ones the next time they're reused.
    private func applyThemeToComments(_ theme: ThemeManager) {
        // The fill lives on `commentsPreviewCard`, not on the stack view —
        // a stack view ignores `backgroundColor` before iOS 14.
        // The card parts from the page by its tone step alone, never an
        // outline (Ardvis theming, Flat).
        commentsPreviewCard.backgroundColor = theme.surface
        commentPreviewContentView.applyTheme()
        commentsPanel.applyTheme(theme)
        loadedQueuePanel?.applyTheme(theme)
        commentsTableView.reloadData()
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        scrollView.backgroundColor = theme.background
        contentView.backgroundColor = theme.background
        relatedCollectionView.backgroundColor = theme.background
        sidebarContainer.backgroundColor = theme.background
        applyThemeToText(theme)
        applyThemeToComments(theme)
        for btn in [likeButton, dislikeButton, shareButton, saveButton, downloadButton] {
            btn.tintColor = theme.primaryText
        }
        playerContainer.backgroundColor = .black
        playerStatusLabel.textColor = theme.secondaryText
        applyThemeToSubscribeButton()
        if isViewLoaded, navigationController != nil {
            setupNavigationBar()
        }
        updateLikeDislikeUI()
        // The fills that mark a liked or saved video take the theme's
        // selection colour, so they are set again too.
        updateSaveButton()
        updateDownloadButton()
    }

    func applyThemeToSubscribeButton() {
        let theme = ThemeManager.shared
        // State-driven, not title-driven: the title is localized (and may
        // even be server-provided text).
        if isSubscribed {
            subscribeButton.backgroundColor = theme.surface
            subscribeButton.setTitleColor(theme.primaryText, for: .normal)
        } else {
            subscribeButton.backgroundColor = theme.accent
            subscribeButton.setTitleColor(theme.accentText, for: .normal)
        }
    }

    // MARK: - Description

    func updateDescriptionUI() {
        let hasDesc = !descriptionText.isEmpty
        descriptionLabel.isHidden = !descriptionExpanded
        channelTopToMeta?.isActive = !descriptionExpanded
        channelTopToDesc?.isActive = descriptionExpanded
        descriptionButton.isHidden = !hasDesc
        descriptionButton.setTitle(
            descriptionExpanded
                ? "player.description.less".localized
                : "player.description.more".localized,
            for: .normal
        )
        view.setNeedsLayout()
    }

    /// The text fades while the rows below it slide, rather than jumping.
    @objc
    func toggleDescription() {
        view.layoutIfNeeded()
        descriptionExpanded.toggle()
        let expanding = descriptionExpanded
        updateDescriptionUI()
        descriptionLabel.isHidden = false
        descriptionLabel.alpha = expanding ? 0 : 1
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.descriptionLabel.alpha = expanding ? 1 : 0
                self.view.layoutIfNeeded()
            },
            completion: { finished in
                // A second tap mid-animation finishes the job instead.
                guard finished else {
                    return
                }
                self.descriptionLabel.isHidden = !self.descriptionExpanded
                self.descriptionLabel.alpha = 1
            }
        )
    }

    // MARK: - Like / Dislike

    /// The chosen thumb shows on the selection fill and its count steps up
    /// from secondary to primary text.
    func updateLikeDislikeUI() {
        let theme = ThemeManager.shared
        let liked = currentLikeStatus == .like
        let disliked = currentLikeStatus == .dislike
        likeButton.setOnState(liked, cornerRadius: 14)
        likeCountLabel.textColor = liked ? theme.primaryText : theme.secondaryText
        dislikeButton.setOnState(disliked, cornerRadius: 14)
        dislikeCountLabel.textColor = disliked
            ? theme.primaryText : theme.secondaryText
    }

    func handleLikeToggleResult(
        _ result: Result<Void, Error>,
        videoId: String,
        wasLiked: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            let label = wasLiked
                ? "removeLike" : "sendLike"
            switch result {
            case .success:
                AppLog.player("\(label) success for \(videoId)")
                let rydVal = wasLiked ? 0 : 1
                if ReturnYouTubeDislikeService.enabled {
                    ReturnYouTubeDislikeService.shared
                        .reportVote(
                            videoId: videoId,
                            value: rydVal
                        )
                }
            case let .failure(error):
                AppLog.player(
                    "\(label) failed for \(videoId): \(error)"
                )
                let revert: LikeStatus = wasLiked
                    ? .like : .indifferent
                self?.currentLikeStatus = revert
                self?.updateLikeDislikeUI()
            }
        }
    }

    func handleDislikeToggleResult(
        _ result: Result<Void, Error>,
        videoId: String,
        wasDisliked: Bool
    ) {
        DispatchQueue.main.async {
            let label = wasDisliked
                ? "removeDislike" : "sendDislike"
            switch result {
            case .success:
                AppLog.player("\(label) success for \(videoId)")
                let rydVal = wasDisliked ? 0 : -1
                if ReturnYouTubeDislikeService.enabled {
                    ReturnYouTubeDislikeService.shared
                        .reportVote(
                            videoId: videoId,
                            value: rydVal
                        )
                }
            case let .failure(error):
                AppLog.player(
                    "\(label) failed for \(videoId): \(error)"
                )
            }
        }
    }
}
