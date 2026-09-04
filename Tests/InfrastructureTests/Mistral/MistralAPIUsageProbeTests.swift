import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite("MistralAPIUsageProbe Tests")
struct MistralAPIUsageProbeTests {

    private func makeRepository() -> (UserDefaultsProviderSettingsRepository, String) {
        let suiteName = "com.claudebar.test.mistralprobe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let repo = UserDefaultsProviderSettingsRepository(userDefaults: defaults)
        return (repo, suiteName)
    }

    private func cleanupDefaults(_ suiteName: String) {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeSuccessResponse(json: String) -> (Data, URLResponse) {
        let data = Data(json.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://chat.mistral.ai")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    private func makeHTTPResponse(statusCode: Int, body: String = "") -> (Data, URLResponse) {
        let data = Data(body.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://chat.mistral.ai")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    // MARK: - Cookie Resolution Tests

    @Test
    func `getSessionCookie uses MISTRAL_CHAT_COOKIE env var by default`() {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        setenv("MISTRAL_CHAT_COOKIE", "env_cookie_123", 1)
        defer { unsetenv("MISTRAL_CHAT_COOKIE") }

        let probe = MistralAPIUsageProbe(settingsRepository: repo)
        #expect(probe.getSessionCookie() == "env_cookie_123")
    }

    @Test
    func `getSessionCookie uses custom env var when configured`() {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.setMistralChatAuthEnvVar("CUSTOM_MISTRAL_VAR")
        setenv("CUSTOM_MISTRAL_VAR", "custom_cookie_456", 1)
        defer { unsetenv("CUSTOM_MISTRAL_VAR") }

        let probe = MistralAPIUsageProbe(settingsRepository: repo)
        #expect(probe.getSessionCookie() == "custom_cookie_456")
    }

    @Test
    func `getSessionCookie falls back to stored cookie when env var is unset`() {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        unsetenv("MISTRAL_CHAT_COOKIE")
        repo.saveMistralChatCookie("stored_cookie_789")

        let probe = MistralAPIUsageProbe(settingsRepository: repo)
        #expect(probe.getSessionCookie() == "stored_cookie_789")
    }

    @Test
    func `getSessionCookie returns nil when neither env var nor stored cookie is set`() {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        unsetenv("MISTRAL_CHAT_COOKIE")
        repo.deleteMistralChatCookie()

        let probe = MistralAPIUsageProbe(settingsRepository: repo)
        #expect(probe.getSessionCookie() == nil)
    }

    // MARK: - isAvailable Tests

    @Test
    func `isAvailable returns true when cookie is configured`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("test_cookie")
        let probe = MistralAPIUsageProbe(settingsRepository: repo)

        #expect(await probe.isAvailable() == true)
    }

    @Test
    func `isAvailable returns false when no cookie is configured`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        unsetenv("MISTRAL_CHAT_COOKIE")
        repo.deleteMistralChatCookie()
        let probe = MistralAPIUsageProbe(settingsRepository: repo)

        #expect(await probe.isAvailable() == false)
    }

    // MARK: - Probe Tests

    @Test
    func `probe throws authenticationRequired when no cookie is configured`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        unsetenv("MISTRAL_CHAT_COOKIE")
        repo.deleteMistralChatCookie()
        let probe = MistralAPIUsageProbe(settingsRepository: repo)

        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test
    func `probe successfully fetches and parses usage`() async throws {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("valid_cookie")
        let mockNetwork = MockNetworkClient()

        let validNDJSON = """
        {"json":{"0":[[0],[null,0,0]]}}
        {"json":[6,0,[[{"usagePercentage":15.5,"resetAt":"2026-09-01T00:00:00Z"}]]]}
        """
        given(mockNetwork).request(.any).willReturn(makeSuccessResponse(json: validNDJSON))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo,
            timeout: 10
        )

        let snapshot = try await probe.probe()
        #expect(snapshot.providerId == "mistral")
        #expect(snapshot.quotas.count == 1)

        let quota = snapshot.quotas[0]
        #expect(quota.percentRemaining == 84.5)
        #expect(quota.resetText == "84% remaining")
        #expect(quota.resetsAt != nil)
    }

    @Test
    func `probe parses JSON array format response`() async throws {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("valid_cookie")
        let mockNetwork = MockNetworkClient()

        let arrayJSON = """
        [
            {"json": {"usagePercentage": 30.0, "resetAt": "2026-08-01T12:00:00.500Z"}}
        ]
        """
        given(mockNetwork).request(.any).willReturn(makeSuccessResponse(json: arrayJSON))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo
        )

        let snapshot = try await probe.probe()
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas[0].percentRemaining == 70.0)
    }

    @Test
    func `probe throws authenticationRequired on HTTP 401`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("expired_cookie")
        let mockNetwork = MockNetworkClient()
        given(mockNetwork).request(.any).willReturn(makeHTTPResponse(statusCode: 401))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo
        )

        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test
    func `probe throws authenticationRequired on HTTP 403`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("forbidden_cookie")
        let mockNetwork = MockNetworkClient()
        given(mockNetwork).request(.any).willReturn(makeHTTPResponse(statusCode: 403))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo
        )

        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test
    func `probe throws executionFailed on HTTP 500`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("some_cookie")
        let mockNetwork = MockNetworkClient()
        given(mockNetwork).request(.any).willReturn(makeHTTPResponse(statusCode: 500))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo
        )

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    @Test
    func `probe throws executionFailed on non-HTTP response`() async {
        let (repo, suite) = makeRepository()
        defer { cleanupDefaults(suite) }

        repo.saveMistralChatCookie("some_cookie")
        let mockNetwork = MockNetworkClient()
        let nonHTTP = URLResponse(
            url: URL(string: "https://chat.mistral.ai")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        given(mockNetwork).request(.any).willReturn((Data(), nonHTTP))

        let probe = MistralAPIUsageProbe(
            networkClient: mockNetwork,
            settingsRepository: repo
        )

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    // MARK: - Additional Parsing Error Path Tests

    @Test
    func `parseResponse throws executionFailed on root level error dictionary`() {
        let jsonWithError = """
        [{"error": "Session expired"}]
        """
        let data = Data(jsonWithError.utf8)

        #expect(throws: ProbeError.self) {
            try MistralAPIUsageProbe.parseResponse(data, providerId: "mistral")
        }
    }

    @Test
    func `parseResponse throws executionFailed on nested json error`() {
        let jsonWithNestedError = """
        [{"json": [{"error": "Rate limit exceeded"}]}]
        """
        let data = Data(jsonWithNestedError.utf8)

        #expect(throws: ProbeError.self) {
            try MistralAPIUsageProbe.parseResponse(data, providerId: "mistral")
        }
    }

    @Test
    func `parseResponse handles invalid resetAt date format gracefully`() throws {
        let jsonWithBadDate = """
        [
            {"json": {"usagePercentage": 10.0, "resetAt": "not-a-valid-date"}}
        ]
        """
        let data = Data(jsonWithBadDate.utf8)
        let snapshot = try MistralAPIUsageProbe.parseResponse(data, providerId: "mistral")

        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas[0].percentRemaining == 90.0)
        #expect(snapshot.quotas[0].resetsAt == nil)
    }

    @Test
    func `parseResponse throws parseFailed on empty whitespace NDJSON`() {
        let emptyNDJSON = "\n   \n\t\n"
        let data = Data(emptyNDJSON.utf8)

        #expect(throws: ProbeError.parseFailed("Invalid JSON response")) {
            try MistralAPIUsageProbe.parseResponse(data, providerId: "mistral")
        }
    }
}
