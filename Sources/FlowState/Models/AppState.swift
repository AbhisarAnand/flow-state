import Foundation
import SwiftUI

enum AppStatus: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var state: AppStatus = .idle
    @Published var isNotificationVisible = false
    @Published var notificationText = ""
    @Published var isAccessibilityGranted = false
    @Published var amplitude: Float = 0.0
    
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base.en"
        self.userTypingSpeed = UserDefaults.standard.integer(forKey: "userTypingSpeed")
        if self.userTypingSpeed == 0 { self.userTypingSpeed = 40 } // Default
    }

    @Published var userTypingSpeed: Int {
        didSet { UserDefaults.standard.set(userTypingSpeed, forKey: "userTypingSpeed") }
    }    

    @Published var isModelLoading: Bool = false
    @Published var loadingProgress: String = "" // "Downloading 50%..."
    @Published var lastLog: String = "No logs yet."
    
    func showNotificationBriefly(text: String = "Copied") {
        DispatchQueue.main.async {
            self.notificationText = text
            self.isNotificationVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.isNotificationVisible = false }
        }
    }
}
