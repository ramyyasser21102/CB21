import Testing
@testable import CB21Core

@Test func flowHasTheSixPagesInOrder() {
    #expect(WelcomeFlow.Page.allCases == [.welcome, .clipboard, .files, .login, .shortcuts, .privacy])
}

@Test func flowStartsOnTheWelcomePageNotFinished() {
    let flow = WelcomeFlow()
    #expect(flow.page == .welcome)
    #expect(flow.isFirstPage)
    #expect(!flow.isLastPage)
    #expect(!flow.isFinished)
    #expect(flow.lastMove == .none)
}

@Test func nextWalksForwardThroughEveryPage() {
    var flow = WelcomeFlow()
    var seen = [flow.page]
    while !flow.isLastPage {
        flow.next()
        seen.append(flow.page)
    }
    #expect(seen == WelcomeFlow.Page.allCases)
    #expect(!flow.isFinished)
    #expect(flow.lastMove == .forward)
}

@Test func nextOnTheLastPageFinishesTheFlow() {
    var flow = WelcomeFlow(page: .privacy)
    flow.next()
    #expect(flow.isFinished)
    #expect(flow.page == .privacy)
}

@Test func backGoesToThePreviousPageAndDoesNothingOnTheFirst() {
    var flow = WelcomeFlow(page: .login)
    flow.back()
    #expect(flow.page == .files)
    #expect(flow.lastMove == .backward)
    flow = WelcomeFlow()
    flow.back()
    #expect(flow.page == .welcome)
    #expect(flow.lastMove == .none)
}

@Test func skippingAPageMovesOnAndRemembersWhichWereSkipped() {
    var flow = WelcomeFlow(page: .clipboard)
    flow.skipPage()
    #expect(flow.page == .files)
    flow.next()
    #expect(flow.skippedPages == [.clipboard])
}

@Test func skippingTheLastPageFinishesTheFlow() {
    var flow = WelcomeFlow(page: .privacy)
    flow.skipPage()
    #expect(flow.isFinished)
}

@Test func closingTheWindowAtAnyStepFinishesTheFlow() {
    var flow = WelcomeFlow(page: .login)
    flow.close()
    #expect(flow.isFinished)
}

@Test func progressRunsFromOneSixthToComplete() {
    var flow = WelcomeFlow()
    #expect(abs(flow.progress - 1.0 / 6.0) < 0.0001)
    flow = WelcomeFlow(page: .privacy)
    #expect(flow.progress == 1.0)
    #expect(flow.pageNumber == 6)
    #expect(flow.pageCount == 6)
}

@Test func theFilesPageComesRightAfterClipboardAccessAndCanBeSkipped() {
    var flow = WelcomeFlow(page: .clipboard)
    flow.next()
    #expect(flow.page == .files)
    flow.skipPage()
    #expect(flow.page == .login)
    #expect(flow.skippedPages == [.files])
}

@Test func finishedFlowIgnoresFurtherMoves() {
    var flow = WelcomeFlow(page: .privacy)
    flow.close()
    flow.back()
    flow.next()
    #expect(flow.page == .privacy)
    #expect(flow.isFinished)
}
