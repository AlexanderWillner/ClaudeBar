import Foundation
import Domain

/// Infrastructure adapter that probes the Gemini API to fetch usage quotas.
/// Uses OAuth credentials stored by the Gemini CLI.
public struct GeminiUsageProbe: UsageProbePort {
    public let provider: AIProvider = .gemini

    private let homeDirectory: String
    private let timeout: TimeInterval
    private let dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    private static let credentialsPath = "/.gemini/oauth_creds.json"
    private static let settingsPath = "/.gemini/settings.json"

    public init(
        homeDirectory: String = NSHomeDirectory(),
        timeout: TimeInterval = 10.0,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.homeDirectory = homeDirectory
        self.timeout = timeout
        self.dataLoader = dataLoader
    }

    public func isAvailable() async -> Bool {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)
        return FileManager.default.fileExists(atPath: credsURL.path)
    }

    public func probe() async throws -> UsageSnapshot {
        let creds = try loadCredentials()

        guard let accessToken = creds.accessToken, !accessToken.isEmpty else {
            throw ProbeError.authenticationRequired
        }

        guard let url = URL(string: Self.quotaEndpoint) else {
            throw ProbeError.executionFailed("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = timeout

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProbeError.executionFailed("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw ProbeError.authenticationRequired
        }

        guard httpResponse.statusCode == 200 else {
            throw ProbeError.executionFailed("HTTP \(httpResponse.statusCode)")
        }

        return try Self.parseAPIResponse(data)
    }

    // MARK: - Parsing

    public static func parseAPIResponse(_ data: Data) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QuotaResponse.self, from: data)

        guard let buckets = response.buckets, !buckets.isEmpty else {
            throw ProbeError.parseFailed("No quota buckets in response")
        }

        // Group quotas by model, keeping lowest per model (usually input tokens)
        var modelQuotaMap: [String: Double] = [:]

        for bucket in buckets {
            guard let modelId = bucket.modelId, let fraction = bucket.remainingFraction else { continue }

            if let existing = modelQuotaMap[modelId] {
                if fraction < existing {
                    modelQuotaMap[modelId] = fraction
                }
            } else {
                modelQuotaMap[modelId] = fraction
            }
        }

        // Convert to quotas
        let quotas: [UsageQuota] = modelQuotaMap
            .sorted { $0.key < $1.key }
            .map { modelId, fraction in
                UsageQuota(
                    percentRemaining: fraction * 100,
                    quotaType: .modelSpecific(modelId),
                    provider: .gemini
                )
            }

        guard !quotas.isEmpty else {
            throw ProbeError.parseFailed("No valid quotas found")
        }

        return UsageSnapshot(
            provider: .gemini,
            quotas: quotas,
            capturedAt: Date()
        )
    }

    public static func parseCLIOutput(_ text: String) throws -> UsageSnapshot {
        let clean = stripANSICodes(text)

        // Check for login errors
        let lower = clean.lowercased()
        if lower.contains("login with google") || lower.contains("use gemini api key") {
            throw ProbeError.authenticationRequired
        }

        // Parse model usage table
        let quotas = parseModelUsageTable(clean)

        guard !quotas.isEmpty else {
            throw ProbeError.parseFailed("No usage data found in output")
        }

        return UsageSnapshot(
            provider: .gemini,
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - Credentials

    private struct OAuthCredentials {
        let accessToken: String?
        let refreshToken: String?
        let expiryDate: Date?
    }

    private func loadCredentials() throws -> OAuthCredentials {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)

        guard FileManager.default.fileExists(atPath: credsURL.path) else {
            throw ProbeError.authenticationRequired
        }

        let data = try Data(contentsOf: credsURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProbeError.parseFailed("Invalid credentials file")
        }

        let accessToken = json["access_token"] as? String
        let refreshToken = json["refresh_token"] as? String

        var expiryDate: Date?
        if let expiryMs = json["expiry_date"] as? Double {
            expiryDate = Date(timeIntervalSince1970: expiryMs / 1000)
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDate: expiryDate
        )
    }

    // MARK: - Text Parsing Helpers

    private static func stripANSICodes(_ text: String) -> String {
        let pattern = #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func parseModelUsageTable(_ text: String) -> [UsageQuota] {
        let lines = text.components(separatedBy: .newlines)
        var quotas: [UsageQuota] = []

        let pattern = #"(gemini[-\w.]+)\s+.*?([0-9]+(?:\.[0-9]+)?)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "│", with: " ")
            let range = NSRange(cleanLine.startIndex..<cleanLine.endIndex, in: cleanLine)
            guard let match = regex.firstMatch(in: cleanLine, options: [], range: range),
                  match.numberOfRanges >= 3 else { continue }

            guard let modelRange = Range(match.range(at: 1), in: cleanLine),
                  let pctRange = Range(match.range(at: 2), in: cleanLine),
                  let pct = Double(cleanLine[pctRange])
            else { continue }

            let modelId = String(cleanLine[modelRange])

            quotas.append(UsageQuota(
                percentRemaining: pct,
                quotaType: .modelSpecific(modelId),
                provider: .gemini
            ))
        }

        return quotas
    }

    // MARK: - Response Types

    private struct QuotaBucket: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
        let modelId: String?
        let tokenType: String?
    }

    private struct QuotaResponse: Decodable {
        let buckets: [QuotaBucket]?
    }
}
