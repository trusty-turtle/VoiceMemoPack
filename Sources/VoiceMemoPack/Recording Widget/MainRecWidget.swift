import SwiftUI
import AVFoundation
import SwiftData

// This is a test note!!

// TODO: tidy this color issue up
let darkGray = Color.gray

public protocol ProtocolForParentOfARecording: Observable, AnyObject {
    associatedtype _Rec: ProtocolForARecording
    
    var recording: _Rec? { get set }
    
    func deleteRecording(modelContext: ModelContext)
    func replaceRecording(newRecording: MemoBuffer, modelContext: ModelContext)
    
}

public protocol ProtocolForARecording: Observable, AnyObject {
    //init()
    var duration: Double { get }
    var trimStartPoint: Double { get set }
    var trimEndPoint: Double { get set }
    var isFinalized:Bool { get }
    func getMemoBuffer(withoutTrim: Bool) -> MemoBuffer
    func finalizeTrim()
    
}

public struct RecordingWidget<_RecParent: ProtocolForParentOfARecording>: View {
    
    //public init() {}
    
    public init(parentOfRecording: _RecParent, openAppSettingsForMicPermission: @escaping () -> Void, buttonSideLengthInPoints: CGFloat, buttonColor: Color, postWaveColor: Color, finalWaveColor: Color) {
        self.parentOfRecording = parentOfRecording
        self.openAppSettingsForMicPermission = openAppSettingsForMicPermission
        self.buttonSideLengthInPoints = buttonSideLengthInPoints
        self.buttonColor = buttonColor
        self.postWaveColor = postWaveColor
        self.finalWaveColor = finalWaveColor
    }
    
    @Environment(\.modelContext) var modelContext // insert,delete
    // ------------------------------------------------- BOILERPLATE
    
    // for replacing onDisappear due to screen transition delay (????? (old note))
    // @Environment(NavigationTarget.self) var navController
    @Environment(\.scenePhase) var scenePhase
    
    // for matched geom effect
    @Namespace var recNamespace
    
    // ------------------------------------------------- STATE
    
    @State private var isRecording = false
    
    // ------------------------------------------------- SINGLETONS
    let recorder = MemoRecorder.shared
    let player = MemoPlayer.shared
    
    // ------------------------------------------------- PARAMS
    
    let parentOfRecording: _RecParent
    
    // Injected Functions
    let openAppSettingsForMicPermission: () -> Void
    
    // UI
    let buttonSideLengthInPoints:CGFloat
    let buttonColor:Color
    let postWaveColor:Color
    let finalWaveColor:Color
    
    var micIsDenied: Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
    
    // ------------------------------------------------- CONFIG
    let waveResolution = 800
    
    public var body: some View { GeometryReader { geometry in
        
        
        let h = geometry.size.height
        let w = geometry.size.width
        let bsp = buttonSideLengthInPoints
        // all layout should be definable using the following vars -- not changing values in the view code
        let buttonVSpace = h*1.5/5
        let waveVSpace = h*2/5
        let sliderVSpace = h*1.5/5
        let hPad = w/10
        let hSpace = w - hPad*2
        
        
        if isRecording {
            RW_RecordingInProgressView(namespace: recNamespace, parentHeight: h, parentWidth: w, buttonSideLengthInPoints: bsp, recordingLevel: recorder.currentRecLevel, peakRecordingLevel: recorder.currentRecLevel, peakHoldTimeRemaining: recorder.peakHoldTimeRemaining, onStopRecordingPressed: stopRecording)
        } else if parentOfRecording.recording != nil {
            //@Bindable var recording = parentOfRecording.recording!
            //let memoBuffer = recording.getMemoBuffer(withoutTrim: true)
            /*
             // ------------------------------------------- PARAMS
             let namespace: Namespace.ID // for matched geom effect
             let buttonColor:Color
             // inherited geometry
             let buttonSideLengthInPoints:CGFloat
             let buttonVSpace:Double
             let hPad:Double
             let sliderVSpace:Double
             let hSpace:Double
             let waveVSpace:Double
             // audio representation and bindings
             let audioWave:[Double]
             let playHeadPosition:Double
             let recordingIsFinalized:Bool
             @Binding var trimStart:Double
             @Binding var trimEnd:Double
             // Callbacks
             let onPlayPressed: () -> Void
             let onTrashPressed: () -> Void
             let onTrimGestureBegan: () -> Void
             let onTrimGestureEnded: () -> Void
             let onFinalizeTrimPressed: () -> Void
             */
            
            RW_PostAndFinalizedView(
                namespace: recNamespace,
                buttonColor: buttonColor,
                buttonSideLengthInPoints: bsp,
                buttonVSpace: buttonVSpace,
                hPad: hPad,
                sliderVSpace: sliderVSpace,
                hSpace: hSpace, waveVSpace: waveVSpace,
                playHeadPosition: player.playHeadPosition,
                recording: parentOfRecording.recording!,
                onTrashPressed: trashPressed
            )
            
        } else {
            // STATE = blank
            RW_BlankView(namespace: recNamespace, parentHeight: h, parentWidth: w, buttonSideLengthInPoints: bsp, micIsDenied: micIsDenied, onBrokenMicPressed: openAppSettingsForMicPermission, onStartRecordingPressed: startRecording)
        }
    }
        // important to stop recording when this view disappears
    .onDisappear() {
        onDismiss()
    }
        // important to stop recording is app is backgrounded
        // (onDisappear is not triggered when this happens)
    .onChange(of: scenePhase) {
        oldValue, newValue in
        if newValue == .background {
            onDismiss()
        }
    }
        
    }
    
    // *** STATE CHANGE : blank ->> recording
    private func startRecording() {
        
        if AVAudioApplication.shared.recordPermission == .granted {
            
            do {
                try recorder.startRecordingWithPermission()
            } catch {
                print("we are here")
                print(error)
                fatalError()
            }
            
            
            withAnimation(.easeInOut (duration: 0.25)) {
                isRecording = true
            }
            
            return
        }
        
        Task {
            // Request permission to record.
            if await AVAudioApplication.requestRecordPermission() {
                // The user grants access. Present recording interface.
                DispatchQueue.main.async {
                    
                    do { try recorder.startRecordingWithPermission()
                        withAnimation(.easeInOut (duration: 0.25)) {
                            isRecording = true
                        }
                    } catch {
                        fatalError()
                    }
                
                }
            }
        }
    }
    
    // !!! improve error handling here
    // *** STATE CHANGE : recording ->> recorded
    private func stopRecording() {
        do {
            let result = try recorder.stopRecordingAndReturnBuffer()
            parentOfRecording.replaceRecording(newRecording: result, modelContext: modelContext)
            withAnimation(.easeInOut (duration: 0.25)) {
                isRecording = false
            }
        } catch {
            print(error)
            fatalError()
        }
        
        
    }
    
    // *** STATE CHANGE : recorded ->> blank
    private func trashPressed() {
        // removed ex.recording == nil check because:
        // - we are checking it in Exercise.deleteRecording anyway
        // - it should be inherently impossible anyway
        player.stop()
        withAnimation(.easeInOut (duration: 0.25)) {
            player.stop()
            parentOfRecording.deleteRecording(modelContext: modelContext)
        }
        
    }
    
    
    // ----------------------------------------------------------- lifecycle and edge case internal calls
    
    // do we need to cancel earlier (immediately when back is pressed?)
    // in order to avoid stale state in main?
    /*
     // BEGIN OLD NOTE:
     // called when
     // - parent (edit screen) uses nav controller to pop back to main
     //      - necessary because onDisappear does not get called until after view transition
     //        (slide animation back to main screen) is complete
     // - app goes to background (experimental)
     //
     */
    private func onDismiss() {
        if (isRecording) {
            recorder.stopRecordingAndDiscard()
            isRecording = false
        }
        
        
    }
    
    /*
     private func openAppSettings() {
     DispatchQueue.main.async {
     guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
     return
     }
     
     UIApplication.shared.open(url, options: [:], completionHandler: nil)
     }
     }*/
    
}


struct RW_BlankView: View {
    
    // for matched geom effect
    let namespace: Namespace.ID
    
    let parentHeight:Double
    let parentWidth:Double
    let buttonSideLengthInPoints:Double
    let micIsDenied: Bool
    // Callbacks
    let onBrokenMicPressed: () -> Void
    let onStartRecordingPressed: () -> Void
    
    var body: some View {
        let h = parentHeight
        let w = parentWidth
        let bsp = buttonSideLengthInPoints
        let stopButtonSide = bsp*2
        Group {
            // show problem logo is mic permission denied
            if micIsDenied {
                Button(action: onBrokenMicPressed) {
                    Image(systemName: "exclamationmark.transmission").resizable()
                }
            } else {
                Button(action: onStartRecordingPressed) {
                    Image(systemName: "mic.circle.fill").resizable()
                }
            }
        }
        .aspectRatio(contentMode: .fit)
        .foregroundColor(Color.red)
        .matchedGeometryEffect(id: "recStopPlay", in: namespace)
        .frame(width: bsp*2, height: bsp*2)
        .offset(x:w/2 - stopButtonSide/2, y: h/2 - stopButtonSide/2)
    }
}



struct RW_RecordingInProgressView: View {
    
    // ---------------------------------- ARGS
    // for matched geom effect
    let namespace: Namespace.ID
    let parentHeight:Double
    let parentWidth:Double
    let buttonSideLengthInPoints:CGFloat
    
    // Published vars from Recorder
    let recordingLevel:Double // value from 0 to 1
    let peakRecordingLevel:Double // value from 0 to 1
    let peakHoldTimeRemaining:Double // value from 0 to 1
    
    // Callbacks
    let onStopRecordingPressed: () -> Void
    
    // ---------------------------------- UI CONFIG
    let meterRingLineWidth:CGFloat = 2
    let peakRingLineWidth:CGFloat = 4
    let playHeadLineWidth:CGFloat = 2
    
    var body: some View {
        let h = parentHeight
        let w = parentWidth
        let bsp = buttonSideLengthInPoints
        let stopButtonSide = bsp*2
        let recButtonSide = bsp*2
        
        let meterRingDiameter = stopButtonSide + (min(h,w) - stopButtonSide) * recordingLevel
        let peakRingDiameter = stopButtonSide + (min(h,w) - stopButtonSide) * peakRecordingLevel
        Button(action: onStopRecordingPressed) {
            Image(systemName: "stop.circle.fill").resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Color.red)
                .matchedGeometryEffect(id: "recStopPlay", in: namespace)
                .frame(width: stopButtonSide, height: stopButtonSide)
        }
        .offset(x:w/2 - recButtonSide/2, y: h/2 - recButtonSide/2)
        // Ring
        Circle()
            .stroke(Color.red, lineWidth: meterRingLineWidth)
            .frame(width: meterRingDiameter, height: meterRingDiameter)
            .offset(x:w/2 - meterRingDiameter/2, y: h/2 - meterRingDiameter/2)
        Circle()
            .stroke(Color.red, lineWidth: peakRingLineWidth)
            .frame(width: peakRingDiameter, height: peakRingDiameter)
            .offset(x:w/2 - peakRingDiameter/2, y: h/2 - peakRingDiameter/2)
            .opacity(peakHoldTimeRemaining)
    }
    
    
}


struct RW_PostAndFinalizedView<AnnoyingRequirement2: ProtocolForARecording>: View {
    
    // precise control over post -> final transition UI
    @State var isSwitchingFromPostToFinal = false
    
    let player = MemoPlayer.shared
    
    // ------------------------------------------- PARAMS
    let namespace: Namespace.ID // for matched geom effect
    let buttonColor:Color
    // inherited geometry
    let buttonSideLengthInPoints:CGFloat
    let buttonVSpace:Double
    let hPad:Double
    let sliderVSpace:Double
    let hSpace:Double
    let waveVSpace:Double
    // audio representation and bindings
    let playHeadPosition:Double
    @Bindable var recording:AnnoyingRequirement2
    // Callbacks
    let onTrashPressed: () -> Void
    
    // ------------------------------------------- UI CONFIG
    // POST
    let numButtonsInPost:CGFloat = 3
    let inactiveScissorButtonColor = Color.gray.opacity(0.25)
    let cropLineWidth:CGFloat = 2
    let cropOverlayColor = Color.gray.opacity(0.5)
    let cropCutLineColor = darkGray
    let recordedWaveColor = Color.red
    // FINAL
    let numButtonsInFinal:CGFloat = 2
    let finalizedWaveColor = darkGray
    // POST & FINAL
    let playHeadLineWidth:CGFloat = 2
    let waveViewBorderWidth:CGFloat = 2
    let waveViewBorderColor = darkGray
    let waveResolution = 800
    
    var body: some View {
        let bsp = buttonSideLengthInPoints
        // -------- POST
        Group{
            if !recording.isFinalized {
                
                let scissorsAreActive = (recording.trimStartPoint != 0 || recording.trimEndPoint != 1)
                
                if (!isSwitchingFromPostToFinal) {
                    RangeSlider_NEW(lowerValue: $recording.trimStartPoint, upperValue: $recording.trimEndPoint, mainColor: darkGray, thumbSideSize: bsp, trackHeight: 4, performOnEnd: playTrimmed, onDragBegan: player.stop)
                        .frame(width: hSpace + bsp, height: sliderVSpace)
                        .offset(x:hPad-bsp/2,y:buttonVSpace + waveVSpace)
                    
                }
                
                Button(action: playPressed) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(buttonColor)
                        .matchedGeometryEffect(id: "recStopPlay", in: namespace)
                        .frame(width:bsp, height: bsp)
                }
                .offset(x:hSpace/numButtonsInPost/2 - bsp/2 + hPad, y: buttonVSpace/2 - bsp/2)
                
                Button(action: { if (scissorsAreActive) {finalizeTrimPressed()}} ) {
                    Image(systemName: "scissors.circle.fill").resizable()
                        .foregroundColor(scissorsAreActive ? buttonColor : inactiveScissorButtonColor)
                        .frame(width: bsp, height: bsp)
                }
                .offset(x:(3 * (hSpace/numButtonsInPost/2) - bsp/2) + hPad, y: buttonVSpace/2 - bsp/2)
                .disabled(scissorsAreActive ? false : true)
                
                Button(action: onTrashPressed) {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(buttonColor)
                        .matchedGeometryEffect(id: "trash", in: namespace)
                        .frame(width: bsp, height: bsp)
                }
                .offset(x:(5 * (hSpace/numButtonsInPost/2) - bsp/2) + hPad, y: buttonVSpace/2 - bsp/2)
                
                ZStack{
                    isSwitchingFromPostToFinal ? AnyView(Rectangle().fill(Color.white)) :
                    AnyView(SimpleWave(audioWave: recording.getMemoBuffer(withoutTrim: true).getVisualWave(resolution: waveResolution), color: recordedWaveColor))
                    CropModeOverlay(startPoint: recording.trimStartPoint, endPoint: recording.trimEndPoint, cutLineColor: cropCutLineColor, cropColor: cropOverlayColor, cropLineWidth: cropLineWidth)
                    if (playHeadPosition > 0) {
                        PlayHeadOverlay(currentPlaybackPoint: playHeadPosition, lineWidthInPoints: playHeadLineWidth, startTrim: recording.trimStartPoint, endTrim: recording.trimEndPoint)
                    }
                }
                .frame(width: hSpace, height: waveVSpace)
                .border(waveViewBorderColor, width: waveViewBorderWidth)
                .offset(x:hPad,y:buttonVSpace)
                
            }
            // ------ FINALIZED
            else {
                Button(action: playPressed) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(buttonColor)
                        .matchedGeometryEffect(id: "recStopPlay", in: namespace)
                        .frame(width:bsp, height: bsp)
                }
                .offset(x:(hSpace/numButtonsInFinal/2 - bsp/2) + hPad, y: buttonVSpace/2 - bsp/2)
                
                Button(action: onTrashPressed) {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(buttonColor)
                        .matchedGeometryEffect(id: "trash", in: namespace)
                        .frame(width: bsp, height: bsp)
                }
                .offset(x: (3 * (hSpace/numButtonsInFinal/2) - bsp/2) + hPad, y: buttonVSpace/2 - bsp/2)
                ZStack{
                    SimpleWave(audioWave: recording.getMemoBuffer(withoutTrim: true).getVisualWave(resolution: waveResolution), color: finalizedWaveColor)
                    if (playHeadPosition > 0) {
                        PlayHeadOverlay(currentPlaybackPoint: playHeadPosition, lineWidthInPoints: playHeadLineWidth, startTrim: 0, endTrim: 1)
                    }
                }
                .frame(width: hSpace, height: waveVSpace)
                .border(waveViewBorderColor, width: waveViewBorderWidth)
                .offset(x:hPad,y:buttonVSpace)
            }
        }
    }
    
    
    // ------------------------------------------------------------------------------------------------------------------
    
    
    
    // fire and forget function... simply plays trimmed buffer
    private func playTrimmed() {
        do {
            try player.playMemoWithPlayHeadAnimation(recording.getMemoBuffer(withoutTrim: false))
        } catch {
            //
        }
    }
    
    private func finalizeTrimPressed() {
        isSwitchingFromPostToFinal = true
        player.stop()
        withAnimation(.easeInOut (duration: 0.45)) {
            recording.finalizeTrim()
            isSwitchingFromPostToFinal = false
        }
        
    }
    
    
    private func playPressed() {
        do {
            try player.playMemoWithPlayHeadAnimation(recording.getMemoBuffer(withoutTrim: false))
        } catch {
            //
        }
    }
}




