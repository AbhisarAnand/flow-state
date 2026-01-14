import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    @Published var isRecording = false
    
    var audioBuffer: [Float] = []
    
    // Converter state
    private var converter: AVAudioConverter?
    private var targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default: break
        }
    }
    
    func startRecording() {
        checkPermissions()
        stopRecording() // Safety reset
        
        audioBuffer.removeAll()
        
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        
        // Initialize Converter
        // From Input Format -> 16kHz Mono Float
        self.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { (buffer, time) in
            // Resample to 16kHz
            self.processAudioBuffer(buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
            self.inputNode = input
            self.isRecording = true
            print("[AudioManager] Started recording at \(inputFormat.sampleRate)Hz -> Resampling to 16000Hz")
        } catch {
            print("[AudioManager] Error starting engine: \(error)")
        }
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
            for vid in floats { sum += vid * vid }
            let rms = sqrt(sum / Float(processedFrames))
            let normalized = min(max(rms * 10.0, 0), 1.0) 
            
            DispatchQueue.main.async {
                AppState.shared.amplitude = normalized
            }
        }
    }
    
    func stopRecording() -> [Float] {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        converter = nil
        isRecording = false
        print("[AudioManager] Stopped. Captured \(audioBuffer.count) samples (should be ~16000 per sec)")
        return audioBuffer
    }
}
