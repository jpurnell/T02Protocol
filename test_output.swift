#!/usr/bin/env swift

import Foundation
import T02Protocol
import CoreGraphics
import ImageIO
import AppKit

// Quick script to dump hex output for debugging

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift test_output.swift <image.png>")
    exit(1)
}

let imagePath = CommandLine.arguments[1]

// Load image
guard let image = NSImage(contentsOf: URL(fileURLWithPath: imagePath)) else {
    print("Failed to load image")
    exit(1)
}

print("Image: \(image.size.width)x\(image.size.height)")

// Generate data
let proto = T02Protocol()
do {
    let data = try proto.generatePrintData(from: image, feedLines: 4)
    print("Generated \(data.count) bytes\n")

    // Hex dump first 100 bytes
    print("First 100 bytes:")
    let dumpSize = min(100, data.count)
    for i in 0..<dumpSize {
        if i % 16 == 0 {
            print(String(format: "%04x: ", i), terminator: "")
        }
        print(String(format: "%02x ", data[i]), terminator: "")
        if (i + 1) % 16 == 0 {
            print()
        }
    }
    print("\n")

    // Write to file for comparison
    let outputPath = "/tmp/swift_protocol_output.bin"
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote to: \(outputPath)")

} catch {
    print("Error: \(error)")
    exit(1)
}
