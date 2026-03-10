import SwiftUI
import Combine

/// SwiftUI popover shown when the user clicks the menu bar icon.
struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var isRecordingHotkey = false
    @State private var hotkeyMonitor: Any?

    // Re-check accessibility every second while the popover is open
    private let accessibilityTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("FocusBlur")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $prefs.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // Accessibility status banner
            if !accessibilityGranted {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility Required")
                            .font(.subheadline.bold())
                    }
                    Text("FocusBlur needs Accessibility access to detect the active window.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accessibility Enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Blur intensity
            VStack(alignment: .leading, spacing: 4) {
                Text("Blur: \(Int(prefs.blurRadius))")
                    .font(.subheadline)
                Slider(value: $prefs.blurRadius, in: 0...30, step: 1)
            }

            // Dim intensity
            VStack(alignment: .leading, spacing: 4) {
                Text("Dim: \(Int(prefs.dimOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: $prefs.dimOpacity, in: 0...1, step: 0.01)
            }

            Divider()

            // Global hotkey
            HStack {
                Toggle("Keyboard shortcut", isOn: $prefs.hotkeyEnabled)
                    .font(.subheadline)
                Spacer()
                Button(action: { startRecording() }) {
                    Text(isRecordingHotkey ? "Press shortcut…" : prefs.hotkeyLabel)
                        .font(.subheadline.monospaced())
                        .foregroundColor(isRecordingHotkey ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isRecordingHotkey ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isRecordingHotkey ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Launch at login
            Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                .font(.subheadline)
                .onChange(of: prefs.launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }

            Divider()

            // Quit
            Button("Quit FocusBlur") {
                NSApplication.shared.terminate(nil)
            }
            .font(.subheadline)
        }
        .padding(16)
        .frame(width: 280)
        .onReceive(accessibilityTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Hotkey recording

    private func startRecording() {
        guard !isRecordingHotkey else { return }
        isRecordingHotkey = true

        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            // Require at least one modifier (⌘, ⌥, ⌃, or ⇧)
            let hasModifier = !mods.intersection([.command, .option, .control, .shift]).isEmpty
            guard hasModifier else { return nil }

            // Save the new hotkey
            let character = event.charactersIgnoringModifiers ?? ""
            prefs.hotkeyKeyCode = Int(event.keyCode)
            prefs.hotkeyModifiers = Int(mods.rawValue)
            prefs.hotkeyCharacter = character

            stopRecording()
            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecordingHotkey = false
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
    }
}
