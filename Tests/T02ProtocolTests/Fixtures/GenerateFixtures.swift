#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

/// Generate test fixtures for T02 protocol testing
/// This mirrors the Python generate_fixtures.py script

let T02_WIDTH_DOTS = 384  // 50mm at 203 DPI

func createSolidBlackImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 100

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill with black (0.0)
    ctx.setFillColor(gray: 0.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    return ctx.makeImage()
}

func createSolidWhiteImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 100

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill with white (1.0)
    ctx.setFillColor(gray: 1.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    return ctx.makeImage()
}

func createCheckerboardImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 100

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill background with white
    ctx.setFillColor(gray: 1.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw black squares in checkerboard pattern
    ctx.setFillColor(gray: 0.0, alpha: 1.0)
    let squareSize = 8

    for y in stride(from: 0, to: height, by: squareSize) {
        for x in stride(from: 0, to: width, by: squareSize) {
            if (x / squareSize + y / squareSize) % 2 == 0 {
                ctx.fill(CGRect(x: x, y: y, width: squareSize, height: squareSize))
            }
        }
    }

    return ctx.makeImage()
}

func createSingleLineImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 1

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill with black
    ctx.setFillColor(gray: 0.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    return ctx.makeImage()
}

func createVerticalStripesImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 50

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill background with white
    ctx.setFillColor(gray: 1.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw black vertical stripes (8 pixels wide, 16 pixel period)
    ctx.setFillColor(gray: 0.0, alpha: 1.0)
    for x in stride(from: 0, to: width, by: 16) {
        ctx.fill(CGRect(x: x, y: 0, width: 8, height: height))
    }

    return ctx.makeImage()
}

func createLargeImage() -> CGImage? {
    let width = T02_WIDTH_DOTS
    let height = 300  // Requires multiple blocks (>255 lines)

    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )

    guard let ctx = context else { return nil }

    // Fill background with white
    ctx.setFillColor(gray: 1.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw horizontal lines every 10 pixels
    ctx.setStrokeColor(gray: 0.0, alpha: 1.0)
    ctx.setLineWidth(1.0)

    for y in stride(from: 0, to: height, by: 10) {
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: width, y: y))
        ctx.strokePath()
    }

    return ctx.makeImage()
}

func saveImage(_ image: CGImage, to filename: String) -> Bool {
    let url = URL(fileURLWithPath: filename)

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
        return false
    }

    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

// Main execution
print("Generating T02 protocol test fixtures for Swift...")

let fixtures = [
    ("solid_black.png", createSolidBlackImage),
    ("solid_white.png", createSolidWhiteImage),
    ("checkerboard.png", createCheckerboardImage),
    ("single_line.png", createSingleLineImage),
    ("vertical_stripes.png", createVerticalStripesImage),
    ("large_image.png", createLargeImage),
]

for (filename, generator) in fixtures {
    if let image = generator() {
        if saveImage(image, to: filename) {
            print("✓ Created \(filename)")
        } else {
            print("✗ Failed to save \(filename)")
        }
    } else {
        print("✗ Failed to create \(filename)")
    }
}

print("\nTest fixtures generated successfully!")
