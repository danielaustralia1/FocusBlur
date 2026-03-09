import SwiftUI

/// SwiftUI popover shown when the user clicks the menu bar icon.
struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

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

            // Shake to toggle
            Toggle("Shake cursor to toggle", isOn: $prefs.shakeToToggle)
                .font(.subheadline)

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
        .frame(width: 260)
    }
}
