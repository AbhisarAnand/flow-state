import SwiftUI

// MARK: - Color Palette & Materials
extension Color {
    static let flowBackground = Color("FlowBackground") // Use Asset or Fallback
    
    // Adaptive Gradients
    static let gaugeGradient = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers
struct GlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                // Layered background for premium glass effect
                ZStack {
                    if colorScheme == .light {
                        Color.white.opacity(0.01) // Ultra subtle (Glassier)
                    } else {
                        Color.black.opacity(0.01) // Ultra clear
                    }
                    Rectangle().fill(.ultraThinMaterial.opacity(0.3)) // Reduced material opacity
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 15, x: 0, y: 8)
            .overlay {
                // Premium Glass Edge: Gradient Stroke + Inner Glow
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.9), location: 0),   // Much brighter Highlight
                                    .init(color: .white.opacity(0.2), location: 0.3), // Quicker fade
                                    .init(color: .white.opacity(0.05), location: 0.6),
                                    .init(color: .white.opacity(0.5), location: 1.0)  // Stronger Refraction
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.0 // Thicker border
                        )
                    
                    // Inner Shadow for Thickness (Subtle depth)
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .blur(radius: 3)
                            .mask(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                            )
                    }
                }
            }
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
}

// MARK: - Components

struct FlowVelocityGauge: View {
    let wpm: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background Ring (Centered)
            Circle()
                .trim(from: 0.15, to: 0.85) // 270 degree arc
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 200, height: 200)
            
            // Glow Layer (Behind progress)
            Circle()
                .trim(from: 0.15, to: 0.15 + (Double(min(wpm, 150)) / 150.0) * 0.7)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue],
                        center: .center,
                        startAngle: .degrees(90),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .blur(radius: 8) // Reduced from 12
                .opacity(0.35) // Reduced from 0.6
                .frame(width: 200, height: 200)
            
            // Progress Ring
            Circle()
                .trim(from: 0.15, to: 0.15 + (Double(min(wpm, 150)) / 150.0) * 0.7)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .blue],
                        center: .center,
                        startAngle: .degrees(90),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: wpm)
                .frame(width: 200, height: 200)
            
            VStack(spacing: 2) {
                Text("\(wpm)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(wpm)))
                    .foregroundStyle(.primary)
                
                Text("WPM")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text("Flow Velocity")
                    .font(.title3) // Much bigger
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary) // More visible
                    .padding(.top, 6)
            }
            .offset(y: 10)
        }
        .frame(width: 220, height: 220)
        .padding()
        .glassCard()
    }
}

struct V2StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct StatusBanner: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 16) {
           // Dynamic Visualizer Icon
           ZStack {
                // logic for color:
               // 1. Accessibility Missing -> RED
               // 2. Model Not Ready -> YELLOW/ORANGE
               // 3. Ready -> GREEN
               
               let isReady = appState.isAccessibilityGranted && appState.isModelReady
               let statusColor = !appState.isAccessibilityGranted ? Color.red.gradient : (appState.isModelReady ? Color.green.gradient : Color.orange.gradient)
               
               Circle()
                 .fill(statusColor)
                 .frame(width: 44, height: 44)
                 .shadow(radius: 4)
                 
               if isReady {
                  // FFT Visualizer Overlay (Reduced to 4 bars from 8)
                  HStack(spacing: 2) {
                      ForEach(0..<4) { i in
                          // Combine pairs: 0+1, 2+3, 4+5, 6+7
                          let mag1 = appState.fftMagnitudes[i*2]
                          let mag2 = appState.fftMagnitudes[i*2+1]
                          let combined = max(mag1, mag2)
                          
                          RoundedRectangle(cornerRadius: 1)
                              .fill(.white.opacity(0.8))
                              .frame(width: 3, height: 10 + (CGFloat(combined) * 20))
                      }
                  }
               } else if !appState.isAccessibilityGranted {
                   Image(systemName: "mic.slash.fill")
                       .font(.title2)
                       .foregroundStyle(.white)
               } else {
                   // Loading State
                   WhiteSpinner() // Re-use spinner
               }
           }
            
            VStack(alignment: .leading) {
                Text(titleText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
    
    var titleText: String {
        if !appState.isAccessibilityGranted { return "Permission Required" }
        if !appState.isModelReady { return "Initializing AI..." }
        return "Ready to Capture"
    }
    
    var subText: String {
        if !appState.isAccessibilityGranted { return "Grant Access in System Settings" }
        if !appState.isModelReady { return "Please wait for model..." }
        return "Hold Fn Key to Speak"
    }
}
