import Foundation
import Sparkle
import SwiftUI

class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()
    
    // Sparkle Controller
    private var updaterController: SPUStandardUpdaterController!
    
    override init() {
        super.init()
        // Initialize Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        print("[UpdateManager] 🔄 Checking for updates...")
        print("[UpdateManager] Current Feed URL: \(String(describing: updaterController.updater.feedURL))")
        updaterController.checkForUpdates(nil)
    }
    
    // MARK: - SPUUpdaterDelegate
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let msg = "[Update Error] ❌ \(error.localizedDescription)"
        print(msg)
        DispatchQueue.main.async { AppState.shared.lastLog = msg }
    }
    
    func updater(_ updater: SPUUpdater, didFinishUpdate_ error: Error?) {
        if let error = error {
            let msg = "[Update Failed] ❌ \(error.localizedDescription)"
            print(msg)
            DispatchQueue.main.async { AppState.shared.lastLog = msg }
        } else {
             print("[UpdateManager] ✅ Update Check Finished (Idle)")
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let msg = "[UpdateFound] 🎉 Found v\(item.displayVersionString)"
        print(msg)
        DispatchQueue.main.async { AppState.shared.lastLog = msg }
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        let msg = "[No Updates] ✅ You are on the latest version."
        print(msg)
        DispatchQueue.main.async { AppState.shared.lastLog = msg }
    }
}
