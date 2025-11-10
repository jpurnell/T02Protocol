import Foundation
import IOBluetooth

/// Manages active Bluetooth RFCOMM connection to T02 printer
class BluetoothConnection {
    private var device: IOBluetoothDevice?
    private var rfcommChannel: IOBluetoothRFCOMMChannel?

    enum ConnectionError: Error {
        case deviceNotFound
        case noServices
        case connectionFailed(String)
        case sendFailed(String)
    }

    /// Find and connect to T02 printer
    func connect() throws {
        print("    🔍 Searching for T02 printer...")
        fflush(stdout)

        // Get all paired devices
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            throw ConnectionError.deviceNotFound
        }

        // Find T02
        for dev in devices {
            if let name = dev.name, name.contains("T02") {
                print("    ✓ Found: \(name) (\(dev.addressString ?? "unknown"))")
                fflush(stdout)
                device = dev
                break
            }
        }

        guard let device = device else {
            throw ConnectionError.deviceNotFound
        }

        print("    🔌 Establishing RFCOMM connection...")
        fflush(stdout)

        // Get services - may need to query
        var services = device.services as? [IOBluetoothSDPServiceRecord]

        if services == nil || services?.isEmpty == true {
            print("    ⏳ Performing SDP query...")
            fflush(stdout)

            // Synchronous SDP query
            let result = device.performSDPQuery(nil)
            if result == kIOReturnSuccess {
                services = device.services as? [IOBluetoothSDPServiceRecord]
            }
        }

        guard let services = services, !services.isEmpty else {
            throw ConnectionError.noServices
        }

        print("    ℹ️  Found \(services.count) service(s)")
        fflush(stdout)

        // Try to find RFCOMM channel ID
        var channelID: BluetoothRFCOMMChannelID = 0

        for service in services {
            var channel: BluetoothRFCOMMChannelID = 0
            let result = service.getRFCOMMChannelID(&channel)

            if result == kIOReturnSuccess && channel > 0 {
                channelID = channel
                print("    ✓ Found RFCOMM channel: \(channel)")
                fflush(stdout)
                break
            }
        }

        // If no channel found, try default channel 1
        if channelID == 0 {
            print("    ⚠️  No RFCOMM channel in services, trying channel 1...")
            fflush(stdout)
            channelID = 1
        }

        // Make sure device is connected first
        if !device.isConnected() {
            print("    ⏳ Connecting to device...")
            fflush(stdout)

            let connectResult = device.openConnection()
            if connectResult != kIOReturnSuccess {
                print("    ⚠️  Direct connection failed, continuing anyway...")
                fflush(stdout)
            }
        }

        // Open RFCOMM channel - try async version with completion
        print("    ⏳ Opening RFCOMM channel \(channelID)...")
        fflush(stdout)

        // Use synchronous version
        var channel: IOBluetoothRFCOMMChannel?
        let result = device.openRFCOMMChannelSync(&channel, withChannelID: channelID, delegate: nil)

        if result != kIOReturnSuccess {
            // Try without sync - just use the device's method
            let asyncResult = device.openRFCOMMChannelAsync(&channel, withChannelID: channelID, delegate: nil)
            if asyncResult != kIOReturnSuccess || channel == nil {
                throw ConnectionError.connectionFailed("Failed to open RFCOMM channel (sync: \(result), async: \(asyncResult))")
            }

            // Wait a bit for async connection
            sleep(2)
        }

        guard let channel = channel else {
            throw ConnectionError.connectionFailed("Channel is nil")
        }

        rfcommChannel = channel
        print("    ✓ RFCOMM channel created")
        fflush(stdout)

        // Give the channel time to fully establish connection
        print("    ⏳ Waiting for connection to establish...")
        fflush(stdout)
        sleep(2) // Give it 2 seconds to fully connect

        // Now check if it's open
        if channel.isOpen() {
            print("    ✓ Channel is now open and ready")
            fflush(stdout)
        } else {
            print("    ⚠️  Channel reports not open, but attempting to send anyway...")
            fflush(stdout)
        }
    }

    /// Send data to printer
    func send(_ data: Data) throws {
        guard let channel = rfcommChannel else {
            throw ConnectionError.sendFailed("Not connected")
        }

        print("    📤 Sending \(data.count) bytes in chunks...")
        fflush(stdout)

        // Send data in smaller chunks to avoid buffer overflow
        let chunkSize = 512  // Conservative chunk size for Bluetooth
        var offset = 0
        var totalSent = 0

        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + length))

            // Send chunk
            var mutableChunk = chunk
            let result = mutableChunk.withUnsafeMutableBytes { buffer in
                channel.writeSync(buffer.baseAddress, length: UInt16(length))
            }

            if result != kIOReturnSuccess {
                throw ConnectionError.sendFailed("Write failed at offset \(offset) (error: \(result))")
            }

            totalSent += length
            offset += length

            // Progress indicator
            if totalSent % 2048 == 0 || totalSent == data.count {
                print("    ℹ️  Sent \(totalSent)/\(data.count) bytes (\(totalSent * 100 / data.count)%)")
                fflush(stdout)
            }

            // Small delay between chunks
            usleep(10000) // 10ms
        }

        print("    ✓ Sent all \(totalSent) bytes")
        fflush(stdout)
    }

    /// Close connection
    func disconnect() {
        if let channel = rfcommChannel {
            print("    🔌 Closing connection...")
            fflush(stdout)
            channel.close()
            rfcommChannel = nil
        }
    }

    deinit {
        disconnect()
    }
}
