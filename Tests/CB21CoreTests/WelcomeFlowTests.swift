import Testing
@testable import CB21Core

@Test func flowHasTheFivePagesInOrder() {
    #expect(WelcomeFlow.Page.allCases == [.welcome, .clipboard, .login, .shortcuts, .privacy])
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
    #expect(flow.page == .clipboard)
    #expect(flow.lastMove == .backward)
    flow = WelcomeFlow()
    flow.back()
    #expect(flow.page == .welcome)
    #expect(flow.lastMove == .none)
}

@Test func skippingAPageMovesOnAndRemembersWhichWereSkipped() {
    var flow = WelcomeFlow(page: .clipboard)
    flow.skipPage()
    #expect(flow.page == .login)
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

@Test func progressRunsFromOneFifthToComplete() {
    var flow = WelcomeFlow()
    #expect(flow.progress == 0.2)
    flow = WelcomeFlow(page: .privacy)
    #expect(flow.progress == 1.0)
    #expect(flow.pageNumber == 5)
    #expect(flow.pageCount == 5)
}

@Test func finishedFlowIgnoresFurtherMoves() {
    var flow = WelcomeFlow(page: .privacy)
    flow.close()
    flow.back()
    flow.next()
    #expect(flow.page == .privacy)
    #expect(flow.isFinished)
}
