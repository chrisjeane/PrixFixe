/// BSD Socket implementation using POSIX sockets
///
/// This implementation uses low-level POSIX socket APIs to provide
/// IPv6-first networking with IPv4-mapped address support.

import Foundation

#if canImport(Darwin)
import Darwin
private let posixClose = Darwin.close
private let posixRead = Darwin.read
private let posixWrite = Darwin.write
private let posixBind = Darwin.bind
private let posixListen = Darwin.listen
private let posixAccept = Darwin.accept
#elseif canImport(Glibc)
import Glibc
private let posixClose = Glibc.close
private let posixRead = Glibc.read
private let posixWrite = Glibc.write
private let posixBind = Glibc.bind
private let posixListen = Glibc.listen
private let posixAccept = Glibc.accept
#else
#error("Unsupported platform - requires Darwin or Glibc")
#endif

/// Socket implementation using Foundation/POSIX sockets
public final class FoundationSocket: NetworkTransport, @unchecked Sendable {
    public typealias Address = SocketAddress

    private var fileDescriptor: Int32?
    private let lock = NSLock()

    public init() {
        self.fileDescriptor = nil
    }

    deinit {
        // Synchronous cleanup in deinit
        lock.withLock {
            if let fd = fileDescriptor {
                posixClose(fd)
                fileDescriptor = nil
            }
        }
    }

    // MARK: - NetworkTransport Implementation

    public func bind(to address: SocketAddress) async throws {
        try lock.withLock {
            // Create IPv6 socket
            let fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)
            guard fd >= 0 else {
                throw NetworkError.bindFailed("Failed to create socket: \(String(cString: strerror(errno)))")
            }

            self.fileDescriptor = fd

            // Set socket options
            try setSocketOptions(fd)

            // Bind to address
            try bindSocket(fd, to: address)
        }
    }

    public func listen(backlog: Int) async throws {
        guard let fd = fileDescriptor else {
            throw NetworkError.invalidState("Socket not bound")
        }

        let result = posixListen(fd, Int32(backlog))
        guard result == 0 else {
            throw NetworkError.listenFailed("listen() failed: \(String(cString: strerror(errno)))")
        }
    }

    public func accept() async throws -> any NetworkConnection {
        guard let fd = fileDescriptor else {
            throw NetworkError.invalidState("Socket not listening")
        }

        // Use detached task to avoid blocking cooperative thread pool
        // The blocking accept() call runs on a thread pool managed by the global concurrent executor
        return try await Task.detached {
            var addr = sockaddr_in6()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in6>.size)

            let clientFD = withUnsafeMutablePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    posixAccept(fd, sockaddrPtr, &addrLen)
                }
            }

            guard clientFD >= 0 else {
                throw NetworkError.acceptFailed("accept() failed: \(String(cString: strerror(errno))))")
            }

            // Parse remote address
            let remoteAddress = self.parseSocketAddress(from: addr)

            return FoundationConnection(fileDescriptor: clientFD, remoteAddress: remoteAddress)
        }.value
    }

    public func close() async throws {
        lock.withLock {
            guard let fd = fileDescriptor else { return }

            posixClose(fd)
            fileDescriptor = nil
        }
    }

    // MARK: - Private Helpers

    private func setSocketOptions(_ fd: Int32) throws {
        // Allow address reuse
        var reuseAddr: Int32 = 1
        let reuseResult = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        guard reuseResult == 0 else {
            throw NetworkError.bindFailed("Failed to set SO_REUSEADDR: \(String(cString: strerror(errno)))")
        }

        // Allow dual-stack (IPv6 socket can accept IPv4-mapped connections)
        var ipv6Only: Int32 = 0
        let ipv6Result = setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &ipv6Only, socklen_t(MemoryLayout<Int32>.size))
        guard ipv6Result == 0 else {
            throw NetworkError.bindFailed("Failed to set IPV6_V6ONLY: \(String(cString: strerror(errno)))")
        }

        // Set non-blocking mode (for future async I/O)
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0 else {
            throw NetworkError.bindFailed("Failed to get socket flags: \(String(cString: strerror(errno)))")
        }

        let setResult = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        guard setResult >= 0 else {
            throw NetworkError.bindFailed("Failed to set non-blocking: \(String(cString: strerror(errno)))")
        }
    }

    private func bindSocket(_ fd: Int32, to address: SocketAddress) throws {
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = address.port.bigEndian

        // Parse IPv6 address into sin6_addr
        let parseResult = inet_pton(AF_INET6, address.host, &addr.sin6_addr)
        guard parseResult == 1 else {
            throw NetworkError.bindFailed("Invalid IPv6 address: \(address.host)")
        }

        // Handle zone ID for link-local addresses
        if let zoneID = address.zoneID {
            // Convert zone name to interface index
            #if canImport(Darwin)
            addr.sin6_scope_id = if_nametoindex(zoneID)
            #endif
        }

        // Bind
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                posixBind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }

        guard bindResult == 0 else {
            throw NetworkError.bindFailed("bind() failed: \(String(cString: strerror(errno)))")
        }
    }

    private func parseSocketAddress(from addr: sockaddr_in6) -> SocketAddress {
        var addr = addr
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))

        inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))

        // Convert CChar (Int8) to UInt8 for String decoding
        let nullTerminatorIndex = buffer.firstIndex(of: 0) ?? buffer.count
        let bytes = buffer[..<nullTerminatorIndex].map { UInt8(bitPattern: $0) }
        let host = String(decoding: bytes, as: UTF8.self)
        let port = UInt16(bigEndian: addr.sin6_port)

        // Best effort - if parsing fails, return a placeholder
        return (try? SocketAddress.ipv6(host, port: port)) ?? .localhost(port: port)
    }
}

/// Connection implementation using BSD sockets
public final class FoundationConnection: NetworkConnection, @unchecked Sendable {
    private var fileDescriptor: Int32?
    private let lock = NSLock()
    public let remoteAddress: any NetworkAddress

    init(fileDescriptor: Int32, remoteAddress: any NetworkAddress) {
        self.fileDescriptor = fileDescriptor
        self.remoteAddress = remoteAddress
    }

    deinit {
        // Synchronous cleanup in deinit
        lock.withLock {
            if let fd = fileDescriptor {
                posixClose(fd)
                fileDescriptor = nil
            }
        }
    }

    public func read(maxBytes: Int) async throws -> Data {
        guard let fd = lock.withLock({ fileDescriptor }) else {
            throw NetworkError.connectionClosed
        }

        // Use detached task to avoid blocking cooperative thread pool
        // The blocking read() call runs on a thread pool managed by the global concurrent executor
        return try await Task.detached {
            var buffer = [UInt8](repeating: 0, count: maxBytes)

            let bytesRead = posixRead(fd, &buffer, maxBytes)

            if bytesRead < 0 {
                let err = errno
                if err == EAGAIN || err == EWOULDBLOCK {
                    // Non-blocking socket would block - return empty data to retry
                    return Data()
                } else {
                    throw NetworkError.readFailed("read() failed: \(String(cString: strerror(err))))")
                }
            } else if bytesRead == 0 {
                // Connection closed
                throw NetworkError.connectionClosed
            } else {
                return Data(buffer.prefix(bytesRead))
            }
        }.value
    }

    public func write(_ data: Data) async throws {
        guard let fd = lock.withLock({ fileDescriptor }) else {
            throw NetworkError.connectionClosed
        }

        // Use detached task to avoid blocking cooperative thread pool
        // Implements retry logic for partial writes
        try await Task.detached {
            var remainingData = data
            var totalWritten = 0
            let maxRetries = 10
            var retryCount = 0

            while totalWritten < data.count {
                let bytesWritten = remainingData.withUnsafeBytes { bufferPtr in
                    posixWrite(fd, bufferPtr.baseAddress!, remainingData.count)
                }

                if bytesWritten < 0 {
                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        // Non-blocking socket would block - retry after brief delay
                        retryCount += 1
                        if retryCount > maxRetries {
                            throw NetworkError.writeFailed("write() exceeded max retries (EAGAIN)")
                        }
                        // Brief sleep to avoid tight loop
                        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        continue
                    } else {
                        throw NetworkError.writeFailed("write() failed: \(String(cString: strerror(err))))")
                    }
                } else if bytesWritten == 0 {
                    // No bytes written - socket may be closed
                    throw NetworkError.writeFailed("write() returned 0 bytes")
                } else {
                    // Successfully wrote some bytes
                    totalWritten += bytesWritten
                    if totalWritten < data.count {
                        // Partial write - continue with remaining data
                        remainingData = remainingData.advanced(by: bytesWritten)
                        retryCount = 0 // Reset retry count on successful write
                    }
                }
            }
        }.value
    }

    public func close() async throws {
        lock.withLock {
            guard let fd = fileDescriptor else { return }

            posixClose(fd)
            fileDescriptor = nil
        }
    }
}
