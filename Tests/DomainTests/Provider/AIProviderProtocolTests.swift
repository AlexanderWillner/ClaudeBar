import Testing
import Foundation
import Mockable
@testable import Domain

@Suite
struct AIProviderProtocolTests {

    // MARK: - Protocol Conformance

    @Test
    func `provider has required id property`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.id == "claude")
    }

    @Test
    func `provider has required name property`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.name == "Claude")
    }

    @Test
    func `provider has required cliCommand property`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.cliCommand == "claude")
    }

    @Test
    func `provider has dashboardURL property`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.dashboardURL != nil)
        #expect(claude.dashboardURL?.absoluteString.contains("anthropic.com") == true)
    }

    @Test
    func `provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe(isAvailableResult: true)
        let claude = ClaudeProvider(probe: mockProbe)

        let isAvailable = await claude.isAvailable()

        #expect(isAvailable == true)
    }

    @Test
    func `provider delegates refresh to probe`() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe(probeResult: expectedSnapshot)
        let claude = ClaudeProvider(probe: mockProbe)

        let snapshot = try await claude.refresh()

        #expect(snapshot.quotas.isEmpty)
    }

    // MARK: - Equality via ID

    @Test
    func `providers with same id are equal`() {
        let provider1 = ClaudeProvider(probe: MockUsageProbe())
        let provider2 = ClaudeProvider(probe: MockUsageProbe())

        #expect(provider1.id == provider2.id)
    }

    @Test
    func `different providers have different ids`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.id != codex.id)
        #expect(claude.id != gemini.id)
        #expect(codex.id != gemini.id)
    }

    // MARK: - Provider State

    @Test
    func `provider tracks isSyncing state during refresh`() async throws {
        let mockProbe = MockUsageProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        ))
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.isSyncing == false)

        _ = try await claude.refresh()

        // After refresh completes, isSyncing should be false again
        #expect(claude.isSyncing == false)
    }

    @Test
    func `provider stores snapshot after refresh`() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe(probeResult: expectedSnapshot)
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.snapshot == nil)

        _ = try await claude.refresh()

        #expect(claude.snapshot != nil)
        #expect(claude.snapshot?.quotas.first?.percentRemaining == 50)
    }

    @Test
    func `provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe(probeError: ProbeError.timeout)
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.lastError == nil)

        do {
            _ = try await claude.refresh()
        } catch {
            // Expected to throw
        }

        #expect(claude.lastError != nil)
    }
}

@Suite
struct AIProviderRegistryTests {

    @Test
    func `registry can register providers`() {
        let registry = AIProviderRegistry.shared
        let providers: [any Domain.AIProvider] = [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ]

        registry.register(providers)

        #expect(registry.allProviders.count == 3)
    }

    @Test
    func `registry lookup by id returns correct provider`() {
        let registry = AIProviderRegistry.shared
        registry.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        let claude = registry.provider(for: "claude")

        #expect(claude != nil)
        #expect(claude?.name == "Claude")
    }

    @Test
    func `registry lookup with invalid id returns nil`() {
        let registry = AIProviderRegistry.shared
        registry.register([ClaudeProvider(probe: MockUsageProbe())])

        let unknown = registry.provider(for: "unknown")

        #expect(unknown == nil)
    }

    // MARK: - Static Accessors

    @Test
    func `static accessor returns claude provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.claude?.id == "claude")
        #expect(AIProviderRegistry.claude?.name == "Claude")
    }

    @Test
    func `static accessor returns codex provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.codex?.id == "codex")
        #expect(AIProviderRegistry.codex?.name == "Codex")
    }

    @Test
    func `static accessor returns gemini provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.gemini?.id == "gemini")
        #expect(AIProviderRegistry.gemini?.name == "Gemini")
    }

    @Test
    func `static accessors return nil when providers not registered`() {
        AIProviderRegistry.shared.register([])

        #expect(AIProviderRegistry.claude == nil)
        #expect(AIProviderRegistry.codex == nil)
        #expect(AIProviderRegistry.gemini == nil)
    }

    @Test
    func `static lookup by id returns correct provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.provider(for: "claude")?.id == "claude")
        #expect(AIProviderRegistry.provider(for: "codex")?.id == "codex")
        #expect(AIProviderRegistry.provider(for: "gemini")?.id == "gemini")
    }
}

// MARK: - Provider Identity Tests

@Suite
struct ProviderIdentityTests {

    @Test
    func `all providers have unique ids`() {
        let providers: [any AIProvider] = [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ]

        let ids = Set(providers.map(\.id))
        #expect(ids.count == 3)
    }

    @Test
    func `all providers have display names`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.name == "Claude")
        #expect(codex.name == "Codex")
        #expect(gemini.name == "Gemini")
    }

    @Test
    func `provider name matches its identity`() {
        // This tests the rich domain model - name is from provider, not hardcoded
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.id == "claude")
        #expect(claude.name == "Claude")
        #expect(claude.cliCommand == "claude")
    }

    @Test
    func `codex provider has correct identity`() {
        let codex = CodexProvider(probe: MockUsageProbe())

        #expect(codex.id == "codex")
        #expect(codex.name == "Codex")
        #expect(codex.cliCommand == "codex")
    }

    @Test
    func `gemini provider has correct identity`() {
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(gemini.id == "gemini")
        #expect(gemini.name == "Gemini")
        #expect(gemini.cliCommand == "gemini")
    }

    @Test
    func `all providers have dashboard urls`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.dashboardURL != nil)
        #expect(codex.dashboardURL != nil)
        #expect(gemini.dashboardURL != nil)
    }

    @Test
    func `claude dashboard url points to anthropic`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.dashboardURL?.host?.contains("anthropic") == true)
    }

    @Test
    func `codex dashboard url points to openai`() {
        let codex = CodexProvider(probe: MockUsageProbe())

        #expect(codex.dashboardURL?.host?.contains("openai") == true)
    }

    @Test
    func `gemini dashboard url points to google`() {
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(gemini.dashboardURL?.host?.contains("google") == true)
    }

    @Test
    func `providers are enabled by default`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.isEnabled == true)
        #expect(codex.isEnabled == true)
        #expect(gemini.isEnabled == true)
    }
}
