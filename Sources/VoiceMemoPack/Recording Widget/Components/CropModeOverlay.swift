import SwiftUI
import AVFoundation

// FINISHED

struct CropModeOverlay: View {
    
    let startPoint: Double
    let endPoint: Double
    let cutLineColor: Color
    let cropColor: Color
    let cropLineWidth: CGFloat
    
    var body: some View {
        
        GeometryReader { geometry in
    
            let h = geometry.size.height
            let w = geometry.size.width
            
            let overlayWidthLeft = CGFloat(startPoint) * w
            let overlayWidthRight = w - (w * CGFloat(endPoint))
            let overlayOffsetRight = CGFloat(endPoint) * w
            
            
            Rectangle()
                .fill(cropColor) // Semi-transparent fill
                .frame(width: overlayWidthLeft,
                       height: h)
                .offset(x:0, y:0)
            
            Rectangle()
                .fill(cropColor) // Semi-transparent fill
                .frame(width: overlayWidthRight,
                       height: h)
                .offset(x:overlayOffsetRight, y:0)
            
            
            
            
            if (startPoint > 0) {
                // Left cut line
                Path { path in
                    path.move(to: CGPoint(x: overlayWidthLeft, y: 0))
                    path.addLine(to: CGPoint(x: overlayWidthLeft, y: h))
                }
                .stroke(style: StrokeStyle(lineWidth: cropLineWidth, dash: [5]))
                .foregroundColor(cutLineColor)
                .alignmentGuide(.leading) { _ in overlayWidthLeft / 2 }
            }
            
            if (endPoint < 1) {
                
                // Right cut line
                Path { path in
                    path.move(to: CGPoint(x: overlayOffsetRight, y: 0))
                    path.addLine(to: CGPoint(x: overlayOffsetRight, y: h))
                }
                .stroke(style: StrokeStyle(lineWidth: cropLineWidth, dash: [5]))
                .foregroundColor(cutLineColor)
                .alignmentGuide(.leading) { _ in overlayOffsetRight / 2 }
            }
        }
        
        /*
         
         if shouldDrawCutLines {
         // Left cut line
         .overlay(
         Path { path in
         path.move(to: CGPoint(x: overlayWidthLeft, y: 0))
         path.addLine(to: CGPoint(x: overlayWidthLeft, y: h))
         }
         .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
         .foregroundColor(.red),
         alignment: .leading
         )
         // Right cut line
         .overlay(
         Path { path in
         path.move(to: CGPoint(x: overlayOffsetRight, y: 0))
         path.addLine(to: CGPoint(x: overlayOffsetRight, y: h))
         }
         .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
         .foregroundColor(.red),
         alignment: .leading
         )
         } */
        
        
    }
}





