import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("MistralProvider Tests")
struct MistralProviderTests {

    private func makeIsolatedSettingsRepository() -> UserDefaultsProviderSettingsRepository {
        let suiteName = "com.claudebar.test.mistralprovider.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return UserDefaultsProviderSettingsRepository(userDefaults: defaults)
    }

    private func makeMockSettingsRepository(enabled: Bool = false) -> MockProviderSettingsRepository {
        let mock = MockProviderSettingsRepository()
        given(mock).isEnabled(forProvider: .any, defaultValue: .any).willReturn(enabled)
        given(mock).isEnabled(forProvider: .any).willReturn(enabled)
        given(mock).setEnabled(.any, forProvider: .any).willReturn()
        return mock
    }

    // MARK: - Identity Tests

    @Test
    func `mistral provider has correct identity properties`() {
        let settings = makeMockSettingsRepository()
        let mockProbe = MockUsageProbe()
        let provider = MistralProvider(probe: mockProbe, settingsRepository: settings)

        #expect(provider.id == "mistral")
        #expect(provider.name == "Mistral")
        #expect(provider.cliCommand == "")
        #expect(provider.dashboardURL == URL(string: "https://console.mistral.ai/codestral/cli"))
        #expect(provider.statusPageURL == nil)
        #expect(provider.isEnabled == false)
        #expect(provider.supportsApiMode == false)
    }

    @Test
    func `isEnabled setter persists to settings repository`() {
        let settings = makeIsolatedSettingsRepository()
        let mockProbe = MockUsageProbe()
        let provider = MistralProvider(probe: mockProbe, settingsRepository: settings)

        #expect(provider.isEnabled == false)
        provider.isEnabled = true
        #expect(settings.isEnabled(forProvider: "mistral") == true)
        provider.isEnabled = false
        #expect(settings.isEnabled(forProvider: "mistral") == false)
    }

    // MARK: - Legacy Initializer & Probe Mode Tests

    @Test
    func `legacy init defaults probeMode to localLogs and ignores non-MistralSettingsRepository`() {
        let settings = makeMockSettingsRepository()
        let mockProbe = MockUsageProbe()
        let provider = MistralProvider(probe: mockProbe, settingsRepository: settings)

        #expect(provider.probeMode == .localLogs)
        provider.probeMode = .api
        #expect(provider.probeMode == .localLogs)
    }

    // MARK: - Dual Probe Initializer Tests

    @Test
    func `dual probe init supportsApiMode and persists probeMode`() {
        let settings = makeIsolatedSettingsRepository()
        let localLogsProbe = MockUsageProbe()
        let apiProbe = MockUsageProbe()
        let provider = MistralProvider(
            localLogsProbe: localLogsProbe,
            apiProbe: apiProbe,
            settingsRepository: settings
        )

        #expect(provider.supportsApiMode == true)
        #expect(provider.probeMode == .localLogs)

        provider.probeMode = .api
        #expect(provider.probeMode == .api)
        #expect(settings.mistralProbeMode() == .api)

        provider.probeMode = .localLogs
        #expect(provider.probeMode == .localLogs)
        #expect(settings.mistralProbeMode() == .localLogs)
    }

    // MARK: - Delegation Tests

    @Test
    func `isAvailable delegates to active probe depending on probeMode`() async {
        let settings = makeIsolatedSettingsRepository()
        let localLogsProbe = MockUsageProbe()
        let apiProbe = MockUsageProbe()

        given(localLogsProbe).isAvailable().willReturn(true)
        given(apiProbe).isAvailable().willReturn(false)

        let provider = MistralProvider(
            localLogsProbe: localLogsProbe,
            apiProbe: apiProbe,
            settingsRepository: settings
        )

        provider.probeMode = .localLogs
        #expect(await provider.isAvailable() == true)

        provider.probeMode = .api
        #expect(await provider.isAvailable() == false)
    }

    @Test
    func `refresh delegates to active probe depending on probeMode`() async throws {
        let settings = makeIsolatedSettingsRepository()
        let localLogsProbe = MockUsageProbe()
        let apiProbe = MockUsageProbe()

        let localSnapshot = UsageSnapshot(
            providerId: "mistral",
            quotas: [],
            capturedAt: Date()
        )
        let apiSnapshot = UsageSnapshot(
            providerId: "mistral",
            quotas: [UsageQuota(percentRemaining: 75.0, quotaType: .timeLimit("Monthly"), providerId: "mistral")],
            capturedAt: Date()
        )

        given(localLogsProbe).probe().willReturn(localSnapshot)
        given(apiProbe).probe().willReturn(apiSnapshot)

        let provider = MistralProvider(
            localLogsProbe: localLogsProbe,
            apiProbe: apiProbe,
            settingsRepository: settings
        )

        // Refresh in localLogs mode
        provider.probeMode = .localLogs
        let refreshed1 = try await provider.refresh()
        #expect(refreshed1.quotas.isEmpty)
        #expect(provider.snapshot?.quotas.isEmpty == true)

        // Refresh in api mode
        provider.probeMode = .api
        let refreshed2 = try await provider.refresh()
        #expect(refreshed2.quotas.count == 1)
        #expect(provider.snapshot?.quotas.first?.percentRemaining == 75.0)
    }

    @Test
    func `refresh handles and clears errors`() async throws {
        let settings = makeIsolatedSettingsRepository()
        let localLogsProbe = MockUsageProbe()
        let failingProbe = MockUsageProbe()

        given(failingProbe).probe().willThrow(ProbeError.authenticationRequired)

        let providerWithFailing = MistralProvider(
            localLogsProbe: localLogsProbe,
            apiProbe: failingProbe,
            settingsRepository: settings
        )
        providerWithFailing.probeMode = .api

        await #expect(throws: ProbeError.authenticationRequired) {
            try await providerWithFailing.refresh()
        }
        #expect(providerWithFailing.lastError != nil)

        // Now probe succeeds
        let succeedingProbe = MockUsageProbe()
        let successSnapshot = UsageSnapshot(
            providerId: "mistral",
            quotas: [],
            capturedAt: Date()
        )
        given(succeedingProbe).probe().willReturn(successSnapshot)

        let providerWithSucceeding = MistralProvider(
            localLogsProbe: localLogsProbe,
            apiProbe: succeedingProbe,
            settingsRepository: settings
        )
        providerWithSucceeding.probeMode = .api

        let result = try await providerWithSucceeding.refresh()
        #expect(result.providerId == "mistral")
        #expect(providerWithSucceeding.lastError == nil)
    }
}
