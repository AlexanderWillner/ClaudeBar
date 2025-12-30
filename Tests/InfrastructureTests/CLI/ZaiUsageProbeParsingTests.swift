import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct ZaiUsageProbeParsingTests {

    // MARK: - Sample Data

    static let sampleQuotaLimitResponse = """
    {
      "data": {
        "limits": [
          {
            "type": "TOKENS_LIMIT",
            "percentage": 65
          },
          {
            "type": "TIME_LIMIT",
            "percentage": 30,
            "currentValue": 100,
            "usage": 3600,
            "usageDetails": []
          }
        ]
      }
    }
    """

    static let sampleQuotaLimitResponseOnlyTokens = """
    {
      "data": {
        "limits": [
          {
            "type": "TOKENS_LIMIT",
            "percentage": 45
          }
        ]
      }
    }
    """

    static let sampleQuotaLimitResponseEmpty = """
    {
      "data": {
        "limits": []
      }
    }
    """

    static let sampleQuotaLimitResponseFullUsage = """
    {
      "data": {
        "limits": [
          {
            "type": "TOKENS_LIMIT",
            "percentage": 100
          }
        ]
      }
    }
    """

    static let sampleQuotaLimitResponseNoUsage = """
    {
      "data": {
        "limits": [
          {
            "type": "TOKENS_LIMIT",
            "percentage": 0
          }
        ]
      }
    }
    """

    // MARK: - Quota Limit Parsing Tests

    @Test
    func `parses quota limits into UsageQuota`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponse.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        #expect(snapshot.quotas.count == 2)
    }

    @Test
    func `maps percentage used to percentRemaining`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponse.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then - percentage is "used", so remaining = 100 - used
        let tokenQuota = snapshot.quotas.first { $0.quotaType == .session }
        #expect(tokenQuota != nil)
        #expect(tokenQuota?.percentRemaining == 35.0) // 100 - 65 = 35
    }

    @Test
    func `creates session quota type for TOKENS_LIMIT`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponse.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        let tokenQuota = snapshot.quotas.first { $0.quotaType == .session }
        #expect(tokenQuota != nil)
    }

    @Test
    func `creates MCP quota type for TIME_LIMIT`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponse.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        let timeQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("MCP") }
        #expect(timeQuota != nil)
        #expect(timeQuota?.percentRemaining == 70.0) // 100 - 30 = 70
    }

    @Test
    func `handles only TOKENS_LIMIT present`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponseOnlyTokens.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.quotaType == .session)
        #expect(snapshot.quotas.first?.percentRemaining == 55.0) // 100 - 45 = 55
    }

    @Test
    func `sets providerId correctly`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponse.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        #expect(snapshot.providerId == "zai")
        #expect(snapshot.quotas.allSatisfy { $0.providerId == "zai" })
    }

    @Test
    func `treats 100% used as 0% remaining`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponseFullUsage.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        #expect(snapshot.quotas.first?.percentRemaining == 0.0)
    }

    @Test
    func `treats 0% used as 100% remaining`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponseNoUsage.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then
        #expect(snapshot.quotas.first?.percentRemaining == 100.0)
    }

    // MARK: - Error Handling Tests

    @Test
    func `throws parseFailed for invalid JSON`() throws {
        // Given
        let invalidData = Data("not json".utf8)

        // When/Then
        #expect(throws: ProbeError.self) {
            try ZaiUsageProbe.parseQuotaLimitResponse(invalidData, providerId: "zai")
        }
    }

    @Test
    func `throws parseFailed when no limits found`() throws {
        // Given
        let data = Data(Self.sampleQuotaLimitResponseEmpty.utf8)

        // When/Then
        #expect(throws: ProbeError.self) {
            try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")
        }
    }

    @Test
    func `handles missing data field gracefully`() throws {
        // Given
        let responseWithoutData = """
        {
          "error": "Unauthorized"
        }
        """
        let data = Data(responseWithoutData.utf8)

        // When/Then
        #expect(throws: ProbeError.self) {
            try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")
        }
    }

    @Test
    func `clamps percentage to valid range`() throws {
        // Given - edge case where percentage might be negative or > 100
        let responseWithInvalidPercentage = """
        {
          "data": {
            "limits": [
              {
                "type": "TOKENS_LIMIT",
                "percentage": -10
              },
              {
                "type": "TIME_LIMIT",
                "percentage": 150
              }
            ]
          }
        }
        """
        let data = Data(responseWithInvalidPercentage.utf8)

        // When
        let snapshot = try ZaiUsageProbe.parseQuotaLimitResponse(data, providerId: "zai")

        // Then - should clamp to 0-100 range
        #expect(snapshot.quotas.count == 2)
        #expect(snapshot.quotas[0].percentRemaining >= 0 && snapshot.quotas[0].percentRemaining <= 100)
        #expect(snapshot.quotas[1].percentRemaining >= 0 && snapshot.quotas[1].percentRemaining <= 100)
    }
}
