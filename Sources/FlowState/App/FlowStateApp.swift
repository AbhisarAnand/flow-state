import SwiftUI

@main
struct FlowStateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DashboardView()
                .frame(minWidth: 1100, minHeight: 800)
                .onAppear {
                    // Register the openWindow action with WindowManager
                    WindowManager.shared.openDashboardAction = {
                        openWindow(id: "dashboard")
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
