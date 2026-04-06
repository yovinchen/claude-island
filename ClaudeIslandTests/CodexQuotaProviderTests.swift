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
}
