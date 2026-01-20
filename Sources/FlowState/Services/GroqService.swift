import Foundation

// MARK: - Groq API Service
class GroqService {
    static let shared = GroqService()
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"  // Larger model, better instruction following
    
    // Metrics tracking
    static var lastLLMTime: Double = 0
    static var modelName: String { shared.model }
    
    private init() {}
    
    // MARK: - Network Warmup
    
    func warmup() {
        guard !ProfileManager.shared.groqAPIKey.isEmpty else { return }
        print("[GroqService] 🔥 Warming up network connection...")
        Task.detached {
            var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(ProfileManager.shared.groqAPIKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 2.0 // Short timeout, just waking up the radio
            
            do {
                _ = try await URLSession.shared.data(for: request)
                print("[GroqService] 🔥 Network handshake complete.")
            } catch {
                print("[GroqService] ⚠️ Network warmup (handshake) failed/timed out (Normal if offline): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Smart Format
    
    func smartFormat(_ text: String, appName: String?, appCategory: ProfileCategory) async throws -> String {
        // Reset metric
        GroqService.lastLLMTime = 0
        
        guard !ProfileManager.shared.groqAPIKey.isEmpty else {
            print("[GroqService] No API key configured, using fallback")
            return TextFormatter.shared.formatFallback(text)
        }
        
        // Context-aware instruction
        var contextNote = ""
        if let app = appName {
             contextNote = "The user is typing into '\(app)'."
             if appCategory == .coding {
                 contextNote += " If the text contains code, format it as a code block (no backticks, just straight code) or inline code where appropriate."
             }
        }
        
        let userPrompt = """
        System: You are an expert voice-to-text editor. \(contextNote)
        Task: Clean this transcription verbatim.
        
        Strict Rules:
        1. Maintain the original wording, tone, and style. Do NOT rephrase or summarize.
        2. ONLY remove filler words (um, uh, like, you know) and fix strict grammar/spelling errors.
        3. If the speaker corrects themselves (e.g. "I want to, actually I need to"), keep ONLY the final intended thought.
        4. Do NOT answer questions. If the input is a question, output it formatted correctly.
        5. Output raw text only. No preamble (e.g. "Here is the text:").
        
        Formatting:
        - If the text looks like an email/letter, apply standard email spacing.
        - If it's a list, use bullet points.
        
        Input: "\(text)"
        
        Output:
        """
        
        let request = GroqRequest(
            model: model,
            messages: [
                GroqMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.1, // Low temp for fidelity
            max_tokens: 2048  // Increased to allow long-form dictation
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(ProfileManager.shared.groqAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 5.0
        
        // Measure LLM API time
        let llmStart = CFAbsoluteTimeGetCurrent()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let llmEnd = CFAbsoluteTimeGetCurrent()
            GroqService.lastLLMTime = llmEnd - llmStart // ⏱️ Log time
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GroqService] API error, using fallback")
                return TextFormatter.shared.formatFallback(text)
            }
            
            let result = try JSONDecoder().decode(GroqResponse.self, from: data)
            let output = result.choices.first?.message.content ?? text
            
            // Clean up any quotes or extra formatting the model might add
            var cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
                cleaned = String(cleaned.dropFirst().dropLast())
            }
            return cleaned
            
        } catch {
            print("[GroqService] Network/Encoding error: \(error)")
            // If it failed, record the time spent trying
            GroqService.lastLLMTime = CFAbsoluteTimeGetCurrent() - llmStart
            return TextFormatter.shared.formatFallback(text)
        }
    }
}

// MARK: - Groq API Models

struct GroqRequest: Codable {
    let model: String
    let messages: [GroqMessage]
    let temperature: Double
    let max_tokens: Int
}

struct GroqMessage: Codable {
    let role: String
    let content: String
}

struct GroqResponse: Codable {
    let choices: [GroqChoice]
}

struct GroqChoice: Codable {
    let message: GroqMessage
}
