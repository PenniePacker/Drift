// SampleDataLoader.swift
// Debug-only helper — strip from Release via #if DEBUG.
//
// Inserts 26 realistic sleep sessions across 5 artists so every screen
// has something meaningful to display during development.

#if DEBUG
import SwiftData
import Foundation

@MainActor
enum SampleDataLoader {

    // MARK: - Entry point

    static func load(into context: ModelContext) {
        clearExisting(context)
        let sessions = buildSessions()
        for s in sessions { context.insert(s) }
        let artists = buildArtistStats(from: sessions)
        for a in artists { context.insert(a); a.trackStats.forEach { context.insert($0) } }
        try? context.save()
    }

    // MARK: - Clear

    private static func clearExisting(_ context: ModelContext) {
        try? context.delete(model: SleepSession.self)
        try? context.delete(model: ArtistStat.self)
        try? context.delete(model: TrackStat.self)
        try? context.delete(model: GlobalContribution.self)
    }

    // MARK: - Raw session data

    private struct SessionSeed {
        let daysAgo: Int
        let bedHour: Int
        let onsetMinutes: Double
        let trackTitle: String
        let artistName: String
        let appBundleID: String
        let appDisplayName: String
        let albumOrShow: String?
        let elapsedSeconds: Double
        let durationSeconds: Double
        let deepLinkURI: String?
        let sleepStage: String
    }

    // swiftlint:disable function_body_length
    private static func seeds() -> [SessionSeed] {
        [
            // Brian Eno — Ambient 1: Music for Airports (5 sessions)
            SessionSeed(daysAgo: 2,  bedHour: 23, onsetMinutes: 8,  trackTitle: "Ambient 1: Music for Airports", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Ambient 1", elapsedSeconds: 480,  durationSeconds: 2890, deepLinkURI: "spotify:track:ambient1airports", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 5,  bedHour: 22, onsetMinutes: 11, trackTitle: "Ambient 1: Music for Airports", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Ambient 1", elapsedSeconds: 660,  durationSeconds: 2890, deepLinkURI: "spotify:track:ambient1airports", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 8,  bedHour: 23, onsetMinutes: 9,  trackTitle: "Ambient 1: Music for Airports", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Ambient 1", elapsedSeconds: 540,  durationSeconds: 2890, deepLinkURI: "spotify:track:ambient1airports", sleepStage: "asleepDeep"),
            SessionSeed(daysAgo: 12, bedHour: 22, onsetMinutes: 12, trackTitle: "Ambient 1: Music for Airports", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Ambient 1", elapsedSeconds: 720,  durationSeconds: 2890, deepLinkURI: "spotify:track:ambient1airports", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 17, bedHour: 23, onsetMinutes: 10, trackTitle: "Ambient 1: Music for Airports", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Ambient 1", elapsedSeconds: 600,  durationSeconds: 2890, deepLinkURI: "spotify:track:ambient1airports", sleepStage: "asleepCore"),
            // Brian Eno — Thursday Afternoon (3 sessions)
            SessionSeed(daysAgo: 20, bedHour: 23, onsetMinutes: 14, trackTitle: "Thursday Afternoon", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Thursday Afternoon", elapsedSeconds: 840,  durationSeconds: 3660, deepLinkURI: "spotify:track:thursdayafternoon", sleepStage: "asleepREM"),
            SessionSeed(daysAgo: 24, bedHour: 22, onsetMinutes: 16, trackTitle: "Thursday Afternoon", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Thursday Afternoon", elapsedSeconds: 960,  durationSeconds: 3660, deepLinkURI: "spotify:track:thursdayafternoon", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 28, bedHour: 23, onsetMinutes: 13, trackTitle: "Thursday Afternoon", artistName: "Brian Eno", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Thursday Afternoon", elapsedSeconds: 780,  durationSeconds: 3660, deepLinkURI: "spotify:track:thursdayafternoon", sleepStage: "asleepCore"),

            // Max Richter — Sleep (4 sessions)
            SessionSeed(daysAgo: 3,  bedHour: 22, onsetMinutes: 12, trackTitle: "Sleep", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Sleep", elapsedSeconds: 720,  durationSeconds: 28800, deepLinkURI: "spotify:track:maxrichtersleep", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 7,  bedHour: 23, onsetMinutes: 15, trackTitle: "Sleep", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Sleep", elapsedSeconds: 900,  durationSeconds: 28800, deepLinkURI: "spotify:track:maxrichtersleep", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 14, bedHour: 22, onsetMinutes: 11, trackTitle: "Sleep", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Sleep", elapsedSeconds: 660,  durationSeconds: 28800, deepLinkURI: "spotify:track:maxrichtersleep", sleepStage: "asleepDeep"),
            SessionSeed(daysAgo: 21, bedHour: 23, onsetMinutes: 17, trackTitle: "Sleep", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Sleep", elapsedSeconds: 1020, durationSeconds: 28800, deepLinkURI: "spotify:track:maxrichtersleep", sleepStage: "asleepCore"),
            // Max Richter — On the Nature of Daylight (2 sessions)
            SessionSeed(daysAgo: 9,  bedHour: 23, onsetMinutes: 21, trackTitle: "On the Nature of Daylight", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Blue Notebooks", elapsedSeconds: 1260, durationSeconds: 394, deepLinkURI: "spotify:track:natureofday", sleepStage: "asleepREM"),
            SessionSeed(daysAgo: 19, bedHour: 22, onsetMinutes: 24, trackTitle: "On the Nature of Daylight", artistName: "Max Richter", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Blue Notebooks", elapsedSeconds: 1440, durationSeconds: 394, deepLinkURI: "spotify:track:natureofday", sleepStage: "asleepCore"),

            // The Daily — NYT Podcasts (5 sessions, different episodes)
            SessionSeed(daysAgo: 1,  bedHour: 23, onsetMinutes: 7,  trackTitle: "The Battle Over AI in Schools", artistName: "The Daily", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "The Daily", elapsedSeconds: 420,  durationSeconds: 1980, deepLinkURI: nil, sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 4,  bedHour: 23, onsetMinutes: 9,  trackTitle: "Is the U.S. Economy Heading for a Recession?", artistName: "The Daily", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "The Daily", elapsedSeconds: 540,  durationSeconds: 2160, deepLinkURI: nil, sleepStage: "asleepUnspecified"),
            SessionSeed(daysAgo: 10, bedHour: 22, onsetMinutes: 6,  trackTitle: "The Rise of the Anti-Streaming Movement", artistName: "The Daily", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "The Daily", elapsedSeconds: 360,  durationSeconds: 1740, deepLinkURI: nil, sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 15, bedHour: 23, onsetMinutes: 8,  trackTitle: "A Conversation With the Surgeon General", artistName: "The Daily", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "The Daily", elapsedSeconds: 480,  durationSeconds: 1920, deepLinkURI: nil, sleepStage: "asleepDeep"),
            SessionSeed(daysAgo: 22, bedHour: 22, onsetMinutes: 7,  trackTitle: "The Week in Good News", artistName: "The Daily", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "The Daily", elapsedSeconds: 420,  durationSeconds: 1620, deepLinkURI: nil, sleepStage: "asleepCore"),

            // Radiohead — How to Disappear Completely (3 sessions)
            SessionSeed(daysAgo: 6,  bedHour: 23, onsetMinutes: 19, trackTitle: "How to Disappear Completely", artistName: "Radiohead", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Kid A", elapsedSeconds: 1140, durationSeconds: 336, deepLinkURI: "spotify:track:howtodisappear", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 13, bedHour: 22, onsetMinutes: 22, trackTitle: "How to Disappear Completely", artistName: "Radiohead", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Kid A", elapsedSeconds: 1320, durationSeconds: 336, deepLinkURI: "spotify:track:howtodisappear", sleepStage: "asleepREM"),
            SessionSeed(daysAgo: 25, bedHour: 23, onsetMinutes: 18, trackTitle: "How to Disappear Completely", artistName: "Radiohead", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Kid A", elapsedSeconds: 1080, durationSeconds: 336, deepLinkURI: "spotify:track:howtodisappear", sleepStage: "asleepCore"),
            // Radiohead — Motion Picture Soundtrack (1 session)
            SessionSeed(daysAgo: 30, bedHour: 23, onsetMinutes: 17, trackTitle: "Motion Picture Soundtrack", artistName: "Radiohead", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Kid A", elapsedSeconds: 1020, durationSeconds: 284, deepLinkURI: "spotify:track:motionpicture", sleepStage: "asleepCore"),

            // Sleep Token — (3 sessions, just unlocked)
            SessionSeed(daysAgo: 11, bedHour: 23, onsetMinutes: 17, trackTitle: "The Summoning", artistName: "Sleep Token", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Take Me Back to Eden", elapsedSeconds: 1020, durationSeconds: 374, deepLinkURI: "spotify:track:thesummoning", sleepStage: "asleepCore"),
            SessionSeed(daysAgo: 18, bedHour: 22, onsetMinutes: 20, trackTitle: "The Summoning", artistName: "Sleep Token", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Take Me Back to Eden", elapsedSeconds: 1200, durationSeconds: 374, deepLinkURI: "spotify:track:thesummoning", sleepStage: "asleepDeep"),
            SessionSeed(daysAgo: 26, bedHour: 23, onsetMinutes: 23, trackTitle: "Aqua Regia", artistName: "Sleep Token", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Take Me Back to Eden", elapsedSeconds: 1380, durationSeconds: 298, deepLinkURI: "spotify:track:aquaregia", sleepStage: "asleepREM"),
        ]
    }

    // MARK: - Build SleepSessions

    private static func buildSessions() -> [SleepSession] {
        let cal = Calendar.current
        let now = Date()
        return seeds().map { seed in
            let bed = cal.date(bySettingHour: seed.bedHour, minute: 0, second: 0,
                               of: cal.date(byAdding: .day, value: -seed.daysAgo, to: now)!)!
            let onset = bed.addingTimeInterval(seed.onsetMinutes * 60)
            let snap = MediaSnapshot(
                appBundleID: seed.appBundleID,
                appDisplayName: seed.appDisplayName,
                trackTitle: seed.trackTitle,
                artistName: seed.artistName,
                albumOrShow: seed.albumOrShow,
                elapsedSeconds: seed.elapsedSeconds,
                durationSeconds: seed.durationSeconds,
                isLiveStream: false,
                deepLinkURI: seed.deepLinkURI,
                spotifyID: nil
            )
            return SleepSession(
                bedTime: bed,
                sleepOnsetTime: onset,
                sleepStage: seed.sleepStage,
                mediaSnapshot: snap
            )
        }
    }

    // MARK: - Build ArtistStats + TrackStats

    private static func buildArtistStats(from sessions: [SleepSession]) -> [ArtistStat] {
        // Group sessions by artist
        let grouped = Dictionary(grouping: sessions) {
            $0.mediaSnapshot?.artistName ?? "Unknown"
        }

        let emojis: [String: String] = [
            "Brian Eno":    "🎹",
            "Max Richter":  "🎻",
            "The Daily":    "🎙️",
            "Radiohead":    "🎸",
            "Sleep Token":  "🌙",
        ]
        let apps: [String: (bundleID: String, displayName: String)] = [
            "Brian Eno":    ("com.spotify.client", "Spotify"),
            "Max Richter":  ("com.spotify.client", "Spotify"),
            "The Daily":    ("com.apple.podcasts", "Podcasts"),
            "Radiohead":    ("com.spotify.client", "Spotify"),
            "Sleep Token":  ("com.spotify.client", "Spotify"),
        ]

        return grouped.compactMap { artistName, artistSessions in
            guard let snap = artistSessions.first?.mediaSnapshot else { return nil }
            let app = apps[artistName] ?? (snap.appBundleID, snap.appDisplayName)
            let artist = ArtistStat(
                artistName: artistName,
                appBundleID: app.bundleID,
                appDisplayName: app.displayName,
                categoryEmoji: emojis[artistName] ?? "🎵"
            )

            // Build per-track stats
            let byTrack = Dictionary(grouping: artistSessions) {
                $0.mediaSnapshot?.trackTitle ?? "Unknown"
            }
            var trackStats: [TrackStat] = []
            for (_, trackSessions) in byTrack {
                guard let firstSnap = trackSessions.first?.mediaSnapshot else { continue }
                let ts = TrackStat(from: firstSnap)
                for session in trackSessions {
                    ts.recordSession(onsetMinutes: session.onsetMinutes,
                                     elapsedSeconds: session.mediaSnapshot?.elapsedSeconds)
                }
                trackStats.append(ts)
            }
            artist.trackStats = trackStats

            // Aggregate artist stats from all sessions
            for session in artistSessions {
                let onset = session.onsetMinutes
                artist.confirmedSessionCount += 1
                artist.totalOnsetMinutes += onset
                artist.lastSessionDate = max(artist.lastSessionDate, session.sleepOnsetTime)
                if onset < artist.fastestOnsetMinutes {
                    artist.fastestOnsetMinutes = onset
                    artist.fastestOnsetTrackTitle = session.mediaSnapshot?.trackTitle
                    artist.fastestOnsetDeepLink = session.mediaSnapshot?.deepLinkURI
                }
            }
            artist.averageOnsetMinutes = artist.totalOnsetMinutes / Double(artist.confirmedSessionCount)
            artist.isUnlocked = artist.confirmedSessionCount >= 3
            artist.driftScore = artist.confirmedSessionCount > 0
                ? Double(artist.confirmedSessionCount) * (30.0 / artist.averageOnsetMinutes)
                : 0

            return artist
        }
    }
}
#endif
