#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let outerRect = NSRect(x: 52, y: 52, width: 920, height: 920)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 210, yRadius: 210)
let gradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.05, green: 0.63, blue: 0.57, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.31, blue: 0.88, alpha: 1),
    ]
)!
gradient.draw(in: outerPath, angle: -45)

NSColor.white.withAlphaComponent(0.16).setStroke()
outerPath.lineWidth = 16
outerPath.stroke()

let terminalRect = NSRect(x: 198, y: 260, width: 628, height: 504)
let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 64, yRadius: 64)
NSColor(calibratedWhite: 0.05, alpha: 0.78).setFill()
terminalPath.fill()
NSColor.white.withAlphaComponent(0.32).setStroke()
terminalPath.lineWidth = 10
terminalPath.stroke()

let topLine = NSBezierPath()
topLine.move(to: NSPoint(x: 200, y: 648))
topLine.line(to: NSPoint(x: 824, y: 648))
NSColor.white.withAlphaComponent(0.28).setStroke()
topLine.lineWidth = 8
topLine.stroke()

for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 250 + CGFloat(index) * 54, y: 686, width: 28, height: 28)).fill()
}

let text = ">_" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 220, weight: .bold),
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attributes)
text.draw(
    at: NSPoint(x: (1024 - textSize.width) / 2, y: 345),
    withAttributes: attributes
)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render icon\n", stderr)
    exit(1)
}
try png.write(to: outputURL, options: .atomic)
