#!/usr/bin/env swift
import AppKit
import Foundation

// ── Vim Logo Reproduction ──────────────────────────────────────
// Render the Vim logo SVG paths using NSBezierPath

let canvasSize: CGFloat = 1024

// SVG viewBox: fit V + cursor content
let svgWidth: CGFloat = 306
let svgHeight: CGFloat = 276

// ── SVG Path Parser (M/L/H/V/Z only) ──────────────────────────

func parseSVGPath(_ d: String) -> NSBezierPath {
    let path = NSBezierPath()
    var tokens: [String] = []

    // Tokenize: split by commands and commas/spaces
    var current = ""
    for ch in d {
        if "MLHVZmlhvz".contains(ch) {
            if !current.isEmpty {
                tokens.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
            tokens.append(String(ch))
        } else if ch == "," || ch == " " {
            if !current.isEmpty {
                tokens.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        } else {
            current.append(ch)
        }
    }
    if !current.isEmpty {
        tokens.append(current.trimmingCharacters(in: .whitespaces))
    }

    var i = 0
    var curX: CGFloat = 0
    var curY: CGFloat = 0

    func nextNum() -> CGFloat {
        i += 1
        guard i < tokens.count else { return 0 }
        return CGFloat(Double(tokens[i]) ?? 0)
    }

    while i < tokens.count {
        let cmd = tokens[i]
        switch cmd {
        case "M":
            let x = nextNum()
            let y = nextNum()
            path.move(to: NSPoint(x: x, y: y))
            curX = x; curY = y
            // Implicit L after M
            while i + 2 < tokens.count,
                  Double(tokens[i + 1]) != nil,
                  Double(tokens[i + 2]) != nil {
                let x = nextNum()
                let y = nextNum()
                path.line(to: NSPoint(x: x, y: y))
                curX = x; curY = y
            }
        case "L":
            let x = nextNum()
            let y = nextNum()
            path.line(to: NSPoint(x: x, y: y))
            curX = x; curY = y
            // Implicit L after L
            while i + 2 < tokens.count,
                  Double(tokens[i + 1]) != nil,
                  Double(tokens[i + 2]) != nil {
                let x = nextNum()
                let y = nextNum()
                path.line(to: NSPoint(x: x, y: y))
                curX = x; curY = y
            }
        // H/V: only single argument supported (no implicit repetition)
        case "H":
            let x = nextNum()
            path.line(to: NSPoint(x: x, y: curY))
            curX = x
        case "V":
            let y = nextNum()
            path.line(to: NSPoint(x: curX, y: y))
            curY = y
        case "Z", "z":
            path.close()
        // Note: lowercase (relative) commands (m, l, h, v) are not supported.
        // All path data in this file uses uppercase (absolute) commands only.
        default:
            break
        }
        i += 1
    }
    return path
}

// ── SVG Path Data (from vimlogo.svg) ───────────────────────────

struct SVGLayer {
    let d: String
    let fill: NSColor?
    let stroke: NSColor?
    let strokeWidth: CGFloat
}

func color(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
    let hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let r = CGFloat(Int(hex.prefix(2), radix: 16) ?? 0) / 255.0
    let g = CGFloat(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
    let b = CGFloat(Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: alpha)
}

// ── Cursor geometry helpers ──────────────────────────────────────

func offsetPolygon(_ verts: [(CGFloat, CGFloat)], by dist: CGFloat) -> [(CGFloat, CGFloat)] {
    let n = verts.count
    var result: [(CGFloat, CGFloat)] = []
    for i in 0..<n {
        let prev = verts[(i - 1 + n) % n]
        let curr = verts[i]
        let next = verts[(i + 1) % n]
        let d1x = curr.0 - prev.0, d1y = curr.1 - prev.1
        let d2x = next.0 - curr.0, d2y = next.1 - curr.1
        let len1 = sqrt(d1x * d1x + d1y * d1y)
        let len2 = sqrt(d2x * d2x + d2y * d2y)
        // Outward normals (for CW winding in SVG coords)
        let n1x = -d1y / len1, n1y = d1x / len1
        let n2x = -d2y / len2, n2y = d2x / len2
        let bx = n1x + n2x, by = n1y + n2y
        let blen = sqrt(bx * bx + by * by)
        guard blen > 0.001 else {
            result.append((curr.0 + dist * n1x, curr.1 + dist * n1y))
            continue
        }
        let bisX = bx / blen, bisY = by / blen
        let cosHalf = n1x * bisX + n1y * bisY
        let miterDist = dist / max(cosHalf, 0.1)
        result.append((curr.0 + miterDist * bisX, curr.1 + miterDist * bisY))
    }
    return result
}

func bevelPolygon(_ verts: [(CGFloat, CGFloat)], bevelDist: CGFloat) -> [(CGFloat, CGFloat)] {
    let n = verts.count
    var result: [(CGFloat, CGFloat)] = []
    for i in 0..<n {
        let prev = verts[(i - 1 + n) % n]
        let curr = verts[i]
        let next = verts[(i + 1) % n]
        let d1x = prev.0 - curr.0, d1y = prev.1 - curr.1
        let d2x = next.0 - curr.0, d2y = next.1 - curr.1
        let len1 = sqrt(d1x * d1x + d1y * d1y)
        let len2 = sqrt(d2x * d2x + d2y * d2y)
        let b1 = min(bevelDist, len1 * 0.4)
        let b2 = min(bevelDist, len2 * 0.4)
        result.append((curr.0 + b1 * d1x / len1, curr.1 + b1 * d1y / len1))
        result.append((curr.0 + b2 * d2x / len2, curr.1 + b2 * d2y / len2))
    }
    return result
}

func polyPath(_ verts: [(CGFloat, CGFloat)]) -> String {
    guard let f = verts.first else { return "" }
    var s = String(format: "M %.1f,%.1f", f.0, f.1)
    for v in verts.dropFirst() { s += String(format: " L %.1f,%.1f", v.0, v.1) }
    return s + " Z"
}

// ── Compute cursor paths ────────────────────────────────────────

let cursorBase: [(CGFloat, CGFloat)] = [
    (145.0, 147.5),  // 0: tip
    (145.0, 237.0),  // 1: bottom-left
    (165.2, 217.5),  // 2: notch
    (188.4, 261.5),  // 3: tail bottom-left
    (202.6, 253.9),  // 4: tail bottom-right
    (180.3, 212.2),  // 5: inner right
    (209.2, 212.2),  // 6: outer right
]

let cursorScale: CGFloat = 1.1
let cursorOffset = (x: 25.0 as CGFloat, y: -25.0 as CGFloat)  // shift right and up to fit V bbox
let cursorTip = cursorBase[0]
let cursorVerts: [(CGFloat, CGFloat)] = cursorBase.map {
    (cursorTip.0 + ($0.0 - cursorTip.0) * cursorScale + cursorOffset.x,
     cursorTip.1 + ($0.1 - cursorTip.1) * cursorScale + cursorOffset.y)
}

let cursorBody = bevelPolygon(cursorVerts, bevelDist: 5)            // 14 pts - innermost
let cursorStripRaw = offsetPolygon(cursorVerts, by: 6)              // white/gray outer edge
let cursorStrip = bevelPolygon(cursorStripRaw, bevelDist: 6)        // 14 pts
let cursorBorderRaw = offsetPolygon(cursorVerts, by: 12)            // black outline edge
let cursorBorder = bevelPolygon(cursorBorderRaw, bevelDist: 9)      // 14 pts - outermost

let cursorBorderPath = polyPath(cursorBorder)
let cursorBodyPath = polyPath(cursorBody)

// White highlight strip: E60 (top diagonal) + V0 bevel + E01 (left edge) + V1 bevel
let cursorWhitePath: String = {
    let outer = [cursorStrip[12], cursorStrip[13],
                 cursorStrip[0], cursorStrip[1],
                 cursorStrip[2], cursorStrip[3]]
    let inner = [cursorBody[3], cursorBody[2], cursorBody[1],
                 cursorBody[0], cursorBody[13], cursorBody[12]]
    var s = String(format: "M %.1f,%.1f", outer[0].0, outer[0].1)
    for v in outer.dropFirst() { s += String(format: " L %.1f,%.1f", v.0, v.1) }
    for v in inner { s += String(format: " L %.1f,%.1f", v.0, v.1) }
    return s + " Z"
}()

// Gray shadow strip: remaining edges (E12..E56 + bevels)
let cursorGrayPath: String = {
    var s = String(format: "M %.1f,%.1f", cursorStrip[3].0, cursorStrip[3].1)
    for i in 4...12 { let v = cursorStrip[i]; s += String(format: " L %.1f,%.1f", v.0, v.1) }
    for i in (3...12).reversed() { let v = cursorBody[i]; s += String(format: " L %.1f,%.1f", v.0, v.1) }
    return s + " Z"
}()

// ── Layer data ──────────────────────────────────────────────────

let layers: [SVGLayer] = [
    // Black V outline
    SVGLayer(d: "M 171.72514,48.968207 180.22123,57.534607 121.61576,117.00727 V 57.534607 H 127.30326 L 135.79936,48.968207 V 26.358827 L 127.30326,17.792417 H 32.83842 L 24.34233,26.358827 V 48.968207 L 32.83842,57.534607 H 39.46341 V 250.28071 L 49.8306,258.7768 H 79.135285 L 282.24467,48.968207 V 26.358827 L 273.74858,17.792417 H 181.15873 L 171.72514,26.358827 V 48.968207",
             fill: color("#000000"), stroke: nil, strokeWidth: 0),

    // White highlights - left top bar
    SVGLayer(d: "M 35.647,51.847107 29.95951,46.159607 V 29.167417 L 35.647,23.479917 124.49467,23.409607 130.11186,29.167417 124.49467,31.905707 121.61576,29.167417 35.647,43.280707 V 51.847107",
             fill: color("#ffffff"), stroke: nil, strokeWidth: 0),

    // White highlight - left vertical bar
    SVGLayer(d: "M 52.63919,253.0893 46.01419,247.4018 V 51.776797 L 52.63919,46.159607 V 253.0893",
             fill: color("#ffffff"), stroke: nil, strokeWidth: 0),

    // White highlight - diagonal stroke
    SVGLayer(d: "M 194.40483,51.847107 200.09233,46.159607 V 57.534607 L 105.55717,153.87055 115.99858,131.19086 194.40483,51.847107",
             fill: color("#ffffff"), stroke: nil, strokeWidth: 0),

    // Dark green shadow - left corner
    SVGLayer(d: "M 54.5806,43.351017 52.63919,46.159607 46.01419,51.847107 H 35.647 V 40.472107 L 54.5806,43.351017",
             fill: color("#859966"), stroke: nil, strokeWidth: 0),

    // Dark green shadow - left bar inner
    SVGLayer(d: "M 115.99858,51.847107 V 131.19086 L 105.55717,153.80024 V 46.089297 H 121.61576 L 124.49467,43.280707 121.61576,29.167417 H 130.11186 V 46.159607 L 124.49467,51.847107 H 115.99858",
             fill: color("#859966"), stroke: nil, strokeWidth: 0),

    // White highlight - right top bar
    SVGLayer(d: "M 183.02983,51.847107 177.41264,46.159607 V 29.167417 L 183.96733,23.479917 H 270.00639 L 276.63139,29.167417 267.12748,37.663517 183.02983,43.280707 V 51.847107",
             fill: color("#ffffff"), stroke: nil, strokeWidth: 0),

    // Dark green shadow - diagonal + bottom
    SVGLayer(d: "M 276.63139,46.159607 77.189975,253.0893 H 52.63919 V 244.59321 H 70.639195 L 270.00639,40.472107 267.12748,29.167417 H 276.63139 V 46.159607",
             fill: color("#859966"), stroke: nil, strokeWidth: 0),

    // Dark green shadow - right corner
    SVGLayer(d: "M 201.96733,43.351017 200.02201,46.159607 194.40483,51.847107 H 183.02983 V 40.472107 L 201.96733,43.351017",
             fill: color("#859966"), stroke: nil, strokeWidth: 0),

    // Green V body (main face)
    SVGLayer(d: "M 105.55717,153.80024 V 46.089297 H 121.61576 L 124.49467,43.280707 V 31.905707 L 121.61576,29.097107 H 38.4556 L 35.647,31.905707 V 43.280707 L 38.4556,46.089297 H 52.63919 V 244.59321 L 56.31108,247.4018 H 72.510285 L 270.93998,40.472107 V 32.335387 L 268.06108,29.097107 H 185.90873 L 183.02983,31.905707 V 43.351017 L 185.90873,46.159607 H 200.09233 V 57.534607 L 105.55717,153.80024",
             fill: color("#a7c080"), stroke: nil, strokeWidth: 0),

    // ── Cursor (3D, computed) ────────────────────────────────
    SVGLayer(d: cursorBorderPath, fill: color("#000000"), stroke: nil, strokeWidth: 0),
    SVGLayer(d: cursorWhitePath, fill: color("#ffffff"), stroke: nil, strokeWidth: 0),
    SVGLayer(d: cursorGrayPath, fill: color("#859966"), stroke: nil, strokeWidth: 0),
    SVGLayer(d: cursorBodyPath, fill: color("#a7c080"), stroke: nil, strokeWidth: 0),
]

// ── Drawing ────────────────────────────────────────────────────

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Transparent background
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    // ── Squircle background ──
    let gutter: CGFloat = size * 0.1                   // Apple standard: 100px at 1024
    let sqSize = size - 2 * gutter                     // 824 at 1024
    let sqRect = NSRect(x: gutter, y: gutter, width: sqSize, height: sqSize)
    let sqRadius = sqSize * 0.225                      // ~185.4 at 824
    let sqPath = NSBezierPath(roundedRect: sqRect, xRadius: sqRadius, yRadius: sqRadius)

    // Drop shadow
    let scale1024 = size / 1024
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale1024)
    shadow.shadowBlurRadius = 28 * scale1024
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)

    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    sqPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Fill again without shadow
    NSColor.white.setFill()
    sqPath.fill()

    // ── Scale V+cursor to fit inside squircle ──
    let contentPad: CGFloat = sqSize * 0.04
    let available = sqSize - 2 * contentPad
    let scaleVal = available / max(svgWidth, svgHeight)

    let offsetX = gutter + contentPad + (available - svgWidth * scaleVal) / 2
    let offsetY = gutter + contentPad + (available - svgHeight * scaleVal) / 2

    // SVG → screen transform
    let transform = NSAffineTransform()
    transform.translateX(by: offsetX, yBy: offsetY + svgHeight * scaleVal)
    transform.scaleX(by: scaleVal, yBy: -scaleVal)

    for layer in layers {
        let svgPath = parseSVGPath(layer.d)
        guard let drawPath = svgPath.copy() as? NSBezierPath else { continue }
        drawPath.transform(using: transform as AffineTransform)

        if let fill = layer.fill {
            fill.setFill()
            drawPath.fill()
        }
        if let stroke = layer.stroke {
            stroke.setStroke()
            drawPath.lineWidth = layer.strokeWidth * scaleVal
            drawPath.stroke()
        }
    }

    image.unlockFocus()
    return image
}

// ── Menu Bar Icon (template image) ────────────────────────────

func drawMenuBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    // Keycap rounded rect
    let margin: CGFloat = size * 0.04
    let sw: CGFloat = max(1.5, size * 0.06)
    let w = size - 2 * margin
    let h = w * 0.82
    let x = margin
    let y = (size - h) / 2
    let r = size * 0.14

    let rect = NSRect(x: x + sw / 2, y: y + sw / 2,
                      width: w - sw, height: h - sw)
    let kcPath = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
    kcPath.lineWidth = sw
    NSColor.black.setStroke()
    kcPath.stroke()

    // "V" text centered in keycap
    let fontSize = h * 0.65
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
    ]
    let text = "V" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = x + (w - textSize.width) / 2
    let textY = y + (h - textSize.height) / 2
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    image.unlockFocus()
    image.isTemplate = true
    return image
}

// ── PNG Export & Main ──────────────────────────────────────────

func savePNG(_ image: NSImage, to path: String) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGen", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG"])
    }
    try pngData.write(to: URL(fileURLWithPath: path))
    print("  Created: \(path)")
}

// ── ICNS Generation ────────────────────────────────────────────

struct IconsetEntry {
    let name: String
    let size: CGFloat
}

let iconsetEntries: [IconsetEntry] = [
    IconsetEntry(name: "icon_16x16.png",      size: 16),
    IconsetEntry(name: "icon_16x16@2x.png",   size: 32),
    IconsetEntry(name: "icon_32x32.png",      size: 32),
    IconsetEntry(name: "icon_32x32@2x.png",   size: 64),
    IconsetEntry(name: "icon_128x128.png",    size: 128),
    IconsetEntry(name: "icon_128x128@2x.png", size: 256),
    IconsetEntry(name: "icon_256x256.png",    size: 256),
    IconsetEntry(name: "icon_256x256@2x.png", size: 512),
    IconsetEntry(name: "icon_512x512.png",    size: 512),
    IconsetEntry(name: "icon_512x512@2x.png", size: 1024),
]

func generateIcns(outputPath: String) throws {
    let fm = FileManager.default
    let tempDir = NSTemporaryDirectory()
    let iconsetPath = "\(tempDir)Vimursor.iconset"

    // 既存の一時ディレクトリを削除してから再作成
    if fm.fileExists(atPath: iconsetPath) {
        try fm.removeItem(atPath: iconsetPath)
    }
    try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    // 各サイズの PNG を生成
    print("  Generating iconset...")
    for entry in iconsetEntries {
        let image = drawIcon(size: entry.size)
        let destPath = "\(iconsetPath)/\(entry.name)"
        try savePNG(image, to: destPath)
    }

    // iconutil で .icns を生成
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["--convert", "icns", "--output", outputPath, iconsetPath]

    let pipe = Pipe()
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
        throw NSError(domain: "IconGen", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "iconutil failed: \(errMsg)"])
    }

    // 一時ディレクトリを削除
    try fm.removeItem(atPath: iconsetPath)
    print("  Created: \(outputPath)")
}

// ── Main ───────────────────────────────────────────────────────

let repoRoot = FileManager.default.currentDirectoryPath
let resourcesDir = "\(repoRoot)/Resources"
try FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

// アプリアイコンプレビュー (既存)
print("Rendering app icon preview...")
let preview = drawIcon(size: canvasSize)
try savePNG(preview, to: "\(resourcesDir)/AppIcon-preview.png")

// メニューバーアイコンプレビュー (既存)
print("Rendering menu bar icon preview...")
let menuPreview = drawMenuBarIcon(size: 256)
try savePNG(menuPreview, to: "\(resourcesDir)/MenuBarIcon-preview.png")

// .icns 生成
print("Generating AppIcon.icns...")
try generateIcns(outputPath: "\(resourcesDir)/AppIcon.icns")

// メニューバー PNG (@1x / @2x)
print("Rendering menu bar icons...")
let menuIcon1x = drawMenuBarIcon(size: 18)
try savePNG(menuIcon1x, to: "\(resourcesDir)/MenuBarIcon.png")

let menuIcon2x = drawMenuBarIcon(size: 36)
try savePNG(menuIcon2x, to: "\(resourcesDir)/MenuBarIcon@2x.png")

print("Done!")
