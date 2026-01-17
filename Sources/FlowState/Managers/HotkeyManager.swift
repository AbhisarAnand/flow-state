import Cocoa
import Carbon.HIToolbox

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var onHandsFreeToggle: (() -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyDown = false
    
    func startListening() {
        checkPermissionsAndStart()
        
        // Start polling if not trusted
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            
            DispatchQueue.main.async {
                if AppState.shared.isAccessibilityGranted != trusted {
                    AppState.shared.isAccessibilityGranted = trusted
                    if trusted {
                         print("[HotkeyManager] 🟢 Permissions granted! Starting listener...")
                         self.startListening() // Restart listener now that we have perms
                         timer.invalidate()
                    }
                }
            }
            
            if trusted && self.eventTap == nil {
                 // Try binding again if we are trusted but missed the initial bind
                 self.createEventTap()
            }
        }
    }
    
    private func createEventTap() {
        if eventTap != nil { return } // Already active
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask), callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            print("[HotkeyManager] Still unable to create event tap.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] ✅ Event Tap Created")
    }
    
    func checkPermissionsAndStart() {
        // Initial check with prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[HotkeyManager] Accessibility Trusted: \(trusted)")
        
        DispatchQueue.main.async { AppState.shared.isAccessibilityGranted = trusted }
        
        if trusted {
            createEventTap()
        }
    }
    
    // Configuration
    @Published var pttShortcut: KeyShortcut {
        didSet {
            if let encoded = try? JSONEncoder().encode(pttShortcut) {
                UserDefaults.standard.set(encoded, forKey: "userPTTShortcut")
            }
        }
    }
    
    @Published var handsFreeShortcut: KeyShortcut {
        didSet {
            if let encoded = try? JSONEncoder().encode(handsFreeShortcut) {
                UserDefaults.standard.set(encoded, forKey: "userHandsFreeShortcut")
            }
        }
    }
    
    @Published var isLearning = false // For Settings UI Binding
    var onBindUpdate: ((KeyShortcut) -> Void)?
    var onBindComplete: (() -> Void)? // Called on Release
    
    // Internal state for "Capture on Release" logic
    private var maxModifiers: UInt64 = 0
    private var maxKeyCode: Int64 = 0
    private var isBindingActive = false 
    private var isHandsFreeLocked = false // When true, PTT release doesn't stop recording 
    
    private init() {
        // Load PTT Shortcut (Default: Fn)
        if let data = UserDefaults.standard.data(forKey: "userPTTShortcut"),
           let decoded = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
            self.pttShortcut = decoded
        } else {
            self.pttShortcut = KeyShortcut(keyCode: 63, modifiers: 8388608, isModifierOnly: true, displayString: "Fn")
        }
        
        // Load Hands-Free Shortcut (Default: Fn + Space)
        if let data = UserDefaults.standard.data(forKey: "userHandsFreeShortcut"),
           let decoded = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
            self.handsFreeShortcut = decoded
        } else {
            self.handsFreeShortcut = KeyShortcut(keyCode: 49, modifiers: 8388608, isModifierOnly: false, displayString: "Fn Space")
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // --- BINDING MODE (Capture on Release) ---
        if isLearning {
            // Logic: Track the "highest" state reached during the press sequence.
            // On full release (flags == 0), finalize the "max" state.
            
            if type == .flagsChanged || type == .keyDown {
                // Update Max Modifiers
                if flags.rawValue > maxModifiers { maxModifiers = flags.rawValue }
                
                // Update Max KeyCode (if it's a keyDown event)
                if type == .keyDown { maxKeyCode = keyCode }
                
                let isModifier = (type == .flagsChanged && maxKeyCode == 0) // Only flags so far
                
                // Preview Logic
                let currentFlags = CGEventFlags(rawValue: maxModifiers)
                let tempShortcut = KeyShortcut(
                    keyCode: isModifier ? 0 : maxKeyCode,
                    modifiers: maxModifiers,
                    isModifierOnly: isModifier,
                    displayString: generateDisplayString(keyCode: maxKeyCode, flags: currentFlags, isModifierOnly: isModifier)
                )
                DispatchQueue.main.async { self.onBindUpdate?(tempShortcut) }
            }
            
            // Check for Release
            if type == .keyUp || (type == .flagsChanged && flags.rawValue == 0) {
                // If it's a keyUp, we treat it as done.
                // If it's flagsChanged and flags are empty, we treat it as done.
                
                // Finalize Binding
                DispatchQueue.main.async { self.onBindComplete?() }
                
                // Reset internal state for next time (though we usually exit isLearning)
                maxModifiers = 0
                maxKeyCode = 0
            }
            
            return nil // Consume events while binding
        }
        
        // --- TRIGGER LOGIC ---
        
        // Check triggers
        checkShortcut(shortcut: pttShortcut, type: type, flags: flags, keyCode: keyCode, isPTT: true)
        checkShortcut(shortcut: handsFreeShortcut, type: type, flags: flags, keyCode: keyCode, isPTT: false)
        
        return Unmanaged.passRetained(event)
    }
    
    private func checkShortcut(shortcut: KeyShortcut, type: CGEventType, flags: CGEventFlags, keyCode: Int64, isPTT: Bool) {
        let modifiersMatch = (flags.rawValue & shortcut.modifiers) == shortcut.modifiers
        let modeLabel = isPTT ? "PTT" : "HF"
        
        // Debug logging
        if type == .flagsChanged || type == .keyDown || type == .keyUp {
            print("[HotkeyManager] [\(modeLabel)] type=\(type.rawValue) flags=\(flags.rawValue) keyCode=\(keyCode) modMatch=\(modifiersMatch) shortcut.mods=\(shortcut.modifiers) isModOnly=\(shortcut.isModifierOnly)")
        }
        
        // --- PTT Logic ---
        if isPTT {
            // PTT Start: Modifiers match (works for both modifier-only AND when pressing other keys with modifier held)
            if modifiersMatch && !isHotkeyDown {
                // Only start on flagsChanged (for modifier-only) or if it's the first detection
                if type == .flagsChanged || (shortcut.isModifierOnly == false && type == .keyDown && keyCode == shortcut.keyCode) {
                    isHotkeyDown = true
                    print("[HotkeyManager] 🔵 PTT Start")
                    DispatchQueue.main.async { self.onHotkeyPressed?() }
                }
            }
            
            // PTT Stop: Modifiers no longer match AND we're not in hands-free lock
            if !modifiersMatch && isHotkeyDown && !isHandsFreeLocked {
                if type == .flagsChanged {
                    isHotkeyDown = false
                    print("[HotkeyManager] ⚪️ PTT Stop (Mod Released)")
                    DispatchQueue.main.async { self.onHotkeyReleased?() }
                }
            }
            
            // Also stop on keyUp for combo PTT
            if !shortcut.isModifierOnly && type == .keyUp && keyCode == shortcut.keyCode && isHotkeyDown && !isHandsFreeLocked {
                isHotkeyDown = false
                print("[HotkeyManager] ⚪️ PTT Stop (Key Released)")
                DispatchQueue.main.async { self.onHotkeyReleased?() }
            }
        }
        
        // --- Hands-Free Logic ---
        else {
            // Hands-Free is a toggle triggered by combo (keyDown)
            if !shortcut.isModifierOnly && type == .keyDown && keyCode == shortcut.keyCode && modifiersMatch {
                // Toggle Hands-Free Lock
                if isHandsFreeLocked {
                    // Second press: Stop recording
                    isHandsFreeLocked = false
                    isHotkeyDown = false
                    print("[HotkeyManager] 🔴 HandsFree STOP (Toggle Off)")
                    DispatchQueue.main.async { self.onHotkeyReleased?() }
                } else {
                    // First press: Lock recording
                    isHandsFreeLocked = true
                    print("[HotkeyManager] 🟢 HandsFree LOCK (Toggle On)")
                    // If not already recording, start it
                    if !isHotkeyDown {
                        isHotkeyDown = true
                        DispatchQueue.main.async { self.onHotkeyPressed?() }
                    }
                }
            }
        }
    }
    
    // Fix modifier trigger logic for toggles later if needed.
    // Simplifying display string generation...
    
    func generateDisplayString(keyCode: Int64, flags: CGEventFlags, isModifierOnly: Bool) -> String {
        var str = ""
        if flags.contains(.maskControl) { str += "⌃ " }
        if flags.contains(.maskAlternate) { str += "⌥ " }
        if flags.contains(.maskShift) { str += "⇧ " }
        if flags.contains(.maskCommand) { str += "⌘ " }
        if flags.contains(.maskSecondaryFn) { str += "Fn " }
        
        if isModifierOnly {
            return str.trimmingCharacters(in: .whitespaces)
        }
        
        if keyCode == 49 { str += "Space" }
        else { str += "Key(\(keyCode))" }
        return str
    }
}
