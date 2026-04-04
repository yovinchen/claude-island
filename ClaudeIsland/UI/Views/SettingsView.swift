//
//  SettingsView.swift
//  ClaudeIsland
//
//  Full settings view for the independent settings window.
//  Organized into tabs: General, Hooks, Sound, Usage, Diagnostics.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                settingsTab(icon: "gearshape", label: "General", index: 0)
                settingsTab(icon: "link", label: "Hooks", index: 1)
                settingsTab(icon: "speaker.wave.2", label: "Sound", index: 2)
                settingsTab(icon: "chart.bar", label: "Usage", index: 3)
                settingsTab(icon: "doc.text.magnifyingglass", label: "Diagnostics", index: 4)
                Spacer()
            }
            .frame(width: 160)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.3))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0: generalTab
                    case 1: hooksTab
                    case 2: soundTab
                    case 3: usageTab
                    case 4: diagnosticsTab
                    default: generalTab
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)))
    }

    // MARK: - Tab Button

    private func settingsTab(icon: String, label: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == index ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        sectionHeader("Behavior")

        SettingsToggle(label: "Auto-expand on task complete",
                      getter: { AppSettings.autoExpandOnTaskComplete },
                      setter: { AppSettings.autoExpandOnTaskComplete = $0 })
        SettingsToggle(label: "Suppress auto-expand when focused",
                      getter: { AppSettings.suppressAutoExpandWhenFocusedSession },
                      setter: { AppSettings.suppressAutoExpandWhenFocusedSession = $0 })
        SettingsToggle(label: "Auto-hide when idle",
                      getter: { AppSettings.autoHideWhenIdle },
                      setter: { AppSettings.autoHideWhenIdle = $0 })
        SettingsToggle(label: "Global shortcut (\u{2318}\u{21E7}I)",
                      getter: { AppSettings.globalShortcutEnabled },
                      setter: { AppSettings.globalShortcutEnabled = $0; KeyboardShortcutManager.shared.updateRegistration() })

        Divider().background(Color.white.opacity(0.1))

        sectionHeader("System")

        LaunchAtLoginToggle()
    }

    // MARK: - Hooks Tab

    @ViewBuilder
    private var hooksTab: some View {
        sectionHeader("AI Tool Integrations")

        SettingsHookList()

        Divider().background(Color.white.opacity(0.1))

        SettingsToggle(label: "Auto-repair hooks when removed",
                      getter: { AppSettings.autoRepairHooks },
                      setter: { AppSettings.autoRepairHooks = $0; HookRepairManager.shared.restart() })
    }

    // MARK: - Sound Tab

    @ViewBuilder
    private var soundTab: some View {
        sectionHeader("Sound Theme")

        SoundThemePicker()

        Divider().background(Color.white.opacity(0.1))

        sectionHeader("Audio Device")

        Text("Sound output automatically follows your active audio device.")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Usage Tab

    @ViewBuilder
    private var usageTab: some View {
        sectionHeader("API Usage Display")

        SettingsToggle(label: "Show usage data in notch header",
                      getter: { AppSettings.showUsageData },
                      setter: { AppSettings.showUsageData = $0 })

        Text("API usage and context window data are displayed as ring indicators when a session is active.")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))
            .padding(.top, 4)
    }

    // MARK: - Diagnostics Tab

    @ViewBuilder
    private var diagnosticsTab: some View {
        sectionHeader("Diagnostic Log")

        Text("The diagnostic log captures hook, socket, and session events for troubleshooting.")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))

        HStack(spacing: 12) {
            Button("Copy Log to Clipboard") {
                Task {
                    let log = await DiagnosticLogger.shared.export()
                    await MainActor.run {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(log, forType: .string)
                    }
                }
            }
            .buttonStyle(SettingsButtonStyle())

            Button("Clear Log") {
                Task { await DiagnosticLogger.shared.clear() }
            }
            .buttonStyle(SettingsButtonStyle(isDestructive: true))
        }
        .padding(.top, 4)

        Divider().background(Color.white.opacity(0.1))

        sectionHeader("App Info")

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        Text("Version \(version) (\(build))")
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.8))
            .padding(.bottom, 4)
    }
}

// MARK: - Reusable Settings Components

struct SettingsToggle: View {
    let label: String
    let getter: () -> Bool
    let setter: (Bool) -> Void

    @State private var isOn: Bool = false

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.8))
            .tint(TerminalColors.green)
            .onAppear { isOn = getter() }
            .onChange(of: isOn) { _, newValue in
                setter(newValue)
            }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var isOn = false

    var body: some View {
        Toggle("Launch at login", isOn: $isOn)
            .toggleStyle(.switch)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.8))
            .tint(TerminalColors.green)
            .onAppear { isOn = SMAppService.mainApp.status == .enabled }
            .onChange(of: isOn) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isOn = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

struct SettingsHookList: View {
    @State private var statuses: [SessionSource: Bool] = [:]

    private let sources: [SessionSource] = [
        .claude, .codexCLI, .gemini, .cursor, .opencode, .copilot,
        .factory, .qoder, .droid, .codebuddy
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(sources, id: \.rawValue) { source in
                HStack {
                    Circle()
                        .fill(statusColor(for: source))
                        .frame(width: 6, height: 6)
                    Text(source.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(statusText(for: source))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))

                    Button(AppSettings.isHookEnabled(for: source) ? "Disable" : "Enable") {
                        if AppSettings.isHookEnabled(for: source) {
                            HookInstaller.uninstallSource(source)
                        } else {
                            HookInstaller.installSource(source)
                        }
                        refreshStatuses()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(TerminalColors.green)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear { refreshStatuses() }
    }

    private func refreshStatuses() {
        statuses = HookInstaller.allStatuses()
    }

    private func statusColor(for source: SessionSource) -> Color {
        if !AppSettings.isHookEnabled(for: source) { return .white.opacity(0.3) }
        return (statuses[source] ?? false) ? TerminalColors.green : Color(red: 1.0, green: 0.4, blue: 0.4)
    }

    private func statusText(for source: SessionSource) -> String {
        if !AppSettings.isHookEnabled(for: source) { return "Disabled" }
        return (statuses[source] ?? false) ? "Active" : "Not Installed"
    }
}

struct SoundThemePicker: View {
    @State private var selected: SoundThemePack = AppSettings.soundThemePack

    var body: some View {
        Picker("Theme", selection: $selected) {
            ForEach(SoundThemePack.allCases, id: \.self) { pack in
                Text(pack.displayName).tag(pack)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selected) { _, newValue in
            AppSettings.soundThemePack = newValue
        }
    }
}

struct SettingsButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isDestructive ? Color(red: 1, green: 0.4, blue: 0.4) : .white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
    }
}
