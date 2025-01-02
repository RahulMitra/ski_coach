import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        VStack(spacing: 10) {
            Text(sessionManager.calibrationStageText)
                .font(.headline)
            
            if sessionManager.isCalibrated {
                Text("Percent Down: \(sessionManager.percentDown * 100, specifier: "%.1f")%")
                    .foregroundColor(sessionManager.percentDown >= 0.1 ? .red : .primary)
                
                Button("Re-calibrate") {
                    sessionManager.sendMessageToPhone(action: "recalibrate")
                }
            } else {
                Button("Calibrate") {
                    sessionManager.sendMessageToPhone(action: "calibrateStep")
                }
            }
        }
        .padding()
    }
}

