import XCTest
@testable import Claude_Island

final class ClaudeCLIQuotaProbeTests: XCTestCase {
    func testParseUsageAndStatusCapturesWindowsAndIdentity() throws {
        let usage = """
        Welcome back
        Settings: Usage

        Current session
        23% used
        Resets Apr 8, 3:30PM

        Current week (all models)
        40% used
        Resets Apr 10, 9:00AM

        Current week (Opus)
        70% used
        Resets Apr 11, 1:15PM

        """

        let status = """
        Email: dev@example.com
        Organization: Demo Team
        Login method: Claude Max
        """

        let snapshot = try ClaudeCLIQuotaProbe.parse(text: usage, statusText: status)

        XCTAssertEqual(snapshot.sessionPercentLeft, 77)
        XCTAssertEqual(snapshot.weeklyPercentLeft, 60)
        XCTAssertEqual(snapshot.opusPercentLeft, 30)
        XCTAssertEqual(snapshot.accountEmail, "dev@example.com")
        XCTAssertEqual(snapshot.accountOrganization, "Demo Team")
        XCTAssertEqual(snapshot.loginMethod, "Max")
        XCTAssertEqual(snapshot.primaryResetDescription, "Resets Apr 8, 3:30PM")
    }

    func testParseResetDateHandlesMonthDayAndTime() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: 12, minute: 0))!

        let parsed = ClaudeCLIQuotaProbe.parseResetDate(from: "Resets Apr 8, 3:30PM", now: now)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(calendar.component(.month, from: parsed!), 4)
        XCTAssertEqual(calendar.component(.day, from: parsed!), 8)
        XCTAssertEqual(calendar.component(.hour, from: parsed!), 15)
        XCTAssertEqual(calendar.component(.minute, from: parsed!), 30)
    }
}
