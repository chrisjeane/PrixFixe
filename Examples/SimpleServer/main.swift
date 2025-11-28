/// SimpleServer - A basic SMTP server example for macOS and Linux
///
/// This example demonstrates how to create a simple SMTP server that
/// accepts connections and logs received messages to the console.

import Foundation
import PrixFixe

@main
struct SimpleServer {
    static func main() async throws {
        print("PrixFixe Simple SMTP Server")
        print("===========================\n")

        // Create configuration
        let config = ServerConfiguration(
            domain: "localhost",
            port: 2525,
            maxConnections: 10,
            maxMessageSize: 10_485_760 // 10 MB
        )

        print("Configuration:")
        print("  Domain: \(config.domain)")
        print("  Port: \(config.port)")
        print("  Max Connections: \(config.maxConnections)")
        print("  Max Message Size: \(config.maxMessageSize / 1_048_576) MB")
        print()

        // Create server
        let server = SMTPServer(configuration: config)

        // Message counter actor for thread-safe access
        actor MessageCounter {
            private var count = 0
            func increment() -> Int {
                count += 1
                return count
            }
        }
        let counter = MessageCounter()

        // Set message handler
        await server.setMessageHandler { message in
            Task {
                let num = await counter.increment()
                print("\n========== Message #\(num) ==========")
                print("From: \(message.from.address)")
                print("To: \(message.recipients.map(\.address).joined(separator: ", "))")
                print("Size: \(message.data.count) bytes")

                if let text = String(data: message.data, encoding: .utf8) {
                    print("\nMessage Data:")
                    print(text)
                }

                print("==========================================\n")
            }
        }

        print("Starting server...")
        try await server.start()

        print("Server started successfully!")
        print("Listening on port \(config.port)")
        print("Press Ctrl+C to stop\n")

        // Keep running until interrupted
        while true {
            try await Task.sleep(for: .seconds(3600))
        }
    }
}

// Helper extension to set message handler from async context
extension SMTPServer {
    func setMessageHandler(_ handler: @escaping @Sendable (EmailMessage) -> Void) async {
        self.messageHandler = handler
    }
}
