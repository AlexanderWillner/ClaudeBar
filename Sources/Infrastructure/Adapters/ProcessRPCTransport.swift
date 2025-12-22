import Foundation
import Domain

/// RPC transport that communicates via Process stdin/stdout pipes.
/// This is excluded from code coverage as it's a pure adapter for system interaction.
public final class ProcessRPCTransport: RPCTransport, @unchecked Sendable {
    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe

    public init(executable: String, arguments: [String], environment: [String: String]? = nil) throws {
        self.process = Process()
        self.stdinPipe = Pipe()
        self.stdoutPipe = Pipe()

        var env = environment ?? ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin",
            "\(NSHomeDirectory())/.local/bin",
            "/usr/local/lib/node_modules/.bin"
        ]
        env["PATH"] = (additionalPaths + [currentPath]).joined(separator: ":")

        process.environment = env
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ProbeError.executionFailed("Failed to start \(executable): \(error.localizedDescription)")
        }
    }

    public func send(_ data: Data) throws {
        stdinPipe.fileHandleForWriting.write(data)
        stdinPipe.fileHandleForWriting.write(Data([0x0A])) // newline
    }

    public func receive() async throws -> Data {
        for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else {
                continue
            }
            return data
        }
        throw ProbeError.executionFailed("Process closed unexpectedly")
    }

    public func close() {
        if process.isRunning {
            process.terminate()
        }
    }
}
