import Foundation
import Observation

/// Repository of AI providers.
/// Rich domain model that provides access to all providers and filters by enabled state.
@Observable
public final class AIProviders: @unchecked Sendable {
    // MARK: - All Providers

    /// All registered providers
    public let all: [any AIProvider]

    // MARK: - Filtered Views

    /// Only enabled providers (computed from all providers' isEnabled state)
    public var enabled: [any AIProvider] {
        all.filter { $0.isEnabled }
    }

    // MARK: - Initialization

    /// Creates an AIProviders repository with the given providers
    /// - Parameter providers: The providers to manage
    public init(providers: [any AIProvider]) {
        self.all = providers
    }

    // MARK: - Lookup

    /// Finds a provider by its ID
    /// - Parameter id: The provider identifier (e.g., "claude", "codex", "gemini")
    /// - Returns: The provider if found, nil otherwise
    public func provider(id: String) -> (any AIProvider)? {
        all.first { $0.id == id }
    }
}
