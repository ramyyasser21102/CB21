#!/usr/bin/env swift
// Regenerates the asset catalog images from the artwork in design/ and docs/assets/.
// Usage: swift scripts/make-assets.swift   (run from the repo root)
import AppKit

let root = FileManager.default.currentDirectoryPath
let catalog = "\(root)/App/Assets.xcassets"
let fm = FileManager.default

func write(_ rep: NSBitmapImageRep, to path: String) throws {
    try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func bitmap(width: Int, height: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func json(_ object: Any, to path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: path))
}

// MARK: Menu bar sprites: black template images, 18 pt tall.

func menuBarImageSet(name: String, svgPath: String) throws {
    var svg = try String(contentsOfFile: svgPath, encoding: .utf8)
    svg = svg.replacingOccurrences(of: "fill:#fff", with: "fill:#000")
    let image = NSImage(data: Data(svg.utf8))!
    let aspect = image.size.width / image.size.height
    let dir = "\(catalog)/\(name).imageset"
    var images: [[String: String]] = []
    for scale in 1...3 {
        let h = 18 * scale
        let w = Int((Double(h) * aspect).rounded())
        let rep = bitmap(width: w, height: h) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
        let file = "\(name)@\(scale)x.png"
        try write(rep, to: "\(dir)/\(file)")
        images.append(["idiom": "universal", "filename": file, "scale": "\(scale)x"])
    }
    try json([
        "images": images,
        "info": ["author": "xcode", "version": 1],
        "properties": ["template-rendering-intent": "template"],
    ], to: "\(dir)/Contents.json")
}

/// The app image (the same artwork as the GitHub image) for the Welcome window, 120 pt tall.
func welcomeLogoImageSet(pngPath: String) throws {
    let image = NSImage(contentsOfFile: pngPath)!
    let aspect = image.size.width / image.size.height
    let dir = "\(catalog)/WelcomeLogo.imageset"
    var images: [[String: String]] = []
    for scale in 1...3 {
        let h = 120 * scale
        let w = Int((Double(h) * aspect).rounded())
        let rep = bitmap(width: w, height: h) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
        let file = "WelcomeLogo@\(scale)x.png"
        try write(rep, to: "\(dir)/\(file)")
        images.append(["idiom": "universal", "filename": file, "scale": "\(scale)x"])
    }
    try json(["images": images, "info": ["author": "xcode", "version": 1]], to: "\(dir)/Contents.json")
}

try menuBarImageSet(name: "MenuBarDefault", svgPath: "\(root)/design/menubar-default.svg")
try menuBarImageSet(name: "MenuBarPaused", svgPath: "\(root)/design/menubar-paused.svg")
try welcomeLogoImageSet(pngPath: "\(root)/docs/assets/CB21.png")

// MARK: App icon: a full-bleed square.
//
// macOS applies the icon shape itself and expects artwork that fills the whole 1024 x 1024 square, with no padding
// and no transparent corners. Artwork that is already a rounded shape, or sits inside margins, gets put on a grey
// plate by the system. The source image is a squircle with transparent corners, so it is scaled up from the centre
// until every pixel along the border is opaque, and every icon size is made from that master.

let source = NSImage(contentsOfFile: "\(root)/docs/assets/CB21.png")!
let masterSize = 1024

func fullBleedMaster(scale: CGFloat) -> NSBitmapImageRep {
    bitmap(width: masterSize, height: masterSize) { rect in
        let cover = max(rect.width / source.size.width, rect.height / source.size.height) * scale
        let w = source.size.width * cover, h = source.size.height * cover
        source.draw(in: NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h),
                    from: .zero, operation: .sourceOver, fraction: 1)
    }
}

func borderIsOpaque(_ rep: NSBitmapImageRep) -> Bool {
    let last = masterSize - 1
    for t in stride(from: 0, through: last, by: 4) {
        for (x, y) in [(t, 0), (t, last), (0, t), (last, t)] {
            if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) < 0.999 { return false }
        }
    }
    return true
}

var bleedScale: CGFloat = 1.0
var master = fullBleedMaster(scale: bleedScale)
while !borderIsOpaque(master) && bleedScale < 2.0 {
    bleedScale += 0.005
    master = fullBleedMaster(scale: bleedScale)
}
precondition(borderIsOpaque(master), "could not make the icon full-bleed")
print("app icon scaled by \(String(format: "%.3f", bleedScale)) to fill the square")
let masterImage = NSImage(size: NSSize(width: masterSize, height: masterSize))
masterImage.addRepresentation(master)

let iconDir = "\(catalog)/AppIcon.appiconset"
var iconImages: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = points * scale
    let rep = bitmap(width: px, height: px) { rect in
        masterImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    }
    let file = "icon_\(points)x\(points)@\(scale)x.png"
    try write(rep, to: "\(iconDir)/\(file)")
    iconImages.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": file])
}
try json(["images": iconImages, "info": ["author": "xcode", "version": 1]], to: "\(iconDir)/Contents.json")
try json(["info": ["author": "xcode", "version": 1]], to: "\(catalog)/Contents.json")
print("assets written to \(catalog)")
