import SwiftUI
import AVFoundation

// FINISHED

struct PlayHeadOverlay: View {
    
    let currentPlaybackPoint: Double
    let lineWidthInPoints: Double
    let startTrim: Double
    let endTrim: Double

    
    var body: some View {
        
        GeometryReader { geometry in
            
            let h = geometry.size.height
            let w = geometry.size.width
            
            let playableRange = endTrim - startTrim
            let translatedPosition = startTrim + (playableRange * currentPlaybackPoint)
            
            let playBackLineOffset = (translatedPosition * w) - lineWidthInPoints/2
            
            
            Rectangle()
                .fill(Color.black)
                .frame(width: lineWidthInPoints,
                       height: h)
                .offset(x:playBackLineOffset, y:0)
            
        }
    }
    

}
