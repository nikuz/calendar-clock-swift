import Foundation
import SwiftyGPIO

private let RASPBERRY_BOARD = SupportedBoard.RaspberryPi3
private let I2C_BUS = 1  // Your I2C bus number (e.g., 1 for Raspberry Pi)
private let SENSOR_ADDR = 0x23  // Default BH1750 address

// BH1750 Commands
private let POWER_ON: UInt8 = 0x01
private let POWER_OFF: UInt8 = 0x00
private let ONE_TIME_HIGH_RES: UInt8 = 0x20
private let CONTINUOUS_HIGH_RES: UInt8 = 0x10

// Measurement time for High-Res modes (max typical)
// Datasheet says 180ms max, add a small buffer.
private let MEASUREMENT_TIME_MAX_S = 0.2 // seconds (200ms)

private enum BrightnessError: Error {
    case deviceUnavailable
    case i2cUnavailable
    case deviceNotReachable
    case readFailed
}

actor BrightnessProvider {
    let bus: I2CInterface

    init() throws {
        let devicePath = "/dev/i2c-\(I2C_BUS)"
        guard FileManager.default.fileExists(atPath: devicePath) else {
            throw BrightnessError.deviceUnavailable
        }

        guard let i2cs = SwiftyGPIO.hardwareI2Cs(for: RASPBERRY_BOARD), I2C_BUS < i2cs.count else {
            throw BrightnessError.i2cUnavailable
        }

        self.bus = i2cs[I2C_BUS]

        guard bus.isReachable(SENSOR_ADDR) else {
            throw BrightnessError.deviceNotReachable
        }
    }

    deinit {
        bus.writeByte(SENSOR_ADDR, value: POWER_OFF)
    }

    func initContinuousHighResMode() async throws {
        bus.writeByte(SENSOR_ADDR, value: POWER_ON)
        try await Task.sleep(for: .seconds(0.01))

        bus.writeByte(SENSOR_ADDR, value: CONTINUOUS_HIGH_RES)
        // Measurement time for High-Res modes (max typical)
        // Datasheet says 180ms max, add a small buffer.
        try await Task.sleep(for: .seconds(0.2))
    }

    func readLux() async throws -> Double {
        let data = bus.readI2CData(SENSOR_ADDR, command: 0x00)
        guard data.count == 2 else {
            throw BrightnessError.readFailed
        }

        // let data = bus.readData(SENSOR_ADDR, command: 0x00)
        // let rawValue = (data[0] << 8) | data[1]
        let rawValue = (UInt16(data[0]) << 8) | UInt16(data[1])

        print(rawValue)

        // Per BH1750 datasheet, divide raw count by 1.2 to get lux.
        return Double(rawValue) / 1.2
    }
}