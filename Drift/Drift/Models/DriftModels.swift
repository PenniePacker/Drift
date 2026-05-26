// DriftModels.swift
// Drift — Local SwiftData schema
//
// Add this file to your main app target.
// Requires: import SwiftData (Xcode 15+, iOS 17+)
//
// Model graph:
//
//   SleepSession  ──►  MediaSnapshot   (one session has one media snapshot)
//       │
//       └──────────►  ArtistStat       (aggregated, one per artist, updated after each session)

import SwiftData
import Foundation

// MARK: - SleepSession
// One record per night Drift detects sleep and pauses media.

@Model
final class SleepSession {

    // When the user got into bed (approximated from HealthKit inBed sample)
    var bedTime: Date

    // When sleep was detected and media was paused (HealthKit asleep sample start)
    var sleepOnsetTime: Date

    // Minutes from bedTime → sleepOnsetTime. Stored for fast querying.
    var onsetMinutes: Double

    // Which HealthKit sleep stage triggered the pause
    // Stored as string to avoid enum fragility across app versions
    // Values: "asleepCore" | "asleepDeep" | "asleepREM" | "asleepUnspecified"
    var sleepStage: String

    // The media that was playing when sleep was detected (nil if nothing was playing)
    @Relationship(deleteRule: .cascade)
    var mediaSnapshot: MediaSnapshot?

    // Derived: has this session been confirmed (≥1 validated HealthKit write)?
    // Future use: could require manual confirmation or Watch corroboration
    var isConfirmed: Bool

    // 1–5 sleep quality entered in the morning log sheet. Nil if feature is
    // disabled or user skipped the rating.
    var qualityRating: Int?

    init(
        bedTime: Date,
        sleepOnsetTime: Date,
        sleepStage: String,
        mediaSnapshot: MediaSnapshot? = nil
    ) {
        self.bedTime = bedTime
        self.sleepOnsetTime = sleepOnsetTime
        self.onsetMinutes = sleepOnsetTime.timeIntervalSince(bedTime) / 60
        self.sleepStage = sleepStage
        self.mediaSnapshot = mediaSnapshot
        self.isConfirmed = true
    }
}

// MARK: - MediaSnapshot
// A frozen record of what was playing at the moment of sleep detection.
// Captured from MPNowPlayingInfoCenter at pause time.

@Model
final class MediaSnapshot {

    // Source app bundle ID e.g. "com.spotify.client", "com.apple.podcasts"
    var appBundleID: String

    // Human-readable app name derived from bundle ID
    var appDisplayName: String

    // Track/episode title from MPMediaItemPropertyTitle
    var trackTitle: String

    // Artist or podcast show name from MPMediaItemPropertyArtist
    var artistName: String

    // Album or podcast feed name from MPMediaItemPropertyAlbumTitle
    var albumOrShow: String?

    // Seconds into the track when paused (MPNowPlayingInfoPropertyElapsedPlaybackTime)
    // Nil for live streams
    var elapsedSeconds: Double?

    // Total track duration in seconds (MPMediaItemPropertyPlaybackDuration)
    // Nil for live streams
    var durationSeconds: Double?

    // True if this was a live stream (elapsedSeconds will be nil)
    var isLiveStream: Bool

    // Spotify/Apple Music/Podcast URI for deep-linking back to this content
    // e.g. "spotify:episode:abc123" or "podcast://..." 
    var deepLinkURI: String?

    // Spotify track/episode ID for API enrichment (tempo, energy, etc.)
    var spotifyID: String?

    // Capture timestamp
    var capturedAt: Date

    init(
        appBundleID: String,
        appDisplayName: String,
        trackTitle: String,
        artistName: String,
        albumOrShow: String? = nil,
        elapsedSeconds: Double? = nil,
        durationSeconds: Double? = nil,
        isLiveStream: Bool = false,
        deepLinkURI: String? = nil,
        spotifyID: String? = nil
    ) {
        self.appBundleID = appBundleID
        self.appDisplayName = appDisplayName
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumOrShow = albumOrShow
        self.elapsedSeconds = elapsedSeconds
        self.durationSeconds = durationSeconds
        self.isLiveStream = isLiveStream
        self.deepLinkURI = deepLinkURI
        self.spotifyID = spotifyID
        self.capturedAt = Date()
    }
}

// MARK: - ArtistStat
// Aggregated sleep stats per artist/show. Updated after every confirmed session.
// This is what powers the leaderboard, "best sleeper" card, and drill-down.
//
// One ArtistStat per unique (artistName + appBundleID) pair.

@Model
final class ArtistStat {

    // The artist or podcast show name (matches MediaSnapshot.artistName)
    var artistName: String

    // App this artist was played from (so Spotify vs Apple Music are distinct)
    var appBundleID: String
    var appDisplayName: String

    // Total confirmed sleep sessions for this artist
    var confirmedSessionCount: Int

    // Running sum of onset minutes — divide by confirmedSessionCount for avg
    var totalOnsetMinutes: Double

    // Cached average (recomputed on every update for fast reads)
    var averageOnsetMinutes: Double

    // Fastest single onset ever recorded for this artist
    var fastestOnsetMinutes: Double

    // The track/episode that produced the fastest onset
    var fastestOnsetTrackTitle: String?
    var fastestOnsetDeepLink: String?

    // Drift sleep score: sessions × (30 / averageOnsetMinutes)
    // Higher = more sessions AND faster onset. Recomputed on every update.
    var driftScore: Double

    // Whether this artist has crossed the 3-session threshold
    // Derived from confirmedSessionCount but cached to avoid repeated checks
    var isUnlocked: Bool

    // Emoji category hint for UI (populated heuristically or via Spotify genre)
    // e.g. "🎙" for podcasts, "🎹" for classical, "🎤" for pop
    var categoryEmoji: String

    // All individual track stats under this artist
    @Relationship(deleteRule: .cascade)
    var trackStats: [TrackStat]

    // Date of most recent sleep session
    var lastSessionDate: Date

    init(artistName: String, appBundleID: String, appDisplayName: String, categoryEmoji: String = "🎵") {
        self.artistName = artistName
        self.appBundleID = appBundleID
        self.appDisplayName = appDisplayName
        self.confirmedSessionCount = 0
        self.totalOnsetMinutes = 0
        self.averageOnsetMinutes = 0
        self.fastestOnsetMinutes = .infinity
        self.driftScore = 0
        self.isUnlocked = false
        self.categoryEmoji = categoryEmoji
        self.trackStats = []
        self.lastSessionDate = Date()
    }

    // Call this after every new confirmed SleepSession for this artist.
    func recordSession(onsetMinutes: Double, track: MediaSnapshot) {
        confirmedSessionCount += 1
        totalOnsetMinutes += onsetMinutes
        averageOnsetMinutes = totalOnsetMinutes / Double(confirmedSessionCount)
        lastSessionDate = Date()

        if onsetMinutes < fastestOnsetMinutes {
            fastestOnsetMinutes = onsetMinutes
            fastestOnsetTrackTitle = track.trackTitle
            fastestOnsetDeepLink = track.deepLinkURI
        }

        isUnlocked = confirmedSessionCount >= 3
        driftScore = computeScore()
    }

    private func computeScore() -> Double {
        guard averageOnsetMinutes > 0 else { return 0 }
        // Weight sessions linearly, reward faster onset exponentially
        return Double(confirmedSessionCount) * (30.0 / averageOnsetMinutes)
    }
}

// MARK: - TrackStat
// Per-track sleep stats, nested under ArtistStat.
// Powers the drill-down "episodes · fastest onset first" list.

@Model
final class TrackStat {

    var trackTitle: String
    var artistName: String
    var albumOrShow: String?
    var appBundleID: String
    var deepLinkURI: String?
    var spotifyID: String?

    var confirmedSessionCount: Int
    var totalOnsetMinutes: Double
    var averageOnsetMinutes: Double
    var fastestOnsetMinutes: Double

    // Average position in the track where sleep occurred (seconds)
    var averageElapsedSeconds: Double?

    var driftScore: Double
    var isUnlocked: Bool
    var lastSessionDate: Date

    init(from snapshot: MediaSnapshot) {
        self.trackTitle = snapshot.trackTitle
        self.artistName = snapshot.artistName
        self.albumOrShow = snapshot.albumOrShow
        self.appBundleID = snapshot.appBundleID
        self.deepLinkURI = snapshot.deepLinkURI
        self.spotifyID = snapshot.spotifyID
        self.confirmedSessionCount = 0
        self.totalOnsetMinutes = 0
        self.averageOnsetMinutes = 0
        self.fastestOnsetMinutes = .infinity
        self.driftScore = 0
        self.isUnlocked = false
        self.lastSessionDate = Date()
    }

    func recordSession(onsetMinutes: Double, elapsedSeconds: Double?) {
        confirmedSessionCount += 1
        totalOnsetMinutes += onsetMinutes
        averageOnsetMinutes = totalOnsetMinutes / Double(confirmedSessionCount)
        lastSessionDate = Date()

        if onsetMinutes < fastestOnsetMinutes {
            fastestOnsetMinutes = onsetMinutes
        }

        if let elapsed = elapsedSeconds {
            let prev = averageElapsedSeconds ?? elapsed
            averageElapsedSeconds = (prev * Double(confirmedSessionCount - 1) + elapsed) / Double(confirmedSessionCount)
        }

        isUnlocked = confirmedSessionCount >= 3
        driftScore = confirmedSessionCount > 0 ? Double(confirmedSessionCount) * (30.0 / averageOnsetMinutes) : 0
    }
}

// MARK: - GlobalContribution
// Lightweight record of what has been anonymously submitted to the global backend.
// Prevents duplicate uploads and tracks submission history.

@Model
final class GlobalContribution {

    var artistName: String
    var appBundleID: String
    var submittedAt: Date

    // The score and stats at time of submission (for diffing on next sync)
    var submittedSessionCount: Int
    var submittedAverageOnset: Double
    var submittedDriftScore: Double

    init(artistStat: ArtistStat) {
        self.artistName = artistStat.artistName
        self.appBundleID = artistStat.appBundleID
        self.submittedAt = Date()
        self.submittedSessionCount = artistStat.confirmedSessionCount
        self.submittedAverageOnset = artistStat.averageOnsetMinutes
        self.submittedDriftScore = artistStat.driftScore
    }
}
