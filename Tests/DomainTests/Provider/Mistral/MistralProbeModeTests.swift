import Testing
import Foundation
@testable import Domain

@Suite("MistralProbeMode Tests")
struct MistralProbeModeTests {

    @Test
    func `allCases contains localLogs and api`() {
        let cases = MistralProbeMode.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.localLogs))
        #expect(cases.contains(.api))
    }

    @Test
    func `localLogs has correct properties`() {
        let mode = MistralProbeMode.localLogs
        #expect(mode.rawValue == "localLogs")
        #expect(mode.displayName == "Local Logs")
        #expect(mode.description == "Token costs from ~/.vibe/logs/session/")
    }

    @Test
    func `api has correct properties`() {
        let mode = MistralProbeMode.api
        #expect(mode.rawValue == "api")
        #expect(mode.displayName == "Code API")
        #expect(mode.description == "Usage % via chat.mistral.ai Code API (session cookie)")
    }

    @Test
    func `init from rawValue succeeds for valid values`() {
        #expect(MistralProbeMode(rawValue: "localLogs") == .localLogs)
        #expect(MistralProbeMode(rawValue: "api") == .api)
    }

    @Test
    func `init from rawValue returns nil for invalid values`() {
        #expect(MistralProbeMode(rawValue: "invalid") == nil)
        #expect(MistralProbeMode(rawValue: "") == nil)
    }
}
