import XCTest
@testable import Claude_Island

final class ClaudeWebQuotaProviderTests: XCTestCase {
    func testClaudeWebSessionKeyParsesRawTokenAndCookieHeader() throws {
        let raw = try ClaudeWebQuotaTestingSupport.parseSessionKey(cookieHeader: "sk-ant-test-session")
        let header = try ClaudeWebQuotaTestingSupport.parseSessionKey(cookieHeader: "sessionKey=sk-ant-cookie; foo=bar")

        XCTAssertEqual(raw, "sk-ant-test-session")
        XCTAssertEqual(header, "sk-ant-cookie")
    }

    func testClaudeWebUsageParsesSessionWeeklyAndOpusWindows() throws {
        let data = Data(
            """
            {
              "five_hour": { "utilization": 25, "resets_at": "2026-04-10T01:00:00Z" },
              "seven_day": { "utilization": 40, "resets_at": "2026-04-14T00:00:00Z" },
              "seven_day_opus": { "utilization": 70, "resets_at": "2026-04-14T00:00:00Z" }
            }
            """.utf8
        )

        let snapshot = try ClaudeWebQuotaTestingSupport.parseUsageData(data: data)

        XCTAssertEqual(snapshot.primaryWindow?.usedRatio ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(snapshot.secondaryWindow?.usedRatio ?? 0, 0.40, accuracy: 0.001)
        XCTAssertEqual(snapshot.tertiaryWindow?.usedRatio ?? 0, 0.70, accuracy: 0.001)
        XCTAssertEqual(snapshot.identity?.organization, "Demo Org")
    }

    func testClaudeWebOverageParsesMonthlyCredits() {
        let data = Data(
            """
            {
              "monthly_credit_limit": 1500,
              "currency": "USD",
              "used_credits": 375,
              "is_enabled": true
            }
            """.utf8
        )

        let credits = ClaudeWebQuotaTestingSupport.parseOverage(data: data)

        XCTAssertEqual(credits?.used ?? 0, 3.75, accuracy: 0.001)
        XCTAssertEqual(credits?.total ?? 0, 15.0, accuracy: 0.001)
        XCTAssertEqual(credits?.remaining ?? 0, 11.25, accuracy: 0.001)
        XCTAssertEqual(credits?.currencyCode, "USD")
    }

    func testClaudeWebAccountParsesEmailAndLoginMethod() {
        let data = Data(
            """
            {
              "email_address": "dev@example.com",
              "memberships": [
                {
                  "organization": {
                    "uuid": "org_123",
                    "rate_limit_tier": "max",
                    "billing_type": "monthly"
                  }
                }
              ]
            }
            """.utf8
        )

        let account = ClaudeWebQuotaTestingSupport.parseAccount(data: data)

        XCTAssertEqual(account?.email, "dev@example.com")
        XCTAssertEqual(account?.loginMethod, "Max Monthly")
    }
}
