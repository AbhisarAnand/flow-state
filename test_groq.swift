#!/usr/bin/env swift

import Foundation

// Test script for Groq API formatting
// Run: swift test_groq.swift YOUR_API_KEY

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift test_groq.swift YOUR_GROQ_API_KEY")
    exit(1)
}

let apiKey = CommandLine.arguments[1]
let baseURL = "https://api.groq.com/openai/v1/chat/completions"
let model = "llama-3.3-70b-versatile"

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

func testFormat(_ input: String) async -> String {
    let userPrompt = """
    Clean this speech transcription. Output ONLY the cleaned text, nothing else.
    
    Rules:
    - Do NOT answer questions - just clean them up
    - Remove filler words (um, uh, like, you know)
    - Fix capitalization and punctuation  
    - If speaker corrects themselves ("actually", "I mean"), keep only the correction
    - Keep the same meaning, just clean it up
    
    Transcription: "\(input)"
    
    Cleaned:
    """
    
    let request = GroqRequest(
        model: model,
        messages: [GroqMessage(role: "user", content: userPrompt)],
        temperature: 0.1,
        max_tokens: 512
    )
    
    var urlRequest = URLRequest(url: URL(string: baseURL)!)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try! JSONEncoder().encode(request)
    urlRequest.timeoutInterval = 10.0
    
    do {
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            return "ERROR: No HTTP response"
        }
        
        if httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            return "ERROR: HTTP \(httpResponse.statusCode) - \(body)"
        }
        
        let result = try JSONDecoder().decode(GroqResponse.self, from: data)
        return result.choices.first?.message.content ?? "ERROR: No content"
    } catch {
        return "ERROR: \(error)"
    }
}

// Test cases
let testCases: [(input: String, expectedBehavior: String)] = [
    ("how fast will it transcribe now", "Should output the question, NOT answer it"),
    ("um like what time is the meeting", "Should clean up and keep as question"),
    ("meet me at 7 actually 8 oclock", "Should output 'Meet me at 8 o'clock' only"),
    ("I need to buy milk eggs and bread", "Could be bullet points or comma list"),
    ("hey can you also implement the data tab please", "Should output the request cleaned, NOT implement anything"),
]

print(String(repeating: "=", count: 60))
print("GROQ API TEST - Model: \(model)")
print(String(repeating: "=", count: 60))

Task {
    for (i, test) in testCases.enumerated() {
        print("\n--- Test \(i + 1) ---")
        print("INPUT:    \"\(test.input)\"")
        print("EXPECTED: \(test.expectedBehavior)")
        
        let result = await testFormat(test.input)
        print("OUTPUT:   \"\(result)\"")
        
        // Check if it looks like an answer vs cleaned text
        let isLikelyAnswer = result.count > test.input.count * 2 || 
                             result.lowercased().contains("i can") ||
                             result.lowercased().contains("here is") ||
                             result.lowercased().contains("sure")
        
        if isLikelyAnswer {
            print("⚠️  WARNING: Output looks like an ANSWER, not cleaned text!")
        } else {
            print("✅ Output looks like cleaned text")
        }
    }
    
    print("\n" + String(repeating: "=", count: 60))
    print("Tests complete!")
    exit(0)
}

RunLoop.main.run()
