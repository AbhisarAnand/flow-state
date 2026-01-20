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
                    let totalStart = CFAbsoluteTimeGetCurrent()
                    
                    // Measure transcription time
                    let transcribeStart = CFAbsoluteTimeGetCurrent()
                    let rawText = await self?.transcriptionManager.transcribe(audioSamples: samples) ?? ""
                    let transcribeTime = CFAbsoluteTimeGetCurrent() - transcribeStart
                    
                    // Skip LLM call if there's no text (accidental triggers)
                    guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("[AppDelegate] Empty transcription, skipping LLM call")
                        await MainActor.run {
                            self?.appState.state = .idle
                            OverlayManager.shared.hide()
                        }
                        return
                    }
                    
                    // Get app context for smart formatting
                    let frontApp = NSWorkspace.shared.frontmostApplication
                    let appName = frontApp?.localizedName
                    let category = ProfileManager.shared.category(for: frontApp?.bundleIdentifier)
                    
                    // Apply universal smart formatting with app context (LLM time tracked inside GroqService)
                    let formattedText = await TextFormatter.shared.format(rawText, appName: appName, category: category)
                    
                    let totalEnd = CFAbsoluteTimeGetCurrent()
                    let totalTime = totalEnd - totalStart
                    
                    // Record metrics
                    let metric = TranscriptionMetric(
                        whisperModel: AppState.shared.selectedModel,
                        llmModel: GroqService.modelName,
                        recordingDuration: duration,
                        transcriptionTime: transcribeTime,
                        llmFormattingTime: GroqService.lastLLMTime,
                        totalProcessingTime: totalTime,
                        rawText: rawText,
                        formattedText: formattedText
                    )
                    MetricsManager.shared.add(metric)
                    
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
        WindowManager.shared.openDashboard()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        
        if !flag {
            // No visible windows - need to create one
            // Find any existing SwiftUI window (may be hidden/closed)
            for window in NSApp.windows {
                if window.level == .normal && 
                   !window.className.contains("StatusBar") &&
                   window.contentView != nil {
                    window.makeKeyAndOrderFront(nil)
                    return true
                }
            }
            
            // No window found at all - SwiftUI will create one on activation
            // Force creation by making a new window request
            DispatchQueue.main.async {
                // Create new window via SwiftUI scene
                for window in NSApp.windows {
                    if window.level == .normal {
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }
            }
        } else {
            // Has visible windows - bring to front
            NSApp.windows.first { $0.level == .normal }?.makeKeyAndOrderFront(nil)
        }
        
        return true
    }
    
    func setupHotkeys() {}
}
