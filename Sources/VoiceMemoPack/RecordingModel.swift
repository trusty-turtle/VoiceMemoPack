import SwiftData
import Foundation

public protocol ProtocolForParentOfARecording: Observable, AnyObject {
    
    var recording: Recording? { get set }
    
    func deleteRecording(modelContext: ModelContext)
    func replaceRecording(newRecording: MemoBuffer, modelContext: ModelContext)
    
}

@Model
public final class Recording {
    
    public init(recordingData: Data, duration: Double, trimStartPoint: Double = 0, trimEndPoint: Double = 1, isFinalized: Bool = false) {
        self.fullAudioData = recordingData
        self._fullDuration = duration
        self.trimStartPoint = trimStartPoint
        self.trimEndPoint = trimEndPoint
        self._isFinalized = isFinalized
    }
    
    @Attribute(.externalStorage) private var fullAudioData: Data

    private var _fullDuration:Double
    
    private var _isFinalized:Bool
    
    private var hasTrimmed:Bool {
        get {
            return trimStartPoint != 0 || trimEndPoint != 1
        }
    }
    
    public var duration: Double {
        get {
            if (!isFinalized && hasTrimmed) {
                let trimRatio = (trimEndPoint - trimStartPoint)/1.0
                let trimmedDuration = trimRatio * _fullDuration
                return trimmedDuration
            } else {
                return _fullDuration
            }
        }
    }
    
    
    public var trimStartPoint: Double
    
    public var trimEndPoint: Double

    public var isFinalized: Bool {
        get {
            return _isFinalized
        }
    }
    
    public func getMemoBuffer(withoutTrim: Bool) -> MemoBuffer {
        let fullBuffer = MemoBuffer(fromData: fullAudioData)
        
        if (isFinalized || withoutTrim || !hasTrimmed) {
            return fullBuffer
        } else {
            return MemoBuffer(fromAVAudioPCMBuffer: fullBuffer.getAVAudioPCMBuffer(), start: trimStartPoint, end: trimEndPoint)
        }
    }
    
    public func finalizeTrim() {
        assert(!isFinalized)
        if hasTrimmed {
            let full = MemoBuffer(fromData: fullAudioData)
            print("!!! - frame len: \(full.getAVAudioPCMBuffer().frameLength)")
            let trimmed = MemoBuffer(fromAVAudioPCMBuffer: full.getAVAudioPCMBuffer(), start: trimStartPoint, end: trimEndPoint)
            print("!!! - trimmed len: \(full.getAVAudioPCMBuffer().frameLength)")
            fullAudioData = trimmed.toData()
            print("!!! - final len: \(fullAudioData.count)")
        }
        // reset trim points so that we don't get compounded trim in recwidget.recorded.play()
        trimStartPoint = 0
        trimEndPoint = 1
        _isFinalized = true
    }
    
    
}
