import AppKit

/// Composites the README images from the App Store screenshots in
/// `docs/screenshots`, and draws the two pieces of furniture the repo has no
/// photograph of: the logo at the size the page uses, and the download button.
///
/// Run as `swift Tools/Screenshots/ArticleImages.swift`.
///
/// Three things here are load bearing.
///
/// The 144 DPI tag is the last thing that happens to a bitmap. Setting the size
/// before drawing makes the context one point per two pixels while every
/// rectangle below is still in pixels, so the whole composite doubles and runs
/// off the canvas.
///
/// The screenshots are the App Store frames, which already carry their own
/// headline and their own device bezel. They are placed as flat panels with a
/// hairline and nothing else: a rounded corner around them would be a frame
/// drawn around a frame, and the heavier the treatment the more obviously the
/// two bezels disagree. The hairline is there only because a panel whose
/// background is pure black has nothing to separate it from a near black
/// ground.
///
/// Text is drawn with AppKit rather than composited from an image because
/// ImageMagick on macOS is commonly built without Freetype, where `-annotate`
/// warns about a missing delegate and then renders nothing at all.

let root = FileManager.default.currentDirectoryPath
let shots = URL(fileURLWithPath: root).appendingPathComponent("docs/screenshots")
let out = URL(fileURLWithPath: root).appendingPathComponent("docs/images")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("cannot allocate a \(width) by \(height) bitmap") }
    rep.size = NSSize(width: width, height: height)
    return rep
}

/// Paper. One flat colour, a shade off the pure black the app itself draws, so
/// the phones sit on it rather than dissolve into it.
func ground(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let result = bitmap(width, height)
    guard let data = result.bitmapData else { fatalError("no bitmap data") }
    let paper: [UInt8] = [18, 18, 20, 255]
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * result.bytesPerRow + x * 4
            for channel in 0..<4 { data[offset + channel] = paper[channel] }
        }
    }
    return result
}

func clearCanvas(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let result = bitmap(width, height)
    memset(result.bitmapData!, 0, result.bytesPerRow * height)
    return result
}

func withCanvas(_ canvas: NSBitmapImageRep, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// Half the pixel count means 144 DPI in the encoded file, so the PNG reads as
/// a retina asset rather than a very large 1x one.
func write(_ image: NSBitmapImageRep, to url: URL) {
    let pixels = NSSize(width: image.pixelsWide, height: image.pixelsHigh)
    image.size = NSSize(width: pixels.width / 2, height: pixels.height / 2)
    guard let png = image.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(url.lastPathComponent)")
    }
    try! png.write(to: url)
    image.size = pixels
    print("\(url.lastPathComponent) \(image.pixelsWide)x\(image.pixelsHigh)")
}

func load(_ name: String) -> NSImage {
    let url = shots.appendingPathComponent(name)
    guard let image = NSImage(contentsOf: url) else { fatalError("cannot read \(url.path)") }
    return image
}

func draw(_ text: String, at point: CGPoint, canvasHeight: CGFloat, size: CGFloat,
          weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ]
    let string = text as NSString
    let measured = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: point.x, y: canvasHeight - point.y - measured.height),
                withAttributes: attributes)
}

/// One App Store panel, placed flat with a hairline around it.
func placePhone(_ image: NSImage, in rect: CGRect, canvasHeight: CGFloat) {
    let flipped = CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)
    let radius: CGFloat = 28
    let path = NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    path.lineWidth = 2
    NSColor(white: 1, alpha: 0.10).setStroke()
    path.stroke()
}

let ink = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.97, alpha: 1)
let inkSoft = NSColor(srgbRed: 0.62, green: 0.62, blue: 0.64, alpha: 1)

// The logo, at the size the README draws it. The 1024 original is 300KB of
// detail nobody can see at 120 points, on the first image the page loads.
do {
    let icon = URL(fileURLWithPath: root)
        .appendingPathComponent("Pickle/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
    let sips = Process()
    sips.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    sips.arguments = ["-Z", "512", "-s", "format", "png", icon.path,
                      "--out", out.appendingPathComponent("logo.png").path]
    sips.standardOutput = FileHandle.nullDevice
    try! sips.run()
    sips.waitUntilExit()
    print("logo.png 512x512")
}

// The hero. Three screens at the size a reader can actually read them, with the
// name and the one line that says what the thing is set beside them the way a
// magazine would. 2400x1600 is the shape the portfolio cards use, so the cover
// comes out of this file rather than a second export.
do {
    let canvas = CGSize(width: 2400, height: 1600)
    let image = ground(Int(canvas.width), Int(canvas.height))
    withCanvas(image) {
        let blockTop: CGFloat = 120

        if let icon = NSImage(contentsOf: out.appendingPathComponent("logo.png")) {
            NSGraphicsContext.current?.imageInterpolation = .high
            icon.draw(in: CGRect(x: 150, y: canvas.height - blockTop - 118, width: 118, height: 118))
        }
        draw("PICKLE", at: CGPoint(x: 300, y: blockTop + 2), canvasHeight: canvas.height,
             size: 64, weight: .semibold, color: ink)
        draw("Built for the fastest possible log.",
             at: CGPoint(x: 304, y: blockTop + 88),
             canvasHeight: canvas.height, size: 30, weight: .regular, color: inkSoft)

        // Three phones, centred as a group under the brand block.
        let names = ["01-home.png", "02-ai.png", "05-activity.png"]
        let phoneHeight: CGFloat = 1080
        let gap: CGFloat = 90
        let first = load(names[0])
        let aspect = first.size.width / first.size.height
        let phoneWidth = phoneHeight * aspect
        let total = phoneWidth * 3 + gap * 2
        let startX = (canvas.width - total) / 2
        let top = blockTop + 260

        for (index, name) in names.enumerated() {
            let rect = CGRect(x: startX + CGFloat(index) * (phoneWidth + gap), y: top,
                              width: phoneWidth, height: phoneHeight)
            placePhone(load(name), in: rect, canvasHeight: canvas.height)
        }
    }
    write(image, to: out.appendingPathComponent("hero.png"))
}

// The two panels the prose points at, copied down to the size the page draws
// them. The originals in docs/screenshots are left alone: they are the App
// Store submission assets and have to stay at the size Apple asks for. One of
// them is 1.9MB, which is not a thing to put inline on a page a stranger loads.
for (source, name) in [("03-explore.png", "explore.png"), ("04-coach.png", "coach.png")] {
    let sips = Process()
    sips.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    sips.arguments = ["-Z", "1600", "-s", "format", "png",
                      shots.appendingPathComponent(source).path,
                      "--out", out.appendingPathComponent(name).path]
    sips.standardOutput = FileHandle.nullDevice
    try! sips.run()
    sips.waitUntilExit()
    print("\(name) from \(source)")
}

// The App Store button. Drawn rather than screenshotted: there is no such
// button in the app, and the badge points at the App Store rather than at
// releases/latest, because this repo publishes no GitHub releases.
do {
    let canvas = CGSize(width: 1040, height: 184)
    let image = clearCanvas(Int(canvas.width), Int(canvas.height))
    withCanvas(image) {
        let bounds = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        let pill = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1).setFill()
        pill.fill()

        // U+F8FF is a private-use glyph that only the system font carries. Ask
        // for the font by name so a fallback cannot substitute an empty box.
        let logo = "\u{F8FF}" as NSString
        let mark = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        let logoAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "SF Pro Text", size: 72) ?? NSFont.systemFont(ofSize: 72),
            .foregroundColor: mark,
        ]
        let label = "Download on the App Store" as NSString
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 60, weight: .semibold),
            .foregroundColor: mark,
        ]
        let logoSize = logo.size(withAttributes: logoAttributes)
        let labelSize = label.size(withAttributes: labelAttributes)
        let gap: CGFloat = 34
        let startX = (bounds.width - (logoSize.width + gap + labelSize.width)) / 2
        logo.draw(at: NSPoint(x: startX, y: (bounds.height - logoSize.height) / 2 + 4),
                  withAttributes: logoAttributes)
        label.draw(at: NSPoint(x: startX + logoSize.width + gap, y: (bounds.height - labelSize.height) / 2),
                   withAttributes: labelAttributes)
    }
    write(image, to: out.appendingPathComponent("download.png"))
}
