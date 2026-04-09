import XCTest
@testable import Claude_Island

@MainActor
final class Wave4QuotaProviderTests: XCTestCase {
    func testAlibabaParsesCodingPlanQuotaWindows() throws {
        let json = """
        {
          "data": {
            "codingPlanInstanceInfos": [
              {
                "planName": "Coding Plan Pro",
                "quotaInfo": {
                  "per5HourUsedQuota": 12,
                  "per5HourTotalQuota": 100,
                  "per5HourQuotaNextRefreshTime": "2026-04-10T01:00:00Z",
                  "perWeekUsedQuota": 80,
                  "perWeekTotalQuota": 500,
                  "perWeekQuotaNextRefreshTime": "2026-04-14T00:00:00Z",
                  "perBillMonthUsedQuota": 120,
                  "perBillMonthTotalQuota": 1500,
                  "perBillMonthQuotaNextRefreshTime": "2026-05-01T00:00:00Z"
                }
              }
            ]
          }
        }
        """

        let snapshot = try AlibabaUsageFetcher.parseUsageSnapshot(from: Data(json.utf8), authMode: "web")
        let quota = snapshot.toQuotaSnapshot()

        XCTAssertEqual(quota.identity?.plan, "Coding Plan Pro")
        XCTAssertEqual(quota.primaryWindow?.usedRatio ?? 0, 0.12, accuracy: 0.001)
        XCTAssertEqual(quota.secondaryWindow?.usedRatio ?? 0, 0.16, accuracy: 0.001)
        XCTAssertEqual(quota.tertiaryWindow?.usedRatio ?? 0, 0.08, accuracy: 0.001)
        XCTAssertNotNil(quota.primaryWindow?.resetsAt)
    }

    func testMiniMaxParsesRemainsPayload() throws {
        let endTs = Int(Date(timeIntervalSince1970: 1_776_000_000).timeIntervalSince1970)
        let startTs = endTs - 3600
        let json = """
        {
          "data": {
            "currentSubscribeTitle": "MiniMax Coding Plan",
            "modelRemains": [
              {
                "currentIntervalTotalCount": 1000,
                "currentIntervalUsageCount": 250,
                "startTime": \(startTs),
                "endTime": \(endTs),
                "remainsTime": 1800
              }
            ]
          }
        }
        """

        let snapshot = try MiniMaxUsageFetcher.parseRemains(data: Data(json.utf8))
        let quota = snapshot.toQuotaSnapshot()

        XCTAssertEqual(quota.identity?.plan, "MiniMax Coding Plan")
        XCTAssertEqual(quota.primaryWindow?.usedRatio ?? 0, 0.75, accuracy: 0.001)
        XCTAssertEqual(quota.primaryWindow?.detail, "1000 prompts / 1h")
    }

    func testOllamaParsesSettingsHTML() throws {
        let html = """
        <html>
          <body>
            <div id="header-email">user@example.com</div>
            <span>Cloud Usage</span><span>Pro</span>
            <section>
              <h2>Session usage</h2>
              <div>24% used</div>
              <span data-time="2026-04-10T02:00:00Z"></span>
            </section>
            <section>
              <h2>Weekly usage</h2>
              <div style="width: 61%"></div>
              <span data-time="2026-04-14T02:00:00Z"></span>
            </section>
          </body>
        </html>
        """

        let snapshot = try OllamaUsageFetcher.parseHTML(html: html)
        let quota = snapshot.toQuotaSnapshot()

        XCTAssertEqual(quota.identity?.email, "user@example.com")
        XCTAssertEqual(quota.identity?.plan, "Pro")
        XCTAssertEqual(quota.primaryWindow?.usedRatio ?? 0, 0.24, accuracy: 0.001)
        XCTAssertEqual(quota.secondaryWindow?.usedRatio ?? 0, 0.61, accuracy: 0.001)
    }

    func testPerplexityParsesRecurringPromoAndPurchasedCredits() throws {
        let renewalTs: Double = 1_767_040_000
        let json = """
        {
          "balance_cents": 7250,
          "renewal_date_ts": \(renewalTs),
          "current_period_purchased_cents": 3000,
          "credit_grants": [
            { "type": "recurring", "amount_cents": 5000, "expires_at_ts": null },
            { "type": "promotional", "amount_cents": 2000, "expires_at_ts": \(renewalTs + 86400) },
            { "type": "purchased", "amount_cents": 3000, "expires_at_ts": null }
          ],
          "total_usage_cents": 2750
        }
        """

        let now = Date(timeIntervalSince1970: renewalTs - 3600)
        let snapshot = try PerplexityUsageFetcher.parseResponse(Data(json.utf8), now: now)
        let quota = snapshot.toQuotaSnapshot()

        XCTAssertEqual(quota.identity?.plan, "Max")
        XCTAssertEqual(quota.primaryWindow?.usedRatio ?? 0, 0.55, accuracy: 0.001)
        XCTAssertEqual(quota.secondaryWindow?.usedRatio ?? 0, 0.0, accuracy: 0.001)
        XCTAssertEqual(quota.tertiaryWindow?.usedRatio ?? 0, 0.0, accuracy: 0.001)
        XCTAssertNotNil(quota.primaryWindow?.resetsAt)
    }

    func testPerplexityFallsBackToPurchasedWhenRecurringIsAbsent() throws {
        let renewalTs: Double = 1_767_040_000
        let json = """
        {
          "balance_cents": 23065,
          "renewal_date_ts": \(renewalTs),
          "current_period_purchased_cents": 0,
          "credit_grants": [
            { "type": "purchased", "amount_cents": 3000, "expires_at_ts": null }
          ],
          "total_usage_cents": 1500
        }
        """

        let snapshot = try PerplexityUsageFetcher.parseResponse(Data(json.utf8), now: Date(timeIntervalSince1970: renewalTs - 3600))
        let quota = snapshot.toQuotaSnapshot()

        XCTAssertNil(quota.primaryWindow)
        XCTAssertEqual(quota.tertiaryWindow?.usedRatio ?? 0, 0.5, accuracy: 0.001)
    }
}
