#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import Foundation

/// Reads ambient light level from a BH1750 sensor over I2C on Raspberry Pi.
///
/// Wiring (I2C1 on the 40-pin header):
///   VCC  -> 3.3V (pin 1)
///   GND  -> GND (pin 6)
///   SCL  -> SCL1 (pin 5, GPIO3)
///   SDA  -> SDA1 (pin 3, GPIO2)
///   ADDR -> GND for address 0x23, or 3.3V for address 0x5C
///
/// Make sure I2C is enabled (`sudo raspi-config` -> Interface Options -> I2C)
/// and that `/dev/i2c-1` is readable by the running user (or run with sudo).
///
/// This class only talks to real I2C hardware on Linux. On other platforms
/// (e.g. macOS during development) every operation fails fast with
/// `.deviceUnavailable` instead of trying to call Linux-only APIs.
final class BrightnessProvider {
    enum BrightnessError: Error, CustomStringConvertible {
        case deviceUnavailable
        case deviceOpenFailed(String)
        case ioctlFailed(String)
        case writeFailed(String)
        case readFailed(String)

        var description: String {
            switch self {
            case .deviceUnavailable: return "I2C device is not available on this platform"
            case .deviceOpenFailed(let path): return "Failed to open I2C device at \(path)"
            case .ioctlFailed(let msg): return "ioctl failed: \(msg)"
            case .writeFailed(let msg): return "Write to sensor failed: \(msg)"
            case .readFailed(let msg): return "Read from sensor failed: \(msg)"
            }
        }
    }

    /// Common BH1750 addresses: 0x23 (ADDR pin low/floating) or 0x5C (ADDR pin high).
    enum Address: UInt8 {
        case low = 0x23
        case high = 0x5C
    }

    /// BH1750 operating modes. "H-Resolution" modes give 1 lx resolution.
    /// Continuous modes keep measuring; One-Time modes power down after one read.
    enum Mode: UInt8 {
        case continuousHighRes = 0x10  // 1 lx resolution, ~120ms
        case continuousHighRes2 = 0x11  // 0.5 lx resolution, ~120ms
        case continuousLowRes = 0x13  // 4 lx resolution, ~16ms
        case oneTimeHighRes = 0x20
        case oneTimeHighRes2 = 0x21
        case oneTimeLowRes = 0x23
    }

    private static let I2C_SLAVE: UInt = 0x0703

    private let devicePath: String
    private let address: Address
    private let mode: Mode
    private var fileDescriptor: Int32 = -1

    init(devicePath: String = "/dev/i2c-1", address: Address = .low, mode: Mode = .continuousHighRes) throws {
        self.devicePath = devicePath
        self.address = address
        self.mode = mode

        guard FileManager.default.fileExists(atPath: devicePath) else {
            throw BrightnessError.deviceUnavailable
        }
    }

    deinit {
        close()
    }

    /// Opens the I2C bus device and selects the sensor's slave address.
    ///
    /// Fails immediately with `.deviceUnavailable` if the bus device doesn't
    /// exist (always true on non-Linux platforms, and possible on Linux too
    /// if I2C isn't enabled).
    func open() throws {
        guard FileManager.default.fileExists(atPath: devicePath) else {
            throw BrightnessError.deviceUnavailable
        }

        #if os(Linux)
            let fd = Glibc.open(devicePath, O_RDWR)
            guard fd >= 0 else {
                let reason = String(cString: strerror(errno))
                throw BrightnessError.deviceOpenFailed("\(devicePath): \(reason)")
            }
            fileDescriptor = fd

            // Third argument must be a fixed-width Int32/CInt, not UInt — Swift's
            // Glibc overlay only provides a non-variadic ioctl overload for CInt
            // (and a couple of pointer variants). Passing UInt doesn't match any
            // overload, which is what produces the "variadic function is
            // unavailable" compile error.
            let result = ioctl(fd, Self.I2C_SLAVE, Int32(address.rawValue))
            guard result >= 0 else {
                close()
                throw BrightnessError.ioctlFailed(String(cString: strerror(errno)))
            }
        #else
            // Should be unreachable in practice (fileExists check above already
            // filters this out on macOS), but keep it explicit and safe.
            throw BrightnessError.deviceUnavailable
        #endif
    }

    /// Closes the underlying file descriptor if open.
    func close() {
        #if os(Linux)
            if fileDescriptor >= 0 {
                Glibc.close(fileDescriptor)
                fileDescriptor = -1
            }
        #endif
    }

    /// Sends the configured measurement mode command to the sensor.
    private func writeMode() throws {
        #if os(Linux)
            var command = mode.rawValue
            let bytesWritten = write(fileDescriptor, &command, 1)
            guard bytesWritten == 1 else {
                throw BrightnessError.writeFailed(String(cString: strerror(errno)))
            }
        #else
            throw BrightnessError.deviceUnavailable
        #endif
    }

    /// Reads a single raw 16-bit measurement (2 bytes, big-endian) from the sensor.
    private func readRawValue() throws -> UInt16 {
        #if os(Linux)
            var buffer = [UInt8](repeating: 0, count: 2)
            let bytesRead = buffer.withUnsafeMutableBytes { ptr -> Int in
                read(fileDescriptor, ptr.baseAddress, 2)
            }
            guard bytesRead == 2 else {
                throw BrightnessError.readFailed(String(cString: strerror(errno)))
            }
            return (UInt16(buffer[0]) << 8) | UInt16(buffer[1])
        #else
            throw BrightnessError.deviceUnavailable
        #endif
    }

    /// Takes a single lux reading. Opens the device if it isn't already open.
    ///
    /// - Returns: Ambient light level in lux.
    func readLux() throws -> Double {
        if fileDescriptor < 0 {
            try open()
        }

        try writeMode()

        // Datasheet: allow the sensor time to complete the measurement before
        // reading it back. High-res modes need up to ~180ms; low-res ~24ms.
        let delayMicroseconds: UInt32
        switch mode {
        case .continuousHighRes, .continuousHighRes2, .oneTimeHighRes, .oneTimeHighRes2:
            delayMicroseconds = 180_000
        case .continuousLowRes, .oneTimeLowRes:
            delayMicroseconds = 24_000
        }
        usleep(delayMicroseconds)

        let raw = try readRawValue()
        // Per BH1750 datasheet, divide raw count by 1.2 to get lux
        // (double the divisor to 2.4 when using an *H2* high-res mode).
        let divisor: Double = (mode == .continuousHighRes2 || mode == .oneTimeHighRes2) ? 2.4 : 1.2
        return Double(raw) / divisor
    }

    /// Async, cancellation-aware version of `startPrintingLoop`.
    ///
    /// Safe to run from a `Task`/`Task.detached`: it suspends between
    /// readings instead of blocking a thread, and stops promptly when the
    /// enclosing task is cancelled.
    ///
    /// - Parameter interval: Seconds between readings.
    func startReadingLoop(
        interval: TimeInterval = 1.0, 
        onRead: @Sendable (_ luxValue: Double) async throws -> Void,
    ) async {
        while !Task.isCancelled {
            do {
                try await onRead(try readLux())
            } catch {
                print("Error reading brightness: \(error)")
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
}