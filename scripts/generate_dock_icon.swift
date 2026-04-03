#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixelSize: Int
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

let specs: [IconSpec] = [
    .init(filename: "icon_16x16.png", pixelSize: 16),
    .init(filename: "icon_16x16@2x.png", pixelSize: 32),
    .init(filename: "icon_32x32.png", pixelSize: 32),
    .init(filename: "icon_32x32@2x.png", pixelSize: 64),
    .init(filename: "icon_128x128.png", pixelSize: 128),
    .init(filename: "icon_128x128@2x.png", pixelSize: 256),
    .init(filename: "icon_256x256.png", pixelSize: 256),
    .init(filename: "icon_256x256@2x.png", pixelSize: 512),
    .init(filename: "icon_512x512.png", pixelSize: 512),
    .init(filename: "icon_512x512@2x.png", pixelSize: 1024)
]

let backgroundTop = NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.24, alpha: 1.0)
let backgroundBottom = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.12, alpha: 1.0)
let accent = NSColor(calibratedRed: 0.27, green: 0.86, blue: 0.82, alpha: 1.0)
let accentSoft = NSColor(calibratedRed: 0.74, green: 0.97, blue: 0.95, alpha: 0.9)
let border = NSColor(white: 1.0, alpha: 0.12)

func cgColor(_ color: NSColor) -> CGColor {
    color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor
}

func writePNG(_ cgImage: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

func roundedRectPath(in rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(pixelSize: Int, url: URL) throws {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let inset = size * 0.055
    let backgroundRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22

    context.saveGState()
    context.addPath(roundedRectPath(in: backgroundRect, radius: cornerRadius))
    context.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [cgColor(backgroundTop), cgColor(backgroundBottom)] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: bounds.minX, y: bounds.minY),
        end: CGPoint(x: bounds.maxX, y: bounds.maxY),
        options: []
    )

    context.setFillColor(cgColor(NSColor(calibratedWhite: 1.0, alpha: 0.05)))
    context.fill(CGRect(x: bounds.minX, y: bounds.maxY * 0.44, width: size, height: size * 0.56))
    context.restoreGState()

    context.setStrokeColor(cgColor(border))
    context.setLineWidth(max(1.0, size * 0.014))
    context.addPath(roundedRectPath(in: backgroundRect, radius: cornerRadius))
    context.strokePath()

    let glowRect = CGRect(
        x: size * 0.18,
        y: size * 0.22,
        width: size * 0.64,
        height: size * 0.56
    )
    context.saveGState()
    context.setFillColor(cgColor(accent.withAlphaComponent(0.18)))
    context.fillEllipse(in: glowRect)
    context.restoreGState()

    let bars: [(CGFloat, CGFloat)] = [
        (0.18, 0.30),
        (0.29, 0.56),
        (0.40, 0.80),
        (0.51, 0.92),
        (0.62, 0.74),
        (0.73, 0.50),
        (0.84, 0.28)
    ]
    let barWidth = size * 0.075
    let baseline = size * 0.73
    let availableHeight = size * 0.48

    for (index, pair) in bars.enumerated() {
        let x = size * pair.0
        let height = availableHeight * pair.1
        let barRect = CGRect(
            x: x - barWidth / 2,
            y: baseline - height,
            width: barWidth,
            height: height
        )

        let barRadius = min(barWidth / 2, barRect.height / 2)
        let barPath = roundedRectPath(in: barRect, radius: barRadius)

        context.saveGState()
        context.setShadow(offset: .zero, blur: size * 0.008, color: cgColor(accentSoft.withAlphaComponent(0.18)))
        context.addPath(barPath)
        context.setFillColor(index == 3 ? cgColor(accentSoft) : cgColor(accent.withAlphaComponent(0.94)))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(barPath)
        context.setStrokeColor(cgColor(NSColor.white.withAlphaComponent(0.10)))
        context.setLineWidth(max(0.6, size * 0.004))
        context.strokePath()
        context.restoreGState()
    }

    context.saveGState()
    context.setBlendMode(.softLight)
    context.setFillColor(cgColor(NSColor.white.withAlphaComponent(0.10)))
    context.fill(CGRect(x: size * 0.14, y: size * 0.12, width: size * 0.72, height: size * 0.20))
    context.restoreGState()

    guard let cgImage = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }
    try writePNG(cgImage, to: url)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for spec in specs {
    try drawIcon(pixelSize: spec.pixelSize, url: outputDirectory.appendingPathComponent(spec.filename))
}

print("Generated \(specs.count) icon files in \(outputDirectory.path)")
