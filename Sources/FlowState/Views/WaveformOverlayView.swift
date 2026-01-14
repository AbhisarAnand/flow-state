import SwiftUI

struct WaveformOverlayView: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 2) {
             if appState.state == .recording {
                // Dynamic Waveform
                ForEach(0..<8) { i in
                    AudioBar(index: i, amplitude: CGFloat(appState.amplitude))
                }
            } else if appState.state == .processing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(.white)
                }
            } else {
                 Circle().fill(Color.white).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Tight width ~70-90pt
        .frame(minWidth: 70, maxWidth: 90, minHeight: 32, maxHeight: 32)
        .background(
            Capsule()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        )
    }
}

struct AudioBar: View {
    let index: Int
    let amplitude: CGFloat
    
    var body: some View {
        // Raw, Tighter, Snappy
        let randomFactor = CGFloat((index * 7 + 3) % 11) / 10.0
        let dynamicHeight = amplitude * 24.0 * (0.5 + randomFactor)
        let height = 4.0 + max(dynamicHeight, 0)
        
        return Capsule() // Perfectly rounded
            .fill(Color.white)
            .frame(width: 3, height: min(height, 28))
            .animation(.linear(duration: 0.05), value: amplitude)
    }
}
