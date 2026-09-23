import AppKit
import CoreText

// Generates the logo kit in Resources/logo/ as SVG + PNG:
//   <slug>-mark        the app icon as a flat vector (full color)
//   <slug>-glyph-black the window-and-shade symbol alone, near-black
//   <slug>-glyph-white the same symbol, white (for dark backgrounds)
//   <slug>-logo        mark + name, for light backgrounds   (needs a font)
//   <slug>-logo-dark   mark + name, for dark backgrounds    (needs a font)
//
// Usage: swift tools/make-logo-kit.swift <Name> [path/to/font.ttf]
//
// The geometry is the same as tools/draw-icon.swift, in its 1024-point canvas.
// The name is converted to outlines, so the logo looks the same everywhere.
// Font used for the published kit: Inter (SIL Open Font License 1.1), file
// "Inter[opsz,wght].ttf" from https://github.com/google/fonts/tree/main/ofl/inter
// It is not stored in this repo: download it only to regenerate the logos.

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("Usage: swift tools/make-logo-kit.swift <Name> [path/to/font.ttf]")
    exit(1)
}
let name = arguments[1]
let fontPath = arguments.count > 2 ? arguments[2] : nil
let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
let outputDirectory = "Resources/logo"

// macOS 27 system blue #0088FF, with the same gradient as the app icon.
let gradientTop = "#47A9FF"     // system blue mixed with 28% white
let gradientBottom = "#007AE6"  // system blue mixed with 10% black
let nearBlack = "#1D1D1F"

/// The window-and-shade symbol in the icon's 1024-point coordinates.
/// The shade's clip reaches 6 points under the frame, so no hairline shows
/// between them when both have the same color.
func symbol(color: String, shadeOpacity: Double, clipID: String) -> String {
    """
    <clipPath id="\(clipID)"><rect x="250" y="250" width="524" height="524" rx="50"/></clipPath>
    <rect x="236" y="236" width="552" height="552" rx="64" fill="none" stroke="\(color)" stroke-width="40"/>
    <rect x="250" y="250" width="524" height="256" fill="\(color)" fill-opacity="\(shadeOpacity)" clip-path="url(#\(clipID))"/>
    <rect x="246" y="492" width="532" height="44" rx="22" fill="\(color)"/>
    <line x1="512" y1="536" x2="512" y2="590" stroke="\(color)" stroke-width="16" stroke-linecap="round"/>
    <circle cx="512" cy="612" r="22" fill="none" stroke="\(color)" stroke-width="14"/>
    """
}

/// The app icon, flat, in a 120-point box (the icon shape fills the box).
func mark(idPrefix: String) -> String {
    """
    <defs>
    <linearGradient id="\(idPrefix)bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="\(gradientTop)"/><stop offset="1" stop-color="\(gradientBottom)"/></linearGradient>
    <linearGradient id="\(idPrefix)hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.18"/><stop offset="0.364" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
    </defs>
    <rect width="120" height="120" rx="27" fill="url(#\(idPrefix)bg)"/>
    <rect width="120" height="120" rx="27" fill="url(#\(idPrefix)hl)"/>
    <g transform="scale(0.1456311) translate(-100 -100)">
    \(symbol(color: "#FFFFFF", shadeOpacity: 0.9, clipID: "\(idPrefix)inner"))
    </g>
    """
}

/// The symbol alone, fitted to a 120-point box with a 6-point margin.
func glyph(color: String) -> String {
    """
    <g transform="translate(6 6) scale(0.1824324) translate(-216 -216)">
    \(symbol(color: color, shadeOpacity: 1, clipID: "inner"))
    </g>
    """
}

/// The name as SVG outlines, cap height 56 points, baseline at y = 88.
func wordmark(text: String, fontURL: URL, color: String, x originX: CGFloat) -> (svg: String, width: CGFloat) {
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
          let base = descriptors.first else {
        fatalError("Could not read the font at \(fontURL.path)")
    }
    // Variable font axes: weight 600 (semibold), optical size 32 (display).
    let wght = 0x7767_6874, opsz = 0x6F70_737A
    let variation = [wght: 600, opsz: 32] as CFDictionary
    let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: variation] as CFDictionary)
    let probe = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
    let size = 100 * 56 / CTFontGetCapHeight(probe)
    let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
    let tracking = -0.01 * size

    let characters = Array(text.utf16)
    var glyphs = [CGGlyph](repeating: 0, count: characters.count)
    CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    var advances = [CGSize](repeating: .zero, count: glyphs.count)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)

    var d = ""
    var penX = originX
    let baseline: CGFloat = 88
    func fmt(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    for (index, glyph) in glyphs.enumerated() {
        if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
            let x0 = penX
            path.applyWithBlock { pointer in
                let element = pointer.pointee
                let p = element.points
                func pt(_ i: Int) -> String { "\(fmt(x0 + p[i].x)) \(fmt(baseline - p[i].y))" }
                switch element.type {
                case .moveToPoint: d += "M\(pt(0))"
                case .addLineToPoint: d += "L\(pt(0))"
                case .addQuadCurveToPoint: d += "Q\(pt(0)) \(pt(1))"
                case .addCurveToPoint: d += "C\(pt(0)) \(pt(1)) \(pt(2))"
                case .closeSubpath: d += "Z"
                @unknown default: break
                }
            }
        }
        penX += advances[index].width + (index < glyphs.count - 1 ? tracking : 0)
    }
    return ("<path fill=\"\(color)\" d=\"\(d)\"/>", penX - originX)
}

func svg(width: CGFloat, height: CGFloat, _ body: String) -> String {
    let w = Int(width.rounded(.up)), h = Int(height)
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(w) \(h)\" width=\"\(w)\" height=\"\(h)\">\n\(body)\n</svg>\n"
}

func write(_ content: String, as file: String, pngWidth: Int) {
    let svgPath = "\(outputDirectory)/\(file).svg"
    try! content.write(toFile: svgPath, atomically: true, encoding: .utf8)
    guard let image = NSImage(contentsOfFile: svgPath) else { fatalError("Could not render \(svgPath)") }
    let pngHeight = Int((CGFloat(pngWidth) * image.size.height / image.size.width).rounded())
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pngWidth, pixelsHigh: pngHeight,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: pngWidth, height: pngHeight))
    NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outputDirectory)/\(file).png"))
    print("Created \(file).svg and \(file).png")
}

try! FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

write(svg(width: 120, height: 120, mark(idPrefix: "")), as: "\(slug)-mark", pngWidth: 1024)
write(svg(width: 120, height: 120, glyph(color: nearBlack)), as: "\(slug)-glyph-black", pngWidth: 1024)
write(svg(width: 120, height: 120, glyph(color: "#FFFFFF")), as: "\(slug)-glyph-white", pngWidth: 1024)

if let fontPath {
    let fontURL = URL(fileURLWithPath: fontPath)
    for (suffix, color) in [("logo", nearBlack), ("logo-dark", "#FFFFFF")] {
        let text = wordmark(text: name, fontURL: fontURL, color: color, x: 150)
        let body = "<g>\n\(mark(idPrefix: "m"))\n</g>\n\(text.svg)"
        write(svg(width: 150 + text.width + 2, height: 120, body), as: "\(slug)-\(suffix)", pngWidth: 1200)
    }
} else {
    print("No font given: skipped the logos with the name.")
}
