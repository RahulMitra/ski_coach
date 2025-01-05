//
//  WatchSessionManager.swift
//  ski_coach
//
//  Created by Rahul Mitra on 1/1/25.
//


import WatchConnectivity
import Combine

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    // State to display in the watch UI
    @Published var calibrationStageText: String = "Unknown"
    
    // Derived from calibrationStageText
    var isCalibrated: Bool {
        calibrationStageText == "Calibrated"
    }
    
    private let session = WCSession.default
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // Send an action to iPhone (e.g., "calibrateStep" or "recalibrate")
    func sendMessageToPhone(action: String) {
        guard session.isReachable else { return }
        session.sendMessage(["action": action], replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Handle errors or do additional setup
    }
    
    // watchOS only
    func sessionReachabilityDidChange(_ session: WCSession) {
        // Could update UI if phone becomes unreachable, etc.
    }
    
    // Called when iPhone sends us updated calibration data
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let stage = message["calibrationStage"] as? String {
                self.calibrationStageText = stage
            }
        }
    }
}
