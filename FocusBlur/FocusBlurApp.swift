import SwiftUI

@main
struct FocusBlurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows — everything is driven from the menu bar
        Settings { EmptyView() }
    }
}
