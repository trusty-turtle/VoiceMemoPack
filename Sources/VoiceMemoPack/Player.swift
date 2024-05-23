import AVFoundation

extension AVAudioPlayerNode{
    var current: TimeInterval{
        if let nodeTime = lastRenderTime,let playerTime = playerTime(forNodeTime: nodeTime) {
            return Double(playerTime.sampleTime) / playerTime.sampleRate
        }
        return 0
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public enum MemoPlayerError: Error {
    case audioEngineFailedToStart(Error)
}

@Observable
public class MemoPlayer {
    
    private let POSITION_TIMER_RESOLUTION_SECONDS = 1.0/60.0
    
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode

    private var playbackTimer: Timer?
    private var bufferDurationSeconds:Double = 0
    public var playHeadPosition:Double = 0
    
    public static let shared:MemoPlayer = MemoPlayer()
    
    private init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        // we are connecting mono to stereo here, but should be OK
        engine.connect(playerNode, to: engine.mainMixerNode, format: MemoBuffer.memoFormat)
        
    }
    
    public func playMemoWithPlayHeadAnimation(_ memoBuffer: MemoBuffer, completionHandler: AVAudioNodeCompletionHandler? = nil) throws {
        playerNode.stop()
        playerNode.scheduleBuffer(memoBuffer.getAVAudioPCMBuffer(), at: nil, options: [], completionHandler: completionHandler)
        do {
            try engine.start()
        } catch {
            throw MemoPlayerError.audioEngineFailedToStart(error)
        }
        // set and re-set vars
        bufferDurationSeconds = memoBuffer.getDurationExpensive()
        //print("duration: \(bufferDurationSeconds)")
        playHeadPosition = 0
        
        // Start the playback
        playerNode.play()
        
        // Start the timer to update playHeadPosition
        startPlaybackTimer()
        
    }
    
    public func stop() {
        if playerNode.isPlaying {
            playHeadPosition = 0
            playbackTimer?.invalidate()
            playerNode.stop()
        }
    }
    
    deinit {
        stop()
        engine.stop()
        engine.detach(playerNode)
    }
    
    // ---------------------------------------------------------------- PLAY HEAD TIMER
    
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()  // Invalidate any existing timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: POSITION_TIMER_RESOLUTION_SECONDS, repeats: true) { _ in
            self.updatePlayHeadPosition()
        }
    }
    
    private func updatePlayHeadPosition() {
        guard playerNode.isPlaying else {
            playHeadPosition = 0
            return
        }

        playHeadPosition = (playerNode.current / bufferDurationSeconds).clamped(to: 0...1)

        if (playHeadPosition >= 1) {
            playbackTimer?.invalidate()
            playHeadPosition = 0
            //print("we auto stopped!")
        } else {
            //print("we did NOT auto-stop")
        }
        
        //print("playhead position: \(playHeadPosition)")
        //print("current node time: \(playerNode.current)")
    }
}


