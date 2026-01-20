import SwiftUI

// WindowManager bridges AppDelegate menu actions with SwiftUI's openWindow
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    // This will be set by the SwiftUI App when it initializes
    var openDashboardAction: (() -> Void)?
    
    private init() {}
    
    func openDashboard() {
        if let action = openDashboardAction {
            action()
        } else {
            // Fallback: activate app and try to find any normal window
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.level == .normal {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}
