import Foundation

/// Registry of all available AI providers.
/// Configured at app startup with providers that have their probes injected.
public final class AIProviderRegistry: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = AIProviderRegistry()

    /// Registered providers (reference types, so no wrapper needed)
    private var _providers: [any AIProvider] = []
    
    /// Lock for thread-safe access
    private let lock = NSLock()

    private init() {}

    // MARK: - Configuration

    /// Registers providers with the registry (called at app startup)
    /// - Parameter providers: The providers to register
    public func register(_ providers: [any AIProvider]) {
        lock.withLock {
            _providers = providers
        }
    }

    /// Clears all registered providers
    public func reset() {
        lock.withLock {
            _providers = []
        }
    }

    // MARK: - All Providers

    /// All registered providers
    public var allProviders: [any AIProvider] {
        lock.withLock {
            _providers
        }
    }

    // MARK: - Static Accessors (for convenience)

    /// Claude provider (if registered)
    public static var claude: (any AIProvider)? {
        shared.provider(for: "claude")
    }

    /// Codex provider (if registered)
    public static var codex: (any AIProvider)? {
        shared.provider(for: "codex")
    }

    /// Gemini provider (if registered)
    public static var gemini: (any AIProvider)? {
        shared.provider(for: "gemini")
    }

    /// Antigravity provider (if registered)
    public static var antigravity: (any AIProvider)? {
        shared.provider(for: "antigravity")
    }

    /// Z.ai provider (if registered)
    public static var zai: (any AIProvider)? {
        shared.provider(for: "zai")
    }

    // MARK: - Lookup

    /// Finds a provider by its ID
    /// - Parameter id: The provider identifier (e.g., "claude", "codex", "gemini")
    /// - Returns: The provider if found, nil otherwise
    public func provider(for id: String) -> (any AIProvider)? {
        lock.withLock {
            _providers.first { $0.id == id }
        }
    }

    /// Static lookup convenience
    public static func provider(for id: String) -> (any AIProvider)? {
        shared.provider(for: id)
    }
}
