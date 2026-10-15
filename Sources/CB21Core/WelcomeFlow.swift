/// Which page of the Welcome window is showing, and whether the user is done with it.
/// Pure state: the window draws it and the app saves `welcomeCompleted` once `isFinished` turns true.
public struct WelcomeFlow: Sendable, Equatable {
    public enum Page: Int, CaseIterable, Sendable {
        case welcome, clipboard, login, shortcuts, privacy
    }

    /// Which way the last move went, so the window can slide pages the right way.
    public enum Move: Sendable, Equatable {
        case none, forward, backward
    }

    public private(set) var page: Page
    public private(set) var lastMove: Move = .none
    public private(set) var isFinished = false
    public private(set) var skippedPages: Set<Page> = []

    public init(page: Page = .welcome) {
        self.page = page
    }

    public var isFirstPage: Bool { page == Page.allCases.first }
    public var isLastPage: Bool { page == Page.allCases.last }
    public var pageCount: Int { Page.allCases.count }
    public var pageNumber: Int { page.rawValue + 1 }
    public var progress: Double { Double(pageNumber) / Double(pageCount) }

    public mutating func next() {
        guard !isFinished else { return }
        if isLastPage {
            isFinished = true
        } else if let following = Page(rawValue: page.rawValue + 1) {
            page = following
            lastMove = .forward
        }
    }

    public mutating func back() {
        guard !isFinished, let previous = Page(rawValue: page.rawValue - 1) else { return }
        page = previous
        lastMove = .backward
    }

    /// Moves on without doing what this page offers.
    public mutating func skipPage() {
        guard !isFinished else { return }
        skippedPages.insert(page)
        next()
    }

    /// The window was closed at any step. The Welcome counts as done.
    public mutating func close() {
        isFinished = true
    }
}
