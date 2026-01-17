import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    @ObservedObject var appState = AppState.shared
    
    // Managers
    let hotkeyManager = HotkeyManager.shared
    let transcriptionManager = TranscriptionManager.shared
    let audioManager = AudioManager.shared
    let outputManager = OutputManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        
        // Removed audioManager.startSession() -> Reverted to PTT-only engine start.
        
        hotkeyManager.onHotkeyPressed = { [weak self] in
            print("PTT Pressed")
            DispatchQueue.main.async {
                self?.appState.state = .recording
                OverlayManager.shared.show()
                self?.audioManager.startRecording()
            }
        }
        
        hotkeyManager.onHotkeyReleased = { [weak self] in
            print("PTT Released")
            DispatchQueue.main.async {
                self?.appState.state = .processing
                let samples = self?.audioManager.stopRecording() ?? []
                let duration = Double(samples.count) / 16000.0 // Duration in Seconds
                
                Task {
                    let rawText = await self?.transcriptionManager.transcribe(audioSamples: samples) ?? ""
                    
                    // Apply profile-based formatting
                    let category = ProfileManager.shared.categoryForFrontmostApp()
                    let formattedText = await TextFormatter.shared.format(rawText, for: category)
                    
                    await MainActor.run {
                        if !formattedText.isEmpty {
                            self?.outputManager.pasteText(formattedText)
                            HistoryManager.shared.add(formattedText, duration: duration)
                        }
                        self?.appState.state = .idle
                        OverlayManager.shared.hide()
                    }
                }
            }
        }
        
        hotkeyManager.onHandsFreeToggle = { [weak self] in
            print("Hands Free Toggle")
            if self?.appState.state == .recording {
                self?.hotkeyManager.onHotkeyReleased?()
            } else {
                self?.hotkeyManager.onHotkeyPressed?()
            }
        }
        
        hotkeyManager.startListening()
        OverlayManager.shared.setup()
    }
    
    func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "BetterWisper")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem.menu = menu
    }
    
    @objc func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Try to find an existing dashboard window
        // Excluding the overlay window if possible (Overlay is typically NSPanel or specific level)
        let windows = NSApp.windows.filter { window in
            return window.isVisible || window.isMiniaturized
        }
        
        if let mainWindow = windows.first(where: { $0.title != "" && $0.className != "NSStatusBarWindow" }) {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // If no window is found (it was closed), we need to rely on SwiftUI's reopen behavior
            // or trigger it via URL if configured.
            // Fallback: Trigger standard app activation which usually reopens main window
            // for "Reopen on activate" apps.
             NSApp.arrangeInFront(nil)
        }
    }
    
    func setupHotkeys() {}
}
