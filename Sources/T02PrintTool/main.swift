#!/usr/bin/env swift

import Foundation
import T02Protocol
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Command Line Tool

struct PrintTool {
    let proto = T02Protocol()

    func findT02Device() {
        print("🔍 Searching for T02 printer...")
        print("\nBluetooth Devices:")

        // List serial devices that might be T02
        let fileManager = FileManager.default
        let devPath = "/dev"

        do {
            let devices = try fileManager.contentsOfDirectory(atPath: devPath)
            let t02Devices = devices.filter { $0.contains("T02") || $0.contains("cu.") }
                .filter { $0.hasPrefix("cu.") || $0.hasPrefix("tty.") }
                .sorted()

            if t02Devices.isEmpty {
                print("  ❌ No T02 devices found")
                print("\n💡 Tips:")
                print("  1. Turn on your T02 printer")
                print("  2. Go to System Settings → Bluetooth")
                print("  3. Pair with 'T02' device")
                print("  4. Wait a few seconds and try again")
            } else {
                for device in t02Devices {
                    let fullPath = "/dev/\(device)"
                    print("  ✓ \(fullPath)")
                }

                // Highlight T02-specific devices
                let likelyT02 = t02Devices.filter { $0.contains("T02") }
                if let recommended = likelyT02.first {
                    print("\n📌 Recommended: /dev/\(recommended)")
                }
            }
        } catch {
            print("  ❌ Error listing devices: \(error)")
        }

        print("\nManual check:")
        print("  Run in Terminal: ls /dev/cu.* | grep -i t02")
    }

    func printImage(imagePath: String, devicePath: String, feedLines: Int = 4) -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("Printing: \(URL(fileURLWithPath: imagePath).lastPathComponent)")
        print(String(repeating: "=", count: 60))
        fflush(stdout)

        // Load image
        print("  📥 Loading image...")
        fflush(stdout)
        guard let image = loadImage(from: imagePath) else {
            print("    ❌ Failed to load image from \(imagePath)")
            fflush(stdout)
            return false
        }
        print("    ✓ Loaded \(image.width)x\(image.height) pixels")
        fflush(stdout)

        // Generate print data
        print("  ⚙️  Generating print data...")
        fflush(stdout)
        let data: Data
        do {
            data = try proto.generatePrintData(from: image, feedLines: feedLines)
            print("    ✓ Generated \(data.count) bytes")
            fflush(stdout)

            // Show protocol breakdown
            print("    ℹ️  Protocol: init(2) + justify(3) + image + feed(3) bytes")
            fflush(stdout)
        } catch {
            print("    ❌ Failed to generate data: \(error)")
            fflush(stdout)
            return false
        }

        // Send to printer with proper serial communication
        print("  📤 Sending to printer at \(devicePath)...")
        fflush(stdout)
        do {
            let serialPort = SerialPort(path: devicePath)
            try serialPort.sendAndWait(data, timeout: 8.0)
            print("    ✓ Sent successfully!")
            print("\n  ✨ Check your printer for output.")
            fflush(stdout)
            return true
        } catch {
            print("    ❌ Failed to send: \(error)")
            fflush(stdout)
            if (error as NSError).domain == NSCocoaErrorDomain {
                print("\n  💡 Try: sudo swift run T02PrintTool print \(imagePath) \(devicePath)")
                fflush(stdout)
            }
            return false
        }
    }

    func printImageBluetooth(imagePath: String, feedLines: Int = 4) -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("Printing via CoreBluetooth: \(URL(fileURLWithPath: imagePath).lastPathComponent)")
        print(String(repeating: "=", count: 60))
        fflush(stdout)

        // Load image
        print("  📥 Loading image...")
        fflush(stdout)
        guard let image = loadImage(from: imagePath) else {
            print("    ❌ Failed to load image from \(imagePath)")
            fflush(stdout)
            return false
        }
        print("    ✓ Loaded \(image.width)x\(image.height) pixels")
        fflush(stdout)

        // Generate print data
        print("  ⚙️  Generating print data...")
        fflush(stdout)
        let data: Data
        do {
            data = try proto.generatePrintData(from: image, feedLines: feedLines)
            print("    ✓ Generated \(data.count) bytes")
            fflush(stdout)
        } catch {
            print("    ❌ Failed to generate data: \(error)")
            fflush(stdout)
            return false
        }

        // Connect and send via CoreBluetooth (like iOS app)
        print("  📡 Connecting via CoreBluetooth...")
        fflush(stdout)
        do {
            let connection = CoreBluetoothConnection()
            try connection.connectAndSend(data, timeout: 30.0)

            print("    ✓ Print job completed!")
            print("\n  ✨ Check your printer for output.")
            fflush(stdout)
            return true
        } catch {
            print("    ❌ Failed: \(error)")
            fflush(stdout)
            return false
        }
    }

    func runDemo(devicePath: String) -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("T02 PRINTER DEMO")
        print(String(repeating: "=", count: 60))
        print("\nThis will print all test fixtures.")
        print("Make sure your printer has enough paper!\n")

        print("Press Enter to start demo...")
        _ = readLine()

        let testImages: [(String, String)] = [
            ("solid_black.png", "Solid black rectangle (tests coverage)"),
            ("solid_white.png", "Solid white (tests no-print)"),
            ("checkerboard.png", "Checkerboard pattern"),
            ("vertical_stripes.png", "Vertical stripes (alignment)"),
            ("text_sample.png", "Text sample"),
            ("single_line.png", "Single line (minimal)"),
            ("large_image.png", "Large image (multi-block, 300 lines)"),
        ]

        var results: [(String, Bool)] = []

        for (filename, description) in testImages {
            // Find fixture path
            guard let fixturePath = findFixture(filename) else {
                print("\n⚠️  Skipping \(filename) (not found)")
                continue
            }

            print("\n" + String(repeating: "─", count: 60))
            print("Test: \(description)")
            print(String(repeating: "─", count: 60))

            let success = printImage(imagePath: fixturePath, devicePath: devicePath, feedLines: 4)
            results.append((filename, success))

            if success {
                print("\n  ⏳ Waiting 3 seconds before next print...")
                sleep(3)
            } else {
                print("\n  Continue anyway? (y/n): ", terminator: "")
                if let response = readLine(), response.lowercased() != "y" {
                    break
                }
            }
        }

        // Summary
        print("\n" + String(repeating: "=", count: 60))
        print("DEMO COMPLETE")
        print(String(repeating: "=", count: 60))

        let passed = results.filter { $0.1 }.count
        print("\nResults: \(passed)/\(results.count) printed successfully")
        for (filename, success) in results {
            let status = success ? "✓" : "✗"
            print("  \(status) \(filename)")
        }

        print("\n" + String(repeating: "=", count: 60))
        return passed == results.count
    }

    func createTestImage(outputPath: String) {
        print("🎨 Creating test image...")

        // Create a test label (384x200 pixels)
        let width = 384
        let height = 200

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("  ❌ Failed to create context")
            return
        }

        // White background
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Black border
        context.setStrokeColor(gray: 0.0, alpha: 1.0)
        context.setLineWidth(2)
        context.stroke(CGRect(x: 5, y: 5, width: width-10, height: height-10))

        // Add text
        context.setFillColor(gray: 0.0, alpha: 1.0)

        // Draw some test patterns
        // Horizontal lines
        for y in stride(from: 30, to: 100, by: 15) {
            context.fill(CGRect(x: 20, y: y, width: 344, height: 2))
        }

        // Checkerboard pattern
        let squareSize = 8
        for y in stride(from: 120, to: 180, by: squareSize) {
            for x in stride(from: 20, to: 364, by: squareSize) {
                if (x / squareSize + y / squareSize) % 2 == 0 {
                    context.fill(CGRect(x: x, y: y, width: squareSize, height: squareSize))
                }
            }
        }

        guard let image = context.makeImage() else {
            print("  ❌ Failed to create image")
            return
        }

        // Save to file
        let url = URL(fileURLWithPath: outputPath)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("  ❌ Failed to create destination")
            return
        }

        CGImageDestinationAddImage(destination, image, nil)

        if CGImageDestinationFinalize(destination) {
            print("  ✓ Created test image: \(outputPath)")
            print("  📏 Size: \(width)x\(height) pixels (50mm x 26mm)")
        } else {
            print("  ❌ Failed to save image")
        }
    }

    func debugProtocol(imagePath: String, outputPath: String? = nil) {
        print("🔍 Debug Protocol Generation")
        print(String(repeating: "=", count: 60))

        // Load image
        guard let image = loadImage(from: imagePath) else {
            print("  ❌ Failed to load image from \(imagePath)")
            return
        }
        print("  📥 Image: \(image.width)x\(image.height) pixels")

        // Generate protocol data
        do {
            let data = try proto.generatePrintData(from: image, feedLines: 4)
            print("  ✓ Generated \(data.count) bytes")
            print()

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
            if dumpSize % 16 != 0 {
                print()
            }
            print()

            // Save to file if specified
            if let outputPath = outputPath {
                try data.write(to: URL(fileURLWithPath: outputPath))
                print("  ✓ Wrote to: \(outputPath)")
            } else {
                let defaultPath = "/tmp/swift_protocol_output.bin"
                try data.write(to: URL(fileURLWithPath: defaultPath))
                print("  ✓ Wrote to: \(defaultPath)")
            }
        } catch {
            print("  ❌ Error: \(error)")
        }
    }

    // MARK: - Helper Functions

    func loadImage(from path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        return NSImage(contentsOf: url)
    }

    func findFixture(_ filename: String) -> String? {
        // Try to find in Tests/T02ProtocolTests/Fixtures
        let possiblePaths = [
            "Tests/T02ProtocolTests/Fixtures/\(filename)",
            "../Tests/T02ProtocolTests/Fixtures/\(filename)",
            "../../Tests/T02ProtocolTests/Fixtures/\(filename)",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}

// MARK: - Main

func printUsage() {
    print("""
    T02 Printer Test Tool (Swift)

    Usage:
        t02-print find                          - Find T02 device
        t02-print print <image> <device>        - Print an image (serial port)
        t02-print bt <image>                    - Print via active Bluetooth
        t02-print demo <device>                 - Run full demo
        t02-print create <output.png>           - Create test image
        t02-print debug <image> [output.bin]    - Debug protocol generation

    Examples:
        # Find your T02 device
        swift run T02PrintTool find

        # Print via Bluetooth (establishes active RFCOMM connection)
        swift run T02PrintTool bt test.png

        # Print via serial port device
        swift run T02PrintTool print test.png /dev/cu.T024

        # Run demo (prints all test fixtures)
        swift run T02PrintTool demo /dev/cu.T024

        # Create a test image
        swift run T02PrintTool create my_test.png

        # Debug protocol output
        swift run T02PrintTool debug test.png

    """)
}

// Parse command line arguments
let args = CommandLine.arguments
let tool = PrintTool()

if args.count < 2 {
    printUsage()
    exit(0)
}

let command = args[1]

switch command {
case "find", "--find", "-f":
    tool.findT02Device()

case "bt", "bluetooth", "-b":
    guard args.count >= 3 else {
        print("Error: bt command requires <image>")
        print("Example: swift run T02PrintTool bt test.png")
        exit(1)
    }
    let imagePath = args[2]
    let feedLines = args.count > 3 ? Int(args[3]) ?? 4 : 4

    let success = tool.printImageBluetooth(imagePath: imagePath, feedLines: feedLines)
    exit(success ? 0 : 1)

case "print", "-p":
    guard args.count >= 4 else {
        print("Error: print command requires <image> <device>")
        print("Example: swift run T02PrintTool print test.png /dev/cu.T02-SerialPort")
        exit(1)
    }
    let imagePath = args[2]
    let devicePath = args[3]
    let feedLines = args.count > 4 ? Int(args[4]) ?? 4 : 4

    let success = tool.printImage(imagePath: imagePath, devicePath: devicePath, feedLines: feedLines)
    exit(success ? 0 : 1)

case "demo", "--demo", "-d":
    guard args.count >= 3 else {
        print("Error: demo command requires <device>")
        print("Example: swift run T02PrintTool demo /dev/cu.T02-SerialPort")
        exit(1)
    }
    let devicePath = args[2]
    let success = tool.runDemo(devicePath: devicePath)
    exit(success ? 0 : 1)

case "create", "--create", "-c":
    guard args.count >= 3 else {
        print("Error: create command requires <output.png>")
        print("Example: swift run T02PrintTool create test.png")
        exit(1)
    }
    let outputPath = args[2]
    tool.createTestImage(outputPath: outputPath)

case "debug", "--debug":
    guard args.count >= 3 else {
        print("Error: debug command requires <image>")
        print("Example: swift run T02PrintTool debug test.png")
        exit(1)
    }
    let imagePath = args[2]
    let outputPath = args.count > 3 ? args[3] : nil
    tool.debugProtocol(imagePath: imagePath, outputPath: outputPath)

case "help", "--help", "-h":
    printUsage()

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
