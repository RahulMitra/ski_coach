//
//  MotionViewModel.swift
//  ski_coach
//
//  Created by Rahul Mitra on 1/1/25.
//

import SwiftUI
import CoreMotion
import AVFoundation

// Ensures that silent audio loops to stop app from getting suspended
final class SilentAudioManager {
    static let shared = SilentAudioManager()
    private var audioPlayer: AVAudioPlayer?

    func startSilentAudio() {
        guard let url = Bundle.main.url(forResource: "1-second-of-silence", withExtension: "mp3") else {
            return
        }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1 // Loop forever
            audioPlayer.volume = 0.01     // Very quiet
            audioPlayer.play()
            self.audioPlayer = audioPlayer
        } catch {
            print("Error loading/playing silent audio: \(error)")
        }
    }

    func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}


class MotionViewModel: ObservableObject {
    // MARK: - Motion Managers
    private let phoneMotionManager = CMMotionManager()
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    
    // MARK: - Audio for beep
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isMuted: Bool = false

    // MARK: - Published: Current iPhone Orientation
    @Published var phonePitch: Double = 0.0
    @Published var phoneRoll:  Double = 0.0
    @Published var phoneYaw:   Double = 0.0
    
    // MARK: - Published: Current AirPods Orientation
    @Published var airpodsPitch: Double? = nil
    @Published var airpodsRoll:  Double? = nil
    @Published var airpodsYaw:   Double? = nil
    
    // MARK: - Whether AirPods motion is active
    @Published var isAirpodsMotionActive: Bool = false {
        didSet {
            if !isAirpodsMotionActive {
                clearAirpodsData()
            }
        }
    }
    
    // MARK: - Calibration
    enum CalibrationStage {
        case notStarted
        case captureNeutral
        case captureDown
        case done
    }
    
    @Published var stage: CalibrationStage = .notStarted

    private var neutralPitch: Double?
    private var headDownPitch: Double?
    
    var calibrationStageText: String {
        switch stage {
        case .notStarted:     return "Not Started"
        case .captureNeutral: return "Neutral Head"
        case .captureDown:    return "Head Down"
        case .done:           return "Calibrated"
        }
    }
    
    var buttonTitle: String {
        switch stage {
        case .notStarted:     return "Calibrate"
        case .captureNeutral: return "Calibrate Neutral"
        case .captureDown:    return "Calibrate Head Down"
        case .done:           return "Calibrated"
        }
    }
    
    var isCalibrated: Bool {
        return stage == .done
    }
    
    @Published var percentDown: Double = 0.0
    
    // MARK: - Timer for continuous beeping
    private var beepTimer: DispatchSourceTimer?
    private let beepInterval = 0.75
    
    // MARK: - Timer to poll headphone connection
    private var connectionStatusTimer: DispatchSourceTimer?
    
    // MARK: - Init
    init() {
        // Preload beep sound
        if let url = Bundle.main.url(forResource: "look_up", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Error loading beep sound: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Start/Stop Updates
    func startUpdates() {
        startPhoneMotionUpdates()
        startAirPodsMotionUpdates()

        // Poll connection status every 1 second
        connectionStatusTimer?.cancel()
        connectionStatusTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        connectionStatusTimer?.schedule(deadline: .now(), repeating: 1.0)
        connectionStatusTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let isConnected = self.headphoneMotionManager.isDeviceMotionAvailable
                && self.headphoneMotionManager.isDeviceMotionActive

            DispatchQueue.main.async {
                if self.isAirpodsMotionActive != isConnected {
                    self.isAirpodsMotionActive = isConnected
                    if !isConnected {
                        self.clearAirpodsData()
                    }
                }
            }
        }
        connectionStatusTimer?.resume()
    }

    func stopUpdates() {
        phoneMotionManager.stopDeviceMotionUpdates()
        headphoneMotionManager.stopDeviceMotionUpdates()
        stopBeeping()
        connectionStatusTimer?.cancel()
        connectionStatusTimer = nil
    }
    
    // MARK: - Handle Calibration
    func handleCalibrationButtonPress() {
        switch stage {
        case .notStarted:
            stage = .captureNeutral
        case .captureNeutral:
            neutralPitch = airpodsPitch ?? 0.0
            stage = .captureDown
        case .captureDown:
            headDownPitch = airpodsPitch ?? 0.0
            stage = .done
        case .done:
            break
        }
    }
    
    func recalibrate() {
        stage = .notStarted
        neutralPitch = nil
        headDownPitch = nil
        percentDown = 0.0
        stopBeeping()
    }
    
    private func startPhoneMotionUpdates() {
        guard phoneMotionManager.isDeviceMotionAvailable else {
            print("iPhone motion data not available.")
            return
        }
        
        let motionQueue = OperationQueue()
        phoneMotionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        phoneMotionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDegrees = motion.attitude.pitch * (180.0 / .pi)
            let rollDegrees  = motion.attitude.roll  * (180.0 / .pi)
            let yawDegrees   = motion.attitude.yaw   * (180.0 / .pi)
            
            DispatchQueue.main.async {
                self.phonePitch = pitchDegrees
                self.phoneRoll  = rollDegrees
                self.phoneYaw   = yawDegrees
            }
        }
    }

    private func startAirPodsMotionUpdates() {
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            DispatchQueue.main.async {
                self.isAirpodsMotionActive = false
            }
            print("AirPods motion data not available or unsupported model.")
            return
        }
        
        let motionQueue = OperationQueue()
        headphoneMotionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("AirPods motion error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isAirpodsMotionActive = false
                }
                return
            }
            
            guard let motion = motion else {
                DispatchQueue.main.async {
                    self.isAirpodsMotionActive = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isAirpodsMotionActive = true
                self.airpodsPitch = motion.attitude.pitch * (180.0 / .pi)
                self.airpodsRoll = motion.attitude.roll * (180.0 / .pi)
                self.airpodsYaw = motion.attitude.yaw * (180.0 / .pi)
                
                self.updatePercentDownAndCheckBeep()
            }
        }
    }

    // MARK: - Clear AirPods Data
    private func clearAirpodsData() {
        airpodsPitch = nil
        airpodsRoll = nil
        airpodsYaw = nil
    }
    
    // MARK: - Compute "percent down" and beep
    private func updatePercentDownAndCheckBeep() {
        guard let neutral = neutralPitch, let down = headDownPitch else { return }
        
        let range = down - neutral
        guard abs(range) > 1e-6 else {
            percentDown = 0.0
            stopBeeping()
            return
        }
        
        let current = airpodsPitch ?? 0.0
        let fraction = (current - neutral) / range
        percentDown = fraction
        
        if fraction >= 0.1 && !isMuted {
            startBeeping()
        } else {
            stopBeeping()
        }
    }
    
    // MARK: - Continuous Beep
    private func startBeeping() {
        guard beepTimer == nil else { return }
        
        beepTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        beepTimer?.schedule(deadline: .now(), repeating: beepInterval)
        beepTimer?.setEventHandler { [weak self] in
            self?.playBeep()
        }
        beepTimer?.resume()
    }
    
    private func stopBeeping() {
        beepTimer?.cancel()
        beepTimer = nil
    }
    
    private func playBeep() {
        DispatchQueue.global(qos: .background).async {
            self.audioPlayer?.stop()
            self.audioPlayer?.currentTime = 0
            self.audioPlayer?.play()
        }
    }
}
