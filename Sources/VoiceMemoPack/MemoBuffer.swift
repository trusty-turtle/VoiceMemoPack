//
//  MemoBuffer.swift
//  WWPD
//
//  Created by Me on 4/11/24.
//

import Foundation
import AVFoundation
import SwiftData

// our custom AVAUDIOPCMBuffer
public class MemoBuffer {
    
    // Changing this format from 44100 / float32 / 1-channel / nonInterleaved
    // will require careful search for side-effects
    // Bang is safe because this is a standard format
    public static let memoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100.0, channels: 1, interleaved: false)!
    
    // Always guaranteed to be in correct ("memoFormat" above) format!
    private let PCMBuffer: AVAudioPCMBuffer
    
    // ------------------------------------------------------------------------ INIT
    
    public init(fromData: Data) {
        PCMBuffer = MemoBuffer.dataToPCM(dataSource: fromData, withFormat: MemoBuffer.memoFormat)
    }
    
    // the condition where start and end are too close together* is guarded for in the UI widget
    // * (this could cause a zero-frame length problem)
    public init(fromAVAudioPCMBuffer inBuffer: AVAudioPCMBuffer, start: Double = 0.0, end: Double = 1.0) {
        assert(inBuffer.format == MemoBuffer.memoFormat)
        // Ensure trim points are valid
        assert(start <= end && start >= 0 && end <= 1)
        if (start == 0 && end == 1) {
            PCMBuffer = inBuffer
        } else {
            PCMBuffer = MemoBuffer.trimPCMBuffer(inBuffer, from: start, to: end)
        }
    }
    
    // ------------------------------------------------------------------------ PUBLIC FUNCTIONS
    
    public func getAVAudioPCMBuffer() -> AVAudioPCMBuffer {
        return PCMBuffer
    }
    
    public func toData() -> Data {
        return PCMToData(fromPCMBuffer: PCMBuffer)
    }
    
    // should not be confused with recording (model).duration which is the cached version.
    // This is expensive so there are lots of functions that should NOT use it.
    public func getDurationExpensive() -> Double {
        return getPCMBufferDuration(buffer: PCMBuffer)
    }
    
    /// An array of doubles that are absolute values of amplitude
    /// ... of count equal to desired "resultion"
    /// eg: Buffer sent in that has 100,000 frames, resolution set to 200, result is 200 doubles.
    /// result is normalized such that peak amplitude always appears to be 1
    public func getVisualWave(resolution: Int) -> [Double] {
        
        // Bang is safe because guaranteed float format
        let channelData = PCMBuffer.floatChannelData![0]
        
        let bufferSampleCount = Int(PCMBuffer.frameLength)
        
        let steps: Int
        
        if bufferSampleCount <= resolution {
            // If we have fewer samples than (or equal to) the desired resolution,
            // then we can just map the buffer directly to the resulting wave array stepping by 1
            steps = 1
        } else {
            // If we have more samples than resolution,
            // then we need to make the step equal to:
            // the following rounded down to the nearest whole number (which happens auto due to int division)
            steps = bufferSampleCount / resolution
        }
        
        var result = [Double]()
        
        // Find the peak value (maximum amplitude) in the buffer
         var peakValue: Float = 0.0
         for i in stride(from: 0, to: bufferSampleCount, by: steps) {
             peakValue = max(peakValue, abs(channelData[i]))
         }
         
         // Normalize only if peakValue is greater than 0 to prevent division by zero
         if peakValue > 0 {
             for i in stride(from: 0, to: bufferSampleCount, by: steps) {
                 let sampleValue: Float = channelData[i]
                 let normalizedSampleValue = Double(abs(sampleValue)) / Double(peakValue) // Normalize the sample value
                 result.append(normalizedSampleValue)
             }
         }
        
        return result
    
    }
    
    // ------------------------------------------------------------------------------------------ PRIVATE UTILS
    
    
    // dangerous low level functions

    private func PCMToData(fromPCMBuffer buffer: AVAudioPCMBuffer) -> Data {
        // bang is safe because guaranteed float format
        let floatChannelData = buffer.floatChannelData!

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let samples = floatChannelData[0]
        let data = Data(bytes: samples, count: frameLength * channelCount * MemoryLayout<Float32>.size)
        
        return data
    }
    
    // assumes that trim points are valid
    private static func trimPCMBuffer(_ buffer: AVAudioPCMBuffer, from startFrameRatio: Double, to endFrameRatio: Double) -> AVAudioPCMBuffer {
        
        let startFrame = AVAudioFramePosition(Int(startFrameRatio * Double(buffer.frameLength)))
        let endFrame = AVAudioFramePosition(Int(endFrameRatio * Double(buffer.frameLength)))
    
        let framesToCopy = AVAudioFrameCount(endFrame - startFrame)
        // Bang is safe because guaranteed float format
        let segment = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: framesToCopy)!


        let sampleSize = buffer.format.streamDescription.pointee.mBytesPerFrame

        let srcPtr = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let dstPtr = UnsafeMutableAudioBufferListPointer(segment.mutableAudioBufferList)
        for (src, dst) in zip(srcPtr, dstPtr) {
            memcpy(dst.mData, src.mData?.advanced(by: Int(startFrame) * Int(sampleSize)), Int(framesToCopy) * Int(sampleSize))
        }

        segment.frameLength = framesToCopy
        return segment
    }
    
    
    private static func dataToPCM(dataSource data: Data, withFormat format: AVAudioFormat) -> AVAudioPCMBuffer {
        let channelCount:UInt32 = format.channelCount
        let frameLength:UInt32 = UInt32(data.count) / channelCount / UInt32(MemoryLayout<Float32>.size)

        // Bang is safe because format is guaranteed OK
        // Also, zero frame length is OK
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        
        buffer.frameLength = frameLength
        // Bang is safe because guaranteed float format
        let samples = buffer.floatChannelData![0]
        data.withUnsafeBytes { (floatBufferPointer: UnsafeRawBufferPointer) in
            guard let floatPointer = floatBufferPointer.baseAddress?.assumingMemoryBound(to: Float32.self) else {
                fatalError("MemoBuffer.dataToPCM: floatBufferPointer.baseAddress? is nil (pigs are flying)")
            }
            memcpy(samples, floatPointer, data.count)
        }
        
        return buffer
    }
    
    private func getPCMBufferDuration(buffer: AVAudioPCMBuffer) -> TimeInterval {
        // figure out time duration of buffer
        let sampleRate: Double = buffer.format.sampleRate
        let frames: Double = Double(buffer.frameLength)
        
        return TimeInterval(frames / sampleRate)
    }
    
    
}

