import XCTest
@testable import Claude_Island

final class CodexQuotaProviderTests: XCTestCase {
    func testCodexCreditDetailsDecodesStringBalance() throws {
        let data = Data(
            """
            {
              "has_credits": true,
              "unlimited": false,
              "balance": "12.50"
            }
            """.utf8
        )

        let balance = try CodexQuotaTestingSupport.decodeCreditBalance(data)

        XCTAssertEqual(balance ?? 0, 12.5, accuracy: 0.001)
    }

    func testCodexUsageURLPrefersConfiguredBaseURLWithoutBackendAPI() {
        let config = """
        chatgpt_base_url = "https://example.com"
        """

        let url = CodexQuotaTestingSupport.resolveUsageURL(configContents: config)

        XCTAssertEqual(url.absoluteString, "https://example.com/api/codex/usage")
    }

    func testCodexWebDashboardParserExtractsLimitsCreditsAndPlan() {
        let bodyText = """
        5h limit
        35% remaining
        Resets Apr 10 3:30PM

        Weekly limit
        60% remaining
        Resets Apr 14 9:00AM

        Credits remaining 12.5
        """

        let html = """
        <html>
          <script id="client-bootstrap" type="application/json">
            {"session":{"user":{"email":"dev@example.com"}},"subscription":{"plan":"ChatGPT Pro"}}
          </script>
        </html>
        """

        let snapshot = CodexWebQuotaTestingSupport.parseDashboard(bodyText: bodyText, html: html)

        XCTAssertEqual(snapshot?.signedInEmail, "dev@example.com")
        XCTAssertEqual(snapshot?.accountPlan, "Chatgpt Pro")
        XCTAssertEqual(snapshot?.creditsRemaining ?? 0, 12.5, accuracy: 0.001)
        XCTAssertEqual(snapshot?.primaryLimit?.usedRatio ?? 0, 0.65, accuracy: 0.001)
        XCTAssertEqual(snapshot?.secondaryLimit?.usedRatio ?? 0, 0.40, accuracy: 0.001)
    }
}
