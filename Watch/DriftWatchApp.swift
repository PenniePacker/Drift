// DriftWatchApp.swift
// Drift — watchOS app entry point
//
// This is a separate target in your Xcode project: File → New → Target → Watch App.
// Name it "Drift Watch". Ensure "Include Companion iPhone App" is checked.
//
// Required capabilities on the Watch target:
//   - HealthKit (for sleep analysis + motion data)
//   - Background Modes → Background processing
//   - Background Modes → Workout processing (keeps CPU alive for motion sampling)
//
// Required Info.plist keys (Watch target):
//   NSHealthShareUsageDescription
//   NSHealthUpdateUsageDescription
//   WKBackgroundModes → workout-processing, background-app-refresh

#if os(watchOS)
import SwiftUI
import WatchKit

@main
struct DriftWatchApp: App {

    // WatchSessionManager bridges data back to the iPhone via WatchConnectivity
    @StateObject private var sessionManager = WatchSessionManager.shared

    // WatchSleepDetector runs on-device motion + heart rate detection
    @StateObject private var detector = WatchSleepDetector.shared

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
                    .environmentObject(sessionManager)
                    .environmentObject(detector)
            }
        }
        WKNotificationScene(controller: NotificationController.self, category: "sleepDetected")
    }
}
#endif // os(watchOS)
