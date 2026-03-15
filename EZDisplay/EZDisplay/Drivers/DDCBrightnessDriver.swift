import IOKit
import CoreGraphics
import Foundation

private let kDDCVCPBrightness: UInt8 = 0x10
private let kDDCGetVCPReplyCmd: UInt8 = 0x02
private let kAVDDCChipAddress: UInt32 = 0x37
private let kAVDDCDataAddress:  UInt32 = 0x51

private typealias IOAVServiceCreateWithServiceFn = @convention(c) (CFAllocator?, io_service_t) -> UnsafeMutableRawPointer?
private typealias IOAVServiceReadI2CFn  = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> kern_return_t
private typealias IOAVServiceWriteI2CFn = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> kern_return_t

final class DDCBrightnessDriver {
    static let shared = DDCBrightnessDriver()
    private let queue = DispatchQueue(label: "com.EzDisplay.ddc", qos: .userInitiated)

    private var avServiceCreate: IOAVServiceCreateWithServiceFn?
    private var avServiceRead:   IOAVServiceReadI2CFn?
    private var avServiceWrite:  IOAVServiceWriteI2CFn?

    private var avServiceCache: [CGDirectDisplayID: UnsafeMutableRawPointer] = [:]
    private var ddcMaxCache:    [CGDirectDisplayID: [UInt8: UInt16]] = [:]

    private init() {
        guard let h = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY) else { return }
        avServiceCreate = unsafeBitCast(dlsym(h, "IOAVServiceCreateWithService"), to: IOAVServiceCreateWithServiceFn?.self)
        avServiceRead   = unsafeBitCast(dlsym(h, "IOAVServiceReadI2C"),           to: IOAVServiceReadI2CFn?.self)
        avServiceWrite  = unsafeBitCast(dlsym(h, "IOAVServiceWriteI2C"),          to: IOAVServiceWriteI2CFn?.self)
    }

    // MARK: - Public API

    func getBrightness(for displayID: CGDirectDisplayID, completion: @escaping (Float?) -> Void) {
        queue.async {
            let result = self.ddcGet(displayID: displayID, vcpCode: kDDCVCPBrightness)
            if let result { self.cacheMax(result.max, for: displayID, vcpCode: kDDCVCPBrightness) }
            DispatchQueue.main.async {
                completion(result.map { Float($0.current) / Float($0.max) })
            }
        }
    }

    func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) {
        setVCP(kDDCVCPBrightness, value: value, for: displayID)
    }

    // Probe a list of VCP codes; returns only those the display responds to.
    func probeVCPs(_ codes: [UInt8], for displayID: CGDirectDisplayID,
                   completion: @escaping ([(code: UInt8, current: UInt16, max: UInt16)]) -> Void) {
        queue.async {
            var results: [(code: UInt8, current: UInt16, max: UInt16)] = []
            for code in codes {
                if let r = self.ddcGet(displayID: displayID, vcpCode: code), r.max > 0, r.max <= 1000 {
                    self.cacheMax(r.max, for: displayID, vcpCode: code)
                    results.append((code: code, current: r.current, max: r.max))
                }
            }
            DispatchQueue.main.async { completion(results) }
        }
    }

    func setVCP(_ vcpCode: UInt8, value: Float, for displayID: CGDirectDisplayID) {
        queue.async {
            let maxVal: UInt16
            if let cached = self.ddcMaxCache[displayID]?[vcpCode] {
                maxVal = cached
            } else if let r = self.ddcGet(displayID: displayID, vcpCode: vcpCode) {
                self.cacheMax(r.max, for: displayID, vcpCode: vcpCode)
                maxVal = r.max
            } else {
                return
            }
            let newVal = UInt16(max(0, min(Float(maxVal), value * Float(maxVal))))
            self.ddcSet(displayID: displayID, vcpCode: vcpCode, value: newVal)
        }
    }

    // MARK: - Cache helpers

    private func cacheMax(_ max: UInt16, for displayID: CGDirectDisplayID, vcpCode: UInt8) {
        if ddcMaxCache[displayID] == nil { ddcMaxCache[displayID] = [:] }
        ddcMaxCache[displayID]![vcpCode] = max
    }

    // MARK: - DDC packets

    private func avGetPacket(vcpCode: UInt8) -> [UInt8] {
        let body: [UInt8] = [0x82, 0x01, vcpCode]
        return body + [body.reduce(UInt8(0x37 << 1) ^ 0x51) { $0 ^ $1 }]
    }

    private func avSetPacket(vcpCode: UInt8, value: UInt16) -> [UInt8] {
        let body: [UInt8] = [0x84, 0x03, vcpCode, UInt8(value >> 8), UInt8(value & 0xFF)]
        return body + [body.reduce(UInt8(0x37 << 1) ^ 0x51) { $0 ^ $1 }]
    }

    private func i2cGetPacket(vcpCode: UInt8) -> [UInt8] {
        let body: [UInt8] = [0x51, 0x82, 0x01, vcpCode]
        return body + [body.reduce(UInt8(0x6F)) { $0 ^ $1 }]
    }

    private func i2cSetPacket(vcpCode: UInt8, value: UInt16) -> [UInt8] {
        let body: [UInt8] = [0x51, 0x84, 0x03, vcpCode, UInt8(value >> 8), UInt8(value & 0xFF)]
        return body + [body.reduce(UInt8(0x6F)) { $0 ^ $1 }]
    }

    // MARK: - DDC read/write

    private func ddcGet(displayID: CGDirectDisplayID, vcpCode: UInt8) -> (current: UInt16, max: UInt16)? {
        if let av = findAVService(for: displayID) { return avServiceGetVCP(avService: av, vcpCode: vcpCode) }
        if let fb = findFramebuffer(for: displayID) { defer { IOObjectRelease(fb) }
            return framebufferGetVCP(framebuffer: fb, vcpCode: vcpCode) }
        return nil
    }

    @discardableResult
    private func ddcSet(displayID: CGDirectDisplayID, vcpCode: UInt8, value: UInt16) -> Bool {
        if let av = findAVService(for: displayID) { return avServiceSetVCP(avService: av, vcpCode: vcpCode, value: value) }
        if let fb = findFramebuffer(for: displayID) { defer { IOObjectRelease(fb) }
            return framebufferSetVCP(framebuffer: fb, vcpCode: vcpCode, value: value) }
        return false
    }

    // MARK: - Apple Silicon (IOAVService)

    private func findAVService(for displayID: CGDirectDisplayID) -> UnsafeMutableRawPointer? {
        if let cached = avServiceCache[displayID] { return cached }
        guard let createFn = avServiceCreate else { return nil }
        let target = CGDisplayIsBuiltin(displayID) != 0 ? "Embedded" : "External"
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iter) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iter) }
        var svc = IOIteratorNext(iter)
        while svc != 0 {
            defer { IOObjectRelease(svc); svc = IOIteratorNext(iter) }
            guard let loc = IORegistryEntryCreateCFProperty(svc, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
                  loc == target else { continue }
            if let av = createFn(kCFAllocatorDefault, svc) { avServiceCache[displayID] = av; return av }
        }
        return nil
    }

    private func avServiceGetVCP(avService: UnsafeMutableRawPointer, vcpCode: UInt8) -> (current: UInt16, max: UInt16)? {
        guard let writeFn = avServiceWrite, let readFn = avServiceRead else { return nil }
        var packet = avGetPacket(vcpCode: vcpCode)
        for _ in 0..<2 {
            usleep(10_000)
            _ = packet.withUnsafeMutableBytes { writeFn(avService, kAVDDCChipAddress, kAVDDCDataAddress, $0.baseAddress!, UInt32($0.count)) }
        }
        usleep(50_000)
        for _ in 0..<5 {
            var reply = [UInt8](repeating: 0, count: 11)
            let ok = reply.withUnsafeMutableBytes { readFn(avService, kAVDDCChipAddress, 0, $0.baseAddress!, UInt32($0.count)) == kIOReturnSuccess }
            let chkOK = reply.dropLast().reduce(UInt8(0x50), { $0 ^ $1 }) == reply.last
            if ok && chkOK {
                return parseDDCReply(reply, expectedVCP: vcpCode)
            }
            usleep(20_000)
        }
        return nil
    }

    private func avServiceSetVCP(avService: UnsafeMutableRawPointer, vcpCode: UInt8, value: UInt16) -> Bool {
        guard let writeFn = avServiceWrite else { return false }
        var packet = avSetPacket(vcpCode: vcpCode, value: value)
        for _ in 0..<5 {
            var success = false
            for _ in 0..<2 {
                usleep(10_000)
                success = packet.withUnsafeMutableBytes { writeFn(avService, kAVDDCChipAddress, kAVDDCDataAddress, $0.baseAddress!, UInt32($0.count)) } == kIOReturnSuccess
            }
            if success { return true }
            usleep(20_000)
        }
        return false
    }

    // MARK: - Intel (IOFramebuffer)

    private func findFramebuffer(for displayID: CGDirectDisplayID) -> io_service_t? {
        let unit = CGDisplayUnitNumber(displayID)
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOFramebuffer"), &iter) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iter) }
        var svc = IOIteratorNext(iter)
        while svc != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any],
               dict["IOFramebufferUnit"] as? UInt32 == unit { return svc }
            IOObjectRelease(svc)
            svc = IOIteratorNext(iter)
        }
        return nil
    }

    private func framebufferGetVCP(framebuffer: io_service_t, vcpCode: UInt8) -> (current: UInt16, max: UInt16)? {
        var count: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &count) == kIOReturnSuccess, count > 0 else { return nil }
        for bus in 0..<count {
            var iface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &iface) == kIOReturnSuccess else { continue }
            defer { IOObjectRelease(iface) }
            var conn: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(iface, 0, &conn) == kIOReturnSuccess, let conn else { continue }
            defer { IOI2CInterfaceClose(conn, 0) }
            if let r = i2cGetVCP(conn: conn, vcpCode: vcpCode) { return r }
        }
        return nil
    }

    private func framebufferSetVCP(framebuffer: io_service_t, vcpCode: UInt8, value: UInt16) -> Bool {
        var count: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &count) == kIOReturnSuccess, count > 0 else { return false }
        for bus in 0..<count {
            var iface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &iface) == kIOReturnSuccess else { continue }
            defer { IOObjectRelease(iface) }
            var conn: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(iface, 0, &conn) == kIOReturnSuccess, let conn else { continue }
            defer { IOI2CInterfaceClose(conn, 0) }
            if i2cSetVCP(conn: conn, vcpCode: vcpCode, value: value) { return true }
        }
        return false
    }

    private func i2cGetVCP(conn: IOI2CConnectRef, vcpCode: UInt8) -> (current: UInt16, max: UInt16)? {
        var send = i2cGetPacket(vcpCode: vcpCode)
        var reply = [UInt8](repeating: 0, count: 12)
        let sendCount = UInt32(send.count), replyCount = UInt32(reply.count)
        var kr = kIOReturnError as kern_return_t
        send.withUnsafeMutableBytes { sp in reply.withUnsafeMutableBytes { rp in
            var req = IOI2CRequest()
            req.sendAddress = 0x37; req.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            req.sendBuffer = vm_address_t(bitPattern: sp.baseAddress); req.sendBytes = sendCount
            req.replyAddress = 0x37 | 1; req.replyTransactionType = IOOptionBits(kIOI2CDDCciReplyTransactionType)
            req.replyBuffer = vm_address_t(bitPattern: rp.baseAddress); req.replyBytes = replyCount
            req.minReplyDelay = 30000
            kr = IOI2CSendRequest(conn, 0, &req)
        }}
        guard kr == kIOReturnSuccess else { return nil }
        return parseDDCReply(Array(reply), expectedVCP: vcpCode)
    }

    private func i2cSetVCP(conn: IOI2CConnectRef, vcpCode: UInt8, value: UInt16) -> Bool {
        var send = i2cSetPacket(vcpCode: vcpCode, value: value)
        let sendCount = UInt32(send.count)
        var kr = kIOReturnError as kern_return_t
        send.withUnsafeMutableBytes { sp in
            var req = IOI2CRequest()
            req.sendAddress = 0x37; req.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            req.sendBuffer = vm_address_t(bitPattern: sp.baseAddress); req.sendBytes = sendCount
            req.replyBytes = 0; req.minReplyDelay = 30000
            kr = IOI2CSendRequest(conn, 0, &req)
        }
        return kr == kIOReturnSuccess
    }

    private func parseDDCReply(_ reply: [UInt8], expectedVCP: UInt8) -> (current: UInt16, max: UInt16)? {
        guard reply.count >= 10, reply[2] == kDDCGetVCPReplyCmd, reply[3] == 0x00, reply[4] == expectedVCP else { return nil }
        let maxVal = (UInt16(reply[6]) << 8) | UInt16(reply[7])
        let curVal = (UInt16(reply[8]) << 8) | UInt16(reply[9])
        return (current: curVal, max: maxVal == 0 ? 100 : maxVal)
    }
}
