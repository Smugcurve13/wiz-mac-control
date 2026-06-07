import Foundation
import Network

/// Errors the networking layer can surface to the UI.
enum WizError: Error, LocalizedError {
    case timeout
    case noResponse
    case invalidHost

    var errorDescription: String? {
        switch self {
        case .timeout:      return "The bulb didn't respond in time."
        case .noResponse:   return "No reply from the bulb."
        case .invalidHost:  return "That doesn't look like a valid IP address."
        }
    }
}

/// Talks to a WiZ bulb directly over UDP (port 38899), the same protocol your
/// Flask app used — just native, no server in between.
///
/// Swift note: this is a `struct` with no stored state, so it's cheap to create
/// (`WizClient()`) anywhere and is safe to use from any task. Each call opens a
/// fresh, short-lived UDP "connection", sends one datagram, optionally waits for
/// one reply, then tears it down. (UDP is connectionless; `NWConnection` just
/// gives us a tidy send/receive object.)
struct WizClient {

    private static let port = NWEndpoint.Port(rawValue: 38899)!

    // MARK: - High-level API (what the app and widget actually call)

    func setPower(_ on: Bool, host: String) async throws {
        _ = try await send(WizCommand.setPower(on), to: host, expectReply: false)
    }

    func setBrightness(_ percent: Int, host: String) async throws {
        _ = try await send(WizCommand.setBrightness(percent), to: host, expectReply: false)
    }

    func setColor(r: Int, g: Int, b: Int, host: String) async throws {
        _ = try await send(WizCommand.setColor(r: r, g: g, b: b), to: host, expectReply: false)
    }

    /// Ask the bulb for its current state and parse the JSON reply.
    func getState(host: String) async throws -> WizState {
        guard let data = try await send(WizCommand.getPilot, to: host, expectReply: true) else {
            throw WizError.noResponse
        }
        let response = try JSONDecoder().decode(GetPilotResponse.self, from: data)
        return response.toState()
    }

    // MARK: - The UDP send/receive core

    /// Send one datagram and, if `expectReply` is true, wait for one back.
    /// Returns the reply bytes (or `nil` when no reply was requested).
    func send(_ payload: Data,
              to host: String,
              expectReply: Bool,
              timeout: TimeInterval = 1.5) async throws -> Data? {

        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw WizError.invalidHost
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: Self.port,
            using: .udp
        )
        // Network framework delivers callbacks on a queue we provide.
        connection.start(queue: DispatchQueue(label: "com.smugcurve13.wizcontrol.udp"))
        // `defer` runs when this function exits (success OR throw) — guarantees
        // we always release the socket. (Like a Python `finally`.)
        defer { connection.cancel() }

        // We race two tasks: the real work vs. a timeout. Whichever finishes
        // first wins. This is how you put a deadline on async work in Swift.
        return try await withThrowingTaskGroup(of: Data?.self) { group in
            group.addTask {
                try await Self.sendData(payload, on: connection)
                return expectReply ? try await Self.receiveData(on: connection) : nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                // Cancelling the connection makes any pending receive call
                // complete immediately, so the other task never hangs forever.
                connection.cancel()
                throw WizError.timeout
            }

            // Take the first result, then cancel the loser.
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    // MARK: - Bridging callback APIs into async/await

    // `NWConnection` is callback-based (you hand it a closure it calls later).
    // `withCheckedThrowingContinuation` is the standard Swift tool to turn one
    // such callback into a single `await`: the function suspends until we call
    // `continuation.resume(...)` exactly once. (Conceptually like wrapping a
    // callback in a Python `asyncio.Future`.)

    private static func sendData(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private static func receiveData(on connection: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
            // `receiveMessage` waits for exactly one complete datagram — perfect
            // for WiZ's one-request/one-reply pattern.
            connection.receiveMessage { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
