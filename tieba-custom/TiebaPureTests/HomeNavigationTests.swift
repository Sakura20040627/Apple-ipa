import XCTest
import UIKit
@testable import TiebaPure

final class HomeNavigationTests: XCTestCase {
    @MainActor
    func testHomeReselectIsHandledBeforeNativeNavigationCanChange() {
        let tabBar = UITabBarController()
        let home = UIViewController()
        let forums = UIViewController()
        tabBar.viewControllers = [home, forums]
        tabBar.selectedViewController = home
        let nativeDelegate = RecordingTabDelegate()
        tabBar.delegate = nativeDelegate
        var reselectCount = 0
        let observer = TabSelectionObserver.Coordinator { reselectCount += 1 }
        observer.attach(to: tabBar)

        XCTAssertFalse(observer.tabBarController(tabBar, shouldSelect: home))
        XCTAssertEqual(reselectCount, 1, "Handle the tap synchronously before navigation changes")
        XCTAssertEqual(nativeDelegate.selectionCount, 0, "Native reselection must not also pop or scroll")
        XCTAssertTrue(tabBar.selectedViewController === home)
    }

    @MainActor
    func testSwitchingTabsPreservesNativeSelectionAndVeto() {
        let tabBar = UITabBarController()
        let home = UIViewController()
        let forums = UIViewController()
        tabBar.viewControllers = [home, forums]
        tabBar.selectedViewController = forums
        let nativeDelegate = RecordingTabDelegate()
        tabBar.delegate = nativeDelegate
        var reselectCount = 0
        let observer = TabSelectionObserver.Coordinator { reselectCount += 1 }
        observer.attach(to: tabBar)

        XCTAssertTrue(observer.tabBarController(tabBar, shouldSelect: home))
        nativeDelegate.permitsSelection = false
        XCTAssertFalse(observer.tabBarController(tabBar, shouldSelect: home))
        XCTAssertEqual(nativeDelegate.selectionCount, 2)
        XCTAssertEqual(reselectCount, 0, "Returning from another tab must not refresh Home")
        observer.tabBarController(tabBar, didSelect: home)
        XCTAssertTrue(nativeDelegate.lastSelectedController === home)
        observer.detach()
        XCTAssertTrue(tabBar.delegate === nativeDelegate)
    }

    func testBackFromForumThreadKeepsForumAsCurrentRoute() {
        let threadA = ReaderSplitThreadRoute(threadID: 101, forumID: 7)
        let threadB = ReaderSplitThreadRoute(threadID: 202, forumID: 7)
        let forum = Forum(
            id: 7,
            name: "test",
            displayName: "test forum",
            avatarURL: nil,
            memberCount: 0,
            threadCount: 0
        )

        var path: [HomeNavigationRoute] = [.thread(threadA)]
        path = HomeNavigationPathPolicy.pushing(.fromForum(forum), onto: path)
        path = HomeNavigationPathPolicy.pushing(.thread(threadB), onto: path)

        path = HomeNavigationPathPolicy.removingCurrent(.thread(threadB), from: path)

        XCTAssertEqual(path, [.thread(threadA), .fromForum(forum)])
    }

    func testStaleRouteRemovalDoesNotPopAnotherLayer() {
        let threadA = ReaderSplitThreadRoute(threadID: 101, forumID: 7)
        let threadB = ReaderSplitThreadRoute(threadID: 202, forumID: 7)
        let path: [HomeNavigationRoute] = [.thread(threadA), .thread(threadB)]

        XCTAssertEqual(
            HomeNavigationPathPolicy.removingCurrent(.thread(threadA), from: path),
            path
        )
    }

    func testUserOpenedFromThreadIsOwnedByTheSameTypedPath() {
        let thread = ReaderSplitThreadRoute(threadID: 101, forumID: 7)
        let user = UserSummary(
            id: 9,
            name: "user",
            displayName: "User",
            portrait: ""
        )
        var path: [HomeNavigationRoute] = [.thread(thread)]

        path = HomeNavigationPathPolicy.pushing(
            .user(user: user, sourceThreadID: thread.threadID),
            onto: path
        )

        XCTAssertEqual(
            HomeNavigationPathPolicy.removingCurrent(path.last!, from: path),
            [.thread(thread)]
        )
    }

    func testInheritedReaderHandlerDoesNotEscapeCompactLocalStack() {
        XCTAssertEqual(
            ForumThreadsOpenRoutingPolicy.destination(
                hasExplicitParentHandler: false,
                hasReaderSplitHandler: true,
                isReaderSplitListColumn: false
            ),
            .localStack
        )
        XCTAssertEqual(
            ForumThreadsOpenRoutingPolicy.destination(
                hasExplicitParentHandler: true,
                hasReaderSplitHandler: true,
                isReaderSplitListColumn: false
            ),
            .parentReader
        )
        XCTAssertEqual(
            ForumThreadsOpenRoutingPolicy.destination(
                hasExplicitParentHandler: false,
                hasReaderSplitHandler: true,
                isReaderSplitListColumn: true
            ),
            .parentReader
        )
    }
}

@MainActor
private final class RecordingTabDelegate: NSObject, UITabBarControllerDelegate {
    var permitsSelection = true
    var selectionCount = 0
    var lastSelectedController: UIViewController?

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        selectionCount += 1
        return permitsSelection
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        lastSelectedController = viewController
    }
}

final class FollowingFeedRegressionTests: XCTestCase {
    private func user(_ id: Int64) -> UserSummary {
        UserSummary(id: id, name: "user", displayName: "user", portrait: "")
    }

    @MainActor
    func testFastUserAppearsBeforeSlowUserAndFailuresDoNotDiscardPosts() async throws {
        let fast = user(1)
        let slow = user(2)
        let broken = user(3)
        let post = ThreadSummary(id: 11, title: "test", author: user(0), replyCount: 0, viewCount: 0, blocks: [])
        var slowFinished = false
        var publishedBeforeSlowFinished = false
        var visible: [ThreadSummary] = []
        let results = try await FollowingFeedLoader.load(users: [slow, broken, fast], nextPages: [2: 3], fetch: { id, page in
            if id == 3 { throw URLError(.cannotConnectToHost) }
            if id == 2 {
                XCTAssertEqual(page, 3)
                try await Task.sleep(nanoseconds: 200_000_000)
                slowFinished = true
            }
            return UserThreadsPage(threads: id == 1 ? [post] : [], currentPage: page, hasMore: false, visibility: .visible)
        }, onPage: { posts in
            if posts.isEmpty == false {
                publishedBeforeSlowFinished = slowFinished == false
                visible.append(contentsOf: posts)
            }
        })
        XCTAssertTrue(publishedBeforeSlowFinished)
        XCTAssertEqual(visible.map(\.id), [11])
        XCTAssertEqual(visible.first?.author.id, 1, "Profile identity repairs omitted author IDs")
        XCTAssertEqual(results.filter { $0.error != nil }.count, 1)
    }

    func testTimeoutStopsAStalledRead() async {
        do {
            let _: Int = try await FollowingFeedTimeout.run(seconds: 0.02) {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return 1
            }
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }

    @MainActor
    func testCancelledReadDoesNotPublishOrBecomeAnEmptySuccess() async {
        var published = false
        let users = [user(1)]
        let task = Task {
            try await FollowingFeedLoader.load(users: users, nextPages: [:], fetch: { _, page in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return UserThreadsPage(threads: [], currentPage: page, hasMore: false, visibility: .visible)
            }, onPage: { _ in published = true })
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(published)
    }
}
