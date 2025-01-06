import SwiftUI
import AVFoundation

@main
struct MyApp: App {
    @StateObject private var motionVM = MotionViewModel()
    @StateObject private var watchConnectivityManager = WatchConnectivityManager()
    
    init() {
        configureAudioSession()
        SilentAudioManager.shared.startSilentAudio()
    }
    

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionVM)
                .onAppear {
                    // Link the manager to the MotionViewModel
                    watchConnectivityManager.motionViewModel = motionVM
                }
        }
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Category .playback for background audio
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Error setting up audio session:", error)
        }
    }

}
