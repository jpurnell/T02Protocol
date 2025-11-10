import Foundation
import CoreBluetooth

/// CoreBluetooth-based connection to T02 printer (like the iOS app uses)
class CoreBluetoothConnection: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    private var centralManager: CBCentralManager!
    private var printer: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    private var isScanning = false
    private var isConnected = false
    private var dataToSend: Data?
    private var sendCompletion: ((Result<Void, Error>) -> Void)?

    enum BTError: Error {
        case notFound
        case connectionFailed
        case noWriteCharacteristic
        case sendFailed(String)
        case timeout
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Connect to T02 and send data
    func connectAndSend(_ data: Data, timeout: TimeInterval = 30.0) throws {
        print("    🔍 Starting CoreBluetooth scan for T02...")
        fflush(stdout)

        dataToSend = data
        var result: Result<Void, Error>? = nil

        // Set completion handler
        sendCompletion = { res in
            result = res
        }

        // Wait for Bluetooth to be ready
        let startTime = Date()
        while centralManager.state != .poweredOn {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            if Date().timeIntervalSince(startTime) > 5.0 {
                throw BTError.timeout
            }
        }

        print("    ✓ Bluetooth powered on")
        fflush(stdout)

        // Scan for T02
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        // Wait for connection and send to complete
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

            // Check if we completed
            if let result = result {
                switch result {
                case .success:
                    return
                case .failure(let error):
                    throw error
                }
            }

            // Check for early errors
            if !isScanning && printer == nil {
                throw BTError.notFound
            }
        }

        throw BTError.timeout
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("    ℹ️  Bluetooth state: \(central.state.rawValue)")
        fflush(stdout)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // Debug: log all discovered devices
        print("    🔍 Discovered: \(peripheral.name ?? "unnamed") (\(peripheral.identifier))")
        fflush(stdout)

        guard let name = peripheral.name, name.uppercased().contains("T02") || name.uppercased().contains("PHOMEMO") else {
            return
        }

        print("    ✓ Found T02 printer: \(name) (\(peripheral.identifier))")
        fflush(stdout)

        // Stop scanning
        centralManager.stopScan()
        isScanning = false

        // Connect
        printer = peripheral
        peripheral.delegate = self

        print("    🔌 Connecting to \(name)...")
        fflush(stdout)

        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("    ✓ Connected!")
        fflush(stdout)

        isConnected = true

        print("    🔍 Discovering services...")
        fflush(stdout)

        // Discover all services
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("    ❌ Connection failed: \(error?.localizedDescription ?? "unknown")")
        fflush(stdout)

        sendCompletion?(.failure(error ?? BTError.connectionFailed))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("    🔌 Disconnected")
        fflush(stdout)

        isConnected = false
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("    ❌ Service discovery failed: \(error.localizedDescription)")
            fflush(stdout)
            sendCompletion?(.failure(error))
            return
        }

        guard let services = peripheral.services else {
            sendCompletion?(.failure(BTError.noWriteCharacteristic))
            return
        }

        print("    ✓ Found \(services.count) service(s)")
        fflush(stdout)

        // Discover characteristics for all services
        for service in services {
            print("    ℹ️  Service: \(service.uuid)")
            fflush(stdout)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("    ❌ Characteristic discovery failed: \(error.localizedDescription)")
            fflush(stdout)
            return
        }

        guard let characteristics = service.characteristics else { return }

        print("    ✓ Service \(service.uuid) has \(characteristics.count) characteristic(s)")
        fflush(stdout)

        // Look for write characteristic
        for characteristic in characteristics {
            let props = characteristic.properties
            print("    ℹ️  Characteristic: \(characteristic.uuid) properties: \(props.rawValue)")
            fflush(stdout)

            // Check if writable
            if props.contains(.write) || props.contains(.writeWithoutResponse) {
                print("    ✓ Found writable characteristic: \(characteristic.uuid)")
                fflush(stdout)

                writeCharacteristic = characteristic

                // Send data
                if let data = dataToSend {
                    sendData(data, to: peripheral, characteristic: characteristic)
                }
                return
            }
        }
    }

    private func sendData(_ data: Data, to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("    📤 Sending \(data.count) bytes...")
        fflush(stdout)

        // Determine write type - prefer with response for reliability
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse

        print("    ℹ️  Using write type: \(writeType == .withResponse ? "with response" : "without response")")
        fflush(stdout)

        // Send in small chunks - BLE printers need small chunks
        let chunkSize = 20  // Very conservative - typical BLE MTU is 20-23 bytes
        var offset = 0

        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data[offset..<(offset + length)]

            peripheral.writeValue(chunk, for: characteristic, type: writeType)

            offset += length

            if offset % 1000 == 0 || offset == data.count {
                print("    ℹ️  Sent \(offset)/\(data.count) bytes (\(offset * 100 / data.count)%)")
                fflush(stdout)
            }

            // Important: Give the printer time to process each chunk
            // BLE printers are slow and need time between packets
            usleep(50000) // 50ms delay between chunks (conservative)

            // Let the run loop process events
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
        }

        print("    ✓ All data sent!")
        fflush(stdout)

        // Wait for printer to finish processing
        print("    ⏳ Waiting for printer to process...")
        fflush(stdout)
        sleep(5) // Give it more time to print

        // Disconnect
        centralManager.cancelPeripheralConnection(peripheral)

        sendCompletion?(.success(()))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("    ❌ Write error: \(error.localizedDescription)")
            fflush(stdout)
            sendCompletion?(.failure(error))
        }
    }
}
