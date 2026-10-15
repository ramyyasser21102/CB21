import CoreGraphics
import Foundation
import ImageIO
import QuickLookThumbnailing

/// Draws the picture shown in the Detail pane for images, PDFs and files.
/// Decoding can be slow for big content, so the app calls this off the main thread.
public enum PreviewRenderer {
    public static func render(_ clip: Clip, maxPixelSize: Int = 1200) async -> CGImage? {
        let main = clip.preferred
        switch main.kind {
        case .image:
            return image(from: main.data, maxPixelSize: maxPixelSize)
        case .pdf:
            return firstPage(of: main.data, maxPixelSize: maxPixelSize)
        case .file:
            guard let url = clip.fileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
            return await thumbnail(of: url, maxPixelSize: maxPixelSize)
        case .link, .richText, .plainText:
            return nil
        }
    }

    /// Scales down to fit, never up.
    private static func image(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        if max(width, height) <= maxPixelSize {
            return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Draws page 1 on white, at up to 2x so small pages stay sharp, and no larger than `maxPixelSize`.
    private static func firstPage(of data: Data, maxPixelSize: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let rotated = page.rotationAngle % 180 != 0
        let pageWidth = rotated ? box.height : box.width
        let pageHeight = rotated ? box.width : box.height
        let scale = min(2, CGFloat(maxPixelSize) / max(pageWidth, pageHeight))
        let width = Int((pageWidth * scale).rounded())
        let height = Int((pageHeight * scale).rounded())
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height),
                                                 rotate: 0, preserveAspectRatio: true))
        ctx.drawPDFPage(page)
        return ctx.makeImage()
    }

    private static func thumbnail(of url: URL, maxPixelSize: Int) async -> CGImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxPixelSize, height: maxPixelSize),
            scale: 1,
            representationTypes: .all
        )
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
    }
}

extension Clip {
    /// Where a file Clip points, when it has a file Representation.
    public var fileURL: URL? {
        guard preferred.kind == .file else { return nil }
        let text = String(decoding: preferred.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: text) ?? URL(fileURLWithPath: text)
    }
}
