import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var contentSubmissionSettingsStore: ContentSubmissionSettingsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.readingPreferences) private var readingPreferences
    let account: Account?
    var refreshToken: Int = 0

    @ObservedObject private var blocklistStore = BlocklistStore.shared
    @State private var activeSearch: SearchRoute?
    @State private var threads: [ThreadSummary] = []
    @State private var forumMetadataByName: [String: Forum] = [:]
    @State private var loadingForumNames: Set<String> = []
    @State private var followingUsers: [UserSummary] = []
    @State private var remainingUserIDs: Set<Int64> = []
    @State private var userNextPages: [Int64: Int] = [:]
    @State private var page = 1
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var navigationPath: [HomeNavigationRoute] = []
    @State private var programmaticRefreshToken = 0
    @State private var lastScenePhase: ScenePhase = .inactive
    @State private var scrollToTopRequest = 0
    @State private var requestGeneration = 0
    @State private var loadTask: Task<FollowingFeedBatch, Error>?
    @State private var pendingPaginationRequest = false
    @State private var paginationRequestScheduled = false
    @State private var splitDetailPath: [ReaderSplitThreadRoute] = []
    @State private var homeLikeOperationIDs: [Int64: UUID] = [:]
    @State private var homeLikeTasks: [Int64: Task<Void, Never>] = [:]
    @State private var likeActionError: String?

    var body: some View {
        ReaderSplitLayout(
            account: account,
            navigationPath: $navigationPath,
            detailPath: $splitDetailPath,
            openThreadInDetail: { openThreadInSplitDetail($0) },
            openThreadInCompact: { openThreadInCompactStack($0) },
            listColumn: { feedColumn },
            detailRoot: { placeholder in
                // Regular width routes global search into the detail column so
                // the feed list stays visible and drivable next to it.
                placeholder
                    .navigationDestination(isPresented: splitSearchIsActive) {
                        if let activeSearch {
                            SearchResultsView(account: account, scope: .global, initialKeyword: activeSearch.keyword)
                                .interactiveNavigationPopStateSync {
                                    self.activeSearch = nil
                                }
                        }
                    }
            }
        )
        .toolbar(.visible, for: .tabBar)
        .onChange(of: horizontalSizeClass) { sizeClass in
            foldNavigationForSizeClassChange(to: sizeClass)
        }
        .onChange(of: refreshToken) { _ in
            // Observe outside the feed's navigation destination so reselecting
            // Home also works while a detail or search view covers the list.
            if navigationPath.isEmpty == false || activeSearch != nil
                || splitDetailPath.isEmpty == false {
                navigationPath = []
                activeSearch = nil
                splitDetailPath = []
                return
            }
            // Returning to the top must still work during an existing refresh;
            // the refresh modifier separately coalesces duplicate requests.
            scrollToTopRequest &+= 1
            programmaticRefreshToken &+= 1
        }
        .alert("提示", isPresented: likeActionErrorIsPresented) {
            Button("好", role: .cancel) { likeActionError = nil }
        } message: {
            Text(likeActionError ?? "")
        }
    }

    private var feedColumn: some View {
        ScrollViewReader { scrollProxy in
            refreshableScrollView {
                feedContent
            }
            .onChange(of: scrollToTopRequest) { _ in
                // Feed changes during an animated scroll-to-top can make the
                // lazy layout update endlessly on iOS 26. Finish the jump in
                // a transaction that cannot inherit the refresh animation.
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollProxy.scrollTo(HomeScrollTarget.top, anchor: .top)
                }
            }
        }
        .navigationTitle("关注")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSearch = SearchRoute(keyword: "")
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .minTouchTarget()
                .accessibilityLabel("搜索")
                .accessibilityHint("打开单独的搜索页面")
                .accessibilityIdentifier("home-search-button")
            }
        }
        .navigationDestination(isPresented: searchIsActive) {
            if let activeSearch {
                SearchResultsView(account: account, scope: .global, initialKeyword: activeSearch.keyword)
                    .interactiveNavigationPopStateSync {
                        self.activeSearch = nil
                    }
            }
        }
        .navigationDestination(for: HomeNavigationRoute.self) { route in
            switch route {
            case let .thread(threadRoute):
                ThreadDetailView(
                    account: account,
                    threadID: threadRoute.threadID,
                    forumID: threadRoute.forumID,
                    initialPostID: threadRoute.initialPostID,
                    initialDestination: threadRoute.initialDestination,
                    ownThreadDeletionTarget: threadRoute.ownThreadDeletionTarget,
                    mainPostFallback: threadRoute.mainPostFallback,
                    openUserInParent: { user in
                        openUser(user, sourceThreadID: threadRoute.threadID)
                    },
                    openForumInParent: openForum
                )
                .interactiveNavigationPopStateSync {
                    removeNavigationRouteIfCurrent(route)
                }
            case let .forum(id, name, displayName, avatarURL):
                ForumThreadsView(
                    account: account,
                    forum: Forum(
                        id: id,
                        name: name,
                        displayName: displayName,
                        avatarURL: avatarURL,
                        memberCount: 0,
                        threadCount: 0
                    ),
                    openThreadInParent: { route in
                        openThreadFromNestedForum(route)
                    },
                    openUserInParent: { user in
                        openUser(user, sourceThreadID: nil)
                    }
                )
                .interactiveNavigationPopStateSync {
                    removeNavigationRouteIfCurrent(route)
                }
            case let .user(user, sourceThreadID):
                UserProfileView(
                    account: account,
                    user: user,
                    sourceThreadID: sourceThreadID,
                    onReturnToSourceThread: {
                        removeNavigationRouteIfCurrent(route)
                    },
                    openThreadInParent: openThreadFromNestedForum,
                    openForumInParent: openForum
                )
                .interactiveNavigationPopStateSync {
                    removeNavigationRouteIfCurrent(route)
                }
            }
        }
        .interactiveNavigationPopRevealSource()
        .task {
            guard didLoad == false else { return }
            await reload()
        }
        .onChange(of: account?.sessionIdentity) { _ in
            cancelHomeLikeTasks()
            requestGeneration += 1
            loadTask?.cancel()
            threads = []
            page = 1
            hasMore = true
            didLoad = false
            isLoading = false
            pendingPaginationRequest = false
            paginationRequestScheduled = false
            errorMessage = nil
            navigationPath = []
            splitDetailPath = []
            Task { await reload() }
        }
        .onChange(of: blocklistStore.entries) { _ in
            threads.removeAll { TiebaContentFilter.shouldKeep(thread: $0) == false }
        }
        .onChange(of: scenePhase) { newPhase in
            let previousPhase = lastScenePhase
            lastScenePhase = newPhase
            guard HomeOpenRefreshPolicy.shouldRefreshOnScenePhaseChange(
                from: previousPhase,
                to: newPhase,
                didLoad: didLoad
            ) else {
                return
            }
            Task { await reload() }
        }
        .onDisappear {
            loadTask?.cancel()
            requestGeneration += 1
            isLoading = false
            pendingPaginationRequest = false
            paginationRequestScheduled = false
        }
    }

    private var usesSplitDetailLayout: Bool {
        horizontalSizeClass == .regular
    }

    // Search presents in exactly one column per layout: the feed stack when
    // compact, the detail column when the split layout is active.
    private var searchIsActive: Binding<Bool> {
        Binding(
            get: { usesSplitDetailLayout == false && activeSearch != nil },
            set: { isActive in
                if isActive == false {
                    activeSearch = nil
                }
            }
        )
    }

    private var splitSearchIsActive: Binding<Bool> {
        Binding(
            get: { usesSplitDetailLayout && activeSearch != nil },
            set: { isActive in
                if isActive == false {
                    activeSearch = nil
                }
            }
        )
    }

    private func removeNavigationRouteIfCurrent(_ route: HomeNavigationRoute) {
        navigationPath = HomeNavigationPathPolicy.removingCurrent(
            route,
            from: navigationPath
        )
    }

    private func openThread(
        _ thread: ThreadSummary,
        initialDestination: ThreadDetailInitialDestination? = nil
    ) {
        let route = ReaderSplitThreadRoute(
            threadID: thread.id,
            forumID: thread.forumID,
            initialDestination: initialDestination,
            mainPostFallback: ThreadMainPostFallback(thread: thread)
        )
        if usesSplitDetailLayout {
            openThreadInSplitDetail(route)
            return
        }
        navigationPath = HomeNavigationPathPolicy.pushing(
            .thread(route),
            onto: navigationPath
        )
    }

    private func openThreadInSplitDetail(_ route: ReaderSplitThreadRoute) {
        // A newly selected thread owns the whole detail column; a search page
        // pushed there would otherwise keep covering the new selection.
        activeSearch = nil
        splitDetailPath = [route]
    }

    private func openThreadInCompactStack(_ route: ReaderSplitThreadRoute) {
        navigationPath = HomeNavigationPathPolicy.pushing(
            .thread(route),
            onto: navigationPath
        )
    }

    private func openThreadFromNestedForum(_ route: ReaderSplitThreadRoute) {
        if usesSplitDetailLayout {
            openThreadInSplitDetail(route)
        } else {
            openThreadInCompactStack(route)
        }
    }

    private func openForum(_ forum: Forum) {
        RecentForumStore.shared.save(forum)
        navigationPath = HomeNavigationPathPolicy.pushing(
            .fromForum(forum),
            onto: navigationPath
        )
    }

    private func openUser(_ user: UserSummary, sourceThreadID: Int64?) {
        navigationPath = HomeNavigationPathPolicy.pushing(
            .user(user: user, sourceThreadID: sourceThreadID),
            onto: navigationPath
        )
    }

    /// Keeps the open thread when the split layout appears or collapses
    /// mid-session (e.g. iPad Split View resizes across the width threshold).
    private func foldNavigationForSizeClassChange(to sizeClass: UserInterfaceSizeClass?) {
        let bridged = HomeSplitDetailBridgePolicy.state(
            changingTo: sizeClass,
            navigationPath: navigationPath,
            splitDetail: splitDetailPath.last
        )
        navigationPath = bridged.navigationPath
        splitDetailPath = bridged.splitDetail.map { [$0] } ?? []
    }

    @ViewBuilder
    private var feedContent: some View {
        Color.clear
            .frame(height: 0)
            .id(HomeScrollTarget.top)

        if isLoading && didLoad == false && threads.isEmpty {
            ReaderStateView.loading("正在加载帖子")
        } else if let errorMessage, threads.isEmpty {
            ReaderStateView.error(message: errorMessage) {
                Task { await reload() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, TiebaPureTheme.Spacing.lg)
        } else if threads.isEmpty {
            ReaderStateView.empty(
                title: account == nil ? "登录后查看关注动态" : "暂无关注动态",
                message: account == nil ? "请前往“我的”登录贴吧账号。" : "关注用户发布的可见帖子会显示在这里，下拉即可刷新。",
                actionTitle: hasMore && didLoad ? "继续加载" : nil,
                action: hasMore && didLoad ? { Task { await loadMore() } } : nil
            )
            .frame(maxWidth: .infinity)
            .padding(.top, TiebaPureTheme.Spacing.lg)
        } else {
            LazyVStack(spacing: TiebaPureTheme.Spacing.sm, pinnedViews: []) {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    ForumThreadRow(
                        thread: threadWithForumMetadata(thread),
                        presentation: .homeFeed,
                        onOpenThread: {
                            openThread(thread)
                        },
                        onOpenForum: { forum in
                            openForum(forum)
                        },
                        onOpenUser: { openUser($0, sourceThreadID: nil) },
                        onBlockForum: { blockedThread in
                            blocklistStore.addForum(
                                id: blockedThread.forumID,
                                named: blockedThread.forumName
                            )
                        },
                        onOpenMedia: { item, mediaItems, sourceFrame, sourceImage, sourceAnchor in
                            switch HomeMediaActionPolicy.action(for: item, in: mediaItems) {
                            case let .previewImages(images, index):
                                ImagePreviewCoordinator.shared.present(
                                    ImagePreviewSession(
                                        images: images,
                                        initialIndex: index,
                                        sourceFrame: sourceFrame,
                                        sourceImage: sourceImage,
                                        sourceAnchor: sourceAnchor,
                                        prefetchesAdjacentPages: readingPreferences.mediaLoading != .manual
                                    )
                                )
                            case let .playVideo(video):
                                VideoPreviewCoordinator.shared.present(
                                    VideoPreviewSession(
                                        video: video,
                                        sourceFrame: sourceFrame,
                                        sourceImage: sourceImage,
                                        sourceAnchor: sourceAnchor
                                    )
                                )
                            case .openThread:
                                openThread(thread)
                            }
                        },
                        onOpenComments: {
                            openThread(
                                thread,
                                initialDestination: .replies
                            )
                        },
                        isLikeUpdating: homeLikeOperationIDs[thread.id] != nil,
                        onToggleLike: contentSubmissionSettingsStore.likesEnabled
                            && thread.firstPostID != nil
                            ? { toggleHomeThreadLike(thread) }
                            : nil,
                        commentsAccessibilityIdentifier: "home-comments-button-\(thread.id)",
                        likesAccessibilityIdentifier: "home-like-button-\(thread.id)"
                    )
                    .task(id: thread.forumName) {
                        await loadForumMetadata(for: thread)
                    }
                    .onAppear {
                        requestLoadMoreIfNeeded(currentIndex: index, totalCount: threads.count)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("thread-row")

                    if index == threads.count - 1, isLoading, didLoad {
                        ProgressView()
                            .padding(TiebaPureTheme.Spacing.md)
                            .accessibilityLabel("正在加载更多帖子")
                    }
                }

                if let errorMessage {
                    InlineLoadErrorView(message: errorMessage) {
                        Task {
                            if page <= 1 { await reload() }
                            else {
                                self.errorMessage = nil
                                await loadMore()
                            }
                        }
                    }
                } else if hasMore, isLoading == false, didLoad {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Label("加载更多", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .minTouchTarget()
                    .accessibilityHint("加载下一页推荐帖子")
                    .padding(.horizontal, TiebaPureTheme.Spacing.md)
                }

                Color.clear
                    .frame(height: 64)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, TiebaPureTheme.Spacing.sm)
            .padding(.vertical, TiebaPureTheme.Spacing.sm)
            .readableWidth()
        }
    }

    private var likeActionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { likeActionError != nil },
            set: { isPresented in
                if isPresented == false { likeActionError = nil }
            }
        )
    }

    private func toggleHomeThreadLike(_ thread: ThreadSummary) {
        guard contentSubmissionSettingsStore.likesEnabled else { return }
        guard homeLikeOperationIDs[thread.id] == nil else { return }
        guard let account else {
            likeActionError = "登录后才能点赞。"
            return
        }
        guard let postID = thread.firstPostID, postID > 0 else {
            likeActionError = "暂时无法获取该帖的点赞信息。"
            return
        }

        let operationID = UUID()
        let requestedSession = account.sessionIdentity
        let targetState = thread.isLiked == false
        homeLikeOperationIDs[thread.id] = operationID
        likeActionError = nil

        let task = Task {
            do {
                try await environment.socialMutationCoordinator.setPostLiked(
                    account: account,
                    threadID: thread.id,
                    postID: postID,
                    objectType: .thread,
                    liked: targetState
                )
                try Task.checkCancellation()
                guard homeLikeOperationIDs[thread.id] == operationID,
                      self.account?.sessionIdentity == requestedSession else {
                    throw CancellationError()
                }
                applyHomeThreadLikeState(threadID: thread.id, liked: targetState)
            } catch is CancellationError {
                // The coordinator owns an already-started write. This view
                // only stops stale presentation updates.
            } catch {
                guard Task.isCancelled == false,
                      homeLikeOperationIDs[thread.id] == operationID,
                      self.account?.sessionIdentity == requestedSession else {
                    finishHomeLikeOperation(threadID: thread.id, operationID: operationID)
                    return
                }
                likeActionError = ReaderErrorMessage.message(for: error)
            }
            finishHomeLikeOperation(threadID: thread.id, operationID: operationID)
        }
        homeLikeTasks[thread.id] = task
    }

    private func applyHomeThreadLikeState(threadID: Int64, liked: Bool) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }),
              threads[index].isLiked != liked else { return }
        threads[index].isLiked = liked
        let delta = liked ? 1 : -1
        threads[index].likeCount = max(threads[index].likeCount + delta, 0)
    }

    private func finishHomeLikeOperation(threadID: Int64, operationID: UUID) {
        guard homeLikeOperationIDs[threadID] == operationID else { return }
        homeLikeOperationIDs[threadID] = nil
        homeLikeTasks[threadID] = nil
    }

    private func cancelHomeLikeTasks() {
        homeLikeTasks.values.forEach { $0.cancel() }
        homeLikeTasks.removeAll()
        homeLikeOperationIDs.removeAll()
    }

    @ViewBuilder
    private func refreshableScrollView<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .accessibilityIdentifier("home-feed-scroll-view")
        .shortPullRefresh(
            isEnabled: didLoad && isLoading == false,
            surface: .grouped,
            accessibilityIdentifier: "home-refresh-animation",
            programmaticRefreshToken: programmaticRefreshToken
        ) { source in
            if source == .pullGesture {
                guard isLoading == false else { return }
            }
            await reload()
        }
        .background(TiebaPureTheme.ColorToken.readerGroupedBackground)
    }

    private func threadWithForumMetadata(_ thread: ThreadSummary) -> ThreadSummary {
        guard let name = thread.forumName,
              let forum = forumMetadataByName[name] else { return thread }
        var result = thread
        result.forumAvatarURL = thread.forumAvatarURL ?? forum.avatarURL
        if result.forumID == nil { result.forumID = forum.id }
        return result
    }

    private func loadForumMetadata(for thread: ThreadSummary) async {
        guard thread.forumAvatarURL == nil, let name = thread.forumName,
              forumMetadataByName[name] == nil,
              loadingForumNames.contains(name) == false else { return }
        // Recent forums already carry the same service-provided avatar URL.
        if let cached = RecentForumStore.shared.items.first(where: { $0.forum.name == name })?.forum,
           cached.avatarURL != nil {
            forumMetadataByName[name] = cached
            return
        }
        loadingForumNames.insert(name)
        defer { loadingForumNames.remove(name) }
        do {
            let forum = try await FollowingFeedTimeout.run {
                try await environment.api.forumMetadata(named: name)
            }
            try Task.checkCancellation()
            if let forum, forum.avatarURL != nil {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { forumMetadataByName[name] = forum }
            }
        } catch {
            // Avatar failure never blocks reading or refreshing posts. A later
            // appearance can retry; successful metadata is cached by forum.
        }
    }

    private func reload() async {
        loadTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = false
        pendingPaginationRequest = false
        paginationRequestScheduled = false
        page = 1
        hasMore = true
        errorMessage = nil
        await loadMore(generation: generation)
    }

    private func loadMore() async {
        await loadMore(generation: requestGeneration)
    }

    private func loadMore(
        generation: Int,
        consecutiveHiddenPageCount: Int = 0
    ) async {
        guard hasMore else {
            pendingPaginationRequest = false
            return
        }
        guard errorMessage == nil else {
            pendingPaginationRequest = false
            return
        }
        guard isLoading == false else {
            pendingPaginationRequest = true
            return
        }
        let requestedSession = account?.sessionIdentity
        isLoading = true
        errorMessage = nil
        var continuation: LocallyFilteredPaginationDecision?

        do {
            let requestedPage = page
            let cachedUsers = followingUsers
            let remainingIDs = remainingUserIDs
            let cachedPages = userNextPages
            let streamsInitialLoad = threads.isEmpty && requestedPage == 1
            let task = Task {
                guard let account else {
                    return FollowingFeedBatch(users: [], threads: [], remainingUserIDs: [], nextPages: [:], failureCount: 0)
                }
                var users = cachedUsers
                if requestedPage == 1 {
                    users = []
                    var relationshipPage = 1
                    var seen = Set<Int64>()
                    while true {
                        try Task.checkCancellation()
                        let currentPage = relationshipPage
                        let result = try await FollowingFeedTimeout.run {
                            try await environment.api.followedUsers(account: account, page: currentPage)
                        }
                        let fresh = result.users.filter { $0.id > 0 && seen.insert($0.id).inserted }
                        users.append(contentsOf: fresh)
                        if result.hasMore == false { break }
                        guard fresh.isEmpty == false else {
                            throw FollowingFeedError.paginationDidNotAdvance
                        }
                        relationshipPage += 1
                    }
                }
                var posts: [ThreadSummary] = []
                var nextIDs = Set<Int64>()
                var nextPages: [Int64: Int] = [:]
                var failures = 0
                var replacedRefresh = false
                let candidates = users.filter { requestedPage == 1 || remainingIDs.contains($0.id) }
                // Four concurrent readers; each completion immediately becomes visible.
                for offset in stride(from: 0, to: candidates.count, by: 4) {
                    try Task.checkCancellation()
                    let chunk = Array(candidates[offset..<min(offset + 4, candidates.count)])
                    let results = try await FollowingFeedLoader.load(
                        users: chunk,
                        nextPages: requestedPage == 1 ? [:] : cachedPages,
                        fetch: { userID, userPage in
                            try await FollowingFeedTimeout.run {
                                try await environment.api.userThreads(account: account, userID: userID, page: userPage)
                            }
                        },
                        onPage: { incoming in
                            guard streamsInitialLoad, generation == requestGeneration,
                                  requestedSession == self.account?.sessionIdentity else { return }
                            guard incoming.isEmpty == false else { return }
                            if requestedPage == 1 && replacedRefresh == false {
                                threads = []
                                replacedRefresh = true
                            }
                            let visible = incoming.filter(TiebaContentFilter.shouldKeep(thread:))
                            threads = HomeFeedMerge.append(existing: threads, incoming: visible, maximumItemCount: Int.max)
                            threads = FollowingFeedLoader.sorted(threads)
                            if threads.isEmpty == false { didLoad = true }
                        }
                    )
                    for result in results {
                        if result.error != nil {
                            failures += 1
                            nextIDs.insert(result.user.id)
                            nextPages[result.user.id] = result.requestedPage
                            continue
                        }
                        guard let userPage = result.page else { continue }
                        posts.append(contentsOf: result.threads)
                        if userPage.visibility == .visible && userPage.hasMore {
                            nextIDs.insert(result.user.id)
                            nextPages[result.user.id] = result.requestedPage + 1
                        }
                    }
                }
                return FollowingFeedBatch(users: users, threads: posts, remainingUserIDs: nextIDs,
                                          nextPages: nextPages, failureCount: failures)
            }
            loadTask = task
            let batch = try await task.value
            let next = batch.threads
            guard generation == requestGeneration,
                  requestedSession == account?.sessionIdentity else { return }
            followingUsers = batch.users
            remainingUserIDs = batch.remainingUserIDs
            userNextPages = batch.nextPages
            let visibleNext = next.filter(TiebaContentFilter.shouldKeep(thread:))
            // Refresh commits once. Keep old rows in place until the complete
            // snapshot is ready; async completion order must not move the list.
            let merged: [ThreadSummary]
            if requestedPage == 1 {
                merged = batch.failureCount > 0
                    ? HomeFeedMerge.refresh(existing: threads, incoming: visibleNext, maximumItemCount: Int.max)
                    : HomeFeedMerge.append(existing: [], incoming: visibleNext, maximumItemCount: Int.max)
            } else {
                merged = HomeFeedMerge.append(existing: threads, incoming: visibleNext, maximumItemCount: Int.max)
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                threads = FollowingFeedLoader.sorted(merged)
            }
            if batch.failureCount > 0 {
                errorMessage = "有 \(batch.failureCount) 位关注用户的帖子暂时未能加载，已显示其他内容，请重试。"
            }
            hasMore = batch.remainingUserIDs.isEmpty == false
            page = requestedPage + 1
            continuation = LocallyFilteredPaginationPolicy.decision(
                visibleItemCount: visibleNext.count,
                serverHasMore: hasMore,
                consecutiveHiddenPageCount: consecutiveHiddenPageCount
            )
        } catch is CancellationError {
            guard generation == requestGeneration,
                  requestedSession == account?.sessionIdentity else { return }
            loadTask = nil
            isLoading = false
            pendingPaginationRequest = false
            paginationRequestScheduled = false
            return
        } catch {
            guard generation == requestGeneration,
                  requestedSession == account?.sessionIdentity else { return }
            errorMessage = ReaderErrorMessage.message(for: error)
        }
        guard generation == requestGeneration,
              requestedSession == account?.sessionIdentity else { return }
        loadTask = nil
        isLoading = false
        didLoad = true
        if let continuation, continuation.shouldAutomaticallyLoadNextPage {
            await loadMore(
                generation: generation,
                consecutiveHiddenPageCount: continuation.consecutiveHiddenPageCount
            )
            return
        }
        if continuation?.shouldOfferManualContinuation == true {
            // A still-visible footer/empty-state button resumes with a fresh
            // bounded batch instead of turning a queued prefetch into a loop.
            pendingPaginationRequest = false
            return
        }
        let shouldContinuePagination = pendingPaginationRequest
            && hasMore
            && errorMessage == nil
        pendingPaginationRequest = false
        if shouldContinuePagination {
            await loadMore(generation: generation)
        }
    }

    private func requestLoadMoreIfNeeded(currentIndex: Int, totalCount: Int) {
        guard PaginationPrefetchPolicy.shouldLoadMore(
            currentIndex: currentIndex,
            totalCount: totalCount
        ) else { return }
        // Row appearances during refresh must not enqueue another page load.
        guard isLoading == false else { return }
        guard paginationRequestScheduled == false else { return }
        paginationRequestScheduled = true
        Task {
            await loadMore()
            paginationRequestScheduled = false
        }
    }
}

enum HomeRefreshAnimationPolicy {
    static var minimumVisibleDurationNanoseconds: UInt64 {
        minimumVisibleDurationNanoseconds(arguments: ProcessInfo.processInfo.arguments)
    }

    static func minimumVisibleDurationNanoseconds(arguments: [String]) -> UInt64 {
        #if DEBUG
        if arguments.contains("UITEST_EXTENDED_REFRESH_ANIMATION") {
            return 5_000_000_000
        }
        #endif

        return 600_000_000
    }

    static func disablesUITestAnimations(arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains("UITEST_DISABLE_ANIMATIONS")
        #else
        return false
        #endif
    }

    static func remainingVisibleDurationNanoseconds(minimum: UInt64, elapsed: UInt64) -> UInt64 {
        minimum > elapsed ? minimum - elapsed : 0
    }
}

enum HomeOpenRefreshPolicy {
    static func shouldRefreshOnScenePhaseChange(
        from previousPhase: ScenePhase,
        to newPhase: ScenePhase,
        didLoad: Bool
    ) -> Bool {
        didLoad && previousPhase == .background && newPhase == .active
    }
}

private enum HomeScrollTarget {
    case top
}

enum HomeFeedMerge {
    static let maximumItemCount = 300

    static func refresh(
        existing: [ThreadSummary],
        incoming: [ThreadSummary],
        maximumItemCount: Int = HomeFeedMerge.maximumItemCount
    ) -> [ThreadSummary] {
        merge(
            preferred: incoming,
            fallback: existing,
            maximumItemCount: maximumItemCount
        )
    }

    static func append(
        existing: [ThreadSummary],
        incoming: [ThreadSummary],
        maximumItemCount: Int = HomeFeedMerge.maximumItemCount
    ) -> [ThreadSummary] {
        merge(
            preferred: existing,
            fallback: incoming,
            maximumItemCount: maximumItemCount
        )
    }

    private static func merge(
        preferred: [ThreadSummary],
        fallback: [ThreadSummary],
        maximumItemCount: Int
    ) -> [ThreadSummary] {
        let boundedCount = max(maximumItemCount, 0)
        guard boundedCount > 0 else { return [] }
        var seen = Set<Int64>()
        var merged: [ThreadSummary] = []
        merged.reserveCapacity(min(preferred.count + fallback.count, boundedCount))

        for thread in preferred + fallback where seen.insert(thread.id).inserted {
            merged.append(thread)
            if merged.count == boundedCount { break }
        }

        return merged
    }
}

enum HomeMediaAction: Equatable {
    case previewImages([ImageContent], index: Int)
    case playVideo(VideoContent)
    case openThread
}

enum HomeMediaActionPolicy {
    static func action(for item: ReaderMediaItem, in mediaItems: [ReaderMediaItem]) -> HomeMediaAction {
        if let video = item.video {
            return .playVideo(video)
        }
        if let image = item.image {
            let images = mediaItems.compactMap(\.image)
            let resolvedImages = images.isEmpty ? [image] : images
            let index = resolvedImages.firstIndex(of: image) ?? 0
            return .previewImages(resolvedImages, index: index)
        }
        return .openThread
    }

    static func action(for item: ReaderMediaItem) -> HomeMediaAction {
        action(for: item, in: [item])
    }
}

enum HomeNavigationRoute: Hashable {
    case thread(ReaderSplitThreadRoute)
    case forum(id: Int64, name: String, displayName: String, avatarURL: URL?)
    case user(user: UserSummary, sourceThreadID: Int64?)

    static func fromForum(_ forum: Forum) -> HomeNavigationRoute {
        .forum(
            id: forum.id,
            name: forum.name,
            displayName: forum.displayName,
            avatarURL: forum.avatarURL
        )
    }
}

enum HomeNavigationPathPolicy {
    static func pushing(
        _ route: HomeNavigationRoute,
        onto navigationPath: [HomeNavigationRoute]
    ) -> [HomeNavigationRoute] {
        navigationPath + [route]
    }

    static func removingCurrent(
        _ route: HomeNavigationRoute,
        from navigationPath: [HomeNavigationRoute]
    ) -> [HomeNavigationRoute] {
        guard navigationPath.last == route else { return navigationPath }
        return Array(navigationPath.dropLast())
    }
}

struct HomeSplitDetailBridgeState: Equatable {
    var navigationPath: [HomeNavigationRoute]
    var splitDetail: ReaderSplitThreadRoute?
}

enum HomeSplitDetailBridgePolicy {
    static func state(
        changingTo sizeClass: UserInterfaceSizeClass?,
        navigationPath: [HomeNavigationRoute],
        splitDetail: ReaderSplitThreadRoute?
    ) -> HomeSplitDetailBridgeState {
        switch sizeClass {
        case .compact:
            guard let splitDetail else {
                return HomeSplitDetailBridgeState(
                    navigationPath: navigationPath,
                    splitDetail: nil
                )
            }
            return HomeSplitDetailBridgeState(
                navigationPath: navigationPath + [.thread(splitDetail)],
                splitDetail: nil
            )
        case .regular:
            guard case let .thread(compactDetail)? = navigationPath.last else {
                return HomeSplitDetailBridgeState(
                    navigationPath: navigationPath,
                    splitDetail: splitDetail
                )
            }
            return HomeSplitDetailBridgeState(
                navigationPath: Array(navigationPath.dropLast()),
                splitDetail: compactDetail
            )
        default:
            return HomeSplitDetailBridgeState(
                navigationPath: navigationPath,
                splitDetail: splitDetail
            )
        }
    }
}

private struct FollowingFeedBatch {
    var users: [UserSummary]
    var threads: [ThreadSummary]
    var remainingUserIDs: Set<Int64>
    var nextPages: [Int64: Int]
    var failureCount: Int
}

private enum FollowingFeedError: LocalizedError {
    case paginationDidNotAdvance

    var errorDescription: String? {
        "关注名单未能完整加载，请下拉重试。"
    }
}

struct FollowingFeedUserResult {
    let user: UserSummary
    let requestedPage: Int
    let page: UserThreadsPage?
    let error: String?

    var threads: [ThreadSummary] {
        guard let page, page.visibility == .visible else { return [] }
        return page.threads.compactMap { thread in
            // Some profile responses omit the author ID. The requested profile
            // supplies that identity; never discard all of those valid posts.
            guard thread.author.id == 0 || thread.author.id == user.id else { return nil }
            var result = thread
            if result.author.id == 0 { result.author = user }
            return result
        }
    }
}

enum FollowingFeedLoader {
    @MainActor
    static func load(
        users: [UserSummary],
        nextPages: [Int64: Int],
        fetch: @escaping (Int64, Int) async throws -> UserThreadsPage,
        onPage: ([ThreadSummary]) -> Void
    ) async throws -> [FollowingFeedUserResult] {
        try await withThrowingTaskGroup(of: FollowingFeedUserResult.self) { group in
            for user in users {
                let page = nextPages[user.id] ?? 1
                group.addTask {
                    do {
                        let response = try await fetch(user.id, page)
                        try Task.checkCancellation()
                        return FollowingFeedUserResult(user: user, requestedPage: page, page: response, error: nil)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        try Task.checkCancellation()
                        return FollowingFeedUserResult(user: user, requestedPage: page, page: nil, error: error.localizedDescription)
                    }
                }
            }
            var results: [FollowingFeedUserResult] = []
            for try await result in group {
                try Task.checkCancellation()
                onPage(result.threads)
                results.append(result)
            }
            return results
        }
    }

    static func sorted(_ threads: [ThreadSummary]) -> [ThreadSummary] {
        threads.sorted {
            let lhs = $0.createdAt ?? .distantPast
            let rhs = $1.createdAt ?? .distantPast
            return lhs == rhs ? $0.id > $1.id : lhs > rhs
        }
    }
}

enum FollowingFeedTimeout {
    static func run<T: Sendable>(
        seconds: Double = 12,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
    }
}
