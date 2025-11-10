# Integrating T02Protocol into Your App

This guide shows how to use the T02Protocol library in your own macOS or iOS applications.

## Swift Package Integration

### Add to Your Project

**Xcode:**
1. File → Add Package Dependencies...
2. Enter repository URL
3. Select T02Protocol package

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/phomemo-tools", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["T02Protocol"]
    )
]
```

## macOS App Example

### Simple Print Function

```swift
import Foundation
import T02Protocol
import CoreBluetooth
import AppKit

class T02Printer: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var printer: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private let protocol = T02Protocol()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func print(image: NSImage, completion: @escaping (Result<Void, Error>) -> Void) {
        // Generate print data
        do {
            let printData = try protocol.generatePrintData(from: image, feedLines: 4)

            // Connect and send
            scanAndConnect { result in
                switch result {
                case .success(let characteristic):
                    self.sendData(printData, to: characteristic, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // ... CBCentralManagerDelegate methods ...
}
```

### SwiftUI Integration

```swift
import SwiftUI
import T02Protocol

struct ContentView: View {
    @StateObject private var printer = T02Printer()
    @State private var selectedImage: NSImage?
    @State private var isPrinting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("T02 Printer")
                .font(.title)

            if let image = selectedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)

                Button(action: printImage) {
                    if isPrinting {
                        ProgressView()
                    } else {
                        Label("Print to T02", systemImage: "printer")
                    }
                }
                .disabled(isPrinting)
            } else {
                Button("Select Image") {
                    selectImage()
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK,
           let url = panel.url,
           let image = NSImage(contentsOf: url) {
            selectedImage = image
            errorMessage = nil
        }
    }

    func printImage() {
        guard let image = selectedImage else { return }

        isPrinting = true
        errorMessage = nil

        printer.print(image: image) { result in
            DispatchQueue.main.async {
                isPrinting = false

                switch result {
                case .success:
                    errorMessage = "✅ Print successful!"
                case .failure(let error):
                    errorMessage = "❌ Print failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

## iOS App Example

### Basic Photo Printer

```swift
import SwiftUI
import T02Protocol
import PhotosUI

struct T02PhotoPrinter: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @StateObject private var printer = T02PrinterManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label("Choose Photo", systemImage: "photo")
                }

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)

                    Button(action: {
                        printer.print(image: image)
                    }) {
                        Label("Print", systemImage: "printer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if printer.isConnected {
                    Label("T02 Connected", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Searching for T02...", systemImage: "magnifyingglass")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .navigationTitle("T02 Printer")
        }
        .onChange(of: selectedPhoto) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .onAppear {
            printer.startScanning()
        }
    }
}

class T02PrinterManager: ObservableObject {
    @Published var isConnected = false
    private let protocol = T02Protocol()

    func print(image: UIImage) {
        // Implementation using CoreBluetooth
    }

    func startScanning() {
        // Start BLE scan
    }
}
```

## Command-Line Tool Example

### Simple CLI Tool

```swift
import Foundation
import T02Protocol
import AppKit

@main
struct PrinterCLI {
    static func main() async throws {
        let args = CommandLine.arguments

        guard args.count > 1 else {
            print("Usage: printer-cli <image.png>")
            return
        }

        let imagePath = args[1]

        guard let image = NSImage(contentsOfFile: imagePath) else {
            print("Error: Could not load image")
            throw CLIError.invalidImage
        }

        print("Generating print data...")
        let protocol = T02Protocol()
        let printData = try protocol.generatePrintData(from: image, feedLines: 4)

        print("Connecting to T02...")
        let printer = T02Printer()
        try await printer.connect()

        print("Printing...")
        try await printer.send(data: printData)

        print("✅ Done!")
    }
}

enum CLIError: Error {
    case invalidImage
}
```

## Protocol-Only Usage

If you just need to generate protocol data (handling Bluetooth yourself):

```swift
import T02Protocol
import UIKit

// Create protocol instance
let protocol = T02Protocol()

// Load your image
let image = UIImage(named: "label")!

// Generate print data
let printData = try protocol.generatePrintData(from: image, feedLines: 4)

// Send via your own Bluetooth implementation
yourBluetoothManager.send(data: printData)
```

## Advanced: Custom Commands

```swift
import T02Protocol

let protocol = T02Protocol()
var commandStream = Data()

// Initialize printer
commandStream.append(protocol.cmdInitPrinter())

// Set alignment
commandStream.append(protocol.cmdSetJustification(.center))

// Add your image data
let image = UIImage(named: "logo")!
let converted = try protocol.convertImage(image)
let bitmap = /* extract bitmap from converted */

// Send raster data
commandStream.append(protocol.cmdRasterHeader(
    widthBytes: 48,
    lines: converted.height,
    mode: .normal
))
commandStream.append(bitmap)

// Feed paper
commandStream.append(try protocol.cmdFeedLines(6))

// Send to printer
bluetoothManager.send(data: commandStream)
```

## Error Handling

```swift
do {
    let printData = try protocol.generatePrintData(from: image, feedLines: 4)
    // ... send data ...
} catch T02Protocol.ProtocolError.imageHeightExceedsMaximum {
    print("Image is too tall")
} catch T02Protocol.ProtocolError.invalidFeedLines {
    print("Feed lines out of range (0-255)")
} catch {
    print("Unknown error: \(error)")
}
```

## Best Practices

### 1. Power Management

Always handle the T02's power-on requirement:

```swift
func printWithRetry(image: UIImage) {
    print("Please power cycle the T02 printer")
    print("Press Enter when ready...")
    _ = readLine()

    print(image: image) { result in
        switch result {
        case .success:
            print("✅ Success!")
        case .failure:
            print("❌ Failed - try power cycling again")
        }
    }
}
```

### 2. Image Preparation

Optimize images before sending:

```swift
func prepareForPrinting(_ image: UIImage) -> UIImage {
    // The protocol handles this, but you can pre-process:
    // - Resize to 384px wide
    // - Increase contrast
    // - Convert to grayscale
    // - Reduce file size

    return image
}
```

### 3. User Feedback

Provide clear status updates:

```swift
func print(image: UIImage, status: @escaping (String) -> Void) {
    status("Preparing image...")
    let printData = try protocol.generatePrintData(from: image)

    status("Scanning for printer...")
    scanForPrinter { printer in

        status("Connecting...")
        connect(to: printer) {

            status("Printing...")
            send(printData) {

                status("✅ Complete!")
            }
        }
    }
}
```

## Complete App Example

See the `T02PrintTool` source code for a complete working example:
- `Sources/T02PrintTool/main.swift` - CLI interface
- `Sources/T02PrintTool/CoreBluetoothConnection.swift` - BLE handling

## Resources

- **Protocol Documentation**: See `T02Protocol.swift` for full API
- **Test Suite**: `Tests/T02ProtocolTests/` for examples
- **Command-Line Tool**: Working reference implementation
- **Quick Start**: `QUICK_START_T02.md` for user instructions

## Support

For questions or issues:
1. Check the Quick Start Guide
2. Review test cases for examples
3. File an issue on GitHub

---

Happy printing! 🖨️
