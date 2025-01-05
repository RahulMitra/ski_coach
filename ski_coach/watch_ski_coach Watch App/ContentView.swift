import SwiftUI

struct SlideToConfirmView: View {
    /// Action to perform when the slider has passed the threshold
    var onConfirmed: () -> Void
    
    /// The current horizontal offset of the knob
    @State private var knobOffset: CGFloat = 0
    
    /// The total width of the track
    @State private var totalWidth: CGFloat = 0
    
    /// Threshold percentage (e.g., 0.8 means 80% of the width)
    private let confirmThreshold: CGFloat = 0.8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 1) Background track
                Capsule()
                    .foregroundColor(.gray.opacity(0.2))
                
                // 2) “Knob” or “Thumb”
                //    We'll make it a circle that can be dragged
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: geometry.size.height, height: geometry.size.height)
                    .offset(x: knobOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Make sure we don't drag outside the track
                                let newOffset = min(max(0, value.translation.width), geometry.size.width - geometry.size.height)
                                knobOffset = newOffset
                            }
                            .onEnded { _ in
                                // If we've passed the threshold, confirm the action
                                if knobOffset > (geometry.size.width - geometry.size.height) * confirmThreshold {
                                    onConfirmed()
                                }
                                // Reset
                                withAnimation {
                                    knobOffset = 0
                                }
                            }
                    )
            }
            // Store total width so we can adjust if needed
            .onAppear {
                totalWidth = geometry.size.width
            }
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    // Tracks how far the user has slid. Resets after hitting threshold.
    @State private var recalibrateSliderValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 10) {
            Text(sessionManager.calibrationStageText)
                .font(.headline)
            
            if sessionManager.isCalibrated {                
                Text("Slide to Re-Calibrate")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Our new SlideToConfirmView
                SlideToConfirmView {
                    // This closure executes after the user slides past threshold
                    sessionManager.sendMessageToPhone(action: "recalibrate")
                }
                .frame(height: 30) // Adjust height to taste
                .padding(.horizontal, 10)
                
                
            } else {
                // If not calibrated yet, keep the "Next Step" button
                Text("Slide to Calibrate")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                SlideToConfirmView {
                    // This closure executes when the slider passes the threshold
                    sessionManager.sendMessageToPhone(action: "calibrateStep")
                }
                .frame(height: 30)
                .padding(.horizontal, 10)
            }
        }
    }
}
