import Foundation
import Combine

class RecordingState: ObservableObject {
    static let shared = RecordingState()
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: Int = 0
    @Published var includeCamera = false
    
    private var timer: Timer?
    
    private init() {}
    
    func startRecording(includeCamera: Bool) {
        isRecording = true
        isPaused = false
        recordingDuration = 0
        self.includeCamera = includeCamera
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }
    
    func pauseRecording() {
        isPaused = true
        timer?.invalidate()
    }
    
    func resumeRecording() {
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }
    
    func stopRecording() {
        isRecording = false
        isPaused = false
        timer?.invalidate()
        timer = nil
    }
}
