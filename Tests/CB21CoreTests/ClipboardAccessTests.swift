import Testing
@testable import CB21Core

@Test func onlyAlwaysAllowMeansCaptureWillWork() {
    #expect(ClipboardAccess.alwaysAllow.isReady)
    for other in [ClipboardAccess.notAsked, .ask, .alwaysDeny, .unknown] {
        #expect(!other.isReady)
    }
}

@Test func askAndDenyPointTheUserToSystemSettings() {
    #expect(ClipboardAccess.ask.needsSystemSettings)
    #expect(ClipboardAccess.alwaysDeny.needsSystemSettings)
    for other in [ClipboardAccess.notAsked, .alwaysAllow, .unknown] {
        #expect(!other.needsSystemSettings)
    }
}

@Test func onlyAFreshInstallStillNeedsTheSystemPromptTriggered() {
    #expect(ClipboardAccess.notAsked.shouldTriggerPrompt)
    for other in [ClipboardAccess.ask, .alwaysAllow, .alwaysDeny, .unknown] {
        #expect(!other.shouldTriggerPrompt)
    }
}

@Test func everyStateHasAShortTitleAndAnExplanation() {
    for state in ClipboardAccess.allCases {
        #expect(!state.title.isEmpty)
        #expect(!state.explanation.isEmpty)
    }
}

@Test func wordingNamesTheChoiceTheUserShouldMake() {
    #expect(ClipboardAccess.ask.explanation.contains("Always Allow"))
    #expect(ClipboardAccess.alwaysDeny.explanation.contains("Always Allow"))
    #expect(ClipboardAccess.notAsked.explanation.contains("Always Allow"))
    #expect(ClipboardAccess.alwaysAllow.title == "Allowed")
}

@Test func theBlockedAndAskStatesWarnThatCaptureWillNotWork() {
    #expect(ClipboardAccess.alwaysDeny.explanation.contains("can't"))
    #expect(ClipboardAccess.ask.explanation.contains("reliably"))
}
