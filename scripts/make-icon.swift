import AppKit

// Renders the Perch app icon (indigo squircle + white bird on a perch) at every size the macOS
// asset catalog needs. Vector drawing scaled per size, so each output is crisp. Re-run after
// changing the design: `swift scripts/make-icon.swift`.

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Perch/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let design: CGFloat = 1024
let svg: CGFloat = 220
func s(_ value: CGFloat) -> CGFloat { value * (design / svg) }
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: s(x), y: s(y)) }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let indigoTop = color(0.388, 0.400, 0.945)
let indigoBottom = color(0.545, 0.361, 0.965)
let white = color(1, 1, 1)
let amber = color(1.0, 0.760, 0.294)
let eyeColor = color(0.137, 0.137, 0.165)

func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.move(to: a); path.addLine(to: b); path.addLine(to: c); path.closeSubpath()
    return path
}

func draw(into ctx: CGContext) {
    // Squircle background with a vertical indigo gradient.
    let rect = CGRect(x: s(14), y: s(14), width: s(192), height: s(192))
    let squircle = CGPath(roundedRect: rect, cornerWidth: s(44), cornerHeight: s(44), transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: space, colors: [indigoTop, indigoBottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: p(110, 14), end: p(110, 206), options: [])
    }
    ctx.restoreGState()

    // Soft contact shadow under the bird.
    ctx.saveGState()
    ctx.setFillColor(color(0, 0, 0, 0.12))
    ctx.addEllipse(in: CGRect(x: s(110 - 34), y: s(159 - 7), width: s(68), height: s(14)))
    ctx.fillPath()
    ctx.restoreGState()

    // Perch.
    ctx.setFillColor(color(1, 1, 1, 0.92))
    ctx.addPath(CGPath(roundedRect: CGRect(x: s(68), y: s(151), width: s(84), height: s(9)),
                       cornerWidth: s(4.5), cornerHeight: s(4.5), transform: nil))
    ctx.fillPath()

    // Legs.
    ctx.setFillColor(amber)
    for legX in [101.0, 120.0] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: s(CGFloat(legX)), y: s(146), width: s(4.5), height: s(11)),
                           cornerWidth: s(2), cornerHeight: s(2), transform: nil))
    }
    ctx.fillPath()

    // Tail.
    ctx.setFillColor(white)
    ctx.addPath(triangle(p(74, 104), p(44, 92), p(74, 124)))
    ctx.fillPath()

    // Body.
    ctx.setFillColor(white)
    ctx.addEllipse(in: CGRect(x: s(112 - 42), y: s(106 - 44), width: s(84), height: s(88)))
    ctx.fillPath()

    // Wing (subtle).
    let wing = CGMutablePath()
    wing.move(to: p(112, 96))
    wing.addQuadCurve(to: p(142, 122), control: p(136, 98))
    wing.addQuadCurve(to: p(108, 116), control: p(122, 132))
    wing.addQuadCurve(to: p(112, 96), control: p(106, 104))
    wing.closeSubpath()
    ctx.setFillColor(color(0, 0, 0, 0.07))
    ctx.addPath(wing)
    ctx.fillPath()

    // Tuft.
    ctx.setFillColor(white)
    let tuft1 = CGMutablePath()
    tuft1.move(to: p(104, 64)); tuft1.addQuadCurve(to: p(116, 48), control: p(107, 50))
    tuft1.addQuadCurve(to: p(104, 64), control: p(117, 57)); tuft1.closeSubpath()
    let tuft2 = CGMutablePath()
    tuft2.move(to: p(116, 64)); tuft2.addQuadCurve(to: p(129, 52), control: p(121, 52))
    tuft2.addQuadCurve(to: p(116, 64), control: p(128, 61)); tuft2.closeSubpath()
    ctx.addPath(tuft1); ctx.addPath(tuft2); ctx.fillPath()

    // Beak.
    ctx.setFillColor(amber)
    ctx.addPath(triangle(p(150, 100), p(172, 107), p(150, 116)))
    ctx.fillPath()

    // Eye.
    ctx.setFillColor(eyeColor)
    ctx.addEllipse(in: CGRect(x: s(130 - 5.5), y: s(98 - 5.5), width: s(11), height: s(11)))
    ctx.fillPath()
}

func render(size px: Int) -> Data? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return nil
    }
    ctx.interpolationQuality = .high
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: CGFloat(px) / design, y: -CGFloat(px) / design)
    draw(into: ctx)
    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    guard let data = render(size: px) else {
        FileHandle.standardError.write(Data("failed to render \(px)\n".utf8))
        exit(1)
    }
    try data.write(to: outputDir.appendingPathComponent("icon_\(px).png"))
    print("wrote icon_\(px).png")
}
