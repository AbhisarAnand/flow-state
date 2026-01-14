import Cocoa
import Carbon.HIToolbox

class HotkeyManager {
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
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Shift+Cmd+Space: keyCode 49 (Space) with Shift+Cmd modifiers
        let hasShift = flags.contains(.maskShift)
        let hasCmd = flags.contains(.maskCommand)
        let isSpaceBar = (keyCode == 49)
        
        if type == .keyDown && isSpaceBar && hasShift && hasCmd {
            if !isHotkeyDown {
                isHotkeyDown = true
                print("[HotkeyManager] 🔴 PTT Pressed")
                DispatchQueue.main.async { self.onHotkeyPressed?() }
            }
            return nil // Consume the event
        }
        
        if type == .keyUp && isSpaceBar && isHotkeyDown {
            isHotkeyDown = false
            print("[HotkeyManager] ⚪️ PTT Released")
            DispatchQueue.main.async { self.onHotkeyReleased?() }
            return nil
        }
        
        return Unmanaged.passRetained(event)
    }
}
