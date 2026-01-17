import Foundation

// MARK: - Groq API Service
class GroqService {
    static let shared = GroqService()
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"  // Larger model, better instruction following
    
    private init() {}
    
    // MARK: - Smart Format
    
    func smartFormat(_ text: String, appName: String?, appCategory: ProfileCategory) async throws -> String {
        guard !ProfileManager.shared.groqAPIKey.isEmpty else {
            print("[GroqService] No API key configured, using fallback")
            return TextFormatter.shared.formatFallback(text)
        }
        
        // Simple prompt - treat as text transformation, not conversation
        let userPrompt = """
        Clean this speech transcription. Output ONLY the cleaned text, nothing else.
        
        Rules:
        - Do NOT answer questions - just clean them up
        - Remove filler words (um, uh, like, you know)
        - Fix capitalization and punctuation  
        - If speaker corrects themselves ("actually", "I mean"), keep only the correction
        - Keep the same meaning, just clean it up
        
        Transcription: "\(text)"
        
        Cleaned:
        """
        
        let request = GroqRequest(
            model: model,
            messages: [
                GroqMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.1,
            max_tokens: 512
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(ProfileManager.shared.groqAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 5.0
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
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
