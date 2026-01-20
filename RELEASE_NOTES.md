# 🚀 Release: Flow State v2.2.0 - "The Speed Update"

**Focus**: Audio Latency & Network Optimization
This update specifically targets the "time-to-text" latency, making the dictation experience feel nearly instantaneous.

## ⚡️ Key Features

### 1. Instant Start (No Cold Lag)
- **Problem**: The first time you pressed Record, there was a ~500ms delay while the Neural Engine woke up.
- **Fix**: Implemented **Model Warmup**. The engine pre-heats silently on app launch.
- **Result**: First interaction is now as fast as the hundredth.

### 2. Smart Streaming (Zero-Wait)
- **Problem**: Previously, you had to wait until you *finished* speaking a long paragraph to see any text.
- **Fix**: Added **VAD-Based Smart Streaming**. The app now intelligently processes audio chunks during natural pauses (breaths) without splitting words.
- **Result**: Text appears progressively as you speak, maintaining full context accuracy.

### 3. Network Warmup (No Connection Lag)
- **Problem**: Initial dictation had a ~3.2s delay due to SSL/DNS handshakes with the LLM provider.
- **Fix**: The app now **pre-connects** to the API the moment you press the Record key.
- **Result**: By the time you finish speaking, the connection is already open and waiting.

## 🔧 Improvements
- **Greedy Decoding**: Switched Whisper decoding strategy to `temperature=0` for a **15% speed boost** with no accuracy loss.
- **Metrics Fix**: Fixed a bug where short audio clips reported `0.0s` duration.
- **Bug Fix**: Resolved a race condition where the final audio chunk was occasionally dropped if recording stopped abruptly.

## 📦 Installation
1. Download `FlowState_Installer.dmg` below.
2. Drag `FlowState` to Applications.
3. Grant Microphone & Accessibility permissions when prompted.
