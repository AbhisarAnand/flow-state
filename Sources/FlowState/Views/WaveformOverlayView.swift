import SwiftUI

struct WaveformOverlayView: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 2) {
             if appState.state == .recording {
                // Dynamic Waveform
                // Dynamic Waveform (8-band Voice FFT)
                // Bands: 0=Fundamental...7=Air
                // Direct mapping: Bar 0 = Band 0
                
                let rawMags = appState.fftMagnitudes
                
                ForEach(0..<8) { i in
                    // Neighbor Smoothing for "Wavy" Look
                    // Kernel: [0.25, 0.5, 0.25]
                    let left = i > 0 ? rawMags[i-1] : rawMags[i]
                    let center = i < rawMags.count ? rawMags[i] : 0
                    let right = i < rawMags.count - 1 ? rawMags[i+1] : rawMags[i]
                    
                    let smoothed = (left * 0.25) + (center * 0.5) + (right * 0.25)
                    let displayMag = CGFloat(smoothed)
                    
                    AudioBar(index: i, amplitude: displayMag)
                }
            } else if appState.state == .processing {
                // Custom White Spinner for visibility on black
                HStack(spacing: 6) {
                    WhiteSpinner()
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
        // We use the raw magnitude from FFT (0.0 - 1.0)
        // USER REQUEST: Reduce max height to provide padding (avoid touching edges).
        let dynamicHeight = amplitude * 16.0 // Reduced multiplier
        let height = 4.0 + max(dynamicHeight, 0)
        
        return Capsule() // Perfectly rounded
            .fill(Color.white)
            // Reduced max height from 28 to 22 for visual padding inside 32pt container
            .frame(width: 3, height: min(height, 22))
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: amplitude)
    }
}
