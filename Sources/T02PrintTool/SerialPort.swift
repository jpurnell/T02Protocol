import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Serial port communication helper for T02 printer
struct SerialPort {
    let path: String

    enum SerialPortError: Error {
        case openFailed(String)
        case writeFailed(String)
    }

    /// Send data to printer
    /// Uses POSIX file operations to match Python's behavior
    func sendAndWait(_ data: Data, timeout: TimeInterval = 8.0) throws {
        print("    📤 Opening \(path)...")
        fflush(stdout)

        // Open device using POSIX open with O_NOCTTY to avoid blocking
        // O_NOCTTY prevents the device from becoming the controlling terminal
        let fd = open(path, O_WRONLY | O_NOCTTY)
        guard fd >= 0 else {
            let error = String(cString: strerror(errno))
            throw SerialPortError.openFailed("Cannot open \(path): \(error)")
        }

        defer {
            close(fd)
        }

        print("    📤 Sending \(data.count) bytes...")
        fflush(stdout)

        // Write data using POSIX write
        let bytesWritten = data.withUnsafeBytes { buffer in
            Darwin.write(fd, buffer.baseAddress, data.count)
        }

        guard bytesWritten == data.count else {
            throw SerialPortError.writeFailed("Only wrote \(bytesWritten) of \(data.count) bytes")
        }

        print("    ✓ Sent \(bytesWritten) bytes")
        print("    ⏳ Giving printer time to process...")
        fflush(stdout)

        // Give printer time to process and print
        sleep(2)
    }
}
