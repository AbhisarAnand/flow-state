import SwiftUI

struct DashboardView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selection: SidebarItem? = .home
    
    enum SidebarItem {
        case home, profiles, data, settings, help
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "house.fill")
                    .tag(SidebarItem.home)
                Label("Profiles", systemImage: "square.grid.2x2.fill")
                    .tag(SidebarItem.profiles)
                Label("Data", systemImage: "waveform.path.ecg")
                    .tag(SidebarItem.data)
                Label("Settings", systemImage: "gearshape.fill")
                    .tag(SidebarItem.settings)
                Label("Help", systemImage: "questionmark.circle.fill")
                    .tag(SidebarItem.help)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            ZStack {
                // Global Background
                // Global Ambient Glow
                ZStack {
                    Color.flowBackground.ignoresSafeArea()
                    
                    // Top-Left Blue Glow
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 800, height: 800)
                        .blur(radius: 120)
                        .offset(x: -300, y: -300)
                    
                    // Bottom-Right Purple Glow
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 600, height: 600)
                        .blur(radius: 100)
                        .offset(x: 400, y: 300)
                        
                    // Center Cyan Glow (Subtle)
                    Circle()
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 700, height: 700)
                        .blur(radius: 150)
                }
                .ignoresSafeArea()
                
                switch selection {
                case .home:
                    HomeViewV2()
                case .profiles:
                    ProfilesView()
                case .data:
                    DataView()
                case .settings:
                    SettingsView()
                case .help:
                    HelpView()
                case .none:
                    HomeViewV2()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Views

struct HomeViewV2: View {
    @ObservedObject var history = HistoryManager.shared
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Title
                Text("Flow State")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.leading, 8)

                // Responsive Top Section
                ViewThatFits(in: .horizontal) {
                    // Wide Layout
                    // Wide Layout (Gauge Left, Stats/Banner Right)
                    HStack(alignment: .center, spacing: 24) {
                        FlowVelocityGauge(wpm: history.averageSpokenWPM)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                V2StatCard(title: "Total Words", value: "\(history.totalWords)", icon: "text.quote", color: .blue)
                                V2StatCard(title: "Time Saved", value: history.timeSavedString, icon: "hourglass", color: .green)
                            }
                            StatusBanner()
                        }
                    }
                    
                    // Narrow Layout (Stack Vertically)
                    VStack(alignment: .center, spacing: 24) {
                        FlowVelocityGauge(wpm: history.averageSpokenWPM)
                        
                        VStack(spacing: 16) {
                            // On narrow screens, maybe stack stats too if super narrow, 
                            // but usually these fit side-by-side.
                            HStack(spacing: 16) {
                                V2StatCard(title: "Words", value: "\(history.totalWords)", icon: "text.quote", color: .blue)
                                V2StatCard(title: "Saved", value: history.timeSavedString, icon: "hourglass", color: .green)
                            }
                            StatusBanner()
                        }
                    }
                }
                .padding(.top, 20)
                
                // Recent Flow Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Recent Flow", systemImage: "clock.arrow.circlepath")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { history.clear() }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(0.7)
                    }
                    .padding(.horizontal, 4)
                    
                    LazyVStack(spacing: 12) {
                        if history.history.isEmpty {
                            Text("No recent sessions")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(12)
                        } else {
                            ForEach(history.history) { item in
                                HistoryRow(item: item)
                            }
                        }
                    }
                }
                .glassCard() // Wrap entire section in a big glass card
            }
            .padding(32) // Increased padding for cleaner look
        }
    }
}

struct ProfilesView: View {
    @ObservedObject var profileManager = ProfileManager.shared
    @State private var searchText = ""
    @State private var showingAPIKeySheet = false
    
    var filteredApps: [AppProfile] {
        if searchText.isEmpty {
            return profileManager.appProfiles.sorted { $0.name < $1.name }
        }
        return profileManager.appProfiles
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("App Profiles")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Description
                Text("Assign formatting profiles to apps. When you transcribe, the text will be formatted based on the active app.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                
                // Category Legend
                HStack(spacing: 16) {
                    ForEach(ProfileCategory.allCases) { category in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(categoryColor(category))
                                .frame(width: 10, height: 10)
                            Text(category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Groq API Key Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Groq API Key (for Formal formatting)", systemImage: "key.fill")
                        .font(.headline)
                    
                    HStack {
                        if profileManager.groqAPIKey.isEmpty {
                            Text("Not configured")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("••••••••••••\(profileManager.groqAPIKey.suffix(4))")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(profileManager.groqAPIKey.isEmpty ? "Add Key" : "Change") {
                            showingAPIKeySheet = true
                        }
                    }
                    
                    Text("Get your free API key at console.groq.com")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .glassCard()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                // App List
                VStack(alignment: .leading, spacing: 12) {
                    Label("Assigned Apps (\(filteredApps.count))", systemImage: "app.badge.checkmark.fill")
                        .font(.headline)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            AppProfileRow(app: app)
                        }
                    }
                }
                .glassCard()
                
                // Actions
                HStack {
                    Button("Reset to Defaults") {
                        profileManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Discover Apps") {
                        let discovered = profileManager.discoverInstalledApps()
                        // Merge discovered apps
                        for app in discovered {
                            if !profileManager.appProfiles.contains(where: { $0.id == app.id }) {
                                profileManager.appProfiles.append(app)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet()
        }
    }
    
    func categoryColor(_ category: ProfileCategory) -> Color {
        switch category {
        case .casual: return .green
        case .formal: return .blue
        case .code: return .purple
        case .default: return .gray
        }
    }
}

struct AppProfileRow: View {
    let app: AppProfile
    @ObservedObject var profileManager = ProfileManager.shared
    
    var body: some View {
        HStack {
            Circle()
                .fill(categoryColor(app.category))
                .frame(width: 8, height: 8)
            
            Text(app.name)
                .fontWeight(.medium)
            
            Spacer()
            
            Menu {
                ForEach(ProfileCategory.allCases) { category in
                    Button(action: {
                        profileManager.updateCategory(for: app.id, to: category)
                    }) {
                        if app.category == category {
                            Label(category.rawValue, systemImage: "checkmark")
                        } else {
                            Text(category.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(app.category.rawValue)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
    
    func categoryColor(_ category: ProfileCategory) -> Color {
        switch category {
        case .casual: return .green
        case .formal: return .blue
        case .code: return .purple
        case .default: return .gray
        }
    }
}

struct APIKeySheet: View {
    @ObservedObject var profileManager = ProfileManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Groq API Key")
                .font(.title2.bold())
            
            Text("Enter your Groq API key for smart email formatting. Get a free key at console.groq.com")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            SecureField("gsk_...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    profileManager.saveAPIKey(apiKey)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            apiKey = profileManager.groqAPIKey
        }
    }
}

struct DataView: View {
    @ObservedObject var metricsManager = MetricsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Performance Data")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Summary Stats
                if !metricsManager.metrics.isEmpty {
                    HStack(spacing: 16) {
                        StatCard(title: "Avg Transcription", value: String(format: "%.2fs", metricsManager.averageTranscriptionTime), color: .blue)
                        StatCard(title: "Avg LLM", value: String(format: "%.2fs", metricsManager.averageLLMTime), color: .purple)
                        StatCard(title: "Avg Total", value: String(format: "%.2fs", metricsManager.averageTotalTime), color: .green)
                        StatCard(title: "Requests", value: "\(metricsManager.metrics.count)", color: .orange)
                    }
                }
                
                // Metrics Table
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Request History", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Spacer()
                        Button("Clear All") {
                            metricsManager.clear()
                        }
                        .foregroundStyle(.red)
                        .disabled(metricsManager.metrics.isEmpty)
                    }
                    
                    if metricsManager.metrics.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No data yet")
                                .foregroundStyle(.secondary)
                            Text("Start transcribing to see performance metrics")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        // Table Header
                        HStack(spacing: 12) {
                            Text("Time").frame(width: 65, alignment: .leading)
                            
                            // Models
                            Group {
                                Text("Audio Model").frame(width: 90, alignment: .leading)
                                Text("Text Model").frame(width: 90, alignment: .leading)
                            }
                            
                            // Timings
                            Group {
                                Text("Audio").frame(width: 50, alignment: .trailing)
                                Text("Text").frame(width: 50, alignment: .trailing)
                                Text("Lag").frame(width: 50, alignment: .trailing)
                                Text("Total").frame(width: 55, alignment: .trailing)
                            }
                            
                            Text("Content").frame(minWidth: 100, alignment: .leading)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        
                        Divider()
                        
                        // Table Rows
                        LazyVStack(spacing: 4) {
                            ForEach(metricsManager.metrics) { metric in
                                MetricRow(metric: metric)
                            }
                        }
                    }
                }
                .glassCard()
            }
            .padding(24)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct MetricRow: View {
    let metric: TranscriptionMetric
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(metric.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                    .frame(width: 65, alignment: .leading)
                    .foregroundStyle(.secondary)
                
                // Models
                Group {
                    Text(shortModelName(metric.whisperModel))
                        .font(.caption)
                        .frame(width: 90, alignment: .leading)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                    
                    Text(shortModelName(metric.llmModel))
                        .font(.caption)
                        .frame(width: 90, alignment: .leading)
                        .foregroundStyle(.purple)
                        .lineLimit(1)
                }
                
                // Timings
                Group {
                    Text(String(format: "%.1fs", metric.transcriptionTime))
                        .font(.caption.monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(.blue.opacity(0.8))
                    
                    Text(String(format: "%.1fs", metric.llmFormattingTime))
                        .font(.caption.monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(.purple.opacity(0.8))
                    
                    Text(String(format: "%.1fs", metric.overheadTime))
                        .font(.caption.monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    Text(String(format: "%.1fs", metric.totalProcessingTime))
                        .font(.caption.monospacedDigit().bold())
                        .frame(width: 55, alignment: .trailing)
                        .foregroundStyle(.green)
                }
                
                Text(metric.formattedText)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(minWidth: 100, alignment: .leading)
                    .lineLimit(1)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isExpanded ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
            .cornerRadius(8)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recording Duration").font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "%.2f seconds", metric.recordingDuration)).font(.caption)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Input Length").font(.caption2).foregroundStyle(.secondary)
                            Text("\(metric.inputLength) chars").font(.caption)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Output Length").font(.caption2).foregroundStyle(.secondary)
                            Text("\(metric.outputLength) chars").font(.caption)
                        }
                    }
                    
                    Divider()
                    
                    Text("Raw Transcription").font(.caption2).foregroundStyle(.secondary)
                    Text(metric.rawText)
                        .font(.caption)
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    
                    Text("Formatted Output").font(.caption2).foregroundStyle(.secondary)
                    Text(metric.formattedText)
                        .font(.caption)
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
                .padding(.leading, 8)
            }
        }
    }
    
    func shortModelName(_ name: String) -> String {
        // Shorten model names for display
        if name.contains("70b") { return "70B" }
        if name.contains("Turbo") || name.contains("turbo") { return "Turbo" }
        if name.contains("Large") { return "Large" }
        if name.contains("medium") { return "Medium" }
        if name.contains("small") { return "Small" }
        if name.contains("base") { return "Base" }
        if name.contains("tiny") { return "Tiny" }
        if name.contains("Distil") { return "Distil" }
        return String(name.prefix(10))
    }
}

// Keeping SettingsView mostly the same but wrapped in V2 structure if needed, or reusing existng.
// Reusing standard SettingsView from previous file content, but ensuring it builds.
// Note: SettingsView and HistoryRow were already in the file, reusing them.

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @State private var useVAD = true
    @State private var suppressNoise = true
    @State private var isRecordingPTT = false
    @State private var isRecordingHandsFree = false
    @State private var tempShortcut: KeyShortcut?
    
    let models = ["tiny.en", "base.en", "small.en", "medium.en", "Distil Large v3", "Large v3 Turbo"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Settings Title
                Text("Settings")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.leading, 8)
                
                // AI Model Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("AI Model", systemImage: "brain.head.profile")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Model")
                            Spacer()
                            Menu {
                                ForEach(models, id: \.self) { model in
                                    Button(action: {
                                        appState.selectedModel = model
                                    }) {
                                        if appState.selectedModel == model {
                                            Label(model, systemImage: "checkmark")
                                        } else {
                                            Text(model)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(appState.selectedModel)
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                        }
                        .onChange(of: appState.selectedModel) { newModel in
                             Task { await TranscriptionManager.shared.loadModel(named: newModel) }
                        }
                        
                        if appState.isModelLoading {
                            Divider()
                            HStack {
                                ProgressView().controlSize(.small)
                                Text(appState.loadingProgress)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                
                // Controls Section (Dual Keybind Recorders)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Controls", systemImage: "keyboard")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. Push-to-Talk Recorder
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Push-to-Talk")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Hold to record, release to transcribe.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            KeybindRecorderButton(
                                shortcut: hotkeyManager.pttShortcut,
                                isRecording: isRecordingPTT,
                                tempShortcut: tempShortcut,
                                onStartRecording: {
                                    isRecordingPTT = true
                                    isRecordingHandsFree = false
                                    hotkeyManager.isLearning = true
                                    hotkeyManager.onBindUpdate = { new in tempShortcut = new }
                                    hotkeyManager.onBindComplete = {
                                        if let new = tempShortcut { hotkeyManager.pttShortcut = new }
                                        isRecordingPTT = false
                                        hotkeyManager.isLearning = false
                                        tempShortcut = nil
                                    }
                                },
                                onCancel: {
                                    isRecordingPTT = false
                                    hotkeyManager.isLearning = false
                                    tempShortcut = nil
                                }
                            )
                        }
                        
                        Divider()
                        
                        // 2. Hands-Free Recorder
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hands-Free Mode")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Press to start, press again to stop.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            KeybindRecorderButton(
                                shortcut: hotkeyManager.handsFreeShortcut,
                                isRecording: isRecordingHandsFree,
                                tempShortcut: tempShortcut,
                                onStartRecording: {
                                    isRecordingHandsFree = true
                                    isRecordingPTT = false
                                    hotkeyManager.isLearning = true
                                    hotkeyManager.onBindUpdate = { new in tempShortcut = new }
                                    hotkeyManager.onBindComplete = {
                                        if let new = tempShortcut { hotkeyManager.handsFreeShortcut = new }
                                        isRecordingHandsFree = false
                                        hotkeyManager.isLearning = false
                                        tempShortcut = nil
                                    }
                                },
                                onCancel: {
                                    isRecordingHandsFree = false
                                    hotkeyManager.isLearning = false
                                    tempShortcut = nil
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                
                // Stats Calculation Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Stats Calculation", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Your Typing Speed")
                            Spacer()
                            Text("\(appState.userTypingSpeed) WPM")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Stepper("", value: $appState.userTypingSpeed, in: 20...120, step: 5)
                                .labelsHidden()
                        }
                        Text("Used to calculate 'Time Saved' vs speaking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                
                // Audio Processing
                VStack(alignment: .leading, spacing: 12) {
                    Label("Audio Processing", systemImage: "waveform")
                        .font(.headline)
                    
                    HStack {
                        Text("Voice Activity Detection (VAD)")
                        Spacer()
                        Toggle("", isOn: $useVAD)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Noise Suppression")
                        Spacer()
                        Toggle("", isOn: $suppressNoise)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                
                // Application Info
                VStack(alignment: .leading, spacing: 12) {
                    Label("System", systemImage: "macwindow")
                        .font(.headline)
                        
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Update Channel")
                        Spacer()
                        Button("Check for Updates") {
                            UpdateManager.shared.checkForUpdates()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                
                // Debug Log
                VStack(alignment: .leading, spacing: 12) {
                    Label("Last Log", systemImage: "ladybug")
                        .font(.headline)
                        
                    Text(appState.lastLog)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
            .padding(24)
        }
    }
}

// Helper Component for Recorder Button
struct KeybindRecorderButton: View {
    let shortcut: KeyShortcut
    let isRecording: Bool
    let tempShortcut: KeyShortcut?
    let onStartRecording: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                if isRecording {
                    onCancel()
                } else {
                    onStartRecording()
                }
            }) {
                HStack(spacing: 8) {
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse)
                        Text(tempShortcut?.displayString ?? "Press Keys...")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    } else {
                        // REMOVED: Image(systemName: "command") per user request for cleaner look
                        
                        Text(shortcut.displayString)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecording ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Cancel button specifically if recording (release-to-save handles save, but cancel is good backup)
            if isRecording {
                Button(action: onCancel) {
                     Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
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
            
            Text("1. Hold Shift+Cmd+Space (or Fn)\n2. Speak clearly\n3. Release to Paste")
                .multilineTextAlignment(.center)
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            
            Divider()
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                
                Spacer()
                Text(String(format: "%.1fs", item.duration))
                     .font(.caption2)
                     .foregroundStyle(.secondary)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial) 
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
             RoundedRectangle(cornerRadius: 12)
                 .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}
