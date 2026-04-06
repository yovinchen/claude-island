import XCTest
@testable import Claude_Island

@MainActor
final class QuotaWebSessionImportTests: XCTestCase {
    func testConfigurationExistsForSupportedWebProviders() {
        XCTAssertNotNil(QuotaWebSessionImportRunner.configuration(for: .cursor))
        XCTAssertNotNil(QuotaWebSessionImportRunner.configuration(for: .opencode))
        XCTAssertNotNil(QuotaWebSessionImportRunner.configuration(for: .amp))
        XCTAssertNotNil(QuotaWebSessionImportRunner.configuration(for: .augment))
        XCTAssertNil(QuotaWebSessionImportRunner.configuration(for: .openrouter))
    }

    func testFilteredCookieHeaderKeepsOnlyMatchingDomains() {
        let configuration = QuotaWebSessionImportRunner.configuration(for: .cursor)!
        let matchingCookie = makeCookie(name: "WorkosCursorSessionToken", value: "abc", domain: ".cursor.com")
        let matchingSubdomainCookie = makeCookie(name: "other", value: "def", domain: "authenticator.cursor.sh")
        let unrelatedCookie = makeCookie(name: "session", value: "ghi", domain: ".example.com")

        let header = QuotaWebSessionImportRunner.filteredCookieHeader(
            cookies: [matchingCookie, unrelatedCookie, matchingSubdomainCookie],
            configuration: configuration
        )

        XCTAssertEqual(header, "WorkosCursorSessionToken=abc; other=def")
    }

    func testReadyURLRequiresConfiguredHost() {
        let configuration = QuotaWebSessionImportRunner.configuration(for: .cursor)!

        XCTAssertTrue(configuration.isReadyURL(URL(string: "https://cursor.com/dashboard")))
        XCTAssertFalse(configuration.isReadyURL(URL(string: "https://authenticator.cursor.sh/login")))
    }

    private func makeCookie(name: String, value: String, domain: String) -> HTTPCookie {
        HTTPCookie(properties: [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: value,
            .secure: true,
        ])!
    }
}
