import Testing
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import T02Protocol

/// Test-Driven Development tests for T02 Protocol in Swift
///
/// These tests mirror the Python test suite and define the expected behavior
/// before implementation. They use Swift Testing's modern @Test syntax.

// MARK: - Constants Tests

@Suite("T02 Protocol Constants")
struct T02ProtocolConstantsTests {

    @Test("Printer width is 384 dots (50mm at 203 DPI)")
    func printerWidthDots() {
        #expect(T02Protocol.widthDots == 384)
    }

    @Test("Printer requires 48 bytes per line (384 dots / 8)")
    func printerWidthBytes() {
        #expect(T02Protocol.widthBytes == 48)
    }

    @Test("Printer resolution is 203 DPI")
    func printerDPI() {
        #expect(T02Protocol.dpi == 203)
    }

    @Test("Protocol supports maximum 255 lines per raster block")
    func maxLinesPerBlock() {
        #expect(T02Protocol.maxLinesPerBlock == 255)
    }

    @Test("Default feed for T02 is 4 lines")
    func defaultFeedLines() {
        #expect(T02Protocol.defaultFeedLines == 4)
    }
}

// MARK: - Command Generation Tests

@Suite("T02 Protocol Commands")
struct T02ProtocolCommandsTests {

    @Test("ESC @ command initializes the printer")
    func initPrinterCommand() {
        let proto = T02Protocol()
        let cmd = proto.cmdInitPrinter()
        #expect(cmd == Data([0x1b, 0x40]))
    }

    @Test("ESC a 1 command sets center justification")
    func centerJustificationCommand() {
        let proto = T02Protocol()
        let cmd = proto.cmdSetJustification(.center)
        #expect(cmd == Data([0x1b, 0x61, 0x01]))
    }

    @Test("ESC a 0 command sets left justification")
    func leftJustificationCommand() {
        let proto = T02Protocol()
        let cmd = proto.cmdSetJustification(.left)
        #expect(cmd == Data([0x1b, 0x61, 0x00]))
    }

    @Test("ESC a 2 command sets right justification")
    func rightJustificationCommand() {
        let proto = T02Protocol()
        let cmd = proto.cmdSetJustification(.right)
        #expect(cmd == Data([0x1b, 0x61, 0x02]))
    }

    @Test("ESC d 4 command feeds 4 lines (T02 default)")
    func feedCommandDefault() throws {
        let proto = T02Protocol()
        let cmd = try proto.cmdFeedLines(4)
        #expect(cmd == Data([0x1b, 0x64, 0x04]))
    }

    @Test("ESC d N command feeds N lines")
    func feedCommandCustom() throws {
        let proto = T02Protocol()
        let cmd = try proto.cmdFeedLines(10)
        #expect(cmd == Data([0x1b, 0x64, 0x0a]))
    }

    @Test("GS v 0 header for single line of raster data")
    func rasterHeaderSingleLine() {
        let proto = T02Protocol()
        let cmd = proto.cmdRasterHeader(widthBytes: 48, lines: 1, mode: .normal)

        let expected = Data([
            0x1d, 0x76, 0x30, 0x00,  // GS v 0
            0x30, 0x00,               // Width: 48 bytes (little-endian)
            0x01, 0x00                // Lines: 1 (little-endian)
        ])

        #expect(cmd == expected)
    }

    @Test("GS v 0 header for maximum 255 lines")
    func rasterHeaderMaxLines() {
        let proto = T02Protocol()
        let cmd = proto.cmdRasterHeader(widthBytes: 48, lines: 255, mode: .normal)

        let expected = Data([
            0x1d, 0x76, 0x30, 0x00,
            0x30, 0x00,
            0xff, 0x00
        ])

        #expect(cmd == expected)
    }

    @Test("GS v 0 with mode 1 (double width)")
    func rasterHeaderDoubleWidthMode() {
        let proto = T02Protocol()
        let cmd = proto.cmdRasterHeader(widthBytes: 48, lines: 100, mode: .doubleWidth)

        // Mode byte should be 0x01
        #expect(cmd[3] == 0x01)
    }
}

// MARK: - Image Conversion Tests

@Suite("T02 Image Conversion")
struct T02ImageConversionTests {

    @Test("Solid black image converts to all 0xFF bytes")
    func convertSolidBlackImage() throws {
        let proto = T02Protocol()

        // Load test fixture
        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "solid_black", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load solid_black.png fixture")
            return
        }

        let converted = try proto.convertImage(image)

        // Should be 384 pixels wide
        #expect(converted.width == 384)

        // All pixels should be 1 (print) after inversion
        let bitmapData = try proto.getBitmapData(from: converted)
        #expect(bitmapData.allSatisfy { $0 == 0xFF })
    }

    @Test("Solid white image converts to all 0x00 bytes")
    func convertSolidWhiteImage() throws {
        let proto = T02Protocol()

        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "solid_white", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load solid_white.png fixture")
            return
        }

        let converted = try proto.convertImage(image)

        #expect(converted.width == 384)

        // All pixels should be 0 (no print) after inversion
        let bitmapData = try proto.getBitmapData(from: converted)
        #expect(bitmapData.allSatisfy { $0 == 0x00 })
    }

    @Test("Image is resized to 384 pixels wide", arguments: [
        (200, 100),
        (100, 50),
        (800, 400),
        (384, 200)  // Already correct width
    ])
    func imageResizesToPrinterWidth(size: (Int, Int)) throws {
        let proto = T02Protocol()

        // Create test image of specified size
        let image = createTestImage(width: size.0, height: size.1, color: .gray)

        let converted = try proto.convertImage(image)

        #expect(converted.width == 384)
    }

    @Test("Image resizing maintains aspect ratio")
    func imageMaintainsAspectRatio() throws {
        let proto = T02Protocol()

        // Create 200x100 image (2:1 ratio)
        let image = createTestImage(width: 200, height: 100, color: .gray)

        let converted = try proto.convertImage(image)

        // At 384 width, height should be approximately 192 (2:1 ratio)
        let expectedHeight = Int(100 * (384.0 / 200.0))
        #expect(converted.height == expectedHeight)
    }

    @Test("Converted image data size matches expected")
    func imageDataSize() throws {
        let proto = T02Protocol()

        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "solid_black", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load solid_black.png fixture")
            return
        }

        let converted = try proto.convertImage(image)

        // 384 dots wide = 48 bytes per line
        // 100 lines tall
        // Total: 4800 bytes
        let bitmapData = try proto.getBitmapData(from: converted)
        #expect(bitmapData.count == 48 * 100)
    }
}

// MARK: - Full Protocol Generation Tests

@Suite("T02 Protocol Generation")
struct T02ProtocolGenerationTests {

    @Test("Generate complete protocol for solid black image")
    func generateProtocolSolidBlack() throws {
        let proto = T02Protocol()

        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "solid_black", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load solid_black.png fixture")
            return
        }

        let output = try proto.generatePrintData(from: image, feedLines: 4)

        // Check header
        #expect(output[0..<2] == Data([0x1b, 0x40]))           // ESC @ init
        #expect(output[2..<5] == Data([0x1b, 0x61, 0x01]))    // ESC a 1 center

        // Check raster header
        #expect(output[5..<9] == Data([0x1d, 0x76, 0x30, 0x00]))   // GS v 0
        #expect(output[9..<11] == Data([0x30, 0x00]))              // Width: 48
        #expect(output[11..<13] == Data([0x64, 0x00]))             // Lines: 100

        // Check image data (48 * 100 = 4800 bytes of 0xFF)
        let imageData = output[13..<13+4800]
        #expect(imageData.count == 4800)
        #expect(imageData.allSatisfy { $0 == 0xFF })

        // Check footer
        let footerStart = 13 + 4800
        #expect(output[footerStart..<footerStart+3] == Data([0x1b, 0x64, 0x04]))  // Feed 4
    }

    @Test("Generate protocol for single-line image")
    func generateProtocolSingleLine() throws {
        let proto = T02Protocol()

        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "single_line", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load single_line.png fixture")
            return
        }

        let output = try proto.generatePrintData(from: image, feedLines: 2)

        // Find raster lines count
        #expect(output[11..<13] == Data([0x01, 0x00]))  // Lines: 1

        // Image data should be 48 bytes (1 line)
        let imageData = output[13..<13+48]
        #expect(imageData.count == 48)

        // Footer should have custom feed
        let footerStart = 13 + 48
        #expect(output[footerStart..<footerStart+3] == Data([0x1b, 0x64, 0x02]))  // Feed 2
    }

    @Test("Generate protocol for large image (multi-block)")
    func generateProtocolLargeImageMultiBlock() throws {
        let proto = T02Protocol()

        let bundle = Bundle.module
        guard let imageURL = bundle.url(forResource: "large_image", withExtension: "png", subdirectory: "Fixtures"),
              let image = loadImage(from: imageURL) else {
            Issue.record("Failed to load large_image.png fixture")
            return
        }

        let output = try proto.generatePrintData(from: image, feedLines: 4)

        // Should contain multiple raster blocks
        // Look for first raster header
        guard let firstBlockIdx = output.firstRange(of: Data([0x1d, 0x76, 0x30, 0x00]))?.lowerBound else {
            Issue.record("First raster block not found")
            return
        }

        // Check first block has 255 lines
        #expect(output[firstBlockIdx+6..<firstBlockIdx+8] == Data([0xff, 0x00]))

        // Look for second raster header (after first block data)
        let secondBlockStart = firstBlockIdx + 8 + (48 * 255)
        #expect(output[secondBlockStart..<secondBlockStart+4] == Data([0x1d, 0x76, 0x30, 0x00]))

        // Second block should have remaining lines (300 - 255 = 45)
        #expect(output[secondBlockStart+6..<secondBlockStart+8] == Data([0x2d, 0x00]))
    }
}

// MARK: - Edge Cases and Error Handling

@Suite("T02 Protocol Edge Cases")
struct T02ProtocolEdgeCasesTests {

    @Test("Negative feed lines throws error")
    func negativeFeedLinesThrowsError() {
        let proto = T02Protocol()

        #expect(throws: T02ProtocolError.self) {
            _ = try proto.cmdFeedLines(-1)
        }
    }

    @Test("Feed lines > 255 throws error")
    func feedLinesTooLargeThrowsError() {
        let proto = T02Protocol()

        #expect(throws: T02ProtocolError.self) {
            _ = try proto.cmdFeedLines(256)
        }
    }

    @Test("Very wide image resizes to printer width")
    func veryWideImageResizes() throws {
        let proto = T02Protocol()

        // Create huge image (10000x100)
        let image = createTestImage(width: 10000, height: 100, color: .gray)

        let converted = try proto.convertImage(image)

        #expect(converted.width == 384)
    }

    @Test("Very tall image processes in multiple blocks")
    func veryTallImageProcesses() throws {
        let proto = T02Protocol()

        // Create 1000-line image
        let image = createTestImage(width: 384, height: 1000, color: .white)

        let output = try proto.generatePrintData(from: image, feedLines: 4)

        // Should complete without error
        #expect(output.count > 0)

        // Should contain multiple blocks (1000 / 255 = 4 blocks)
        let rasterBlockPattern = Data([0x1d, 0x76, 0x30, 0x00])
        var count = 0
        var searchRange = output.startIndex..<output.endIndex

        while let range = output[searchRange].firstRange(of: rasterBlockPattern) {
            count += 1
            searchRange = range.upperBound..<output.endIndex
        }

        #expect(count == 4)  // ceil(1000 / 255)
    }
}

// MARK: - Helper Functions

func loadImage(from url: URL) -> PlatformImage? {
    #if canImport(AppKit)
    return NSImage(contentsOf: url)
    #elseif canImport(UIKit)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
    #endif
}

func createTestImage(width: Int, height: Int, color: ImageColor) -> PlatformImage {
    let cgImage = createCGImage(width: width, height: height, color: color)

    #if canImport(AppKit)
    return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    #elseif canImport(UIKit)
    return UIImage(cgImage: cgImage)
    #endif
}

func createCGImage(width: Int, height: Int, color: ImageColor) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )!

    let grayValue: CGFloat
    switch color {
    case .black: grayValue = 0.0
    case .white: grayValue = 1.0
    case .gray: grayValue = 0.5
    }

    context.setFillColor(gray: grayValue, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    return context.makeImage()!
}

enum ImageColor {
    case black, white, gray
}
