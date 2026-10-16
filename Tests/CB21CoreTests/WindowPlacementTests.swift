import CoreGraphics
import Testing
@testable import CB21Core

private let laptop = CGRect(x: 0, y: 77, width: 1470, height: 846)

@Test func windowIsExactlyCenteredOnTheUsableScreen() {
    let frame = WindowPlacement.centeredFrame(in: laptop, widthFraction: 0.62, heightFraction: 0.78,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(abs(frame.midX - laptop.midX) <= 0.5)
    #expect(abs(frame.midY - laptop.midY) <= 0.5)
}

@Test func sizeFollowsTheScreenWithinTheLimits() {
    let frame = WindowPlacement.centeredFrame(in: laptop, widthFraction: 0.62, heightFraction: 0.78,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(frame.width == (1470 * 0.62).rounded())
    #expect(frame.height == (846 * 0.78).rounded())
}

@Test func hugeScreensStopAtTheMaximum() {
    let big = CGRect(x: 0, y: 0, width: 5120, height: 2880)
    let frame = WindowPlacement.centeredFrame(in: big, widthFraction: 0.62, heightFraction: 0.78,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(frame.size == CGSize(width: 1100, height: 860))
    #expect(abs(frame.midX - big.midX) <= 0.5)
    #expect(abs(frame.midY - big.midY) <= 0.5)
}

@Test func smallScreensGetAtLeastTheMinimumWhenItFits() {
    let small = CGRect(x: 0, y: 0, width: 1280, height: 720)
    let frame = WindowPlacement.centeredFrame(in: small, widthFraction: 0.3, heightFraction: 0.3,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(frame.width == 860)
    #expect(frame.height == 600)
}

@Test func windowNeverGrowsBeyondTheScreenOnATinyDisplay() {
    let tiny = CGRect(x: 0, y: 0, width: 700, height: 500)
    let frame = WindowPlacement.centeredFrame(in: tiny, widthFraction: 0.62, heightFraction: 0.78,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(frame.width <= tiny.width)
    #expect(frame.height <= tiny.height)
    #expect(tiny.contains(frame))
}

@Test func centeringWorksOnASecondaryScreenWithAnOffsetOrigin() {
    let second = CGRect(x: 1470, y: -200, width: 1920, height: 1080)
    let frame = WindowPlacement.centeredFrame(in: second, widthFraction: 0.62, heightFraction: 0.78,
                                              minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860))
    #expect(second.contains(frame))
    #expect(abs(frame.midX - second.midX) <= 0.5)
    #expect(abs(frame.midY - second.midY) <= 0.5)
}

@Test func aWindowOfAKnownSizeIsCenteredOnTheScreen() {
    let frame = WindowPlacement.centered(size: CGSize(width: 911, height: 712), in: laptop)
    #expect(frame.size == CGSize(width: 911, height: 712))
    #expect(abs(frame.midX - laptop.midX) <= 0.5)
    #expect(abs(frame.midY - laptop.midY) <= 0.5)
}

@Test func aWindowTallerThanTheScreenIsPulledInSoItsTopAndBottomShow() {
    let tall = WindowPlacement.centered(size: CGSize(width: 900, height: 1200), in: laptop)
    #expect(tall.height <= laptop.height)
    #expect(laptop.contains(tall))
}
