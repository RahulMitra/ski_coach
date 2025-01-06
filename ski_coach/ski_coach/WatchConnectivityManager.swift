//
//  WatchConnectivityManager.swift
//  ski_coach
//
//  Created by Rahul Mitra on 1/1/25.
//


import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    var motionViewModel: MotionViewModel? {
        didSet {
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
    
    private func subscribeToViewModel() {
        guard let motionViewModel = motionViewModel else { return }
        
        // Whenever calibration stage changes, send that update
        motionViewModel.$stage
            .sink { [weak self] _ in
                self?.sendStateToWatch()
            }
            .store(in: &cancellables)

        // 1) Also watch for changes in the isMuted property
        motionViewModel.$isMuted
            .sink { [weak self] _ in
                self?.sendStateToWatch()
            }
            .store(in: &cancellables)
    }

    // 2) Send the current calibration stage & mute status
    private func sendStateToWatch() {
        guard session.isReachable,
              let motionViewModel = motionViewModel
        else { return }
        
        let message: [String: Any] = [
            "calibrationStage": motionViewModel.calibrationStageText,
            "isMuted": motionViewModel.isMuted
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

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }

    // iPhone receiving messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            guard let motionVM = self.motionViewModel,
                  let action = message["action"] as? String
            else { return }

            switch action {
            case "calibrateStep":
                motionVM.handleCalibrationButtonPress()
            case "recalibrate":
                motionVM.recalibrate()
            case "setMute":
                // 1) Extract the new boolean value from the message
                if let newValue = message["isMutedValue"] as? Bool {
                    // 2) Just SET it (don't toggle)
                    motionVM.isMuted = newValue
                }
            default:
                break
            }
            
            // Always send updated state back after an action
            self.sendStateToWatch()
        }
    }

}
