import Foundation
import NaturalLanguage

// MARK: - Text Formatter
class TextFormatter {
    static let shared = TextFormatter()
    
    private init() {}
    
    // MARK: - Main Format Function
    
    func format(_ text: String, for category: ProfileCategory) async -> String {
        switch category {
        case .casual:
            return formatCasual(text)
        case .formal:
            return await formatFormalAsync(text)
        case .code:
            return formatCode(text)
        case .default:
            return formatDefault(text)
        }
    }
    
    // MARK: - Casual (Messaging)
    
    func formatCasual(_ text: String) -> String {
        // Lowercase, no trailing punctuation
        var result = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing period (keep ? and !)
        if result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        
        return result
    }
    
    // MARK: - Formal (Email) - Async with LLM
    
    func formatFormalAsync(_ text: String) async -> String {
        do {
            return try await GroqService.shared.formatAsEmail(text)
        } catch {
            print("[TextFormatter] Groq failed: \(error), using fallback")
            return formatFormal(text)
        }
    }
    
    // MARK: - Formal Fallback (Rule-based)
    
    func formatFormal(_ text: String) -> String {
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
        let fillerWords = ["um", "uh", "like", "you know", "basically", "actually", "literally"]
        var cleaned = result
        for filler in fillerWords {
            cleaned = cleaned.replacingOccurrences(of: " \(filler) ", with: " ", options: .caseInsensitive)
            cleaned = cleaned.replacingOccurrences(of: " \(filler), ", with: " ", options: .caseInsensitive)
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Code (Preserve Technical Terms)
    
    func formatCode(_ text: String) -> String {
        // Minimal processing - preserve as spoken
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Default (Basic Capitalization)
    
    func formatDefault(_ text: String) -> String {
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
        
        return result.trimmingCharacters(in: .whitespaces)
    }
}
