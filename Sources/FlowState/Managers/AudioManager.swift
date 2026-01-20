import Foundation
import AVFoundation
import Accelerate

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    @Published var isRecording = false
    
    // Buffer to hold float samples (32-bit, 16kHz)
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000.0 // Whisper native
    private var noiseFloors: [Float] = Array(repeating: -60.0, count: 8) // Adaptive Floor Tracker
    
    private var converter: AVAudioConverter?
    private var targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    // FFT State
    private let fftSetup = vDSP_create_fftsetup(10, FFTRadix(FFT_RADIX2)) // 1024 samples
    private var fftRealPart = [Float](repeating: 0, count: 512)
    private var fftImagPart = [Float](repeating: 0, count: 512)
    
    // VAD & Streaming State
    var onChunkCaptured: (([Float]) -> Void)?
    private var lastChunkEndIndex: Int = 0
    private var silenceDuration: Double = 0
    private var timeSinceLastChunk: Double = 0
    
    // Constants for Smart Streaming
    private let minChunkSeconds: Double = 2.0 // Minimum chunk size (was 4.0, lowered for responsiveness)
    private let maxChunkSeconds: Double = 10.0 // Force cut if too long
    private let silenceThreshold: Float = 0.02 // RMS threshold for "Silence"
    private let minSilenceDuration: Double = 0.4 // Duration to confirm pause
    
    // Check permissions only
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            setupAudio()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted { self.setupAudio() }
            }
        default:
            print("Microphone access denied.")
        }
    }
    
    private func setupAudio() {
        guard let audioEngine = self.audioEngine, let inputNode = self.inputNode else {
            print("[AudioManager] Audio engine or input node not initialized.")
            return
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        // Setup Converter to 16kHz
        guard let freqConverter = AVAudioConverter(from: format, to: targetFormat) else {
            print("[AudioManager] Could not create audio converter")
            return
        }
        self.converter = freqConverter
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            self.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async { self.isRecording = true }
            print("[AudioManager] 🔴 Started recording at \(format.sampleRate)Hz -> Resampling to 16000Hz")
        } catch {
            print("[AudioManager] ❌ Audio Engine failed to start: \(error)")
        }
    }
    
    func startRecording() {
        stopRecording() // Safety reset
        
        audioBuffer.removeAll()
        AppState.shared.amplitude = 0
        AppState.shared.fftMagnitudes = Array(repeating: 0.1, count: 16)
        
        // Reset Streaming State
        lastChunkEndIndex = 0
        silenceDuration = 0
        timeSinceLastChunk = 0
        
        // 🔥 Warmup Network (SSL Handshake)
        GroqService.shared.warmup()
        
        self.audioEngine = AVAudioEngine()
        self.inputNode = self.audioEngine?.inputNode
        
        checkPermissions()
    }
    
    private func processAudioBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }
        
        // Calculate output frame count ratio
        let inputFrameCount = AVAudioFrameCount(inputBuffer.frameLength)
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let targetFrameCount = AVAudioFrameCount(Double(inputFrameCount) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCount) else { return }
        
        var error: NSError? = nil
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("[AudioManager] Resample error: \(error)")
            return
        }
        
        // Append converted floats to master buffer
        if let channelData = outputBuffer.floatChannelData?[0] {
            let processedFrames = Int(outputBuffer.frameLength)
            let floats = UnsafeBufferPointer(start: channelData, count: processedFrames)
            self.audioBuffer.append(contentsOf: floats)
            
            // Calculate Amplitude for UI (on 16kHz signal is fine)
            var sum: Float = 0
            for val in floats { sum += val * val }
            let rms = sqrt(sum / Float(processedFrames))
            let normalized = min(max(rms * 10.0, 0), 1.0)
            
            // --- SMART STREAMING LOGIC ---
            let bufferDuration = Double(processedFrames) / sampleRate
            timeSinceLastChunk += bufferDuration
            
            if rms < silenceThreshold {
                silenceDuration += bufferDuration
            } else {
                silenceDuration = 0
            }
            
            // Check Trigger
            let canCut = timeSinceLastChunk > minChunkSeconds && silenceDuration > minSilenceDuration
            let mustCut = timeSinceLastChunk > maxChunkSeconds
            
            if canCut || mustCut {
                // Cut the chunk
                let endIndex = audioBuffer.count
                // If VAD cut, maybe trim the silence? For now, raw cut is safer to keep flow.
                let chunk = Array(audioBuffer[lastChunkEndIndex..<endIndex])
                
                print("[AudioManager] ✂️ Smart Chunk Triggered: \(String(format: "%.1fs", timeSinceLastChunk)) (Silence: \(String(format: "%.2fs", silenceDuration)))")
                
                onChunkCaptured?(chunk)
                
                lastChunkEndIndex = endIndex
                timeSinceLastChunk = 0
                silenceDuration = 0 // Reset silence counter after cut
            }
            // -----------------------------
            
            // --- COMPUTING FFT ---
            if let fftSetup = self.fftSetup {
                // We need 1024 samples. processedFrames should ideally be 1024.
                var inputFloats = Array(floats)
                if inputFloats.count < 1024 {
                    inputFloats += Array(repeating: Float(0), count: 1024 - inputFloats.count)
                } else if inputFloats.count > 1024 {
                    inputFloats = Array(inputFloats.prefix(1024))
                }
                
                // Safe Pointer Access
                self.fftRealPart.withUnsafeMutableBufferPointer { realPtr in
                    self.fftImagPart.withUnsafeMutableBufferPointer { imagPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: realPtr.baseAddress!,
                            imagp: imagPtr.baseAddress!
                        )
                        
                        // Pack Input
                        inputFloats.withUnsafeBytes { ptr in
                             let asSplit = ptr.bindMemory(to: DSPComplex.self)
                             vDSP_ctoz(asSplit.baseAddress!, 2, &splitComplex, 1, 512)
                        }
                        
                        // Perform FFT
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, 10, FFTDirection(FFT_FORWARD))
                        
                        // Calculate Magnitudes
                        var magnitudes = [Float](repeating: 0.0, count: 256)
                        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, 256)
                        
                        let ranges: [(Int, Int)] = [
                            (38, 50),    // Bar 0: ~600 - 800 Hz
                            (50, 65),    // Bar 1: ~800 - 1.0k Hz
                            (65, 85),    // Bar 2: ~1.0k - 1.3k Hz
                            (85, 110),   // Bar 3: ~1.3k - 1.7k Hz
                            (110, 140),  // Bar 4: ~1.7k - 2.2k Hz
                            (140, 180),  // Bar 5: ~2.2k - 2.8k Hz
                            (180, 220),  // Bar 6: ~2.8k - 3.4k Hz
                            (220, 256)   // Bar 7: ~3.4k - 4.0k Hz
                        ]
                        
                        var newMags = [Float](repeating: 0.0, count: 8)
                        
                        for i in 0..<8 {
                            let (start, end) = ranges[i]
                            var magSum: Float = 0
                            var binCount: Float = 0
                            
                            for j in start..<end {
                                if j < magnitudes.count {
                                    magSum += magnitudes[j]
                                    binCount += 1
                                }
                            }
                            
                            let avgMag = binCount > 0 ? magSum / binCount : 0
                            let db = 10 * log10(max(avgMag, 1e-9))
                            let minDb: Float = -35.0
                            let maxDb: Float = 0.0
                            
                            if db < minDb {
                                newMags[i] = 0.0
                            } else {
                                let norm = (db - minDb) / (maxDb - minDb)
                                let clamped = min(max(norm, 0.0), 1.0)
                                newMags[i] = clamped * clamped 
                            }
                        }
                        
                        let decayFactor: Float = 0.7
                        
                        DispatchQueue.main.async {
                            AppState.shared.amplitude = normalized
                            
                             var currentMags = AppState.shared.fftMagnitudes
                             if currentMags.count != 8 { currentMags = Array(repeating: 0.0, count: 8) }
                             
                             for k in 0..<8 {
                                 let target = newMags[k]
                                 let old = currentMags[k]
                                 
                                 if target > old {
                                     currentMags[k] = target
                                 } else {
                                     currentMags[k] = old * decayFactor + target * (1 - decayFactor)
                                 }
                             }
                            AppState.shared.fftMagnitudes = currentMags
                        }
                    }
                }
            }
        }
    }
    
    // Returns (FullBuffer, TailChunk)
    func stopRecording() -> (full: [Float], tail: [Float]) {
        if let engine = audioEngine {
             engine.stop()
             inputNode?.removeTap(onBus: 0)
        }
        audioEngine = nil
        inputNode = nil
        converter = nil
        isRecording = false
        
        // Capture the final tail
        var tail: [Float] = []
        if lastChunkEndIndex < audioBuffer.count {
            tail = Array(audioBuffer[lastChunkEndIndex..<audioBuffer.count])
            print("[AudioManager] ⏹️ Stopped. Capturing tail: \(tail.count) samples")
        } else {
            print("[AudioManager] ⏹️ Stopped. No tail to capture.")
        }
        
        // --- DIAGNOSTICS ---
        var sum: Float = 0
        for val in audioBuffer { sum += val * val }
        let rms = sqrt(sum / Float(max(audioBuffer.count, 1)))
        let isSilent = rms < 0.001
        
        let deviceName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "Unknown Device"
        
        let status = "[AudioManager] 📊 Session: \(audioBuffer.count) samples. RMS: \(String(format: "%.5f", rms)) Device: \(deviceName)"
        print(status)
        
        DispatchQueue.main.async {
            let quietWarning = isSilent ? "\n⚠️ LOW VOLUME on \(deviceName). Check Settings > Sound." : ""
            AppState.shared.lastLog = "Audio: \(self.audioBuffer.count)smp | Vol: \(String(format: "%.3f", rms)) | Mic: \(deviceName)\(quietWarning)"
            AppState.shared.amplitude = 0
            AppState.shared.fftMagnitudes = Array(repeating: 0.1, count: 16)
        }
        
        return (audioBuffer, tail)
    }
}
