import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CB21Core

private func png(width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

private func pdf(width: CGFloat, height: CGFloat, pages: Int = 2) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: width, height: height)
    let ctx = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
    for _ in 0..<pages {
        ctx.beginPDFPage(nil)
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 10, y: 10, width: width / 2, height: height / 2))
        ctx.endPDFPage()
    }
    ctx.closePDF()
    return data as Data
}

private func clip(_ kind: Representation.Kind, _ type: String, _ data: Data) -> Clip {
    Clip(representations: [Representation(kind: kind, typeIdentifier: type, data: data)])
}

@Test func largeImageIsScaledDownKeepingItsAspectRatio() async {
    let image = await PreviewRenderer.render(clip(.image, "public.png", png(width: 400, height: 200)), maxPixelSize: 100)
    #expect(image?.width == 100)
    #expect(image?.height == 50)
}

@Test func smallImageIsNotBlownUp() async {
    let image = await PreviewRenderer.render(clip(.image, "public.png", png(width: 30, height: 20)), maxPixelSize: 600)
    #expect(image?.width == 30)
    #expect(image?.height == 20)
}

@Test func unreadableImageHasNoPreview() async {
    #expect(await PreviewRenderer.render(clip(.image, "public.png", Data([1, 2, 3]))) == nil)
}

@Test func pdfDataShowsItsFirstPage() async {
    let image = await PreviewRenderer.render(clip(.pdf, "com.adobe.pdf", pdf(width: 100, height: 200)), maxPixelSize: 400)
    // A 100 x 200 pt page is drawn at 2x, so it fits and keeps its proportions.
    #expect(image?.width == 200)
    #expect(image?.height == 400)
}

@Test func pdfPageIsScaledDownToFitTheLimit() async {
    let image = await PreviewRenderer.render(clip(.pdf, "com.adobe.pdf", pdf(width: 1000, height: 500)), maxPixelSize: 200)
    #expect(image?.width == 200)
    #expect(image?.height == 100)
}

@Test func unreadablePdfHasNoPreview() async {
    #expect(await PreviewRenderer.render(clip(.pdf, "com.adobe.pdf", Data([0, 1]))) == nil)
}

@Test func missingFileHasNoPreview() async {
    let url = URL(fileURLWithPath: "/tmp/CB21-no-such-\(UUID().uuidString)/Gone.png")
    #expect(await PreviewRenderer.render(clip(.file, "public.file-url", Data(url.absoluteString.utf8))) == nil)
}

@Test func existingImageFileGetsAQuickLookThumbnail() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("Photo.png")
    try png(width: 300, height: 200).write(to: file)
    let image = await PreviewRenderer.render(clip(.file, "public.file-url", Data(file.absoluteString.utf8)), maxPixelSize: 256)
    #expect(image != nil)
}

@Test func textAndLinkClipsHaveNoImagePreview() async {
    #expect(await PreviewRenderer.render(clip(.plainText, "public.utf8-plain-text", Data("hi".utf8))) == nil)
    #expect(await PreviewRenderer.render(clip(.link, "public.url", Data("https://a.b".utf8))) == nil)
}
