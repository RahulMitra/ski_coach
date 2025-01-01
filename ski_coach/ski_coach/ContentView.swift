import SwiftUI
import CoreMotion
import AVFoundation

// MARK: - Main View
struct ContentView: View {
    @StateObject private var motionVM = MotionViewModel()
    
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
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                }
            }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            
            Divider().padding(.vertical, 10)
            
            // MARK: - Calibration Status
            Text("Calibration Status: \(motionVM.calibrationStageText)")
                .font(.headline)
            
            // MARK: - If we are calibrated, show "percent down"
            if motionVM.isCalibrated {
                Text("Percent Down: \(motionVM.percentDown * 100, specifier: "%.1f")%")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(motionVM.percentDown >= 0.1 ? .red : .primary)
            }
            
            // MARK: - Calibration / Recalibration Buttons
            if motionVM.isCalibrated {
                Button("Re-calibrate") {
                    motionVM.recalibrate()
                }
                .padding()
                .font(.headline)
                .foregroundColor(.white)
                .background(Color.blue.cornerRadius(8))
                .disabled(!motionVM.isAirpodsMotionActive)
            } else {
                Button(motionVM.buttonTitle) {
                    motionVM.handleCalibrationButtonPress()
                }
                .padding()
                .font(.headline)
                .foregroundColor(.white)
                .background(Color.blue.cornerRadius(8))
                .disabled(!motionVM.isAirpodsMotionActive)
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

// MARK: - MotionViewModel
class MotionViewModel: ObservableObject {
    // MARK: - Motion Managers
    private let phoneMotionManager = CMMotionManager()
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    
    // MARK: - Audio for beep
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Published: Current iPhone Orientation
    @Published var phonePitch: Double = 0.0
    @Published var phoneRoll:  Double = 0.0
    @Published var phoneYaw:   Double = 0.0
    
    // MARK: - Published: Current AirPods Orientation
    @Published var airpodsPitch: Double? = nil {
        didSet {
            updatePercentDownAndCheckBeep()
        }
    }
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
    
    private var lastUpdated: Date = Date()
    private let updateThreshold: TimeInterval = 2.0

    // MARK: - Calibration
    private enum CalibrationStage {
        case notStarted
        case captureNeutral
        case captureDown
        case done
    }
    private var stage: CalibrationStage = .notStarted
    
    private var neutralPitch: Double?
    private var headDownPitch: Double?
    
    var calibrationStageText: String {
        switch stage {
        case .notStarted:     return "Not Started"
        case .captureNeutral: return "Capture Neutral Head"
        case .captureDown:    return "Capture Head Down"
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
    private var beepTimer: Timer?
    private let beepInterval = 0.75
    
    // MARK: - Timer to poll headphone connection
    private var connectionStatusTimer: Timer?
    
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
        connectionStatusTimer?.invalidate()
        connectionStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentTime = Date()
            let timeSinceLastUpdate = currentTime.timeIntervalSince(self.lastUpdated)

            let isConnectedAndUpdating = self.headphoneMotionManager.isDeviceMotionAvailable
                && self.headphoneMotionManager.isDeviceMotionActive
                && timeSinceLastUpdate < self.updateThreshold

            DispatchQueue.main.async {
                self.isAirpodsMotionActive = isConnectedAndUpdating
                if !isConnectedAndUpdating {
                    self.clearAirpodsData()
                }
            }
        }
    }
    
    func stopUpdates() {
        phoneMotionManager.stopDeviceMotionUpdates()
        headphoneMotionManager.stopDeviceMotionUpdates()
        stopBeeping()
        connectionStatusTimer?.invalidate()
        connectionStatusTimer = nil
    }

    // MARK: - Start iPhone Motion
    private func startPhoneMotionUpdates() {
        guard phoneMotionManager.isDeviceMotionAvailable else {
            print("iPhone motion data not available.")
            return
        }
        
        phoneMotionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        phoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDegrees = motion.attitude.pitch * (180.0 / .pi)
            let rollDegrees  = motion.attitude.roll  * (180.0 / .pi)
            let yawDegrees   = motion.attitude.yaw   * (180.0 / .pi)
            
            self.phonePitch = pitchDegrees
            self.phoneRoll  = rollDegrees
            self.phoneYaw   = yawDegrees
        }
    }

    // MARK: - Start AirPods Motion
    private func startAirPodsMotionUpdates() {
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            DispatchQueue.main.async {
                self.isAirpodsMotionActive = false
                self.clearAirpodsData()
            }
            print("AirPods motion data not available or unsupported model.")
            return
        }
        
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("AirPods motion error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isAirpodsMotionActive = false
                    self.clearAirpodsData()
                }
                return
            }
            
            guard let motion = motion else {
                DispatchQueue.main.async {
                    self.isAirpodsMotionActive = false
                    self.clearAirpodsData()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isAirpodsMotionActive = true
                self.airpodsPitch = motion.attitude.pitch * (180.0 / .pi)
                self.airpodsRoll = motion.attitude.roll * (180.0 / .pi)
                self.airpodsYaw = motion.attitude.yaw * (180.0 / .pi)
                self.lastUpdated = Date()
            }
        }
    }

    // MARK: - Handle Calibration Button Press
    func handleCalibrationButtonPress() {
        switch stage {
        case .notStarted:
            stage = .captureNeutral
        case .captureNeutral:
            neutralPitch = airpodsPitch
            stage = .captureDown
        case .captureDown:
            headDownPitch = airpodsPitch
            stage = .done
        case .done:
            break // Already calibrated
        }
    }

    // MARK: - Recalibrate
    func recalibrate() {
        stage = .notStarted
        neutralPitch = nil
        headDownPitch = nil
        percentDown = 0.0
        stopBeeping()
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
        
        if fraction >= 0.1 {
            startBeeping()
        } else {
            stopBeeping()
        }
    }
    
    // MARK: - Continuous Beep
    private func startBeeping() {
        guard beepTimer == nil else { return }
        
        beepTimer = Timer.scheduledTimer(withTimeInterval: beepInterval, repeats: true) { [weak self] _ in
            self?.playBeep()
        }
    }
    
    private func stopBeeping() {
        beepTimer?.invalidate()
        beepTimer = nil
    }
    
    private func playBeep() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}

