//
//  WatchConnectivityManager.swift
//  ski_coach
//
//  Created by Rahul Mitra on 1/1/25.
//


import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    // Link to your motion view model
    var motionViewModel: MotionViewModel? {
        didSet { 
            // Subscribe to changes (so we can send updates to the watch)
            subscribeToViewModel()
        }
    }
    
    private let session = WCSession.default
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // Subscribe to MotionViewModel so that whenever it changes,
    // we can send the new calibration state to the watch.
    private func subscribeToViewModel() {
        guard let motionViewModel = motionViewModel else { return }
        
        // Example: whenever percentDown changes, push an update
        motionViewModel.$percentDown
            .sink { [weak self] _ in
                self?.sendMotionUpdateToWatch()
            }
            .store(in: &cancellables)
        
        // Also whenever the calibration stage might change, we push an update
        // In practice, you might watch for specific properties or just send periodically
        // for demonstration, let's do phonePitch as a trigger too
        motionViewModel.$phonePitch
            .sink { [weak self] _ in
                self?.sendMotionUpdateToWatch()
            }
            .store(in: &cancellables)
    }
    
    private func sendMotionUpdateToWatch() {
        guard session.isReachable,
              let motionViewModel = motionViewModel else { return }
        
        let message: [String: Any] = [
            "calibrationStage": motionViewModel.calibrationStageText,
            "percentDown": motionViewModel.percentDown
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Handle activation if needed
    }
    
    // iOS only
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }
    
    // Listen for watch messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            guard let motionVM = self.motionViewModel,
                  let action = message["action"] as? String else { return }
            
            switch action {
            case "calibrateStep":
                motionVM.handleCalibrationButtonPress()
            case "recalibrate":
                motionVM.recalibrate()
            default:
                break
            }
            
            // After changing the calibration, send back an updated status
            self.sendMotionUpdateToWatch()
        }
    }
}
