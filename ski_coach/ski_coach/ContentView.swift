import SwiftUI

struct ContentView: View {
    @EnvironmentObject var motionVM: MotionViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Relative Orientation (iPhone vs. AirPods)")
                .font(.title2)
                .padding(.top, 40)
            
            // MARK: - Current Orientation: iPhone
            VStack(spacing: 5) {
                Text("iPhone Pitch: \(motionVM.phonePitch, specifier: "%.2f")°")
                Text("iPhone Roll:  \(motionVM.phoneRoll, specifier: "%.2f")°")
                Text("iPhone Yaw:   \(motionVM.phoneYaw, specifier: "%.2f")°")
            }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            
            // MARK: - AirPods
            VStack(spacing: 5) {
                if motionVM.isAirpodsMotionActive,
                   let pitch = motionVM.airpodsPitch,
                   let roll = motionVM.airpodsRoll,
                   let yaw = motionVM.airpodsYaw {
                    Text("AirPods Pitch: \(pitch, specifier: "%.2f")°")
                    Text("AirPods Roll:  \(roll, specifier: "%.2f")°")
                    Text("AirPods Yaw:   \(yaw, specifier: "%.2f")°")
                } else {
                    Text("AirPods motion not detected")
                        .foregroundColor(.red)
                }
            }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            
            Divider().padding(.vertical, 10)
            
            // MARK: - Calibration Status (read-only)
            Text("Calibration Status: \(motionVM.calibrationStageText)")
                .font(.headline)
            
            // If we are calibrated, show “Percent Down"
            if motionVM.isCalibrated {
                Text("Percent Down: \(motionVM.percentDown * 100, specifier: "%.1f")%")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(motionVM.percentDown >= 0.1 ? .red : .primary)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            motionVM.startUpdates()
        }
        .onDisappear {
            motionVM.stopUpdates()
        }
    }
}
