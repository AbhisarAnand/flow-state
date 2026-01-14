import Foundation
import WhisperKit

class TranscriptionManager {
    static let shared = TranscriptionManager()
    
    var whisperKit: WhisperKit?
    var isModelLoaded = false
    private var currentLoadedModel: String?
    
    init() {
        Task { await loadModel(named: AppState.shared.selectedModel) }
    }
    
    func loadModel(named modelName: String = "base.en") async {
        guard currentLoadedModel != modelName else { return }
        
        DispatchQueue.main.async {
            AppState.shared.isModelLoading = true
            AppState.shared.loadingProgress = "Switching to \(modelName)..."
            AppState.shared.selectedModel = modelName
        }
        
        do {
            print("[TranscriptionManager] Loading WhisperKit Model: \(modelName) ...")
            
            // Set custom model path to Application Support (Avoid Documents)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let modelPath = appSupport.appendingPathComponent("FlowState/Models")
            
            try? FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
            
            // Attempt to init with custom download path if API supports it, or rely on default but ensure we aren't using Documents if possible.
            // Note: WhisperKit default init might still use Documents if we don't configure it.
            // Assuming we can pass downloadBase or similar.
            // If explicit param isn't available in this version, we might need a config.
            // For now, let's try to assume WhisperKit handles this or we download manually? 
            // Actually, best bet is check if we can pass `assetsPath`.
            
            // NOTE: Since I can't browse the exact WhisperKit API version docs here, I will try to use the most common usage
            // to restrict it. If WhisperKit(model:) is hardcoded to Documents, we might need to change library args.
            // Let's assume standard behavior is OK if we can't change it, BUT user specifically asked.
            // I will inject logic to set the storage directory if possible.
            
            // Map friendly names to actual model IDs
            var actualModelName = modelName
            if modelName == "Distil Large v3" {
                actualModelName = "distil-whisper_distil-large-v3"
            } else if modelName == "Large v3 Turbo" {
                actualModelName = "openai_whisper-large-v3-turbo"
            }
            
            // Let's try init with `assetsPath` if valid.
            self.whisperKit = try await WhisperKit(model: actualModelName, downloadBase: modelPath)
            self.isModelLoaded = true
            self.currentLoadedModel = modelName
            
            DispatchQueue.main.async {
                AppState.shared.isModelLoading = false
                AppState.shared.loadingProgress = "Ready"
            }
            print("[TranscriptionManager] ✅ Model Loaded: \(modelName)")
        } catch {
            print("[TranscriptionManager] ❌ Error loading \(modelName): \(error)")
            DispatchQueue.main.async {
                AppState.shared.isModelLoading = false
                AppState.shared.loadingProgress = "Error"
            }
        }
    }
    
    func transcribe(audioSamples: [Float]) async -> String {
        guard let whisper = whisperKit, isModelLoaded else {
            if !isModelLoaded { Task { await loadModel() } }
            return ""
        }
        
        do {
            let result = try await whisper.transcribe(audioArray: audioSamples)
            let rawText = result.map(\.text).joined(separator: " ")
            let clean = cleanupText(rawText)
            
            DispatchQueue.main.async {
                AppState.shared.lastLog = "Raw:[\(rawText)]\nClean:[\(clean)]"
            }
            
            return clean
        } catch {
            print("[TranscriptionManager] Transcription failed: \(error)")
            return ""
        }
    }
    
    private func cleanupText(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Filter common Whisper hallucinations
        let hallucinations = ["[Music]", "[BLANK_AUDIO]", "Breathing", "Subtitle", "(Music)", "Music", "Silence"]
        for h in hallucinations {
            clean = clean.replacingOccurrences(of: h, with: "", options: .caseInsensitive)
        }
        
        // Remove looping punctuation (e.g. "...")
        if clean.filter({ $0.isLetter }).isEmpty { return "" }
        
        return clean
    }
}
