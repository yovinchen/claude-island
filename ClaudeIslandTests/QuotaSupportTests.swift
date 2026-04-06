import XCTest
@testable import Claude_Island

final class QuotaSupportTests: XCTestCase {
    func testParseMonthDayReturnsFutureDate() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!

        let parsed = QuotaRuntimeSupport.parseMonthDay("01/01", now: now)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(calendar.component(.year, from: parsed!), 2027)
        XCTAssertEqual(calendar.component(.month, from: parsed!), 1)
        XCTAssertEqual(calendar.component(.day, from: parsed!), 1)
    }

    func testStripANSIRemovesControlCodes() {
        let value = "\u{001B}[31mHello\u{001B}[0m\r\u{0008}"

        XCTAssertEqual(QuotaRuntimeSupport.stripANSI(value), "Hello")
    }

    func testSummaryLinePrefersUnlimitedCredits() {
        let descriptor = QuotaProviderRegistry.descriptor(for: .openrouter)
        let record = QuotaProviderRecord(
            descriptor: descriptor,
            isEnabled: true,
            isConfigured: true,
            status: .connected,
            snapshot: QuotaSnapshot(
                providerID: .openrouter,
                source: .apiKey,
                primaryWindow: nil,
                secondaryWindow: nil,
                tertiaryWindow: nil,
                credits: QuotaCredits(
                    label: "Credits",
                    used: nil,
                    total: nil,
                    remaining: nil,
                    currencyCode: "USD",
                    isUnlimited: true
                ),
                identity: nil,
                updatedAt: Date(),
                note: nil
            ),
            diagnostics: QuotaDiagnostics()
        )

        XCTAssertEqual(record.summaryLine, "Unlimited")
    }

    func testResolvedBinaryAcceptsExecutablePathOverride() {
        let resolved = QuotaRuntimeSupport.resolvedBinary(defaultBinary: "missing-binary", overrideValue: "/bin/zsh")

        XCTAssertEqual(resolved, "/bin/zsh")
    }

    func testResolvedBinaryRejectsMissingExecutablePathOverride() {
        let resolved = QuotaRuntimeSupport.resolvedBinary(
            defaultBinary: "missing-binary",
            overrideValue: "/definitely/not/a/real/binary"
        )

        XCTAssertNil(resolved)
    }

    func testNormalizeVersionLineStripsCodexPrefix() {
        let version = QuotaRuntimeSupport._test_normalizeVersionLine(providerID: .codex, line: "codex 0.20.3")

        XCTAssertEqual(version, "0.20.3")
    }

    func testNormalizeVersionLineStripsKiroPrefix() {
        let version = QuotaRuntimeSupport._test_normalizeVersionLine(providerID: .kiro, line: "kiro-cli 1.24.0")

        XCTAssertEqual(version, "1.24.0")
    }

    func testNormalizeVersionLineDropsClaudeParenSuffix() {
        let version = QuotaRuntimeSupport._test_normalizeVersionLine(providerID: .claude, line: "1.2.3 (Claude Code)")

        XCTAssertEqual(version, "1.2.3")
    }

    func testPackageJSONVersionReadsVersionField() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("package.json")
        try Data(#"{"version":"1.2.3"}"#.utf8).write(to: fileURL)

        let version = QuotaRuntimeSupport._test_packageJSONVersion(path: fileURL.path)

        XCTAssertEqual(version, "1.2.3")
    }
}
