import Foundation

// MARK: - Groq API Service
class GroqService {
    static let shared = GroqService()
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.1-8b-instant" // Fast model for formatting
    
    private init() {}
    
    // MARK: - Format Email
    
    func smartFormat(_ text: String, appName: String?, appCategory: ProfileCategory) async throws -> String {
        guard !ProfileManager.shared.groqAPIKey.isEmpty else {
            print("[GroqService] No API key configured, using fallback")
            return TextFormatter.shared.formatFallback(text)
        }
        
        let appContext = appName ?? "unknown app"
        let categoryHint: String
        switch appCategory {
        case .casual:
            categoryHint = "This is a casual messaging app - keep it informal, lowercase is fine, minimal punctuation."
        case .formal:
            categoryHint = "This is a professional/email app - use proper capitalization, punctuation, and structure."
        case .code:
            categoryHint = "This is a coding/AI tool - preserve technical terms exactly, be precise."
        case .default:
            categoryHint = "Use standard formatting with proper capitalization and punctuation."
        }
        
        let systemPrompt = """
        You are a speech-to-text post-processor. The user is dictating into "\(appContext)".
        \(categoryHint)

        Clean up the transcription following these rules:

        1. CORRECTIONS: If the speaker corrects themselves ("actually", "I mean", "wait", "no"), 
           ONLY output the corrected version.
           Example: "Let's meet at 7, actually 8" → "Let's meet at 8"

        2. LISTS: If the speaker lists multiple items, format as bullet points.
           Example: "I need milk eggs and bread" → "• Milk\\n• Eggs\\n• Bread"

        3. STRUCTURE: For long text (3+ sentences), add paragraph breaks at topic changes.

        4. CLEANUP: Remove filler words (um, uh, like, you know, basically, so yeah).

        5. TONE: Match the app context - casual for messaging, professional for email.

        Return ONLY the cleaned text. No explanations, no markdown formatting symbols.
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
        urlRequest.timeoutInterval = 5.0
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[GroqService] API error, using fallback")
            return TextFormatter.shared.formatFallback(text)
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
