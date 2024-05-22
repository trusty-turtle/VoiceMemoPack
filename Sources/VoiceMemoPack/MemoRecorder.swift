// The Swift Programming Language
// https://docs.swift.org/swift-book

import AVFoundation

/// Records audio to a temp file
/// and returns it as an in-memory AVAudioPCMBuffer on stop().
/// Format (our chosen format for all memo audio)
/// is enforced (as in the whole app) via static helper
///
/// While recording, three things are published: level, peak level, and % of [peak hold time] remaining

enum AudioExtractionError: Error {
    case fileNotFound
    case fileReadError(Error)
    case catchAll(Error)
}

public enum MemoRecorderError: Error {
    case startCalledWhileRecording
    case stopCalledWhileNotRecording
    case audioRecorderInitFailed(Error)
    case bufferExtractionError(Error)
    case internalBrainAlreadyPlaying
    case internalBrainEngineStartFailed(Error)
    case unexpectedPigsFlyError(Error)

}

@Observable
public class MemoRecorder {
    
    private var randomPrefixForTempFile:String = UUID().uuidString
    
    private var audioRecorder: AVAudioRecorder?
    private var isRecording: Bool = false
    
    private var meteringTimer: Timer?
    private let METERING_TIMER_RESOLUTION_SECONDS:Double = 1.0/60.0
    private let PEAK_HOLD_DURATION_SECONDS:Double = 1
    
    public var currentRecLevel:Double = 0 // from 0 to 1
    public var peakRecLevel:Double = 0 // from 0 to 1
    public var peakHoldTimeRemaining:Double = 0 // from 1 to 0 : percent of peak hold time remaining
    
    public static var shared = MemoRecorder()
    
    private init() {
        print("recorder.init!")
        // Clean up any orphaned temp files used during previous recordings
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: documentsDirectory.path)
            for filePath in filePaths {
                //print(filePath)
                if filePath.hasPrefix("recording-") && filePath.hasSuffix(".wav") {
                    let fileURL = documentsDirectory.appendingPathComponent(filePath)
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print(error)
            fatalError()
            // Not fatal at all (we could not clean up temp file), do nothing.
            // print("Could not clear temp folder: \(error)")
        }
        
    }
    
    // Caller must already have permission!
    public func startRecordingWithPermission() throws {
        if (isRecording) {
            throw MemoRecorderError.startCalledWhileRecording
        }
        randomPrefixForTempFile = UUID().uuidString
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording-\(randomPrefixForTempFile).wav")
        
        do {
            let recorder = try AVAudioRecorder(url: audioFilename, format:MemoBuffer.memoFormat)
            audioRecorder = recorder
            
        } catch {
            throw MemoRecorderError.audioRecorderInitFailed(error)
        }
        isRecording = true
        // Bangs are safe because if nil, then catch would have triggered
        audioRecorder!.isMeteringEnabled = true
        audioRecorder!.record()
        currentRecLevel = 0
        peakRecLevel = 0
        peakHoldTimeRemaining = 0
        startMeteringTimer()
    }
    
    // Called when we need to stop recording but the caller does not want/need the buffer
    public func stopRecordingAndDiscard() {
        meteringTimer?.invalidate()
        audioRecorder?.stop()
        if (isRecording) {
            isRecording = false
        }
    }
    
    public func stopRecordingAndReturnBuffer() throws -> MemoBuffer {
        if (!isRecording) {
            throw MemoRecorderError.stopCalledWhileNotRecording
        }
        meteringTimer?.invalidate()
        audioRecorder?.stop()
        audioRecorder = nil
        
        var result:AVAudioPCMBuffer?
        do {
            result = try extractBufferFromFile()
        } catch {
            throw MemoRecorderError.bufferExtractionError(error)
        }
        isRecording = false
        // Bang is safe because catch would have triggered if nil
        return MemoBuffer(fromAVAudioPCMBuffer: result!)
    }
    
    // ------------------------------------------------------------------ INTERNAL
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func extractBufferFromFile() throws -> AVAudioPCMBuffer {
        
        let recordedFile = getDocumentsDirectory().appendingPathComponent("recording-\(randomPrefixForTempFile).wav")
        
        
        guard FileManager.default.fileExists(atPath: recordedFile.path) else {
            throw AudioExtractionError.fileNotFound
        }
        
        do {
            let avAudioFile = try AVAudioFile(forReading: recordedFile)
            print("recorded file length is: \(avAudioFile.length)")
            
            // Bang is safe because enforced format, and zero frame length is legal
            let buffer = AVAudioPCMBuffer(pcmFormat: MemoBuffer.memoFormat, frameCapacity: AVAudioFrameCount(avAudioFile.length))!
            
            // Attempt to read the file into the buffer
            do {
                try avAudioFile.read(into: buffer)
            } catch {
                // Specific error for file read failure
                throw AudioExtractionError.fileReadError(error)
            }
            
            // Return the filled buffer
            return buffer
        } catch {
            // Catch any other errors that were not anticipated
            throw AudioExtractionError.catchAll(error)
        }
    }
    
    
    // --------------- METERING TIMER
    
    private func startMeteringTimer() {
        meteringTimer?.invalidate()  // Invalidate any existing timer
        meteringTimer = Timer.scheduledTimer(withTimeInterval: METERING_TIMER_RESOLUTION_SECONDS, repeats: true) { _ in
            self.timerCallback()
        }
    }
    
    private func timerCallback() {
        guard let audioRecorder = audioRecorder else { return }
        audioRecorder.updateMeters()
        
        let averagePower = audioRecorder.averagePower(forChannel: 0)
        // debug
        if (averagePower > 0 || averagePower < -160) {
            //print("out of bounds: \(averagePower)")
        }
        let newValue = convertDecibelsToLinear(Double(audioRecorder.averagePower(forChannel: 0)))
        
        currentRecLevel = newValue
        // debug
        if (currentRecLevel > 1) {
            //print("overage: \(currentRecLevel)")
        }
        
        if newValue > peakRecLevel {
            peakRecLevel = newValue
            peakHoldTimeRemaining = PEAK_HOLD_DURATION_SECONDS
        } else if peakHoldTimeRemaining > 0 {
            peakHoldTimeRemaining -= METERING_TIMER_RESOLUTION_SECONDS
        } else {
            peakRecLevel = 0 // Reset peak value when hold time has elapsed
        }
    }
    
    private func convertDecibelsToLinear(_ decibels: Double) -> Double {
        let clampedDecibels = max(decibels, -160.0) // Clamp the minimum decibel value
        return pow(10.0, clampedDecibels / 20.0) // Convert to linear scale
    }
    
}


