import Foundation
import NaturalLanguage

// MARK: - Text Formatter
class TextFormatter {
    static let shared = TextFormatter()
    
    private init() {}
    
    // MARK: - Main Format Function (Universal Smart Formatting)
    
    func format(_ text: String, appName: String?, category: ProfileCategory) async -> String {
        do {
            return try await GroqService.shared.smartFormat(text, appName: appName, appCategory: category)
        } catch {
            print("[TextFormatter] Groq failed: \(error), using fallback")
            return formatFallback(text)
        }
    }
    
    // MARK: - Fallback (Rule-based when API unavailable)
    
    func formatFallback(_ text: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var result = ""
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            var sentence = String(text[range]).trimmingCharacters(in: .whitespaces)
            
            // Capitalize first letter
            if let first = sentence.first {
                sentence = first.uppercased() + sentence.dropFirst()
            }
            
            // Ensure punctuation
            if !sentence.isEmpty && !sentence.hasSuffix(".") && !sentence.hasSuffix("?") && !sentence.hasSuffix("!") {
                sentence += "."
            }
            
            result += sentence + " "
            return true
        }
        
        // Remove filler words
        let fillerWords = ["um", "uh", "like", "you know", "basically", "actually", "literally", "so yeah"]
        var cleaned = result
        for filler in fillerWords {
            cleaned = cleaned.replacingOccurrences(of: " \(filler) ", with: " ", options: .caseInsensitive)
            cleaned = cleaned.replacingOccurrences(of: " \(filler), ", with: " ", options: .caseInsensitive)
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

