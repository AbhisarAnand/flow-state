import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    @ObservedObject var appState = AppState.shared
    
    // Managers
    let hotkeyManager = HotkeyManager()
    let transcriptionManager = TranscriptionManager()
    let audioManager = AudioManager.shared
    let outputManager = OutputManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        audioManager.startRecording()
        
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
                    let text = await self?.transcriptionManager.transcribe(audioSamples: samples) ?? ""
                    await MainActor.run {
                        if !text.isEmpty {
                            self?.outputManager.pasteText(text)
                            HistoryManager.shared.add(text, duration: duration)
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
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func setupHotkeys() {}
}
