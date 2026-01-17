import Foundation

// MARK: - Transcription Metric
struct TranscriptionMetric: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // Models used
    let whisperModel: String
    let llmModel: String
    
    // Timing breakdown (in seconds)
    let recordingDuration: Double      // How long user spoke
    let transcriptionTime: Double      // Whisper processing time
    let llmFormattingTime: Double      // Groq API time
    let totalProcessingTime: Double    // End-to-end time
    
    // Computed properties
    var overheadTime: Double {
        totalProcessingTime - transcriptionTime - llmFormattingTime
    }
    
    // Input/Output
    let inputLength: Int               // Characters before formatting
    let outputLength: Int              // Characters after formatting
    let rawText: String
    let formattedText: String
    
    init(whisperModel: String, llmModel: String, recordingDuration: Double,
         transcriptionTime: Double, llmFormattingTime: Double, totalProcessingTime: Double,
         rawText: String, formattedText: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.whisperModel = whisperModel
        self.llmModel = llmModel
        self.recordingDuration = recordingDuration
        self.transcriptionTime = transcriptionTime
        self.llmFormattingTime = llmFormattingTime
        self.totalProcessingTime = totalProcessingTime
        self.rawText = rawText
        self.formattedText = formattedText
        self.inputLength = rawText.count
        self.outputLength = formattedText.count
    }
}

// MARK: - Metrics Manager
class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published var metrics: [TranscriptionMetric] = []
    
    private let storageKey = "transcriptionMetrics"
    private let maxMetrics = 100  // Keep last 100 entries
    
    private init() {
        loadMetrics()
    }
    
    func add(_ metric: TranscriptionMetric) {
        metrics.insert(metric, at: 0)
        
        // Trim to max size
        if metrics.count > maxMetrics {
            metrics = Array(metrics.prefix(maxMetrics))
        }
        
        saveMetrics()
    }
    
    func clear() {
        metrics.removeAll()
        saveMetrics()
    }
    
    // MARK: - Computed Stats
    
    var averageTranscriptionTime: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.transcriptionTime }.reduce(0, +) / Double(metrics.count)
    }
    
    var averageLLMTime: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.llmFormattingTime }.reduce(0, +) / Double(metrics.count)
    }
    
    var averageTotalTime: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.totalProcessingTime }.reduce(0, +) / Double(metrics.count)
    }
    
    // MARK: - Persistence
    
    private func saveMetrics() {
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadMetrics() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([TranscriptionMetric].self, from: data) {
            metrics = loaded
        }
    }
}
