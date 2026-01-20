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
    
    // Streaming accumulation
    private var accumulatedText: String = ""
    private var activeTasks: [Task<Void, Never>] = []
    private let tasksQueue = DispatchQueue(label: "com.flowstate.tasksQueue") // Serial queue for synchronization
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        
        // --- SMART STREAMING SETUP ---
        audioManager.onChunkCaptured = { [weak self] chunk in
            guard let self = self else { return }
            print("[AppDelegate] ⚡️ Processing stream chunk: \(chunk.count) samples")
            
            let task = Task {
                // Transcribe chunk (Fast/Greedy)
                let chunkText = await self.transcriptionManager.transcribe(audioSamples: chunk)
                let trimmed = chunkText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !trimmed.isEmpty {
                    await MainActor.run {
                        // Append with space if needed
                        if !self.accumulatedText.isEmpty && !self.accumulatedText.hasSuffix(" ") {
                            self.accumulatedText += " "
                        }
                        self.accumulatedText += trimmed
                        self.appState.partialTranscription = self.accumulatedText
                        print("[AppDelegate] 📝 Partial: \(self.accumulatedText)")
                    }
                }
            }
            
            // Sync add to active tasks
            self.tasksQueue.sync {
                self.activeTasks.append(task)
            }
            
            // Cleanup when done
            Task {
                _ = await task.result
                self.tasksQueue.async {
                    // Safe removal by instance identity
                    self.activeTasks.removeAll { $0 == task }
                }
            }
        }
        // -----------------------------
        
        hotkeyManager.onHotkeyPressed = { [weak self] in
            print("PTT Pressed")
            DispatchQueue.main.async {
                self?.appState.state = .recording
                self?.accumulatedText = "" // Reset buffer
                
                self?.tasksQueue.sync {
                    // Cancel old tasks to prevent leaks
                    self?.activeTasks.forEach { $0.cancel() }
                    self?.activeTasks.removeAll()
                }
                
                self?.appState.partialTranscription = ""
                OverlayManager.shared.show()
                self?.audioManager.startRecording()
            }
        }
        
        hotkeyManager.onHotkeyReleased = { [weak self] in
            print("PTT Released")
            DispatchQueue.main.async {
                self?.appState.state = .processing
                // Capture remaining tail
                let result = self?.audioManager.stopRecording()
                let duration = Double(result?.full.count ?? 0) / 16000.0
                let tailSamples = result?.tail ?? []
                
                Task {
                    // 🛑 Wait for all streaming chunks to finish
                    var pending: [Task<Void, Never>] = []
                    self?.tasksQueue.sync {
                        pending = self?.activeTasks ?? []
                    }
                    
                    if !pending.isEmpty {
                        print("[AppDelegate] ⏳ Waiting for \(pending.count) pending chunk(s)...")
                        for t in pending { _ = await t.value }
                        print("[AppDelegate] ✅ Pending chunks finished.")
                    }
                    
                    let totalStart = CFAbsoluteTimeGetCurrent()
                    let transcribeStart = CFAbsoluteTimeGetCurrent()
                    
                    // Transcribe tail
                    var finalRawText = await MainActor.run { self?.accumulatedText ?? "" }
                    if !tailSamples.isEmpty {
                        let tailText = await self?.transcriptionManager.transcribe(audioSamples: tailSamples) ?? ""
                        if !tailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if !finalRawText.isEmpty && !finalRawText.hasSuffix(" ") {
                                finalRawText += " "
                            }
                            finalRawText += tailText
                        }
                    }
                    
                    let transcribeTime = CFAbsoluteTimeGetCurrent() - transcribeStart
                    
                    // Skip LLM if empty
                    guard !finalRawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("[AppDelegate] Empty transcription")
                        await MainActor.run {
                            self?.appState.state = .idle
                            OverlayManager.shared.hide()
                        }
                        return
                    }
                    
                    // Get app context
                    let frontApp = NSWorkspace.shared.frontmostApplication
                    let appName = frontApp?.localizedName
                    let category = ProfileManager.shared.category(for: frontApp?.bundleIdentifier)
                    
                    // LLM Formatting
                    let formattedText = await TextFormatter.shared.format(finalRawText, appName: appName, category: category)
                    
                    let totalEnd = CFAbsoluteTimeGetCurrent()
                    let totalTime = totalEnd - totalStart
                    
                    // Metrics
                    let metric = TranscriptionMetric(
                        whisperModel: AppState.shared.selectedModel,
                        llmModel: GroqService.modelName,
                        recordingDuration: duration,
                        transcriptionTime: transcribeTime,
                        llmFormattingTime: GroqService.lastLLMTime,
                        totalProcessingTime: totalTime,
                        rawText: finalRawText,
                        formattedText: formattedText
                    )
                    MetricsManager.shared.add(metric)
                    
                    await MainActor.run {
                        if !formattedText.isEmpty {
                            self?.outputManager.pasteText(formattedText)
                            HistoryManager.shared.add(formattedText, duration: duration)
                        }
                        self?.appState.state = .idle
                        // self?.appState.partialTranscription = "" // Optional: clear or keep until next
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
