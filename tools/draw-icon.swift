import AppKit

// Draws the Blinds icon (1024x1024) and saves it as a PNG.
// Usage: swift tools/draw-icon.swift <file.png>
//
// A window with a half-lowered shade, white on blue. The blue is the macOS 27.0
// system blue (NSColor.systemBlue, light appearance, read on 23 Sep 2026):
// #0088FF. The gradient goes from slightly lighter at the top to the full color
// at the bottom, like Apple's icons.
// It follows the macOS icon grid: an 824-point rounded shape centered in a
// 1024 canvas, with a 100-point margin for the shadow.

let side: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let blue: UInt32 = 0x0088FF

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func mix(_ a: NSColor, _ b: NSColor, _ amount: CGFloat) -> NSColor {
    let x = a.usingColorSpace(.sRGB)!, y = b.usingColorSpace(.sRGB)!
    return NSColor(srgbRed: x.redComponent + (y.redComponent - x.redComponent) * amount,
                   green: x.greenComponent + (y.greenComponent - x.greenComponent) * amount,
                   blue: x.blueComponent + (y.blueComponent - x.blueComponent) * amount, alpha: 1)
}

// Top-down coordinates, to reason as on paper.
func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: side - y - height, width: width, height: height)
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect(x, y, width, height), xRadius: radius, yRadius: radius)
}

let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
    let base = color(blue)
    let shape = rounded(100, 100, 824, 824, 185)

    // Shadow under the shape
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.30)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    base.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Background: a single hue, lighter at the top, with a soft highlight
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(starting: mix(base, .white, 0.28), ending: mix(base, .black, 0.10))!
        .draw(in: rect(100, 100, 824, 824), angle: -90)
    NSGradient(starting: color(0xFFFFFF, 0.18), ending: color(0xFFFFFF, 0))!
        .draw(in: rect(100, 100, 824, 300), angle: -90)

    // The symbol, white, with a soft shadow to lift it from the background
    let symbolShadow = NSShadow()
    symbolShadow.shadowColor = color(0x000000, 0.15)
    symbolShadow.shadowBlurRadius = 14
    symbolShadow.shadowOffset = NSSize(width: 0, height: -6)
    symbolShadow.set()
    let white = color(0xFFFFFF)

    // Window frame
    white.setStroke()
    let frame = rounded(236, 236, 552, 552, 64)
    frame.lineWidth = 40
    frame.stroke()

    // Half-lowered shade with its bottom bar
    // (clipped to the inner shape of the frame, so the corners don't stick out)
    NSGraphicsContext.saveGraphicsState()
    rounded(256, 256, 512, 512, 44).addClip()
    white.withAlphaComponent(0.9).setFill()
    NSBezierPath(rect: rect(256, 256, 512, 250)).fill()
    NSGraphicsContext.restoreGraphicsState()
    white.setFill()
    rounded(246, 492, 532, 44, 22).fill()

    // Pull cord with its ring
    let cord = NSBezierPath()
    cord.move(to: NSPoint(x: 512, y: side - 536))
    cord.line(to: NSPoint(x: 512, y: side - 590))
    cord.lineWidth = 16
    cord.lineCapStyle = .round
    cord.stroke()
    let ring = NSBezierPath(ovalIn: rect(490, 590, 44, 44))
    ring.lineWidth = 14
    ring.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return true
}

guard let data = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not create the PNG")
}
try! png.write(to: URL(fileURLWithPath: output))
print("Icon saved to \(output)")
