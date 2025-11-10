import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

/// T02 Thermal Printer Protocol
///
/// Platform-independent implementation of the Phomemo T02 thermal printer protocol.
/// This is a Swift port of the Python reference implementation, maintaining byte-for-byte
/// compatibility.
///
/// Protocol: EPSON ESC/POS subset
/// Printer: Phomemo T02 (50mm width, 203 DPI, Bluetooth)
public struct T02Protocol {

    // MARK: - T02 Hardware Specifications

    /// Printer width in dots (50mm at 203 DPI)
    public static let widthDots: Int = 384

    /// Bytes required per line (widthDots / 8)
    public static let widthBytes: Int = 48

    /// Printer resolution (dots per inch)
    public static let dpi: Int = 203

    // MARK: - Protocol Limitations

    /// Maximum lines per GS v 0 command (ESC/POS limitation)
    public static let maxLinesPerBlock: Int = 255

    // MARK: - T02 Default Settings

    /// Default paper feed after printing (T02 specific)
    public static let defaultFeedLines: Int = 4

    // MARK: - ESC/POS Command Bytes

    private static let ESC: UInt8 = 0x1b
    private static let GS: UInt8 = 0x1d

    // MARK: - Initialization

    public init() {
        // TODO: Implement
    }

    // MARK: - Command Generation

    /// Generate ESC @ command to initialize the printer
    public func cmdInitPrinter() -> Data {
        return Data([Self.ESC, 0x40])
    }

    /// Generate ESC a command to set text justification
    public func cmdSetJustification(_ position: Justification) -> Data {
        return Data([Self.ESC, 0x61, position.rawValue])
    }

    /// Generate ESC d command to feed paper N lines
    public func cmdFeedLines(_ lines: Int) throws -> Data {
        guard lines >= 0 else {
            throw T02ProtocolError.invalidParameter("Feed lines cannot be negative: \(lines)")
        }
        guard lines <= 255 else {
            throw T02ProtocolError.invalidParameter("Feed lines cannot exceed 255: \(lines)")
        }
        return Data([Self.ESC, 0x64, UInt8(lines)])
    }

    /// Generate GS v 0 command header for raster bit image
    public func cmdRasterHeader(widthBytes: Int, lines: Int, mode: PrintMode) -> Data {
        var data = Data()
        data.append(Self.GS)
        data.append(0x76)
        data.append(0x30)
        data.append(mode.rawValue)

        // Width in little-endian 16-bit
        data.append(UInt8(widthBytes & 0xFF))
        data.append(UInt8((widthBytes >> 8) & 0xFF))

        // Lines in little-endian 16-bit
        data.append(UInt8(lines & 0xFF))
        data.append(UInt8((lines >> 8) & 0xFF))

        return data
    }

    // MARK: - Image Conversion

    /// Convert a platform image to T02-compatible 1-bit monochrome format
    ///
    /// Process:
    /// 1. Resize to 384 pixels wide (maintaining aspect ratio)
    /// 2. Convert to grayscale
    /// 3. Invert colors (thermal printers print black on white)
    /// 4. Convert to 1-bit monochrome
    ///
    /// - Parameter image: Input platform image (any size/color)
    /// - Returns: Converted CGImage (384px wide, 1-bit monochrome)
    public func convertImage(_ image: PlatformImage) throws -> CGImage {
        // Get CGImage from platform image
        #if canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw T02ProtocolError.invalidImage("Cannot get CGImage from NSImage")
        }
        #elseif canImport(UIKit)
        guard let cgImage = image.cgImage else {
            throw T02ProtocolError.invalidImage("Cannot get CGImage from UIImage")
        }
        #endif

        // Step 1: Resize to 384 pixels wide (maintaining aspect ratio)
        let sourceWidth = cgImage.width
        let sourceHeight = cgImage.height

        let targetWidth = Self.widthDots
        let aspectRatio = CGFloat(sourceHeight) / CGFloat(sourceWidth)
        let targetHeight = Int(CGFloat(targetWidth) * aspectRatio)

        // Step 2: Create grayscale context and draw resized image
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw T02ProtocolError.conversionFailed("Cannot create grayscale context")
        }

        // Draw image into context (this also resizes and converts to grayscale)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let grayscaleImage = context.makeImage() else {
            throw T02ProtocolError.conversionFailed("Cannot create grayscale image")
        }

        // Step 3 & 4: Invert and convert to 1-bit monochrome
        return try invertAndConvertTo1Bit(grayscaleImage)
    }

    /// Invert colors and convert to 1-bit monochrome
    private func invertAndConvertTo1Bit(_ image: CGImage) throws -> CGImage {
        let width = image.width
        let height = image.height

        // Read grayscale data
        guard let grayscaleData = image.dataProvider?.data as Data? else {
            throw T02ProtocolError.conversionFailed("Cannot get image data")
        }

        // Create 1-bit monochrome bitmap (1 bit per pixel)
        let bytesPerRow = (width + 7) / 8  // Round up to nearest byte
        var monochromeBitmap = [UInt8](repeating: 0, count: bytesPerRow * height)

        // Convert each pixel: invert (255 - value), then threshold to 1-bit
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let grayscaleValue = grayscaleData[pixelIndex]

                // Invert: black (0) becomes white (255), white (255) becomes black (0)
                let inverted = 255 - grayscaleValue

                // Threshold at 128: values >= 128 become 1 (print), < 128 become 0 (no print)
                let bit: UInt8 = inverted >= 128 ? 1 : 0

                // Pack into bytes (MSB first)
                let byteIndex = y * bytesPerRow + x / 8
                let bitPosition = 7 - (x % 8)  // MSB first

                if bit == 1 {
                    monochromeBitmap[byteIndex] |= (1 << bitPosition)
                }
            }
        }

        // Create 1-bit CGImage from bitmap
        let bitmapData = Data(monochromeBitmap)
        guard let dataProvider = CGDataProvider(data: bitmapData as CFData) else {
            throw T02ProtocolError.conversionFailed("Cannot create data provider")
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let monochromeImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 1,
            bitsPerPixel: 1,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw T02ProtocolError.conversionFailed("Cannot create monochrome image")
        }

        return monochromeImage
    }

    /// Extract bitmap data from a CGImage
    ///
    /// - Parameter image: Monochrome CGImage
    /// - Returns: Raw bitmap data (packed bytes)
    public func getBitmapData(from image: CGImage) throws -> Data {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data as Data? else {
            throw T02ProtocolError.conversionFailed("Cannot get bitmap data from image")
        }
        return data
    }

    // MARK: - Full Protocol Generation

    /// Generate complete T02 print data from an image
    ///
    /// This is the main method that combines all protocol commands to produce
    /// a complete data stream ready to send to the printer.
    ///
    /// Process:
    /// 1. Initialize printer (ESC @)
    /// 2. Set center justification (ESC a 1)
    /// 3. Convert and send image in blocks (GS v 0)
    /// 4. Feed paper (ESC d n)
    ///
    /// - Parameters:
    ///   - image: Platform image to print
    ///   - feedLines: Number of lines to feed after printing (default: 4 for T02)
    /// - Returns: Complete print data stream
    public func generatePrintData(from image: PlatformImage, feedLines: Int? = nil) throws -> Data {
        let feedLinesToUse = feedLines ?? Self.defaultFeedLines

        // Convert image to printer format
        let converted = try convertImage(image)

        // Get bitmap data
        let bitmapData = try getBitmapData(from: converted)
        let totalLines = converted.height

        // Build output data
        var output = Data()

        // Header: Initialize and set justification
        output.append(cmdInitPrinter())
        output.append(cmdSetJustification(.center))

        // Send image in blocks (max 255 lines per block due to protocol limitation)
        var currentLine = 0
        while currentLine < totalLines {
            // Calculate lines in this block
            let remainingLines = totalLines - currentLine
            let blockLines = min(remainingLines, Self.maxLinesPerBlock)

            // Generate raster header
            output.append(cmdRasterHeader(widthBytes: Self.widthBytes, lines: blockLines, mode: .normal))

            // Extract and append bitmap data for this block
            let startByte = currentLine * Self.widthBytes
            let endByte = startByte + (blockLines * Self.widthBytes)
            output.append(bitmapData[startByte..<endByte])

            currentLine += blockLines
        }

        // Footer: Feed paper
        output.append(try cmdFeedLines(feedLinesToUse))

        return output
    }
}

// MARK: - Supporting Types

/// Text justification options
public enum Justification {
    case left
    case center
    case right

    var rawValue: UInt8 {
        switch self {
        case .left: return 0
        case .center: return 1
        case .right: return 2
        }
    }
}

/// Print mode options for raster images
public enum PrintMode {
    case normal
    case doubleWidth
    case doubleHeight
    case quadruple

    var rawValue: UInt8 {
        switch self {
        case .normal: return 0
        case .doubleWidth: return 1
        case .doubleHeight: return 2
        case .quadruple: return 3
        }
    }
}

/// T02 Protocol errors
public enum T02ProtocolError: Error, CustomStringConvertible {
    case invalidParameter(String)
    case conversionFailed(String)
    case invalidImage(String)

    public var description: String {
        switch self {
        case .invalidParameter(let msg): return "Invalid parameter: \(msg)"
        case .conversionFailed(let msg): return "Conversion failed: \(msg)"
        case .invalidImage(let msg): return "Invalid image: \(msg)"
        }
    }
}

// MARK: - Platform Image Extensions

extension PlatformImage {
    public var width: Int {
        #if canImport(AppKit)
        return Int(self.size.width)
        #elseif canImport(UIKit)
        return Int(self.size.width * self.scale)
        #endif
    }

    public var height: Int {
        #if canImport(AppKit)
        return Int(self.size.height)
        #elseif canImport(UIKit)
        return Int(self.size.height * self.scale)
        #endif
    }
}
