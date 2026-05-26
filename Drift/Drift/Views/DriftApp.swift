// DriftApp.swift
// Drift — App entry point
//
// Wires up SwiftData container, SleepObserver, WatchSessionManager,
// and listens for sleep detection events from the Apple Watch.

import SwiftUI
import SwiftData

@main
struct DriftApp: App {

    @StateObject private var sleepObserver = SleepObserver()
    #if canImport(WatchConnectivity)
    @StateObject private var watchSession = WatchSessionManager.shared
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(DriftStore.shared.container)
                #if canImport(WatchConnectivity)
                .environmentObject(watchSession)
                #endif
                .onAppear {
                    sleepObserver.start()
                    ManualSleepLogger.requestNotificationPermission()
                }
                #if canImport(WatchConnectivity)
                .onReceive(NotificationCenter.default.publisher(for: .watchSleepDetected)) { notification in
                    guard let payload = notification.object as? SleepDetectionPayload else { return }
                    handleWatchSleepDetected(payload)
                }
                #endif
        }
    }

    #if canImport(WatchConnectivity)
    @MainActor
    private func handleWatchSleepDetected(_ payload: SleepDetectionPayload) {
        let mediaSnapshot = MediaSnapshotCapture.capture()
        DriftStore.shared.recordSleepSession(
            bedTime: payload.onsetDate.addingTimeInterval(-payload.estimatedTimeInBedSeconds),
            sleepOnsetTime: payload.onsetDate,
            sleepStage: payload.sleepStage,
            mediaSnapshot: mediaSnapshot
        )
        sleepObserver.pauseViaAudioSession()
        pushBestSleeperToWatch()
    }

    @MainActor
    private func pushBestSleeperToWatch() {
        guard let best = try? DriftStore.shared.bestSleeperTrack() else { return }
        watchSession.pushBestSleeper(
            trackTitle: best.trackTitle,
            artistName: best.artistName,
            deepLinkURI: best.deepLinkURI,
            avgOnsetMinutes: best.averageOnsetMinutes,
            sessionCount: best.confirmedSessionCount
        )
    }
    #endif
}

// MARK: - ContentView (Tab container)

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "moon.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }

            ArtistStatsView()
                .tabItem {
                    Label("Artists", systemImage: "music.mic")
                }

            WorldRankingsView()
                .tabItem {
                    Label("World", systemImage: "globe")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.indigo)
        .preferredColorScheme(.dark)
    }
}
