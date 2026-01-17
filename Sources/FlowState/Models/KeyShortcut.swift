import Foundation
import CoreGraphics

// Enum for Recording Behavior
enum RecordingMode: String, Codable, CaseIterable {
    case hold = "Hold to Record" // Push-to-Talk
    case toggle = "Hands-Free"   // Toggle Start/Stop
}

// Struct to store a User Keybind
struct KeyShortcut: Codable, Equatable {
    var keyCode: Int64
    var modifiers: UInt64 // CGEventFlags rawValue
    var isModifierOnly: Bool // e.g. "Fn" trigger
    var displayString: String // e.g. "⌘ ⇧ Space"
    
    // Default: Fn Key
    static let defaultShortcut = KeyShortcut(
        keyCode: 63, // Fn
        modifiers: 8388608, // Fn mask
        isModifierOnly: true,
        displayString: "Fn"
    )
}
