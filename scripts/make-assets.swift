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

// MARK: App icon: the artwork at 824 pt inside a 1024 pt canvas, as the macOS icon grid expects.

let source = NSImage(contentsOfFile: "\(root)/docs/assets/CB21.png")!
let iconDir = "\(catalog)/AppIcon.appiconset"
var iconImages: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = points * scale
    let rep = bitmap(width: px, height: px) { rect in
        let side = rect.width * 824 / 1024
        let aspect = source.size.width / source.size.height
        let w = aspect >= 1 ? side : side * aspect
        let h = aspect >= 1 ? side / aspect : side
        source.draw(in: NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h),
                    from: .zero, operation: .sourceOver, fraction: 1)
    }
    let file = "icon_\(points)x\(points)@\(scale)x.png"
    try write(rep, to: "\(iconDir)/\(file)")
    iconImages.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": file])
}
try json(["images": iconImages, "info": ["author": "xcode", "version": 1]], to: "\(iconDir)/Contents.json")
try json(["info": ["author": "xcode", "version": 1]], to: "\(catalog)/Contents.json")
print("assets written to \(catalog)")
