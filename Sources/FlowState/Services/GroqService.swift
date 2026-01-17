import Foundation

// MARK: - Groq API Service
class GroqService {
    static let shared = GroqService()
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.1-8b-instant" // Fast model for formatting
    
    private init() {}
    
    // MARK: - Format Email
    
    func formatAsEmail(_ text: String) async throws -> String {
        guard !ProfileManager.shared.groqAPIKey.isEmpty else {
            print("[GroqService] No API key configured, using fallback")
            return TextFormatter.shared.formatFormal(text)
        }
        
        let systemPrompt = """
        You are a professional email formatting assistant.
        Convert the following spoken transcription into a well-structured email.
        - Use proper paragraphs
        - Add appropriate greeting and sign-off if missing
        - Remove filler words (um, uh, like, you know)
        - Maintain the user's intent and tone
        - Keep it concise
        - Return ONLY the formatted email, no explanations or markdown.
        """
        
        let request = GroqRequest(
            model: model,
            messages: [
                GroqMessage(role: "system", content: systemPrompt),
                GroqMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            max_tokens: 1024
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(ProfileManager.shared.groqAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 5.0 // 5 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[GroqService] API error, using fallback")
            return TextFormatter.shared.formatFormal(text)
        }
        
        let result = try JSONDecoder().decode(GroqResponse.self, from: data)
        return result.choices.first?.message.content ?? text
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
