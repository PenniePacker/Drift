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
    @StateObject private var watchSession = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(DriftStore.shared.container)
                .environmentObject(watchSession)
                .onAppear {
                    sleepObserver.start()
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchSleepDetected)) { notification in
                    guard let payload = notification.object as? SleepDetectionPayload else { return }
                    handleWatchSleepDetected(payload)
                }
        }
    }

    // MARK: - Handle Watch-triggered sleep detection

    /// Called when the Watch detects sleep onset and sends a WatchConnectivity message.
    /// Captures the current MPNowPlayingInfo snapshot, pauses media, and records
    /// the session in SwiftData — identical to what SleepObserver does phone-side.
    @MainActor
    private func handleWatchSleepDetected(_ payload: SleepDetectionPayload) {
        // Snapshot what's currently playing on the iPhone
        let mediaSnapshot = MediaSnapshotCapture.capture()

        // Record the session (also triggers global sync)
        DriftStore.shared.recordSleepSession(
            bedTime: payload.onsetDate.addingTimeInterval(-payload.estimatedTimeInBedSeconds),
            sleepOnsetTime: payload.onsetDate,
            sleepStage: payload.sleepStage,
            mediaSnapshot: mediaSnapshot
        )

        // Pause media — the Watch detected sleep, so pause whatever's on the iPhone
        sleepObserver.pauseViaAudioSession()

        // Push updated best sleeper back to the Watch
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
}

// MARK: - MediaSnapshotCapture
// Reads MPNowPlayingInfoCenter to capture what was playing at sleep onset.
// Extracted here so it can be called from both SleepObserver and Watch trigger paths.

import MediaPlayer

enum MediaSnapshotCapture {

    static func capture() -> MediaSnapshot? {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        guard let info, !info.isEmpty else { return nil }

        let title   = info[MPMediaItemPropertyTitle] as? String ?? "Unknown"
        let artist  = info[MPMediaItemPropertyArtist] as? String ?? "Unknown"
        let album   = info[MPMediaItemPropertyAlbumTitle] as? String
        let elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
        let duration = info[MPMediaItemPropertyPlaybackDuration] as? Double

        // Derive the source app from the player's bundle ID if available
        let bundleID = info["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? String
            ?? inferBundleID()
        let displayName = displayName(for: bundleID)

        return MediaSnapshot(
            appBundleID: bundleID,
            appDisplayName: displayName,
            trackTitle: title,
            artistName: artist,
            albumOrShow: album,
            elapsedSeconds: elapsed,
            durationSeconds: duration,
            isLiveStream: duration == nil || duration == 0,
            deepLinkURI: nil,   // enriched later via Spotify API
            spotifyID: nil
        )
    }

    private static func inferBundleID() -> String {
        // Fall back to Spotify if nothing else is detectable
        // A more robust approach uses private MPNowPlayingInfoCenter APIs (see notes)
        return "com.spotify.client"
    }

    private static func displayName(for bundleID: String) -> String {
        switch bundleID {
        case "com.spotify.client":          return "Spotify"
        case "com.apple.podcasts":          return "Podcasts"
        case "com.apple.Music":             return "Apple Music"
        case "com.google.ios.youtube":      return "YouTube"
        case "com.google.ios.youtubemusic": return "YouTube Music"
        default:                            return "Music"
        }
    }
}

// MARK: - SleepDetectionPayload extension

extension SleepDetectionPayload {
    /// Rough estimate: assume user was in bed 20 minutes before sleep onset
    var estimatedTimeInBedSeconds: Double { 20 * 60 }
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
