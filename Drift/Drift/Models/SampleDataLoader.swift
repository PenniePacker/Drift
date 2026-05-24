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
        let isLiveStream: Bool
    }

    // swiftlint:disable function_body_length
    private static func seeds() -> [SessionSeed] {
        [
            // Joe Rogan — The Joe Rogan Experience (6 sessions, ~8 min avg onset)
            SessionSeed(daysAgo: 1,  bedHour: 23, onsetMinutes: 7,  trackTitle: "JRE #2001 — Theo Von",             artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 420, durationSeconds: 8460, deepLinkURI: "spotify:episode:jre2001", sleepStage: "asleepCore",        isLiveStream: false),
            SessionSeed(daysAgo: 5,  bedHour: 22, onsetMinutes: 9,  trackTitle: "JRE #1988 — Andrew Huberman",      artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 540, durationSeconds: 9120, deepLinkURI: "spotify:episode:jre1988", sleepStage: "asleepCore",        isLiveStream: false),
            SessionSeed(daysAgo: 10, bedHour: 23, onsetMinutes: 8,  trackTitle: "JRE #2067 — Mark Zuckerberg",      artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 480, durationSeconds: 7920, deepLinkURI: "spotify:episode:jre2067", sleepStage: "asleepDeep",       isLiveStream: false),
            SessionSeed(daysAgo: 17, bedHour: 22, onsetMinutes: 7,  trackTitle: "JRE #2134 — Shane Gillis",         artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 420, durationSeconds: 8700, deepLinkURI: "spotify:episode:jre2134", sleepStage: "asleepCore",        isLiveStream: false),
            SessionSeed(daysAgo: 24, bedHour: 23, onsetMinutes: 10, trackTitle: "JRE #2089 — Jordan Peterson",      artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 600, durationSeconds: 9540, deepLinkURI: "spotify:episode:jre2089", sleepStage: "asleepUnspecified", isLiveStream: false),
            SessionSeed(daysAgo: 30, bedHour: 22, onsetMinutes: 9,  trackTitle: "JRE #1958 — Naval Ravikant",       artistName: "Joe Rogan", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "The Joe Rogan Experience", elapsedSeconds: 540, durationSeconds: 8280, deepLinkURI: "spotify:episode:jre1958", sleepStage: "asleepCore",        isLiveStream: false),

            // Lofi Girl — YouTube live stream (6 sessions, ~6 min avg onset)
            SessionSeed(daysAgo: 2,  bedHour: 23, onsetMinutes: 5, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 300, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepCore",  isLiveStream: true),
            SessionSeed(daysAgo: 6,  bedHour: 23, onsetMinutes: 7, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 420, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepCore",  isLiveStream: true),
            SessionSeed(daysAgo: 11, bedHour: 22, onsetMinutes: 6, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 360, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepDeep", isLiveStream: true),
            SessionSeed(daysAgo: 18, bedHour: 23, onsetMinutes: 8, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 480, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepCore",  isLiveStream: true),
            SessionSeed(daysAgo: 25, bedHour: 22, onsetMinutes: 5, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 300, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepCore",  isLiveStream: true),
            SessionSeed(daysAgo: 29, bedHour: 23, onsetMinutes: 7, trackTitle: "lofi hip hop radio — beats to relax/study to", artistName: "Lofi Girl", appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", albumOrShow: nil, elapsedSeconds: 420, durationSeconds: 0, deepLinkURI: nil, sleepStage: "asleepREM",  isLiveStream: true),

            // Huberman Lab — podcast (5 sessions, ~10 min avg onset)
            SessionSeed(daysAgo: 3,  bedHour: 23, onsetMinutes: 9,  trackTitle: "Master Your Sleep & Be More Alert When Awake",              artistName: "Huberman Lab", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "Huberman Lab", elapsedSeconds: 540, durationSeconds: 5820, deepLinkURI: nil, sleepStage: "asleepCore",        isLiveStream: false),
            SessionSeed(daysAgo: 9,  bedHour: 22, onsetMinutes: 11, trackTitle: "The Science of Setting & Achieving Goals",                  artistName: "Huberman Lab", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "Huberman Lab", elapsedSeconds: 660, durationSeconds: 6480, deepLinkURI: nil, sleepStage: "asleepCore",        isLiveStream: false),
            SessionSeed(daysAgo: 15, bedHour: 23, onsetMinutes: 10, trackTitle: "Optimize Your Learning & Creativity With Science",          artistName: "Huberman Lab", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "Huberman Lab", elapsedSeconds: 600, durationSeconds: 7140, deepLinkURI: nil, sleepStage: "asleepDeep",       isLiveStream: false),
            SessionSeed(daysAgo: 22, bedHour: 22, onsetMinutes: 12, trackTitle: "Control Your Dopamine for Motivation, Focus & Satisfaction", artistName: "Huberman Lab", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "Huberman Lab", elapsedSeconds: 720, durationSeconds: 6900, deepLinkURI: nil, sleepStage: "asleepUnspecified", isLiveStream: false),
            SessionSeed(daysAgo: 28, bedHour: 23, onsetMinutes: 11, trackTitle: "Master Your Sleep & Be More Alert When Awake",              artistName: "Huberman Lab", appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", albumOrShow: "Huberman Lab", elapsedSeconds: 660, durationSeconds: 5820, deepLinkURI: nil, sleepStage: "asleepCore",        isLiveStream: false),

            // James Blake — Overgrown / James Blake (4 sessions, ~12 min avg onset)
            SessionSeed(daysAgo: 4,  bedHour: 23, onsetMinutes: 12, trackTitle: "Retrograde",         artistName: "James Blake", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Overgrown",   elapsedSeconds: 120, durationSeconds: 249, deepLinkURI: "spotify:track:retrograde",        sleepStage: "asleepCore", isLiveStream: false),
            SessionSeed(daysAgo: 13, bedHour: 22, onsetMinutes: 14, trackTitle: "The Wilhelm Scream",  artistName: "James Blake", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "James Blake", elapsedSeconds: 140, durationSeconds: 240, deepLinkURI: "spotify:track:wilhelmscream",     sleepStage: "asleepREM",  isLiveStream: false),
            SessionSeed(daysAgo: 20, bedHour: 23, onsetMinutes: 11, trackTitle: "Retrograde",         artistName: "James Blake", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "Overgrown",   elapsedSeconds: 110, durationSeconds: 249, deepLinkURI: "spotify:track:retrograde",        sleepStage: "asleepCore", isLiveStream: false),
            SessionSeed(daysAgo: 27, bedHour: 22, onsetMinutes: 13, trackTitle: "Limit to Your Love", artistName: "James Blake", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "James Blake", elapsedSeconds: 130, durationSeconds: 260, deepLinkURI: "spotify:track:limittoyourlove",  sleepStage: "asleepCore", isLiveStream: false),

            // Taylor Swift — folklore / evermore (5 sessions, ~15 min avg onset)
            SessionSeed(daysAgo: 7,  bedHour: 23, onsetMinutes: 14, trackTitle: "the lakes",                 artistName: "Taylor Swift", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "folklore",  elapsedSeconds: 120, durationSeconds: 211, deepLinkURI: "spotify:track:thelakes",  sleepStage: "asleepCore", isLiveStream: false),
            SessionSeed(daysAgo: 12, bedHour: 22, onsetMinutes: 16, trackTitle: "seven",                     artistName: "Taylor Swift", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "folklore",  elapsedSeconds: 140, durationSeconds: 247, deepLinkURI: "spotify:track:seven",     sleepStage: "asleepCore", isLiveStream: false),
            SessionSeed(daysAgo: 16, bedHour: 23, onsetMinutes: 15, trackTitle: "the lakes",                 artistName: "Taylor Swift", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "folklore",  elapsedSeconds: 130, durationSeconds: 211, deepLinkURI: "spotify:track:thelakes",  sleepStage: "asleepDeep", isLiveStream: false),
            SessionSeed(daysAgo: 23, bedHour: 22, onsetMinutes: 17, trackTitle: "august",                    artistName: "Taylor Swift", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "folklore",  elapsedSeconds: 150, durationSeconds: 261, deepLinkURI: "spotify:track:august",    sleepStage: "asleepREM",  isLiveStream: false),
            SessionSeed(daysAgo: 26, bedHour: 23, onsetMinutes: 13, trackTitle: "evermore (feat. Bon Iver)", artistName: "Taylor Swift", appBundleID: "com.spotify.client", appDisplayName: "Spotify", albumOrShow: "evermore", elapsedSeconds: 110, durationSeconds: 304, deepLinkURI: "spotify:track:evermore",  sleepStage: "asleepCore", isLiveStream: false),
        ]
    }
    // swiftlint:enable function_body_length

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
                isLiveStream: seed.isLiveStream,
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
        let grouped = Dictionary(grouping: sessions) {
            $0.mediaSnapshot?.artistName ?? "Unknown"
        }

        let emojis: [String: String] = [
            "Joe Rogan":    "🎙️",
            "Lofi Girl":    "🎧",
            "Huberman Lab": "🧠",
            "James Blake":  "🎹",
            "Taylor Swift": "🎶",
        ]
        let apps: [String: (bundleID: String, displayName: String)] = [
            "Joe Rogan":    ("com.spotify.client",      "Spotify"),
            "Lofi Girl":    ("com.google.ios.youtube",  "YouTube"),
            "Huberman Lab": ("com.apple.podcasts",      "Podcasts"),
            "James Blake":  ("com.spotify.client",      "Spotify"),
            "Taylor Swift": ("com.spotify.client",      "Spotify"),
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
