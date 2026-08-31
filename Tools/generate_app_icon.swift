// Renders the Noor app icon — design 2a "Mihrab of light": a lamp in the
// mihrab arch (Ayat an-Nur motif), paper arch + gold lamp on deep green.
// Run: arch -arm64 swift Tools/generate_app_icon.swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 64.0  // design coordinates are the 64×64 SVG from canvas 2a
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * s, y: (64 - y) * s)  // flip SVG top-left → AppKit bottom-left
    }

    // Deep masjid green field
    NSColor(red: 0.055, green: 0.420, blue: 0.361, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let paper = NSColor(red: 0.980, green: 0.965, blue: 0.933, alpha: 1)
    let gold = NSColor(red: 0.847, green: 0.698, blue: 0.369, alpha: 1)  // #D8B25E

    // Mihrab arch: M32 6 C20 13 11 25 11 42 L11 58 L53 58 L53 42 C53 25 44 13 32 6 Z
    let arch = NSBezierPath()
    arch.move(to: pt(32, 6))
    arch.curve(to: pt(11, 42), controlPoint1: pt(20, 13), controlPoint2: pt(11, 25))
    arch.line(to: pt(11, 58))
    arch.line(to: pt(53, 58))
    arch.line(to: pt(53, 42))
    arch.curve(to: pt(32, 6), controlPoint1: pt(53, 25), controlPoint2: pt(44, 13))
    arch.close()
    paper.setStroke()
    arch.lineWidth = 4.4 * s
    arch.lineJoinStyle = .round
    arch.stroke()

    // The lamp (gold circle at 32,30 r7)
    gold.setFill()
    NSBezierPath(ovalIn: NSRect(x: (32 - 7) * s, y: (64 - 30 - 7) * s,
                                width: 14 * s, height: 14 * s)).fill()

    // Three rays
    gold.setStroke()
    for ray in [(pt(32, 15), pt(32, 11)),
                (pt(21, 19), pt(18.2, 16.2)),
                (pt(43, 19), pt(45.8, 16.2))] {
        let path = NSBezierPath()
        path.move(to: ray.0)
        path.line(to: ray.1)
        path.lineWidth = 3 * s
        path.lineCapStyle = .round
        path.stroke()
    }

    image.unlockFocus()
    return image
}

for size in sizes {
    let image = draw(size: CGFloat(size))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: outDir.appendingPathComponent("icon-\(size).png"))
    print("icon-\(size).png")
}
