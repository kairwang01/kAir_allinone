import AppKit
import CoreGraphics

let width: CGFloat = 1200
let height: CGFloat = 630
let size = NSSize(width: width, height: height)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let ctx = NSGraphicsContext.current!.cgContext
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Soft brand glow
ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.95, blue: 1.0, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: 720, y: 40, width: 420, height: 420))

// Icon
let iconPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets/img/icon-180.png"
if let icon = NSImage(contentsOfFile: iconPath) {
    icon.draw(in: NSRect(x: 88, y: height - 88 - 96, width: 96, height: 96))
}

func draw(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

let baseY = height - 210
draw("Meet Odera", x: 88, y: baseY, size: 72, weight: .bold, color: NSColor(calibratedWhite: 0.11, alpha: 1))
draw("The AI that turns intent into action.", x: 88, y: baseY - 86, size: 34, weight: .regular, color: NSColor(calibratedWhite: 0.34, alpha: 1))
draw("on kAir · Local-first · v1: Chat + Health", x: 88, y: baseY - 146, size: 26, weight: .semibold, color: NSColor(calibratedRed: 0.48, green: 0.30, blue: 0.92, alpha: 1))

NSGraphicsContext.restoreGraphicsState()

let image = NSImage(size: size)
image.addRepresentation(rep)

let outPath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "assets/img/og-image.png"
guard let tiff = rep.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
