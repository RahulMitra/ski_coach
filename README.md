# Ski Coach

An iOS + watchOS companion app that monitors device (iPhone) and AirPods orientation in real-time, calculates how far "down" your head is, and provides audio beeps to remind you to look up if your head dips below a certain threshold. The watch app displays the calibration status and allows you to toggle muting, calibrate, or re-calibrate with a simple "slide to confirm" gesture.

---

## Features

1. **Real-Time Head Tracking**  
   - Uses `CMMotionManager` to track the iPhone’s orientation (pitch, roll, yaw).  
   - Uses `CMHeadphoneMotionManager` (when available on compatible AirPods) to track the user’s head orientation.

2. **Calibration**  
   - Quick, two-step calibration:
     1. Capture a neutral “heads-up” position.
     2. Capture a “head-down” position.  
   - Once calibrated, the app calculates a percentage of how “down” your head is based on these two reference points.

3. **Audio Alerts**  
   - Plays a short beep (from `look_up.wav`) whenever your head is too far down.  
   - You can toggle muting if you don’t want to hear the beep.

4. **Prevents App Suspension**  
   - The app plays a very quiet, looping one-second silent MP3 in the background to keep the audio session active, reducing the likelihood of iOS suspending the app while it’s in the background (e.g., while skiing).

5. **watchOS Companion**  
   - Displays calibration state (“Not Started”, “Neutral Head”, “Head Down”, “Calibrated”).  
   - Allows you to slide to calibrate or re-calibrate.  
   - A toggle lets you mute/unmute audio beeping from your wrist.

---

## Project Structure

Below are the primary Swift files and their roles:

- **`MotionViewModel.swift`**  
  - Orchestrates iPhone and AirPods motion data collection.  
  - Manages calibration states, threshold detection, and beep logic.  
  - Maintains a reference to a `SilentAudioManager` that keeps the app’s audio session alive in the background.

- **`WatchConnectivityManager.swift`**  
  - Bridges data between the iOS app and the watchOS app using `WCSession`.  
  - Sends calibration stage and mute state to the Watch; receives watch “actions” (calibrate, re-calibrate, set mute).

- **`ski_coachApp.swift`**  
  - The main entry point for the iOS app.  
  - Configures the audio session and starts silent audio playback through `SilentAudioManager`.  
  - Initializes `MotionViewModel` and `WatchConnectivityManager` to share data.

- **`ContentView.swift` (iOS)**  
  - A simple SwiftUI view that shows iPhone pitch/roll/yaw, AirPods pitch/roll/yaw, and calibration status.  
  - Starts and stops motion updates appropriately when appearing/disappearing.

- **`MyWatchApp.swift` / `watch_ski_coachApp.swift`**  
  - The main entry point for the watchOS app.

- **`WatchSessionManager.swift`**  
  - The watchOS counterpart to `WatchConnectivityManager.swift`.  
  - Receives calibration stage and mute state from iOS, and sends user actions (calibrate, re-calibrate, set mute) back to iOS.

- **`ContentView.swift` (watchOS)**  
  - Shows calibration stage and includes UI for “slide to calibrate” or “slide to re-calibrate,” plus a toggle for mute.


