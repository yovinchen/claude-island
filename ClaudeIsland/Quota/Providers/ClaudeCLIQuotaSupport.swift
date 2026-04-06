#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

struct ClaudeCLIQuotaSnapshot: Sendable {
    let sessionPercentLeft: Int?
    let weeklyPercentLeft: Int?
    let opusPercentLeft: Int?
    let accountEmail: String?
    let accountOrganization: String?
    let loginMethod: String?
    let primaryResetDescription: String?
    let secondaryResetDescription: String?
    let opusResetDescription: String?
    let rawText: String
}

enum ClaudeCLIQuotaProbeError: LocalizedError, Sendable {
    case claudeNotInstalled
    case parseFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            return "Claude CLI is not installed or not on PATH."
        case .parseFailed(let message):
            return message
        case .timedOut:
            return "Claude CLI usage probe timed out."
        }
    }
}

actor ClaudeCLIQuotaSession {
    static let shared = ClaudeCLIQuotaSession()

    enum SessionError: LocalizedError {
        case launchFailed(String)
        case ioFailed(String)
        case timedOut
        case processExited

        var errorDescription: String? {
            switch self {
            case .launchFailed(let message):
                return "Failed to launch Claude CLI session: \(message)"
            case .ioFailed(let message):
                return "Claude CLI PTY I/O failed: \(message)"
            case .timedOut:
                return "Claude CLI session timed out."
            case .processExited:
                return "Claude CLI session exited."
            }
        }
    }

    private var process: Process?
    private var primaryFD: Int32 = -1
    private var primaryHandle: FileHandle?
    private var secondaryHandle: FileHandle?
    private var processGroup: pid_t?
    private var binaryPath: String?
    private var startedAt: Date?

    private let promptSends: [String: String] = [
        "Do you trust the files in this folder?": "y\r",
        "Quick safety check:": "\r",
        "Yes, I trust this folder": "\r",
        "Ready to code here?": "\r",
        "Press Enter to continue": "\r",
    ]

    private struct RollingBuffer {
        private let maxNeedle: Int
        private var tail = Data()

        init(maxNeedle: Int) {
            self.maxNeedle = max(0, maxNeedle)
        }

        mutating func append(_ data: Data) -> Data {
            guard !data.isEmpty else { return Data() }
            var combined = Data()
            combined.reserveCapacity(self.tail.count + data.count)
            combined.append(self.tail)
            combined.append(data)
            if self.maxNeedle > 1 {
                if combined.count >= self.maxNeedle - 1 {
                    self.tail = combined.suffix(self.maxNeedle - 1)
                } else {
                    self.tail = combined
                }
            } else {
                self.tail.removeAll(keepingCapacity: true)
            }
            return combined
        }
    }

    func capture(
        subcommand: String,
        binary: String,
        timeout: TimeInterval,
        idleTimeout: TimeInterval? = 3.0,
        sendEnterEvery: TimeInterval? = nil
    ) async throws -> String {
        try ensureStarted(binary: binary)
        if let startedAt {
            let sinceStart = Date().timeIntervalSince(startedAt)
            if sinceStart < 2.0 {
                let delay = UInt64((2.0 - sinceStart) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
        drainOutput()

        let trimmed = subcommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            try send(trimmed)
            try send("\r")
        }

        var sendMap = promptSends
        for (needle, keys) in Self.commandPaletteSends(for: trimmed) {
            sendMap[needle] = keys
        }
        let sendNeedles = sendMap.map { (needle: Self.normalizedNeedle($0.key), keys: $0.value) }
        let cursorQuery = Data([0x1B, 0x5B, 0x36, 0x6E])
        let maxNeedle = ([cursorQuery.count] + sendMap.keys.map(\.utf8.count)).max() ?? cursorQuery.count
        var scanBuffer = RollingBuffer(maxNeedle: maxNeedle)
        var triggeredSends = Set<String>()

        var buffer = Data()
        var scanTailText = ""
        var utf8Carry = Data()
        let deadline = Date().addingTimeInterval(timeout)
        var lastOutputAt = Date()
        var lastEnterAt = Date()
        var stoppedEarly = false

        while Date() < deadline {
            let newData = readChunk()
            if !newData.isEmpty {
                buffer.append(newData)
                lastOutputAt = Date()
                Self.appendScanText(newData: newData, scanTailText: &scanTailText, utf8Carry: &utf8Carry)
                if scanTailText.count > 8192 {
                    scanTailText = String(scanTailText.suffix(8192))
                }
            }

            let scanData = scanBuffer.append(newData)
            if !scanData.isEmpty, scanData.range(of: cursorQuery) != nil {
                try? send("\u{1b}[1;1R")
            }

            let normalizedScan = Self.normalizedNeedle(QuotaRuntimeSupport.stripANSI(scanTailText))
            for item in sendNeedles where !triggeredSends.contains(item.needle) {
                if normalizedScan.contains(item.needle) {
                    try? send(item.keys)
                    triggeredSends.insert(item.needle)
                }
            }

            if shouldStopForIdleTimeout(idleTimeout: idleTimeout, bufferIsEmpty: buffer.isEmpty, lastOutputAt: lastOutputAt) {
                stoppedEarly = true
                break
            }

            sendPeriodicEnterIfNeeded(every: sendEnterEvery, lastEnterAt: &lastEnterAt)

            if let process, !process.isRunning {
                throw SessionError.processExited
            }

            try await Task.sleep(nanoseconds: 60_000_000)
        }

        if stoppedEarly {
            let settleDeadline = Date().addingTimeInterval(0.25)
            while Date() < settleDeadline {
                let newData = readChunk()
                if !newData.isEmpty {
                    buffer.append(newData)
                }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        guard !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) else {
            throw SessionError.timedOut
        }
        return text
    }

    func reset() {
        cleanup()
    }

    private func ensureStarted(binary: String) throws {
        if let process, process.isRunning, binaryPath == binary {
            return
        }
        cleanup()

        var primaryFD: Int32 = -1
        var secondaryFD: Int32 = -1
        var windowSize = winsize(ws_row: 50, ws_col: 160, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&primaryFD, &secondaryFD, nil, nil, &windowSize) == 0 else {
            throw SessionError.launchFailed("openpty failed")
        }
        _ = fcntl(primaryFD, F_SETFL, O_NONBLOCK)

        let primaryHandle = FileHandle(fileDescriptor: primaryFD, closeOnDealloc: true)
        let secondaryHandle = FileHandle(fileDescriptor: secondaryFD, closeOnDealloc: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--allowed-tools", ""]
        process.standardInput = secondaryHandle
        process.standardOutput = secondaryHandle
        process.standardError = secondaryHandle
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.environment = scrubbedClaudeEnvironment(from: Foundation.ProcessInfo.processInfo.environment)

        do {
            try process.run()
        } catch {
            try? primaryHandle.close()
            try? secondaryHandle.close()
            throw SessionError.launchFailed(error.localizedDescription)
        }

        let pid = process.processIdentifier
        var processGroup: pid_t?
        if setpgid(pid, pid) == 0 {
            processGroup = pid
        }

        self.process = process
        self.primaryFD = primaryFD
        self.primaryHandle = primaryHandle
        self.secondaryHandle = secondaryHandle
        self.processGroup = processGroup
        self.binaryPath = binary
        self.startedAt = Date()
    }

    private func scrubbedClaudeEnvironment(from base: [String: String]) -> [String: String] {
        var environment = base
        environment["TERM"] = "xterm-256color"
        for key in environment.keys where key.hasPrefix("ANTHROPIC_") {
            environment.removeValue(forKey: key)
        }
        return environment
    }

    private func cleanup() {
        if let process, process.isRunning {
            try? writeAllToPrimary(Data("/exit\r".utf8))
        }
        try? primaryHandle?.close()
        try? secondaryHandle?.close()

        if let process, process.isRunning {
            process.terminate()
        }
        if let processGroup {
            kill(-processGroup, SIGTERM)
        }

        let waitDeadline = Date().addingTimeInterval(1.0)
        if let process {
            while process.isRunning, Date() < waitDeadline {
                usleep(100_000)
            }
            if process.isRunning {
                if let processGroup {
                    kill(-processGroup, SIGKILL)
                }
                kill(process.processIdentifier, SIGKILL)
            }
        }

        process = nil
        primaryHandle = nil
        secondaryHandle = nil
        primaryFD = -1
        processGroup = nil
        binaryPath = nil
        startedAt = nil
    }

    private func readChunk() -> Data {
        guard primaryFD >= 0 else { return Data() }
        var appended = Data()
        while true {
            var temporary = [UInt8](repeating: 0, count: 8192)
            let count = read(primaryFD, &temporary, temporary.count)
            if count > 0 {
                appended.append(contentsOf: temporary.prefix(count))
                continue
            }
            break
        }
        return appended
    }

    private func drainOutput() {
        _ = readChunk()
    }

    private func shouldStopForIdleTimeout(idleTimeout: TimeInterval?, bufferIsEmpty: Bool, lastOutputAt: Date) -> Bool {
        guard let idleTimeout, !bufferIsEmpty else { return false }
        return Date().timeIntervalSince(lastOutputAt) >= idleTimeout
    }

    private func sendPeriodicEnterIfNeeded(every: TimeInterval?, lastEnterAt: inout Date) {
        guard let every, Date().timeIntervalSince(lastEnterAt) >= every else { return }
        try? send("\r")
        lastEnterAt = Date()
    }

    private func send(_ text: String) throws {
        guard let data = text.data(using: .utf8) else { return }
        guard primaryFD >= 0 else { throw SessionError.processExited }
        try writeAllToPrimary(data)
    }

    private func writeAllToPrimary(_ data: Data) throws {
        guard primaryFD >= 0 else { throw SessionError.processExited }
        try data.withUnsafeBytes { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else { return }
            var offset = 0
            var retries = 0

            while offset < rawBytes.count {
                let written = write(primaryFD, baseAddress.advanced(by: offset), rawBytes.count - offset)
                if written > 0 {
                    offset += written
                    retries = 0
                    continue
                }
                if written == 0 {
                    break
                }

                let error = errno
                if error == EINTR || error == EAGAIN || error == EWOULDBLOCK {
                    retries += 1
                    if retries > 200 {
                        throw SessionError.ioFailed("write to PTY would block")
                    }
                    usleep(5_000)
                    continue
                }
                throw SessionError.ioFailed("write to PTY failed: \(String(cString: strerror(error)))")
            }
        }
    }

    private static func normalizedNeedle(_ text: String) -> String {
        String(text.lowercased().filter { !$0.isWhitespace })
    }

    private static func commandPaletteSends(for subcommand: String) -> [String: String] {
        switch subcommand.lowercased() {
        case "/usage":
            return [
                "Show plan": "\r",
                "Show plan usage limits": "\r",
            ]
        case "/status":
            return [
                "Show Claude Code": "\r",
                "Show Claude Code status": "\r",
            ]
        default:
            return [:]
        }
    }

    private static func appendScanText(newData: Data, scanTailText: inout String, utf8Carry: inout Data) {
        var combined = Data()
        combined.reserveCapacity(utf8Carry.count + newData.count)
        combined.append(utf8Carry)
        combined.append(newData)

        if let chunk = String(data: combined, encoding: .utf8) {
            scanTailText.append(chunk)
            utf8Carry.removeAll(keepingCapacity: true)
            return
        }

        for trimCount in 1...3 where combined.count > trimCount {
            let prefix = combined.dropLast(trimCount)
            if let chunk = String(data: prefix, encoding: .utf8) {
                scanTailText.append(chunk)
                utf8Carry = Data(combined.suffix(trimCount))
                return
            }
        }

        utf8Carry = Data(combined.suffix(12))
    }
}

struct ClaudeCLIQuotaProbe: Sendable {
    let binaryPath: String
    var timeout: TimeInterval = 20

    func fetch() async throws -> ClaudeCLIQuotaSnapshot {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw ClaudeCLIQuotaProbeError.claudeNotInstalled
        }

        do {
            var usage = try await ClaudeCLIQuotaSession.shared.capture(
                subcommand: "/usage",
                binary: binaryPath,
                timeout: timeout,
                idleTimeout: 3,
                sendEnterEvery: 0.8
            )
            if !Self.usageOutputLooksRelevant(usage) {
                usage = try await ClaudeCLIQuotaSession.shared.capture(
                    subcommand: "/usage",
                    binary: binaryPath,
                    timeout: max(timeout, 14),
                    idleTimeout: 3,
                    sendEnterEvery: 0.8
                )
            }
            let status = try? await ClaudeCLIQuotaSession.shared.capture(
                subcommand: "/status",
                binary: binaryPath,
                timeout: min(timeout, 12),
                idleTimeout: 2.5,
                sendEnterEvery: nil
            )
            let snapshot = try Self.parse(text: usage, statusText: status)
            await ClaudeCLIQuotaSession.shared.reset()
            return snapshot
        } catch {
            await ClaudeCLIQuotaSession.shared.reset()
            throw error
        }
    }

    static func parse(text: String, statusText: String? = nil) throws -> ClaudeCLIQuotaSnapshot {
        let clean = QuotaRuntimeSupport.stripANSI(text)
        let statusClean = statusText.map(QuotaRuntimeSupport.stripANSI)
        guard !clean.isEmpty else {
            throw ClaudeCLIQuotaProbeError.timedOut
        }

        if let usageError = extractUsageError(text: clean) {
            throw ClaudeCLIQuotaProbeError.parseFailed(usageError)
        }

        let usagePanelText = trimToLatestUsagePanel(clean) ?? clean
        let labelContext = LabelSearchContext(text: usagePanelText)

        var sessionPct = extractPercent(labelSubstring: "Current session", context: labelContext)
        var weeklyPct = extractPercent(labelSubstring: "Current week (all models)", context: labelContext)
        var opusPct = extractPercent(
            labelSubstrings: [
                "Current week (Opus)",
                "Current week (Sonnet only)",
                "Current week (Sonnet)",
            ],
            context: labelContext
        )

        let compactContext = usagePanelText.lowercased().filter { !$0.isWhitespace }
        let hasWeeklyLabel = labelContext.contains("currentweek") || compactContext.contains("currentweek")
        let hasOpusLabel = labelContext.contains("opus") || labelContext.contains("sonnet")

        if sessionPct == nil || (hasWeeklyLabel && weeklyPct == nil) || (hasOpusLabel && opusPct == nil) {
            let ordered = allPercents(usagePanelText)
            if sessionPct == nil, ordered.indices.contains(0) {
                sessionPct = ordered[0]
            }
            if hasWeeklyLabel, weeklyPct == nil, ordered.indices.contains(1) {
                weeklyPct = ordered[1]
            }
            if hasOpusLabel, opusPct == nil, ordered.indices.contains(2) {
                opusPct = ordered[2]
            }
        }

        let identity = parseIdentity(usageText: clean, statusText: statusClean)
        guard let sessionPct else {
            throw ClaudeCLIQuotaProbeError.parseFailed("Missing Current session.")
        }

        let sessionReset = extractReset(labelSubstring: "Current session", context: labelContext)
        let weeklyReset = hasWeeklyLabel
            ? extractReset(labelSubstring: "Current week (all models)", context: labelContext)
            : nil
        let opusReset = hasOpusLabel
            ? extractReset(
                labelSubstrings: [
                    "Current week (Opus)",
                    "Current week (Sonnet only)",
                    "Current week (Sonnet)",
                ],
                context: labelContext
            )
            : nil

        return ClaudeCLIQuotaSnapshot(
            sessionPercentLeft: sessionPct,
            weeklyPercentLeft: weeklyPct,
            opusPercentLeft: opusPct,
            accountEmail: identity.accountEmail,
            accountOrganization: identity.accountOrganization,
            loginMethod: identity.loginMethod,
            primaryResetDescription: sessionReset,
            secondaryResetDescription: weeklyReset,
            opusResetDescription: opusReset,
            rawText: text + (statusText ?? "")
        )
    }

    static func parseResetDate(from text: String?, now: Date = .init()) -> Date? {
        guard let normalized = normalizeResetInput(text) else { return nil }
        let (raw, timeZone) = normalized

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone ?? TimeZone.current
        formatter.defaultDate = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone

        if let date = parseDate(raw, formats: resetDateTimeWithMinutes, formatter: formatter) {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            components.second = 0
            return calendar.date(from: components)
        }
        if let date = parseDate(raw, formats: resetDateTimeHourOnly, formatter: formatter) {
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            components.minute = 0
            components.second = 0
            return calendar.date(from: components)
        }
        if let time = parseDate(raw, formats: resetTimeWithMinutes, formatter: formatter) {
            let components = calendar.dateComponents([.hour, .minute], from: time)
            guard let anchored = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: now
            ) else {
                return nil
            }
            return anchored >= now ? anchored : calendar.date(byAdding: .day, value: 1, to: anchored)
        }
        guard let time = parseDate(raw, formats: resetTimeHourOnly, formatter: formatter) else {
            return nil
        }
        let components = calendar.dateComponents([.hour], from: time)
        guard let anchored = calendar.date(bySettingHour: components.hour ?? 0, minute: 0, second: 0, of: now) else {
            return nil
        }
        return anchored >= now ? anchored : calendar.date(byAdding: .day, value: 1, to: anchored)
    }

    private struct ClaudeAccountIdentity: Sendable {
        let accountEmail: String?
        let accountOrganization: String?
        let loginMethod: String?
    }

    private struct LabelSearchContext {
        let lines: [String]
        let normalizedLines: [String]
        let normalizedData: Data

        init(text: String) {
            self.lines = text.components(separatedBy: .newlines)
            self.normalizedLines = self.lines.map { ClaudeCLIQuotaProbe.normalizedForLabelSearch($0) }
            let normalized = ClaudeCLIQuotaProbe.normalizedForLabelSearch(text)
            self.normalizedData = Data(normalized.utf8)
        }

        func contains(_ needle: String) -> Bool {
            normalizedData.range(of: Data(needle.utf8)) != nil
        }
    }

    private static let resetTimeWithMinutes = ["h:mma", "h:mm a", "HH:mm", "H:mm"]
    private static let resetTimeHourOnly = ["ha", "h a"]
    private static let resetDateTimeWithMinutes = [
        "MMM d, h:mma",
        "MMM d, h:mm a",
        "MMM d h:mma",
        "MMM d h:mm a",
        "MMM d, HH:mm",
        "MMM d HH:mm",
    ]
    private static let resetDateTimeHourOnly = [
        "MMM d, ha",
        "MMM d, h a",
        "MMM d ha",
        "MMM d h a",
    ]

    private static func usageOutputLooksRelevant(_ text: String) -> Bool {
        let normalized = QuotaRuntimeSupport.stripANSI(text).lowercased().filter { !$0.isWhitespace }
        return normalized.contains("currentsession")
            || normalized.contains("currentweek")
            || normalized.contains("loadingusage")
            || normalized.contains("failedtoloadusagedata")
    }

    private static func trimToLatestUsagePanel(_ text: String) -> String? {
        guard let settingsRange = text.range(of: "Settings:", options: [.caseInsensitive, .backwards]) else {
            return nil
        }
        let tail = text[settingsRange.lowerBound...]
        guard tail.range(of: "Usage", options: .caseInsensitive) != nil else {
            return nil
        }
        let lower = tail.lowercased()
        let hasPercent = lower.contains("%")
        let hasUsageWords = lower.contains("used") || lower.contains("left") || lower.contains("remaining") || lower.contains("available")
        let hasLoading = lower.contains("loading usage")
        guard (hasPercent && hasUsageWords) || hasLoading else {
            return nil
        }
        return String(tail)
    }

    private static func extractPercent(labelSubstring: String, context: LabelSearchContext) -> Int? {
        let label = normalizedForLabelSearch(labelSubstring)
        for (index, normalizedLine) in context.normalizedLines.enumerated() where normalizedLine.contains(label) {
            let window = context.lines.dropFirst(index).prefix(12)
            for candidate in window {
                if let percent = percentFromLine(candidate) {
                    return percent
                }
            }
        }
        return nil
    }

    private static func extractPercent(labelSubstrings: [String], context: LabelSearchContext) -> Int? {
        for label in labelSubstrings {
            if let value = extractPercent(labelSubstring: label, context: context) {
                return value
            }
        }
        return nil
    }

    private static func allPercents(_ text: String) -> [Int] {
        let lines = text.components(separatedBy: .newlines)
        let normalized = text.lowercased().filter { !$0.isWhitespace }
        let hasUsageWindows = normalized.contains("currentsession") || normalized.contains("currentweek")
        let hasLoading = normalized.contains("loadingusage")
        let hasUsagePercentKeywords = normalized.contains("used") || normalized.contains("left") || normalized.contains("remaining") || normalized.contains("available")
        if !(hasUsageWindows || hasLoading) || !hasUsagePercentKeywords {
            return []
        }
        if hasLoading && !hasUsageWindows {
            return []
        }
        return lines.compactMap { percentFromLine($0, assumeRemainingWhenUnclear: false) }
    }

    private static func percentFromLine(_ line: String, assumeRemainingWhenUnclear: Bool = false) -> Int? {
        if isLikelyStatusContextLine(line) {
            return nil
        }

        let pattern = #"([0-9]{1,3}(?:\.[0-9]+)?)\p{Zs}*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }

        let rawValue = Double(line[valueRange]) ?? 0
        let clamped = max(0, min(100, rawValue))
        let lower = line.lowercased()
        let usedKeywords = ["used", "spent", "consumed"]
        let remainingKeywords = ["left", "remaining", "available"]
        if usedKeywords.contains(where: lower.contains) {
            return Int(max(0, min(100, 100 - clamped)).rounded())
        }
        if remainingKeywords.contains(where: lower.contains) {
            return Int(clamped.rounded())
        }
        return assumeRemainingWhenUnclear ? Int(clamped.rounded()) : nil
    }

    private static func extractReset(labelSubstring: String, context: LabelSearchContext) -> String? {
        let label = normalizedForLabelSearch(labelSubstring)
        for (index, normalizedLine) in context.normalizedLines.enumerated() where normalizedLine.contains(label) {
            let window = context.lines.dropFirst(index).prefix(14)
            for candidate in window {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = normalizedForLabelSearch(trimmed)
                if normalized.hasPrefix("current"), !normalized.contains(label) {
                    break
                }
                if let reset = resetFromLine(candidate) {
                    return reset
                }
            }
        }
        return nil
    }

    private static func extractReset(labelSubstrings: [String], context: LabelSearchContext) -> String? {
        for label in labelSubstrings {
            if let value = extractReset(labelSubstring: label, context: context) {
                return value
            }
        }
        return nil
    }

    private static func resetFromLine(_ line: String) -> String? {
        guard let range = line.range(of: "Resets", options: [.caseInsensitive]) else {
            return nil
        }
        let raw = String(line[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanResetLine(raw)
    }

    private static func cleanResetLine(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " )"))
        let openCount = cleaned.filter { $0 == "(" }.count
        let closeCount = cleaned.filter { $0 == ")" }.count
        if openCount > closeCount {
            cleaned.append(")")
        }
        return cleaned
    }

    private static func normalizedForLabelSearch(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    private static func isLikelyStatusContextLine(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        let lower = line.lowercased()
        let modelTokens = ["opus", "sonnet", "haiku", "default"]
        return modelTokens.contains(where: lower.contains)
    }

    private static func parseIdentity(usageText: String?, statusText: String?) -> ClaudeAccountIdentity {
        let usageClean = usageText.map(QuotaRuntimeSupport.stripANSI) ?? ""
        let statusClean = statusText.map(QuotaRuntimeSupport.stripANSI)
        return extractIdentity(usageText: usageClean, statusText: statusClean)
    }

    private static func extractIdentity(usageText: String, statusText: String?) -> ClaudeAccountIdentity {
        let emailPatterns = [
            #"(?i)Account:\s+([^\s@]+@[^\s@]+)"#,
            #"(?i)Email:\s+([^\s@]+@[^\s@]+)"#,
        ]
        let looseEmailPatterns = [
            #"(?i)Account:\s+(\S+)"#,
            #"(?i)Email:\s+(\S+)"#,
        ]

        let email = emailPatterns.compactMap { extractFirst(pattern: $0, text: usageText) }.first
            ?? emailPatterns.compactMap { extractFirst(pattern: $0, text: statusText ?? "") }.first
            ?? looseEmailPatterns.compactMap { extractFirst(pattern: $0, text: usageText) }.first
            ?? looseEmailPatterns.compactMap { extractFirst(pattern: $0, text: statusText ?? "") }.first
            ?? extractFirst(pattern: #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, text: usageText)
            ?? extractFirst(pattern: #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, text: statusText ?? "")

        let orgPatterns = [
            #"(?i)Org:\s*(.+)"#,
            #"(?i)Organization:\s*(.+)"#,
        ]
        let orgRaw = orgPatterns.compactMap { extractFirst(pattern: $0, text: usageText) }.first
            ?? orgPatterns.compactMap { extractFirst(pattern: $0, text: statusText ?? "") }.first
        let organization: String? = {
            guard let value = orgRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            if let email, value.lowercased().hasPrefix(email.lowercased()) {
                return nil
            }
            return value
        }()

        let loginMethod = extractLoginMethod(text: statusText ?? "") ?? extractLoginMethod(text: usageText)
        return ClaudeAccountIdentity(
            accountEmail: email,
            accountOrganization: organization,
            loginMethod: loginMethod
        )
    }

    private static func extractLoginMethod(text: String) -> String? {
        guard !text.isEmpty else { return nil }
        if let explicit = extractFirst(pattern: #"(?i)login\s+method:\s*(.+)"#, text: text) {
            return cleanPlan(explicit)
        }

        let planPattern = #"(?i)(claude\s+[a-z0-9][a-z0-9\s._-]{0,24})"#
        var candidates: [String] = []
        if let regex = try? NSRegularExpression(pattern: planPattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match,
                      match.numberOfRanges >= 2,
                      let valueRange = Range(match.range(at: 1), in: text)
                else {
                    return
                }
                candidates.append(cleanPlan(String(text[valueRange])))
            }
        }

        return candidates.first(where: { candidate in
            let lower = candidate.lowercased()
            return !lower.contains("code v") && !lower.contains("code version")
        })
    }

    private static func cleanPlan(_ text: String) -> String {
        let stripped = QuotaRuntimeSupport.stripANSI(text)
        let withoutCodes = stripped.replacingOccurrences(
            of: #"^\s*(?:\[\d{1,3}m\s*)+"#,
            with: "",
            options: [.regularExpression]
        )
        let withoutBoilerplate = withoutCodes.replacingOccurrences(
            of: #"(?i)\b(claude|account|plan)\b"#,
            with: "",
            options: [.regularExpression]
        )
        let cleaned = withoutBoilerplate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? stripped.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    private static func extractFirst(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractUsageError(text: String) -> String? {
        let lower = text.lowercased()
        let compact = lower.filter { !$0.isWhitespace }
        if lower.contains("token_expired") || lower.contains("token has expired") {
            return "Claude CLI token expired. Run `claude login` to refresh."
        }
        if lower.contains("authentication_error") {
            return "Claude CLI authentication error. Run `claude login`."
        }
        if lower.contains("rate_limit_error") || lower.contains("rate limited") || compact.contains("ratelimited") {
            return "Claude CLI usage endpoint is rate limited right now. Please try again later."
        }
        if lower.contains("failed to load usage data") || compact.contains("failedtoloadusagedata") {
            return "Claude CLI could not load usage data. Open the CLI and retry `/usage`."
        }
        return nil
    }

    private static func normalizeResetInput(_ text: String?) -> (String, TimeZone?)? {
        guard var raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        raw = raw.replacingOccurrences(of: #"(?i)^resets?:?\s*"#, with: "", options: .regularExpression)
        raw = raw.replacingOccurrences(of: " at ", with: " ", options: .caseInsensitive)
        raw = raw.replacingOccurrences(of: #"(?i)\b([A-Za-z]{3})(\d)"#, with: "$1 $2", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #",(\d)"#, with: ", $1", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?i)(\d)at(?=\d)"#, with: "$1 ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?<=\d)\.(\d{2})\b"#, with: ":$1", options: .regularExpression)

        let timeZone = extractTimeZone(from: &raw)
        raw = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : (raw, timeZone)
    }

    private static func extractTimeZone(from text: inout String) -> TimeZone? {
        guard let range = text.range(of: #"\(([^)]+)\)"#, options: .regularExpression) else {
            return nil
        }
        let timeZoneID = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "() "))
        text.removeSubrange(range)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return TimeZone(identifier: timeZoneID)
    }

    private static func parseDate(_ text: String, formats: [String], formatter: DateFormatter) -> Date? {
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }
}
