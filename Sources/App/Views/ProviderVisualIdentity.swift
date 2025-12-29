import SwiftUI
import Domain

// MARK: - Provider Visual Identity Protocol

/// Defines visual identity for AI providers.
/// Each concrete provider implements this to own its visual representation.
/// This keeps visual properties with the provider (rich domain) while
/// separating SwiftUI dependencies from the Domain layer.
public protocol ProviderVisualIdentity {
    /// SF Symbol icon name for this provider
    var symbolIcon: String { get }

    /// Icon asset name in the asset catalog
    var iconAssetName: String { get }

    /// Theme color for this provider
    func themeColor(for scheme: ColorScheme) -> Color

    /// Theme gradient for this provider
    func themeGradient(for scheme: ColorScheme) -> LinearGradient
}

// MARK: - ClaudeProvider Visual Identity

extension ClaudeProvider: ProviderVisualIdentity {
    public var symbolIcon: String { "brain.fill" }

    public var iconAssetName: String { "ClaudeIcon" }

    public func themeColor(for scheme: ColorScheme) -> Color {
        AppTheme.coralAccent(for: scheme)
    }

    public func themeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.coralAccent(for: scheme),
                AppTheme.pinkHot(for: scheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - CodexProvider Visual Identity

extension CodexProvider: ProviderVisualIdentity {
    public var symbolIcon: String { "chevron.left.forwardslash.chevron.right" }

    public var iconAssetName: String { "CodexIcon" }

    public func themeColor(for scheme: ColorScheme) -> Color {
        AppTheme.tealBright(for: scheme)
    }

    public func themeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.tealBright(for: scheme),
                scheme == .dark
                    ? Color(red: 0.25, green: 0.65, blue: 0.85)
                    : Color(red: 0.12, green: 0.52, blue: 0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - GeminiProvider Visual Identity

extension GeminiProvider: ProviderVisualIdentity {
    public var symbolIcon: String { "sparkles" }

    public var iconAssetName: String { "GeminiIcon" }

    public func themeColor(for scheme: ColorScheme) -> Color {
        AppTheme.goldenGlow(for: scheme)
    }

    public func themeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.goldenGlow(for: scheme),
                scheme == .dark
                    ? Color(red: 0.95, green: 0.55, blue: 0.35)
                    : Color(red: 0.85, green: 0.45, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - CopilotProvider Visual Identity

extension CopilotProvider: ProviderVisualIdentity {
    public var symbolIcon: String { "chevron.left.forwardslash.chevron.right" }

    public var iconAssetName: String { "CopilotIcon" }

    public func themeColor(for scheme: ColorScheme) -> Color {
        // GitHub's blue color
        scheme == .dark
            ? Color(red: 0.38, green: 0.55, blue: 0.93)
            : Color(red: 0.26, green: 0.43, blue: 0.82)
    }

    public func themeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                themeColor(for: scheme),
                scheme == .dark
                    ? Color(red: 0.55, green: 0.40, blue: 0.90)
                    : Color(red: 0.45, green: 0.30, blue: 0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - AntigravityProvider Visual Identity

extension AntigravityProvider: ProviderVisualIdentity {
    public var symbolIcon: String { "wand.and.stars" }

    public var iconAssetName: String { "AntigravityIcon" }

    public func themeColor(for scheme: ColorScheme) -> Color {
        // Purple/magenta color matching Antigravity branding
        scheme == .dark
            ? Color(red: 0.72, green: 0.35, blue: 0.85)
            : Color(red: 0.58, green: 0.22, blue: 0.72)
    }

    public func themeGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                themeColor(for: scheme),
                scheme == .dark
                    ? Color(red: 0.45, green: 0.25, blue: 0.75)
                    : Color(red: 0.35, green: 0.15, blue: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - AIProvider Visual Identity Helper

/// Extension to access visual identity from any AIProvider.
/// Uses type casting to dispatch to the correct implementation.
extension AIProvider {
    /// Returns the visual identity if this provider conforms to ProviderVisualIdentity
    public var visualIdentity: ProviderVisualIdentity? {
        self as? ProviderVisualIdentity
    }

    /// SF Symbol icon, with fallback for unknown providers
    public var symbolIconOrDefault: String {
        visualIdentity?.symbolIcon ?? "questionmark.circle.fill"
    }

    /// Icon asset name, with fallback for unknown providers
    public var iconAssetNameOrDefault: String {
        visualIdentity?.iconAssetName ?? "QuestionIcon"
    }

    /// Theme color with fallback
    public func themeColorOrDefault(for scheme: ColorScheme) -> Color {
        visualIdentity?.themeColor(for: scheme) ?? AppTheme.purpleVibrant(for: scheme)
    }

    /// Theme gradient with fallback
    public func themeGradientOrDefault(for scheme: ColorScheme) -> LinearGradient {
        visualIdentity?.themeGradient(for: scheme) ?? AppTheme.accentGradient(for: scheme)
    }
}
