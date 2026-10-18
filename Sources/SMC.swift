import Foundation
import IOKit

/// Minimal read-only client for the System Management Controller, the chip
/// that measures power on Macs. Its power sensors update about once a second,
/// far faster than the battery gas gauge in the IORegistry (which can sit on
/// the same value for 30s+). Reading needs no root.
final class SMC {
    // Mirrors the C `SMCKeyData_t` the AppleSMC user client expects. The
    // explicit padding keeps Swift's layout identical to C's (80 bytes);
    // without it Swift packs fields into KeyInfo's tail padding and the
    // kernel rejects the call as a bad argument.
    private struct KeyDataVer { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct PLimitData { var version: UInt16 = 0, length: UInt16 = 0; var cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    private struct KeyInfo {
        var dataSize: UInt32 = 0, dataType: UInt32 = 0
        var attributes: UInt8 = 0
        var pad0: UInt8 = 0, pad1: UInt8 = 0, pad2: UInt8 = 0
    }
    private struct KeyData {
        var key: UInt32 = 0
        var vers = KeyDataVer()
        var pLimit = PLimitData()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0, status: UInt8 = 0, command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
            = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static let kernelIndex: UInt32 = 2
    private static let readBytesCommand: UInt8 = 5
    private static let readKeyInfoCommand: UInt8 = 9

    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return nil }
    }

    deinit {
        IOServiceClose(connection)
    }

    /// Reads a 4-byte float sensor such as "PSTR". Nil if the key doesn't
    /// exist on this Mac or isn't a float.
    func readFloat(_ key: String) -> Float? {
        let code = key.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }

        var request = KeyData()
        request.key = code
        request.command = Self.readKeyInfoCommand
        guard let info = call(&request), info.result == 0, info.keyInfo.dataSize == 4 else { return nil }

        request = KeyData()
        request.key = code
        request.keyInfo.dataSize = 4
        request.command = Self.readBytesCommand
        guard let reply = call(&request), reply.result == 0 else { return nil }

        var bytes = reply.bytes
        let value = withUnsafeBytes(of: &bytes) { $0.load(as: Float.self) }
        return value.isFinite ? value : nil
    }

    private func call(_ input: inout KeyData) -> KeyData? {
        var output = KeyData()
        var outputSize = MemoryLayout<KeyData>.stride
        let result = IOConnectCallStructMethod(
            connection, Self.kernelIndex,
            &input, MemoryLayout<KeyData>.stride,
            &output, &outputSize)
        return result == kIOReturnSuccess ? output : nil
    }
}
