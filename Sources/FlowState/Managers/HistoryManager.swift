import Foundation

struct HistoryItem: Identifiable, Codable {
    var id = UUID()
    let text: String
    let date: Date
    let duration: TimeInterval // Actual time spoken in seconds
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var history: [HistoryItem] = []
    
    // Stats
    var totalWords: Int {
        history.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
    
    var timeSavedString: String {
        // Real Calculation:
        // Saved = (Words / UserTypingSpeed) - ActualSpokenDuration
        
        let typingSpeed = Double(AppState.shared.userTypingSpeed) // e.g., 40 WPM
        let timeToTypeSeconds = Double(totalWords) / (typingSpeed / 60.0) // Words / WPS
        
        let actualDurationSeconds = history.reduce(0) { $0 + $1.duration }
        
        // If legacy items have 0 duration, we might underestimate spoken time (creating artificially high saved time),
        // but that's acceptable for a V1 migration. Alternatively we could estimate old items at 150wpm.
        // Let's implement a safe fallback: if duration is 0, assume 150wpm for that item.
        
        let adjustedDuration = history.reduce(0.0) { result, item in
            if item.duration > 0 {
                return result + item.duration
            } else {
                // Fallback for legacy items: assume 150 wpm
                let words = Double(item.text.split(separator: " ").count)
                return result + (words / (150.0 / 60.0))
            }
        }
        
        let savedSeconds = timeToTypeSeconds - adjustedDuration
        let savedMinutes = savedSeconds / 60.0
        
        if savedMinutes < 0.1 { return "0 mins" }
        return String(format: "%.1f mins", savedMinutes)
    }
    
    // ... historyFileURL properties
    private var historyFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = appSupport.appendingPathComponent("FlowState")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }

    private init() {
        loadHistory()
    }

    func add(_ text: String, duration: TimeInterval) {
        let item = HistoryItem(text: text, date: Date(), duration: duration)
        DispatchQueue.main.async {
            self.history.insert(item, at: 0)
            if self.history.count > 100 { self.history.removeLast() }
            self.saveHistory()
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.history.removeAll()
            self.saveHistory()
        }
    }
    
    private func saveHistory() {
        guard let url = historyFileURL else { return }
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: url)
        } catch {
            print("[HistoryManager] Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let url = historyFileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([HistoryItem].self, from: data)
            self.history = items
        } catch {
             print("[HistoryManager] Failed to load history: \(error)")
        }
    }
}
