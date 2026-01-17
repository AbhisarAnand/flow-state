import Foundation

// MARK: - Profile Category
enum ProfileCategory: String, Codable, CaseIterable, Identifiable {
    case casual = "Casual"
    case formal = "Formal"
    case code = "Code"
    case `default` = "Default"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .casual: return "message.fill"
        case .formal: return "envelope.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .default: return "doc.text.fill"
        }
    }
    
    var color: String {
        switch self {
        case .casual: return "green"
        case .formal: return "blue"
        case .code: return "purple"
        case .default: return "gray"
        }
    }
    
    var description: String {
        switch self {
        case .casual: return "No caps, no punctuation"
        case .formal: return "Professional formatting (LLM)"
        case .code: return "Preserve technical terms"
        case .default: return "Basic capitalization"
        }
    }
}

// MARK: - App Profile
struct AppProfile: Codable, Identifiable, Hashable {
    let id: String  // bundleIdentifier
    let name: String
    var category: ProfileCategory
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppProfile, rhs: AppProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Default App Mappings
extension AppProfile {
    static let defaultMappings: [AppProfile] = [
        // Casual - Messaging
        AppProfile(id: "com.apple.MobileSMS", name: "Messages", category: .casual),
        AppProfile(id: "net.whatsapp.WhatsApp", name: "WhatsApp", category: .casual),
        AppProfile(id: "org.telegram.desktop", name: "Telegram", category: .casual),
        AppProfile(id: "com.hnc.Discord", name: "Discord", category: .casual),
        AppProfile(id: "com.tinyspeck.slackmacgap", name: "Slack", category: .casual),
        AppProfile(id: "com.facebook.Messenger", name: "Messenger", category: .casual),
        
        // Formal - Email & Docs
        AppProfile(id: "com.apple.mail", name: "Mail", category: .formal),
        AppProfile(id: "com.microsoft.Outlook", name: "Outlook", category: .formal),
        AppProfile(id: "com.apple.Notes", name: "Notes", category: .formal),
        AppProfile(id: "com.microsoft.Word", name: "Word", category: .formal),
        AppProfile(id: "com.google.Chrome", name: "Chrome", category: .default), // Could be Gmail
        
        // Code - Development & AI
        AppProfile(id: "com.openai.chat", name: "ChatGPT", category: .code),
        AppProfile(id: "com.anthropic.claudefordesktop", name: "Claude", category: .code),
        AppProfile(id: "com.todesktop.230313mzl4w4u92", name: "Cursor", category: .code),
        AppProfile(id: "com.microsoft.VSCode", name: "VS Code", category: .code),
        AppProfile(id: "com.apple.dt.Xcode", name: "Xcode", category: .code),
        AppProfile(id: "com.apple.Terminal", name: "Terminal", category: .code),
    ]
}
