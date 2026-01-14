import SwiftUI

struct DashboardView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selection: SidebarItem? = .home
    
    enum SidebarItem {
        case home, settings, help
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "house")
                    .tag(SidebarItem.home)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
                Label("Help", systemImage: "questionmark.circle")
                    .tag(SidebarItem.help)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200)
            .toolbar {
                 // Nothing in sidebar toolbar
            }
        } detail: {
            switch selection {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            case .help:
                HelpView()
            case .none:
                HomeView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Subviews

struct HomeView: View {
    @ObservedObject var history = HistoryManager.shared
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Distinct Header Design (Cards)
            HStack(spacing: 16) {
                StatCard(title: "Words Transcribed", value: "\(history.totalWords)", icon: "text.quote", color: .indigo)
                StatCard(title: "Time Saved", value: history.timeSavedString, icon: "hourglass", color: .teal)
            }
            .frame(height: 100)
            
            // Hero / Status
            HStack(spacing: 16) {
                // App Icon
                if let path = Bundle.main.path(forResource: "AppIcon-UI", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(10)
                } else {
                     // Fallback System Icon
                     Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading) {
                    Text("Flow State")
                        .font(.headline)
                    if appState.isAccessibilityGranted {
                        Text("Press Shift + Cmd + Space")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Permission Required")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                if appState.isAccessibilityGranted {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Button("Restart App") {
                           let url = URL(fileURLWithPath: Bundle.main.bundlePath)
                           NSWorkspace.shared.open(url)
                           NSApplication.shared.terminate(nil)
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
            
            // Recent History
            VStack(alignment: .leading) {
                HStack {
                    Text("Recent Transcriptions").font(.headline)
                    Spacer()
                    Button("Clear") { history.clear() }.controlSize(.mini)
                }
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(history.history) { item in
                            HistoryRow(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Spacer()
                Text(value).font(.title2).fontWeight(.bold)
            }
            Text(title).font(.caption).fontWeight(.medium).opacity(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        .foregroundStyle(color)
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(item.text)
                    .font(.body)
                    .lineLimit(3)
                    .layoutPriority(1)
                
                Spacer()
                
                Button(action: {
                    OutputManager.shared.copyToClipboard(item.text)
                    withAnimation { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
                }) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(item.date.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var useVAD = true
    @State private var suppressNoise = true
    
    let models = ["tiny.en", "base.en", "small.en", "medium.en", "Distil Large v3", "Large v3 Turbo"]
    
    var body: some View {
        Form {
            Section("AI Model") {
                Picker("Model", selection: $appState.selectedModel) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: appState.selectedModel) { newModel in
                     Task { await TranscriptionManager.shared.loadModel(named: newModel) }
                }
                
                if appState.isModelLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(appState.loadingProgress)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Stats Calculation") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Your Typing Speed:")
                        Spacer()
                        Text("\(appState.userTypingSpeed) WPM")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $appState.userTypingSpeed, in: 20...120, step: 5)
                            .labelsHidden()
                    }
                    Text("Used to calculate 'Time Saved' vs speaking.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            
            Section("Audio Processing") {
                Toggle("Voice Activity Detection (VAD)", isOn: $useVAD)
                    .help("Detects when you stop speaking to automatically finish recording.")
                
                if useVAD {
                    Text("VAD helps reduce silence at the end of recordings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                Toggle("Noise Suppression", isOn: $suppressNoise)
                    .help("Removes background noise like fans or clicks.")
            }
            
            Section("Debug") {
                 VStack(alignment: .leading) {
                    Text("Last Log:")
                    Text(appState.lastLog)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(height: 100)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct HelpView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Flow State Help")
                .font(.title)
            
            Text("1. Hold Shift+Cmd+Space\n2. Speak clearly\n3. Release to Paste")
                .multilineTextAlignment(.center)
        }
    }
}
