import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct GeminiAPIProbeTests {
    
    // MARK: - Helpers
    
    private func makeTemporaryHomeDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func createCredentialsFile(in homeDirectory: URL, accessToken: String = "test-token") throws {
        let dotGemini = homeDirectory.appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: dotGemini, withIntermediateDirectories: true)
        
        let credsURL = dotGemini.appendingPathComponent("oauth_creds.json")
        let json: [String: Any] = [
            "access_token": accessToken,
            "expiry_date": Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: credsURL)
    }
    
    // MARK: - Tests
    
    @Test
    func `probe fails when credentials missing`() async throws {
        let homeDir = try makeTemporaryHomeDirectory()
        let mockService = MockNetworkClient()
        
        let probe = GeminiAPIProbe(
            homeDirectory: homeDir.path,
            timeout: 1.0,
            networkClient: mockService,
            maxRetries: 1
        )

        await #expect(throws: ProbeError.authenticationRequired) {
            try await probe.probe()
        }
    }

    @Test
    func `probe discovers project id and fetches quota`() async throws {
        let homeDir = try makeTemporaryHomeDirectory()
        try createCredentialsFile(in: homeDir)
        let mockService = MockNetworkClient()

        // Setup mocks
        let projectsResponse = """
        {
            "projects": [
                { "projectId": "gen-lang-client-123456" }
            ]
        }
        """.data(using: .utf8)!

        let quotaResponse = """
        {
            "buckets": [
                {
                    "modelId": "gemini-pro",
                    "remainingFraction": 0.8,
                    "resetTime": "2025-12-21T12:00:00Z"
                }
            ]
        }
        """.data(using: .utf8)!

        given(mockService)
            .request(.any)
            .willProduce { request in
                let url = request.url?.absoluteString ?? ""
                if url.contains("projects") {
                    return (projectsResponse, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                } else {
                    return (quotaResponse, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
            }

        let probe = GeminiAPIProbe(
            homeDirectory: homeDir.path,
            timeout: 1.0,
            networkClient: mockService,
            maxRetries: 1
        )
        
        let snapshot = try await probe.probe()
        
        // Verify quota
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 80.0)
        
        // Verify project ID was included in quota request
        verify(mockService)
            .request(.matching { request in
                guard let url = request.url?.absoluteString else { return false }
                
                // Check if this is the quota request
                if url.contains("retrieveUserQuota") {
                    // Check body for project ID
                    if let body = request.httpBody,
                       let bodyStr = String(data: body, encoding: .utf8) {
                        return bodyStr.contains("gen-lang-client-123456")
                    }
                }
                return false
            })
            .called(1)
    }
    
    @Test
    func `probe handles api error gracefully`() async throws {
        let homeDir = try makeTemporaryHomeDirectory()
        try createCredentialsFile(in: homeDir)
        let mockService = MockNetworkClient()
        
        given(mockService)
            .request(.any)
            .willProduce { _ in
                (Data(), HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
            }
            
        let probe = GeminiAPIProbe(
            homeDirectory: homeDir.path,
            timeout: 1.0,
            networkClient: mockService,
            maxRetries: 1
        )

        await #expect(throws: ProbeError.executionFailed("HTTP 500")) {
            try await probe.probe()
        }
    }
}
