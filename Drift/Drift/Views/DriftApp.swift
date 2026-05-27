// DriftApp.swift
// Drift — App entry point
//
// Wires up SwiftData container, SleepObserver, WatchSessionManager,
// and listens for sleep detection events from the Apple Watch.

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Notification delegate

final class DriftNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DriftNotificationDelegate()
    private override init() { super.init() }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.userInfo["action"] as? String == "openHistory" {
            NotificationCenter.default.post(name: .driftOpenHistory, object: nil)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let driftOpenHistory = Notification.Name("driftOpenHistory")
    static let driftOpenArtist  = Notification.Name("driftOpenArtist")
}

@main
struct DriftApp: App {

    @StateObject private var sleepObserver = SleepObserver()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
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
                    // Defer observer start until onboarding is complete so the
                    // HealthKit permission dialog appears at the right moment.
                    if hasCompletedOnboarding { sleepObserver.start() }
                    ManualSleepLogger.requestNotificationPermission()
                    UNUserNotificationCenter.current().delegate = DriftNotificationDelegate.shared
                }
                .onChange(of: hasCompletedOnboarding) { _, completed in
                    if completed { sleepObserver.start() }
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
        ManualSleepLogger.scheduleMorningSummary(
            artistName: mediaSnapshot?.artistName,
            onsetMinutes: payload.estimatedTimeInBedSeconds / 60
        )
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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var artistToOpen: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "moon.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)

            ArtistStatsView(artistToOpen: $artistToOpen)
                .tabItem { Label("Artists", systemImage: "music.mic") }
                .tag(2)

            WorldRankingsView()
                .tabItem { Label("World", systemImage: "globe") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(.indigo)
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasCompletedOnboarding { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .driftOpenHistory)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .driftOpenArtist)) { notification in
            if let name = notification.userInfo?["artistName"] as? String {
                selectedTab = 2
                artistToOpen = name
            }
        }
    }
}
