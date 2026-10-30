// Draws the app icon (a sheet from a tear-off notepad) into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024

    // Standard macOS icon grid: 824pt body inset 100pt, with a soft drop shadow.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.96, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    shape.addClip()
    NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.995, blue: 0.98, alpha: 1),
               ending: NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1))!
        .draw(in: body, angle: -90)

    // Binding strip across the top.
    let band = NSRect(x: body.minX, y: body.maxY - 190 * s, width: body.width, height: 190 * s)
    NSGradient(starting: NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.33, alpha: 1),
               ending: NSColor(calibratedRed: 0.90, green: 0.32, blue: 0.24, alpha: 1))!
        .draw(in: band, angle: -90)

    // Ruled lines, the last one short like an unfinished thought.
    NSColor(calibratedWhite: 0.55, alpha: 0.35).setFill()
    let widths: [CGFloat] = [584, 584, 584, 340]
    for (i, w) in widths.enumerated() {
        let y = band.minY - 140 * s - CGFloat(i) * 120 * s
        NSBezierPath(roundedRect: NSRect(x: 220 * s, y: y, width: w * s, height: 22 * s),
                     xRadius: 11 * s, yRadius: 11 * s).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
