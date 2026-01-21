# 🧠 Release: Flow State v2.3.0 - "The Intelligence Update"

**Focus**: Context Awareness, Fidelity, and Long-Form Dictation.
Building on the speed of v2.2.0, this update makes the AI smarter about *where* you are typing and *how* it formats your text.

## ✨ New Features

### 1. 🎯 App-Context Intelligence
- **Feature**: Flow State now detects which app you are dictating into.
- **Behavior**:
    - **In VS Code / Xcode**: Automatically activates **Developer Mode** (preserves code snippets, no formatting interference).
    - **In Mail**: Activates **Email Mode** (smart paragraphing).
    - **In Messaging**: Keeps it conversational.
- **Why**: "Anti-Gravity" is gone. The AI knows its environment.

### 2. 📝 Long-Form Dictation (4x Capacity)
- **Change**: Increased Token Limit from `512` → **`2048`**.
- **Impact**: You can now dictate long emails, essays, or technical docs (approx. 1,500 words) without the text cutting off mid-sentence.

### 3. 🔐 "Verbatim" Mode (Stricter Prompts)
- **Change**: Tuned the LLM System Prompt to be significantly stricter.
- **Impact**:
    - forbidden from "rewriting" or "summarizing" your thoughts.
    - Only fixes filler words ("um", "uh") and critical grammar.
    - **Result**: What you say is what you get—just polished.

## 🛠️ Fixes & Polish
- **Stability**: Fixed a concurrency race condition in `AppDelegate` that could cause crashes on rapid toggle.
- **Configuration**: VAD (Voice Activity Detection) thresholds are now dynamically tunable in `AppState`.
- **Hallucinations**: Removed aggressive filters that were accidentally deleting the word "You".

## 📦 Installation
1. Download `FlowState_Installer.dmg`.
2. Drag `FlowState` to Applications.
3. Enjoy the smartest dictation experience on Mac.
