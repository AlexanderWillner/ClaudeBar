import Foundation
import Domain
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "CodexRPC")

/// Default implementation of CodexRPCClient that communicates with `codex app-server`.
/// This class is excluded from code coverage as it's a pure adapter for external CLI.
final class DefaultCodexRPCClient: CodexRPCClient, @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private var nextID = 1

    init(executable: String, timeout: TimeInterval) throws {
        // Build effective PATH including common Node.js installation locations
        var env = ProcessInfo.processInfo.environment
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
        process.arguments = [executable, "-s", "read-only", "-a", "untrusted", "app-server"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ProbeError.executionFailed("Failed to start codex app-server: \(error.localizedDescription)")
        }
    }

    func initialize() async throws {
        _ = try await request(method: "initialize", params: [
            "clientInfo": ["name": "claudebar", "version": "1.0.0"]
        ])
        try sendNotification(method: "initialized")
    }

    func fetchRateLimits() async throws -> CodexRateLimitsResponse {
        let message = try await request(method: "account/rateLimits/read")

        // Log raw response
        if let data = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Codex RPC raw response:\n\(jsonString)")
        }

        guard let result = message["result"] as? [String: Any] else {
            logger.error("No result in response: \(String(describing: message))")
            throw ProbeError.parseFailed("Invalid rate limits response")
        }

        guard let rateLimits = result["rateLimits"] as? [String: Any] else {
            logger.error("No rateLimits in result: \(String(describing: result))")
            throw ProbeError.parseFailed("No rateLimits in response")
        }

        let planType = rateLimits["planType"] as? String
        logger.info("Codex plan type: \(planType ?? "unknown")")

        let primary = parseWindow(rateLimits["primary"])
        let secondary = parseWindow(rateLimits["secondary"])

        // If plan is free and no limits, create default "unlimited" quotas
        if primary == nil && secondary == nil {
            if planType == "free" {
                logger.info("Codex free plan - returning unlimited quotas")
                return CodexRateLimitsResponse(
                    primary: CodexRateLimitWindow(usedPercent: 0, resetDescription: "Free plan"),
                    secondary: nil,
                    planType: planType
                )
            }
            // No rate limit data available yet
            throw ProbeError.parseFailed("No rate limits available yet - make some API calls first")
        }

        return CodexRateLimitsResponse(primary: primary, secondary: secondary, planType: planType)
    }

    private func parseWindow(_ value: Any?) -> CodexRateLimitWindow? {
        guard let dict = value as? [String: Any] else {
            logger.debug("parseWindow: value is not a dict: \(String(describing: value))")
            return nil
        }

        logger.debug("parseWindow dict keys: \(dict.keys.joined(separator: ", "))")

        guard let usedPercent = dict["usedPercent"] as? Double else {
            logger.debug("parseWindow: no usedPercent in dict")
            return nil
        }

        var resetDescription: String?
        if let resetsAt = dict["resetsAt"] as? Int {
            let date = Date(timeIntervalSince1970: TimeInterval(resetsAt))
            resetDescription = formatResetTime(date)
        }

        return CodexRateLimitWindow(usedPercent: usedPercent, resetDescription: resetDescription)
    }

    private func formatResetTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Resets soon" }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    func shutdown() {
        if process.isRunning {
            process.terminate()
        }
    }

    // MARK: - JSON-RPC

    private func request(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = nextID
        nextID += 1

        try sendRequest(id: id, method: method, params: params)

        while true {
            let message = try await readNextMessage()

            // Skip notifications
            if message["id"] == nil {
                continue
            }

            guard let messageID = message["id"] as? Int, messageID == id else {
                continue
            }

            if let error = message["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                throw ProbeError.executionFailed("RPC error: \(errorMessage)")
            }

            return message
        }
    }

    private func sendNotification(method: String) throws {
        let payload: [String: Any] = ["method": method, "params": [:]]
        try sendPayload(payload)
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        let payload: [String: Any] = [
            "id": id,
            "method": method,
            "params": params ?? [:]
        ]
        try sendPayload(payload)
    }

    private func sendPayload(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        stdinPipe.fileHandleForWriting.write(data)
        stdinPipe.fileHandleForWriting.write(Data([0x0A])) // newline
    }

    private func readNextMessage() async throws -> [String: Any] {
        for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            return json
        }
        throw ProbeError.executionFailed("Codex app-server closed unexpectedly")
    }
}
