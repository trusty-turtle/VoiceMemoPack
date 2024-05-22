import SwiftUI
import AVFoundation

/// FINISHED
/// The pure wave view that only shows the full wave data of the pcm buffer
///

struct SimpleWave: View {
    
    let audioWave:[Double]
    let color:Color

    var body: some View {
        Canvas { context, size in
            let lineWidth = 1.0 // CGFloat(audioWave.count)
            // Draw the waveform here using `context`
            let path = myCreateWaveformPath(audioWave: audioWave, size: size)
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
    

    
    private func myCreateWaveformPath(audioWave: [Double], size: CGSize) -> Path {
        
        let w = size.width
        let h = size.height
        let halfHeight = h / 2
        let numSamples = audioWave.count

        let horizontalSpacingSize: CGFloat = w / CGFloat(numSamples)
    
        var path = Path()
        for i in stride(from: 0, to: numSamples, by: 1) {
            
            let sampleValue = audioWave[i]
            
            let sampleLineHalfHeight = h * sampleValue/2
            
            let x = CGFloat(i)*horizontalSpacingSize + horizontalSpacingSize/2
            // Draw a line for each sample
            path.move(to: CGPoint(x: x, y: halfHeight - sampleLineHalfHeight))
            path.addLine(to: CGPoint(x: x, y: halfHeight + sampleLineHalfHeight))
            
           
        }
        return path

    }


}



