import Foundation

/// Errors that can occur when probing a CLI
public enum ProbeError: Error, Equatable, Sendable {
    /// The CLI binary was not found on the system
    case cliNotFound(String)

    /// User needs to log in to the CLI
    case authenticationRequired

    /// The CLI output could not be parsed
    case parseFailed(String)

    /// The probe timed out waiting for a response
    case timeout

    /// No quota data was available
    case noData

    /// The CLI needs to be updated
    case updateRequired

    /// User needs to trust the current folder
    case folderTrustRequired

    /// Command execution failed
    case executionFailed(String)

    /// Usage data requires a subscription plan (API billing accounts don't support /usage)
    case subscriptionRequired
}
