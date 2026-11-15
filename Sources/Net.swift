import Darwin
import Foundation

enum Sock {
    static func nonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    static func setOption(_ fd: Int32, _ level: Int32, _ name: Int32, _ value: Int32 = 1) {
        var v = value
        _ = setsockopt(fd, level, name, &v, socklen_t(MemoryLayout<Int32>.size))
    }

    static func address(_ host: String, _ port: Int) -> sockaddr_in? {
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = UInt16(port).bigEndian
        if host.isEmpty {
            a.sin_addr.s_addr = 0
            return a
        }
        if inet_pton(AF_INET, host, &a.sin_addr) == 1 { return a }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &res) == 0, let info = res, let sa = info.pointee.ai_addr else { return nil }
        defer { freeaddrinfo(res) }
        let resolved = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        a.sin_addr = resolved.sin_addr
        return a
    }

    static func withSockaddr<T>(_ a: sockaddr_in, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        var copy = a
        return withUnsafePointer(to: &copy) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    static func ipString(_ a: sockaddr_in) -> String {
        var addr = a.sin_addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buf)
    }

    static func wouldBlock() -> Bool {
        errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR || errno == EINPROGRESS
    }

    static func localIP() -> String {
        var candidates: [(rank: Int, name: String, ip: String)] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&list) == 0, let first = list {
            var cur: UnsafeMutablePointer<ifaddrs>? = first
            while let ifa = cur {
                defer { cur = ifa.pointee.ifa_next }
                let flags = Int32(ifa.pointee.ifa_flags)
                guard let sa = ifa.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET),
                      flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else { continue }
                let name = String(cString: ifa.pointee.ifa_name)
                guard name.hasPrefix("en") else { continue }
                let addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let ip = ipString(addr)
                if ip.hasPrefix("169.254.") { continue }
                let isPrivate = ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || isPrivate172(ip)
                let rank = (name == "en0" ? 0 : 1) + (isPrivate ? 0 : 2)
                candidates.append((rank, name, ip))
            }
            freeifaddrs(first)
        }
        if let best = candidates.sorted(by: { ($0.rank, $0.name) < ($1.rank, $1.name) }).first {
            return best.ip
        }
        return routeIP()
    }

    private static func isPrivate172(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4, parts[0] == "172", let b = Int(parts[1]) else { return false }
        return (16...31).contains(b)
    }

    private static func routeIP() -> String {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return "127.0.0.1" }
        defer { Darwin.close(fd) }
        guard let target = address("10.255.255.255", 1) else { return "127.0.0.1" }
        let ok = withSockaddr(target) { Darwin.connect(fd, $0, $1) } == 0
        guard ok else { return "127.0.0.1" }
        var me = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &me) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        return got == 0 ? ipString(me) : "127.0.0.1"
    }
}

final class Link {
    let fd: Int32
    private var buf = Data()
    private var out = Data()
    private(set) var closed = false

    init(fd: Int32) {
        self.fd = fd
        Sock.nonBlocking(fd)
        Sock.setOption(fd, SOL_SOCKET, SO_NOSIGPIPE)
        Sock.setOption(fd, Int32(IPPROTO_TCP), TCP_NODELAY)
    }

    func send(_ msg: [String: Any]) {
        if closed { return }
        guard var data = try? JSONSerialization.data(withJSONObject: msg) else { return }
        data.append(0x0A)
        out.append(data)
        flush()
    }

    private func flush() {
        while !out.isEmpty && !closed {
            let n = out.withUnsafeBytes { raw in
                Darwin.send(fd, raw.baseAddress, raw.count, 0)
            }
            if n < 0 {
                if Sock.wouldBlock() { return }
                closed = true
                return
            }
            out.removeFirst(n)
        }
    }

    func receive() -> [[String: Any]] {
        var msgs: [[String: Any]] = []
        if closed { return msgs }
        flush()
        var chunk = [UInt8](repeating: 0, count: 65536)
        while !closed {
            let n = chunk.withUnsafeMutableBytes { raw in
                Darwin.recv(fd, raw.baseAddress, raw.count, 0)
            }
            if n < 0 {
                if !Sock.wouldBlock() { closed = true }
                break
            }
            if n == 0 {
                closed = true
                break
            }
            buf.append(contentsOf: chunk[0..<n])
        }
        while let nl = buf.firstIndex(of: 0x0A) {
            let line = buf[buf.startIndex..<nl]
            buf.removeSubrange(buf.startIndex...nl)
            if let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                msgs.append(obj)
            }
        }
        return msgs
    }

    private var released = false

    func close() {
        closed = true
        if released { return }
        released = true
        Darwin.close(fd)
    }
}

final class Peer {
    let net: Link
    var style: String?
    var ready = false
    var idx = 0
    var rx: Double

    init(net: Link, rx: Double) {
        self.net = net
        self.rx = rx
    }
}

struct PendingConnection {
    let fd: Int32
    let deadline: Double
}

struct FoundHost: Equatable {
    var ip: String
    var port: Int
    var seen: Double
    var count: Int
}
