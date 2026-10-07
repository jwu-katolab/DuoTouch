import SwiftUI

@main
struct DuoTouchDesignerApp: App {
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            SetupView()
                .environmentObject(app)
        }
        .windowStyle(.titleBar)
    }
}
