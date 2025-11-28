/// Network.framework implementation for macOS and iOS
///
/// This implementation uses Apple's Network.framework to provide
/// modern, efficient networking with first-class IPv6 support and
/// automatic path monitoring.

import Foundation

#if canImport(Network)
import Network

/// Network.framework-based socket implementation for macOS and iOS
@available(macOS 13.0, iOS 16.0, *)
public final class NetworkFrameworkSocket: NetworkTransport, @unchecked Sendable {
    public typealias Address = SocketAddress

    private var listener: NWListener?
    private let lock = NSLock()
    private let queue: DispatchQueue

    public init() {
        self.listener = nil
        self.queue = DispatchQueue(label: "com.prixfixe.network.listener", qos: .userInitiated)
    }

    deinit {
        lock.withLock {
            listener?.cancel()
            listener = nil
        }
    }

    // MARK: - NetworkTransport Implementation

    public func bind(to address: SocketAddress) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Thread-safe flag to ensure we only resume once
            final class ResumeOnce: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false

                func tryResume(_ action: () -> Void) {
                    lock.withLock {
                        if !resumed {
                            resumed = true
                            action()
                        }
                    }
                }
            }

            let resumeOnce = ResumeOnce()

            lock.withLock {
                do {
                    // Create listener parameters
                    let parameters = createParameters()

                    // Create listener with port
                    let port = NWEndpoint.Port(rawValue: address.port)!
                    let newListener = try NWListener(using: parameters, on: port)

                    // Configure state change handler
                    newListener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            resumeOnce.tryResume { continuation.resume(returning: ()) }
                        case .failed(let error):
                            resumeOnce.tryResume { continuation.resume(throwing: NetworkError.bindFailed("Listener failed: \(error)")) }
                        case .cancelled:
                            resumeOnce.tryResume { continuation.resume(throwing: NetworkError.invalidState("Listener cancelled")) }
                        case .waiting, .setup:
                            // Still transitioning, wait
                            break
                        @unknown default:
                            break
                        }
                    }

                    // Start listener
                    newListener.start(queue: queue)

                    self.listener = newListener
                } catch {
                    resumeOnce.tryResume { continuation.resume(throwing: error) }
                }
            }
        }
    }

    public func listen(backlog: Int) async throws {
        // Network.framework handles the listen queue automatically
        // The backlog parameter is noted but not directly configurable
        guard listener != nil else {
            throw NetworkError.invalidState("Listener not created - call bind() first")
        }
    }

    public func accept() async throws -> any NetworkConnection {
        guard let listener = lock.withLock({ listener }) else {
            throw NetworkError.invalidState("Listener not started")
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Set new connection handler
            listener.newConnectionHandler = { [weak self] connection in
                guard let self = self else {
                    continuation.resume(throwing: NetworkError.invalidState("Listener deallocated"))
                    return
                }

                // Parse remote address
                let remoteAddress = self.parseRemoteAddress(from: connection)

                // Create connection wrapper
                let networkConnection = NetworkFrameworkConnection(
                    connection: connection,
                    remoteAddress: remoteAddress,
                    queue: self.queue
                )

                continuation.resume(returning: networkConnection)
            }
        }
    }

    public func close() async throws {
        lock.withLock {
            listener?.cancel()
            listener = nil
        }
    }

    // MARK: - Private Helpers

    private func createEndpoint(from address: SocketAddress) throws -> NWEndpoint {
        let port = NWEndpoint.Port(rawValue: address.port)!

        // For wildcard addresses (::), use any IPv6
        if address.isAny {
            return NWEndpoint.hostPort(host: .ipv6(.any), port: port)
        }

        // For specific addresses
        if address.isIPv6 {
            // Parse IPv6 address
            if address.isLoopback && address.host == "::1" {
                return NWEndpoint.hostPort(host: .ipv6(.loopback), port: port)
            } else if let ipv6 = parseIPv6Host(address.host) {
                return NWEndpoint.hostPort(host: .ipv6(ipv6), port: port)
            }
        } else if address.isIPv4 {
            // IPv4-mapped IPv6 - extract the IPv4 part
            if let ipv4Host = extractIPv4FromMapped(address.host) {
                if ipv4Host == "127.0.0.1" {
                    return NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)
                } else if ipv4Host == "0.0.0.0" {
                    return NWEndpoint.hostPort(host: .ipv4(.any), port: port)
                } else if let ipv4 = parseIPv4Host(ipv4Host) {
                    return NWEndpoint.hostPort(host: .ipv4(ipv4), port: port)
                }
            }
        }

        throw NetworkError.invalidAddress("Cannot convert address to NWEndpoint: \(address)")
    }

    private func createParameters() -> NWParameters {
        let parameters = NWParameters.tcp

        // Allow address reuse
        parameters.allowLocalEndpointReuse = true

        // Configure TCP options
        if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 60  // seconds
        }

        // Allow IPv4 and IPv6 (dual-stack)
        parameters.acceptLocalOnly = false
        parameters.preferNoProxies = true

        return parameters
    }


    private func parseRemoteAddress(from connection: NWConnection) -> SocketAddress {
        guard let endpoint = connection.currentPath?.remoteEndpoint else {
            return .localhost(port: 0)
        }

        switch endpoint {
        case .hostPort(let host, let port):
            let portValue = port.rawValue

            switch host {
            case .ipv6(let ipv6):
                let hostString = formatIPv6(ipv6)
                return (try? .ipv6(hostString, port: portValue)) ?? .localhost(port: portValue)

            case .ipv4(let ipv4):
                let hostString = formatIPv4(ipv4)
                // Convert to IPv4-mapped IPv6
                return (try? .ipv4(hostString, port: portValue)) ?? .localhost(port: portValue)

            case .name(let name, _):
                // Hostname - try to parse as IP
                return (try? SocketAddress(host: name, port: portValue)) ?? .localhost(port: portValue)

            @unknown default:
                return .localhost(port: portValue)
            }

        default:
            return .localhost(port: 0)
        }
    }

    // MARK: - Address Parsing Helpers

    private func parseIPv6Host(_ host: String) -> IPv6Address? {
        // Remove zone ID if present
        let cleanHost = host.split(separator: "%").first.map(String.init) ?? host
        return IPv6Address(cleanHost)
    }

    private func parseIPv4Host(_ host: String) -> IPv4Address? {
        return IPv4Address(host)
    }

    private func extractIPv4FromMapped(_ ipv6: String) -> String? {
        // Extract IPv4 from ::ffff:x.x.x.x format
        if ipv6.hasPrefix("::ffff:") {
            return String(ipv6.dropFirst(7))
        }
        return nil
    }

    private func formatIPv6(_ address: IPv6Address) -> String {
        return address.debugDescription
    }

    private func formatIPv4(_ address: IPv4Address) -> String {
        return address.debugDescription
    }
}

/// Network.framework-based connection implementation
@available(macOS 13.0, iOS 16.0, *)
public final class NetworkFrameworkConnection: NetworkConnection, @unchecked Sendable {
    private var connection: NWConnection?
    private let lock = NSLock()
    public let remoteAddress: any NetworkAddress
    private let queue: DispatchQueue
    private var isStarted = false

    init(connection: NWConnection, remoteAddress: any NetworkAddress, queue: DispatchQueue) {
        self.connection = connection
        self.remoteAddress = remoteAddress
        self.queue = queue
    }

    deinit {
        lock.withLock {
            connection?.cancel()
            connection = nil
        }
    }

    // MARK: - NetworkConnection Implementation

    public func read(maxBytes: Int) async throws -> Data {
        let conn = try lock.withLock { () -> NWConnection in
            guard let connection = connection else {
                throw NetworkError.connectionClosed
            }

            // Start connection on first use
            if !isStarted {
                connection.start(queue: queue)
                isStarted = true
            }

            return connection
        }

        return try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: 1, maximumLength: maxBytes) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: NetworkError.readFailed("Read failed: \(error)"))
                } else if isComplete {
                    continuation.resume(throwing: NetworkError.connectionClosed)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    // No data but no error - connection might be closing
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    public func write(_ data: Data) async throws {
        let conn = try lock.withLock { () -> NWConnection in
            guard let connection = connection else {
                throw NetworkError.connectionClosed
            }

            // Start connection on first use
            if !isStarted {
                connection.start(queue: queue)
                isStarted = true
            }

            return connection
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: NetworkError.writeFailed("Write failed: \(error)"))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    public func close() async throws {
        lock.withLock {
            connection?.cancel()
            connection = nil
        }
    }
}

#endif
