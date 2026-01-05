import SwiftUI

// MARK: - CLI Theme

/// Minimalistic monochrome terminal theme with classic green accents.
/// Inspired by classic terminal aesthetics with pure black background
/// and sharp, functional design.
public struct CLITheme: AppThemeProvider {
    // MARK: - Identity

    public let id = "cli"
    public let displayName = "CLI"
    public let icon = "terminal.fill"
    public let subtitle: String? = "Terminal"

    // MARK: - CLI-Specific Colors

    private let cliBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    private let cliCharcoal = Color(red: 0.08, green: 0.08, blue: 0.08)
    private let cliDarkGray = Color(red: 0.15, green: 0.15, blue: 0.15)
    private let cliGray = Color(red: 0.45, green: 0.45, blue: 0.45)
    private let cliGreen = Color(red: 0.0, green: 0.85, blue: 0.35)
    private let cliGreenDim = Color(red: 0.0, green: 0.55, blue: 0.22)
    private let cliAmber = Color(red: 0.95, green: 0.75, blue: 0.2)
    private let cliRed = Color(red: 0.95, green: 0.25, blue: 0.25)
    private let cliWhite = Color(red: 0.92, green: 0.92, blue: 0.92)
    private let cliWhiteDim = Color(red: 0.65, green: 0.65, blue: 0.65)

    // MARK: - Background

    public var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [cliBlack, cliBlack],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var showBackgroundOrbs: Bool { false }

    // MARK: - Cards & Glass

    public var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cliCharcoal, cliCharcoal.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var glassBackground: Color { cliCharcoal }
    public var glassBorder: Color { cliDarkGray }
    public var glassHighlight: Color { cliGray.opacity(0.3) }

    public var cardCornerRadius: CGFloat { 8 }   // Match original CLI
    public var pillCornerRadius: CGFloat { 8 }   // Match original CLI

    // MARK: - Typography

    public var textPrimary: Color { cliWhite }
    public var textSecondary: Color { cliWhiteDim }
    public var textTertiary: Color { cliGray }
    public var fontDesign: Font.Design { .monospaced }

    // MARK: - Status Colors

    public var statusHealthy: Color { cliGreen }
    public var statusWarning: Color { cliAmber }
    public var statusCritical: Color { cliRed }
    public var statusDepleted: Color { Color(red: 0.65, green: 0.15, blue: 0.15) }

    // MARK: - Accents

    public var accentPrimary: Color { cliGreen }
    public var accentSecondary: Color { cliGreenDim }

    public var accentGradient: LinearGradient {
        LinearGradient(
            colors: [cliGreen, cliGreenDim],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var pillGradient: LinearGradient {
        LinearGradient(
            colors: [cliGreen.opacity(0.25), cliGreen.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var shareGradient: LinearGradient {
        LinearGradient(
            colors: [cliAmber, cliAmber.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Interactive States

    public var hoverOverlay: Color { cliGreen.opacity(0.1) }
    public var pressedOverlay: Color { cliGreen.opacity(0.15) }

    // MARK: - Progress Bar

    public var progressTrack: Color { cliDarkGray }

    // MARK: - Custom Progress Gradient

    public func progressGradient(for percent: Double) -> LinearGradient {
        let color: Color = switch percent {
        case 0..<20: statusCritical
        case 20..<50: statusWarning
        default: statusHealthy
        }
        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Initializer

    public init() {}
}
