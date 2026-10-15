import Foundation
import Testing
@testable import CB21Core

private let now = Date(timeIntervalSince1970: 1_000_000)

private let ageCases: [(Double, String)] = [
    (0, "just now"),
    (59, "just now"),
    (60, "1 min ago"),
    (300, "5 min ago"),
    (3540, "59 min ago"),
    (3600, "1 h ago"),
    (82_800, "23 h ago"),
    (86_400, "1 d ago"),
    (518_400, "6 d ago"),
]

@Test(arguments: ageCases)
func ageIsShownInTheLargestFittingUnit(secondsAgo: Double, expected: String) {
    #expect(ClipSubtitle.age(of: now.addingTimeInterval(-secondsAgo), now: now) == expected)
}

@Test func olderThanAWeekShowsTheDate() {
    let text = ClipSubtitle.age(of: now.addingTimeInterval(-30 * 86_400), now: now)
    #expect(!text.contains("ago"))
    #expect(!text.isEmpty)
}

@Test func futureTimestampsAreJustNow() {
    #expect(ClipSubtitle.age(of: now.addingTimeInterval(120), now: now) == "just now")
}

@Test func subtitleJoinsAgeSizeAndSourceApp() {
    let text = ClipSubtitle.make(createdAt: now.addingTimeInterval(-300), byteCount: 2048, sourceAppName: "Safari", now: now)
    #expect(text.hasPrefix("5 min ago · "))
    #expect(text.contains("KB"))
    #expect(text.hasSuffix(" · Safari"))
}

@Test func subtitleLeavesOutAnUnknownSourceApp() {
    let text = ClipSubtitle.make(createdAt: now, byteCount: 10, sourceAppName: nil, now: now)
    #expect(text.hasPrefix("just now · "))
    #expect(text.components(separatedBy: " · ").count == 2)
}

@Test func clipSubtitleUsesItsOwnFacts() {
    let clip = Clip(
        representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data("hello".utf8))],
        createdAt: now.addingTimeInterval(-7200), sourceAppName: "Notes"
    )
    #expect(clip.subtitle(now: now).hasPrefix("2 h ago · "))
    #expect(clip.subtitle(now: now).hasSuffix(" · Notes"))
}
