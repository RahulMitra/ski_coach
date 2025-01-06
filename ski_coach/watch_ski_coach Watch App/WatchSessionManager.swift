//
//  WatchSessionManager.swift
//  ski_coach
//
//  Created by Rahul Mitra on 1/1/25.
//


import WatchConnectivity
import Combine

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var calibrationStageText: String = "Unknown"
    @Published var isMuted: Bool = false  // <-- Add this
    
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

    func sendMessageToPhone(action: String, extra: [String: Any] = [:]) {
        guard session.isReachable else { return }
        
        var message: [String: Any] = ["action": action]
        extra.forEach { key, value in
            message[key] = value
        }
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }


    // MARK: WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // ...
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // ...
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let stage = message["calibrationStage"] as? String {
                self.calibrationStageText = stage
            }
            // 1) Also update local isMuted from phone
            if let newIsMuted = message["isMuted"] as? Bool {
                self.isMuted = newIsMuted
            }
        }
    }
}
