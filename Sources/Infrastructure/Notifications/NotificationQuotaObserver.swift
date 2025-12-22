import Foundation
import UserNotifications
import Domain

/// Infrastructure adapter that sends macOS notifications when quota status changes.
/// Implements StatusChangeObserver from the domain layer.
public final class NotificationQuotaObserver: StatusChangeObserver, @unchecked Sendable {
    /// Lazily initialized notification center to avoid bundle issues during init
    private var notificationCenter: UNUserNotificationCenter? {
        // Only access notification center when running in a proper app context
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    public init() {}

    /// Requests notification permission from the user
    public func requestPermission() async -> Bool {
        guard let center = notificationCenter else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - StatusChangeObserver

    public func onStatusChanged(providerId: String, oldStatus: QuotaStatus, newStatus: QuotaStatus) async {
        // Only notify on degradation (getting worse)
        guard newStatus > oldStatus else { return }

        // Skip if status improved or stayed the same
        guard shouldNotify(for: newStatus) else { return }

        let providerName = providerDisplayName(for: providerId)

        let content = UNMutableNotificationContent()
        content.title = "\(providerName) Quota Alert"
        content.body = notificationBody(for: newStatus, providerName: providerName)
        content.sound = .default

        // Add category for actionable notifications
        content.categoryIdentifier = "QUOTA_ALERT"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        guard let center = notificationCenter else { return }
        do {
            try await center.add(request)
        } catch {
            // Silently fail - notifications are non-critical
        }
    }

    // MARK: - Helpers (internal for testability)

    func shouldNotify(for status: QuotaStatus) -> Bool {
        switch status {
        case .warning, .critical, .depleted:
            return true
        case .healthy:
            return false
        }
    }

    func providerDisplayName(for providerId: String) -> String {
        AIProviderRegistry.shared.provider(for: providerId)?.name ?? providerId.capitalized
    }

    func notificationBody(for status: QuotaStatus, providerName: String) -> String {
        switch status {
        case .warning:
            return "Your \(providerName) quota is running low. Consider pacing your usage."
        case .critical:
            return "Your \(providerName) quota is critically low! Save important work."
        case .depleted:
            return "Your \(providerName) quota is depleted. Usage may be blocked."
        case .healthy:
            return "Your \(providerName) quota has recovered."
        }
    }
}
