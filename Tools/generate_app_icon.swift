// Renders the Noor app icon (design §4: minimal rub-el-hizb motif, deep
// green + gold on paper, no text). Run: arch -arm64 swift Tools/generate_app_icon.swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = size / 1024.0

    // Paper background
    NSColor(red: 0.980, green: 0.965, blue: 0.933, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let center = NSPoint(x: size / 2, y: size / 2)
    let green = NSColor(red: 0.055, green: 0.420, blue: 0.361, alpha: 1)
    let gold = NSColor(red: 0.725, green: 0.541, blue: 0.184, alpha: 1)

    func square(side: CGFloat, rotated: Bool, color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        let half = side / 2
        var points = [
            NSPoint(x: -half, y: -half), NSPoint(x: half, y: -half),
            NSPoint(x: half, y: half), NSPoint(x: -half, y: half),
        ]
        if rotated {
            points = points.map { point in
                NSPoint(x: (point.x - point.y) * 0.7071, y: (point.x + point.y) * 0.7071)
            }
        }
        path.move(to: NSPoint(x: center.x + points[0].x, y: center.y + points[0].y))
        for point in points.dropFirst() {
            path.line(to: NSPoint(x: center.x + point.x, y: center.y + point.y))
        }
        path.close()
        color.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .miter
        path.stroke()
    }

    // Rub-el-hizb: straight + rotated squares in deep green
    square(side: 470 * scale, rotated: false, color: green, width: 42 * scale)
    square(side: 470 * scale, rotated: true, color: green, width: 42 * scale)

    // Inner gold ring + dot (the "noor" — light)
    let ringRect = NSRect(x: center.x - 120 * scale, y: center.y - 120 * scale,
                          width: 240 * scale, height: 240 * scale)
    let ring = NSBezierPath(ovalIn: ringRect)
    gold.setStroke()
    ring.lineWidth = 26 * scale
    ring.stroke()
    let dotRect = NSRect(x: center.x - 42 * scale, y: center.y - 42 * scale,
                         width: 84 * scale, height: 84 * scale)
    gold.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    image.unlockFocus()
    return image
}

for size in sizes {
    let image = draw(size: CGFloat(size))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    // Force pixel dimensions (NSImage points == pixels here at 1x)
    rep.size = NSSize(width: size, height: size)
    try! png.write(to: outDir.appendingPathComponent("icon-\(size).png"))
    print("icon-\(size).png")
}
