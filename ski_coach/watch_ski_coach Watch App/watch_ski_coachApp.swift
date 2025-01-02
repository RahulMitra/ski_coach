import SwiftUI

@main
struct MyWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(sessionManager)
        }
    }
}
