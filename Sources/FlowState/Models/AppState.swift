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
    @Published var fftMagnitudes: [Float] = Array(repeating: 0.1, count: 8) // 8 Frequency Bands for UI
    @Published var partialTranscription: String = "" // For live streaming updates
    
    // VAD / Streaming Configuration
    @Published var minChunkSeconds: Double = 2.0
    @Published var maxChunkSeconds: Double = 10.0
    @Published var silenceThreshold: Float = 0.02
    @Published var minSilenceDuration: Double = 0.4
    
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base.en"
        self.llmEnabled = UserDefaults.standard.object(forKey: "llmEnabled") as? Bool ?? true // Default: enabled
        let savedTypingSpeed = UserDefaults.standard.integer(forKey: "userTypingSpeed")
        self.userTypingSpeed = savedTypingSpeed == 0 ? 40 : savedTypingSpeed
        
        let savedBeamSize = UserDefaults.standard.integer(forKey: "beamSize")
        self.beamSize = savedBeamSize == 0 ? 3 : savedBeamSize
    }

    @Published var userTypingSpeed: Int {
        didSet { UserDefaults.standard.set(userTypingSpeed, forKey: "userTypingSpeed") }
    }    

    @Published var beamSize: Int {
        didSet { UserDefaults.standard.set(beamSize, forKey: "beamSize") }
    }

    @Published var isModelLoading: Bool = false
    @Published var isModelReady: Bool = false // New: Tracks confirmed loaded state
    @Published var loadingProgress: String = "" // "Downloading 50%..."
    @Published var lastLog: String = "No logs yet."
    
    @Published var llmEnabled: Bool {
        didSet { UserDefaults.standard.set(llmEnabled, forKey: "llmEnabled") }
    }
    
    func showNotificationBriefly(text: String = "Copied") {
        DispatchQueue.main.async {
            self.notificationText = text
            self.isNotificationVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.isNotificationVisible = false }
        }
    }
}
