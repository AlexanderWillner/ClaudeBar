import Testing
import Foundation
import Mockable
@testable import Domain

@Suite
struct AIProvidersTests {

    // MARK: - All Providers

    @Test
    func `all returns all registered providers`() {
        let providers = AIProviders(providers: [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(providers.all.count == 3)
    }

    @Test
    func `all returns empty when no providers registered`() {
        let providers = AIProviders(providers: [])

        #expect(providers.all.isEmpty)
    }

    // MARK: - Enabled Providers

    @Test
    func `enabled returns only providers with isEnabled true`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        // Disable gemini
        gemini.isEnabled = false

        let providers = AIProviders(providers: [claude, codex, gemini])

        #expect(providers.enabled.count == 2)
        #expect(providers.enabled.contains { $0.id == "claude" })
        #expect(providers.enabled.contains { $0.id == "codex" })
        #expect(!providers.enabled.contains { $0.id == "gemini" })
    }

    @Test
    func `enabled returns empty when all providers disabled`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        claude.isEnabled = false
        codex.isEnabled = false

        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.enabled.isEmpty)
    }

    @Test
    func `enabled returns all when all providers enabled`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        // Both enabled by default
        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.enabled.count == 2)
    }

    // MARK: - Lookup

    @Test
    func `provider by id returns correct provider`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.provider(id: "claude")?.name == "Claude")
        #expect(providers.provider(id: "codex")?.name == "Codex")
    }

    @Test
    func `provider by id returns nil for unknown id`() {
        let providers = AIProviders(providers: [
            ClaudeProvider(probe: MockUsageProbe())
        ])

        #expect(providers.provider(id: "unknown") == nil)
    }

    // MARK: - Toggle Enabled State

    @Test
    func `toggling provider isEnabled updates enabled list`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude])

        #expect(providers.enabled.count == 1)

        claude.isEnabled = false

        #expect(providers.enabled.isEmpty)

        claude.isEnabled = true

        #expect(providers.enabled.count == 1)
    }
}
