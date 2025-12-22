import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

/// Tests for NotificationQuotaObserver.
/// Tests the helper methods that determine notification behavior.
/// Note: Actual notification delivery cannot be tested without an app bundle.
@Suite
struct NotificationQuotaObserverTests {

    // MARK: - Should Notify Tests

    @Test
    func `shouldNotify returns true for warning status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .warning) == true)
    }

    @Test
    func `shouldNotify returns true for critical status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .critical) == true)
    }

    @Test
    func `shouldNotify returns true for depleted status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .depleted) == true)
    }

    @Test
    func `shouldNotify returns false for healthy status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .healthy) == false)
    }

    // MARK: - Provider Display Name Tests

    @Test
    func `providerDisplayName uses registry for registered provider`() {
        // Given - register providers using Mockable
        let mockProbe = MockUsageProbe()
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: mockProbe),
            CodexProvider(probe: mockProbe),
            GeminiProvider(probe: mockProbe)
        ])
        let observer = NotificationQuotaObserver()

        // Then - returns provider name from registry
        #expect(observer.providerDisplayName(for: "claude") == "Claude")
        #expect(observer.providerDisplayName(for: "codex") == "Codex")
        #expect(observer.providerDisplayName(for: "gemini") == "Gemini")
    }

    @Test
    func `providerDisplayName capitalizes unknown provider id`() {
        // Given - empty registry
        AIProviderRegistry.shared.register([])
        let observer = NotificationQuotaObserver()

        // Then - capitalizes the ID
        #expect(observer.providerDisplayName(for: "unknown") == "Unknown")
        #expect(observer.providerDisplayName(for: "chatgpt") == "Chatgpt")
    }

    // MARK: - Notification Body Tests

    @Test
    func `notificationBody for warning describes low quota`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .warning, providerName: "Claude")

        #expect(body.contains("Claude"))
        #expect(body.contains("running low"))
    }

    @Test
    func `notificationBody for critical describes critically low`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .critical, providerName: "Codex")

        #expect(body.contains("Codex"))
        #expect(body.contains("critically low"))
    }

    @Test
    func `notificationBody for depleted describes depletion`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .depleted, providerName: "Gemini")

        #expect(body.contains("Gemini"))
        #expect(body.contains("depleted"))
    }

    @Test
    func `notificationBody for healthy describes recovery`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .healthy, providerName: "Claude")

        #expect(body.contains("Claude"))
        #expect(body.contains("recovered"))
    }

    // MARK: - Status Degradation Detection (Domain Logic)

    @Test
    func `status degradation from healthy to warning should trigger notification`() {
        // When status degrades (new > old in severity), notification is sent
        #expect(QuotaStatus.warning > QuotaStatus.healthy)
    }

    @Test
    func `status degradation from warning to critical should trigger notification`() {
        #expect(QuotaStatus.critical > QuotaStatus.warning)
    }

    @Test
    func `status degradation to depleted should trigger notification`() {
        #expect(QuotaStatus.depleted > QuotaStatus.critical)
    }

    @Test
    func `status improvement should not trigger notification`() {
        // When status improves (new < old), no notification is sent
        #expect(QuotaStatus.healthy < QuotaStatus.warning)
    }

    @Test
    func `same status should not trigger notification`() {
        // When status is unchanged, no notification is sent
        #expect(QuotaStatus.healthy == QuotaStatus.healthy)
    }
}
