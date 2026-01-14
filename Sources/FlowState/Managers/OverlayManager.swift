import Cocoa
import SwiftUI

class OverlayManager: ObservableObject {
    static let shared = OverlayManager()
    
    private var overlayWindow: NSPanel?
    
    func setup() {
        if overlayWindow == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 40),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.isFloatingPanel = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            
            let contentView = NSHostingView(rootView: WaveformOverlayView())
            window.contentView = contentView
            
            self.overlayWindow = window
            
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let windowRect = window.frame
                let x = screenRect.midX - (windowRect.width / 2)
                let y = screenRect.minY // Absolute Bottom
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    func show() {
        setup()
        overlayWindow?.orderFront(nil)
    }
    
    func hide() {
        overlayWindow?.orderOut(nil)
    }
}
