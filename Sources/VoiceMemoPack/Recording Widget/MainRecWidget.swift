import SwiftUI
import AVFoundation
import SwiftData

/*
 TODO
    - dismiss behavior -- how to allow parent to force immediate "cancel/abort"
 */

// derp

public enum RecordingWidgetError {
    case startRecordingFailed(Error)
    case stopRecordingFailed(Error)
    case playFailed(Error)
}

let darkGray = Color.init(hue: 0, saturation: 0, brightness: 0.25)

public struct RecordingWidget<_RecParent: ProtocolForParentOfARecording>: View {
    
    public struct UIDimensionsConfig {
        var buttonSideLengthInPoints: CGFloat = 30
        var waveHeightAsPercentageOfTotalHeight: Double = 2/5
        var horizontalPaddingAsPercentageOfTotalWidth: Double = 1/10
    }
    
    public struct UIColorConfig {
        var buttonColor: Color = darkGray
        var waveViewBorderColor: Color = darkGray
        var postWaveColor: Color = .red
        var finalWaveColor: Color = darkGray
        var cropLineColor: Color = darkGray
        var cropMaskColor: Color = darkGray
        var cropMaskOpacity: Double = 0.5
        var inactiveScissorButtonOpacity:Double = 0.2
        
    }
    
    public struct UIOtherConfig {
        var waveViewBorderWidthPoints: Double = 2
        var waveResolution: Int = 800
        var cropLineWidthPoints: Double = 2
        var playHeadLineWidthPoints: Double = 2
    }
    
    public init(
        parentOfRecording: _RecParent,
        openAppSettingsForMicPermission: @escaping () -> Void,
        onError: @escaping (RecordingWidgetError) -> Void,
        customColors: UIColorConfig? = nil,
        customDimensions: UIDimensionsConfig? = nil,
        customOther: UIOtherConfig? = nil)
    {
        self.parentOfRecording = parentOfRecording
        self.openAppSettingsForMicPermission = openAppSettingsForMicPermission
        self.onError = onError
        self.colorConfig = customColors ?? UIColorConfig()
        self.dimensionsConfig = customDimensions ?? UIDimensionsConfig()
        self.otherUIConfig = customOther ?? UIOtherConfig()
    }
    
    @Environment(\.modelContext) var modelContext // insert,delete
    
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
    let onError: (RecordingWidgetError) -> Void
    
    var micIsDenied: Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
    
    let colorConfig:UIColorConfig
    let dimensionsConfig:UIDimensionsConfig
    let otherUIConfig:UIOtherConfig
    
    public var body: some View {
        GeometryReader { geometry in
            
            let waveHeightFactor = dimensionsConfig.waveHeightAsPercentageOfTotalHeight
            
            let h = geometry.size.height
            let w = geometry.size.width
            let bsp = dimensionsConfig.buttonSideLengthInPoints
            let buttonVSpace = h * (1 - waveHeightFactor)/2
            let waveVSpace = h * waveHeightFactor
            let sliderVSpace = h * (1 - waveHeightFactor)/2
            let hPad = w * dimensionsConfig.horizontalPaddingAsPercentageOfTotalWidth
            let hSpace = w - hPad*2
            
            
            if isRecording {
                RW_RecordingInProgressView(namespace: recNamespace, parentHeight: h, parentWidth: w, buttonSideLengthInPoints: bsp, recordingLevel: recorder.currentRecLevel, peakRecordingLevel: recorder.currentRecLevel, peakHoldTimeRemaining: recorder.peakHoldTimeRemaining, onStopRecordingPressed: stopRecording)
            } else if parentOfRecording.recording != nil {
                
                RW_PostAndFinalizedView(
                    namespace: recNamespace,
                    buttonColor: colorConfig.buttonColor,
                    buttonSideLengthInPoints: bsp,
                    buttonVSpace: buttonVSpace,
                    hPad: hPad,
                    sliderVSpace: sliderVSpace,
                    hSpace: hSpace, 
                    waveVSpace: waveVSpace,
                    
                    inactiveScissorButtonColor: colorConfig.buttonColor.opacity(colorConfig.inactiveScissorButtonOpacity),
                    postWaveColor: colorConfig.postWaveColor,
                    finalWaveColor: colorConfig.finalWaveColor,
                    cropMaskColor: colorConfig.cropMaskColor.opacity(colorConfig.cropMaskOpacity),
                    cropLineColor: colorConfig.cropLineColor,
                    waveViewBorderColor: colorConfig.waveViewBorderColor,
                    waveViewBorderWidth: otherUIConfig.waveViewBorderWidthPoints,
                    cropLineWidth: otherUIConfig.cropLineWidthPoints,
                    playHeadLineWidth: otherUIConfig.playHeadLineWidthPoints,
                    waveResolution: otherUIConfig.waveResolution,
                    
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
            cancelEverythingDueToLifecycleEvent()
        }
        // important to stop recording is app is backgrounded
        // (onDisappear is not triggered when this happens)
        .onChange(of: scenePhase) {
            oldValue, newValue in
            if newValue == .background {
                cancelEverythingDueToLifecycleEvent()
            }
        }
        
    }
    
    // *** STATE CHANGE : blank ->> recording
    private func startRecording() {
        
        if AVAudioApplication.shared.recordPermission == .granted {
            
            do {
                try recorder.startRecordingWithPermission()
            } catch {
                onError(.startRecordingFailed(error))
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
                        onError(.startRecordingFailed(error))
                    }
                    
                }
            }
        }
    }
    
    // *** STATE CHANGE : recording ->> recorded
    private func stopRecording() {
        do {
            let result = try recorder.stopRecordingAndReturnBuffer()
            parentOfRecording.replaceRecording(newRecording: result, modelContext: modelContext)
            withAnimation(.easeInOut (duration: 0.25)) {
                isRecording = false
            }
        } catch {
            onError(.stopRecordingFailed(error))
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
    
    /*
     Called when
        - this view disappears
        - app is backgrounded
        - todo: when parent explicity ask for it
            - presumably in cases where indisappear is insufficient due to complex screen-to-screen animations
     */

    private func cancelEverythingDueToLifecycleEvent() {
        if (isRecording) {
            recorder.stopRecordingAndDiscard()
            isRecording = false
        }
    }
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

struct RW_PostAndFinalizedView: View {
    
    // precise control over post -> final transition UI
    @State var isSwitchingFromPostToFinal = false
    
    let player = MemoPlayer.shared
    
    // ------------------------------------------- PARAMS
    let namespace: Namespace.ID // for matched geom effect
    // ui args (shared with main)
    let buttonColor:Color
    let buttonSideLengthInPoints:Double
    // ui args (shared with main and computed from main view's geo reader)
    let buttonVSpace:Double
    let hPad:Double
    let sliderVSpace:Double
    let hSpace:Double
    let waveVSpace:Double
    // ui args (not shared with main)
    let inactiveScissorButtonColor:Color
    let postWaveColor:Color
    let finalWaveColor:Color
    let cropMaskColor:Color
    let cropLineColor:Color
    let waveViewBorderColor:Color
    let waveViewBorderWidth:Double
    let cropLineWidth:Double
    let playHeadLineWidth:Double

    let waveResolution: Int

    // audio representation and bindings
    @Bindable var recording:Recording
    // Callbacks
    let onTrashPressed: () -> Void
    
    // ------------------------------------------- INTERNAL UI CONFIG

    let numButtonsInPost:CGFloat = 3
    let numButtonsInFinal:CGFloat = 2
    
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
                    AnyView(SimpleWave(audioWave: recording.getMemoBuffer(withoutTrim: true).getVisualWave(resolution: waveResolution), color: postWaveColor))
                    CropModeOverlay(startPoint: recording.trimStartPoint, endPoint: recording.trimEndPoint, cutLineColor: cropLineColor, cropColor: cropMaskColor, cropLineWidth: cropLineWidth)
                    if (player.playHeadPosition > 0) {
                        PlayHeadOverlay(currentPlaybackPoint: player.playHeadPosition, lineWidthInPoints: playHeadLineWidth, startTrim: recording.trimStartPoint, endTrim: recording.trimEndPoint)
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
                    SimpleWave(audioWave: recording.getMemoBuffer(withoutTrim: true).getVisualWave(resolution: waveResolution), color: finalWaveColor)
                    if (player.playHeadPosition > 0) {
                        PlayHeadOverlay(currentPlaybackPoint: player.playHeadPosition, lineWidthInPoints: playHeadLineWidth, startTrim: 0, endTrim: 1)
                    }
                }
                .frame(width: hSpace, height: waveVSpace)
                .border(waveViewBorderColor, width: waveViewBorderWidth)
                .offset(x:hPad,y:buttonVSpace)
            }
        }
    }
    
    
    // -------------------------------------------------------------- POST/FINAL FUNCTIONS
    
    
    
    // fire and forget function... simply plays trimmed buffer
    private func playTrimmed() {
        do {
            try player.playMemoWithPlayHeadAnimation(recording.getMemoBuffer(withoutTrim: false))
        } catch {
            // !!!
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
            // !!!
        }
    }
}






