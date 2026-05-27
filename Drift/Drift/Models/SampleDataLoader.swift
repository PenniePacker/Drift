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

    // MARK: - Entry points

    static func load(into context: ModelContext) {
        clearExisting(context)
        let sessions = buildSessions()
        for s in sessions { context.insert(s) }
        let artists = buildArtistStats(from: sessions)
        for a in artists { context.insert(a); a.trackStats.forEach { context.insert($0) } }
        try? context.save()
    }

    static func randomize(into context: ModelContext) {
        clearExisting(context)
        let sessions = buildRandomSessions()
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
            "Joe Rogan":             "🎙️",
            "Lofi Girl":             "🎧",
            "Huberman Lab":          "🧠",
            "James Blake":           "🎹",
            "Taylor Swift":          "🎶",
            "Brian Eno":             "🎹",
            "Max Richter":           "🎻",
            "Nils Frahm":            "🎹",
            "Erik Satie":            "🎹",
            "Steezy Gonzalez":       "🎧",
            "Sleep With Me":         "😴",
            "Nothing Much Happens":  "🌿",
            "J.K. Rowling":          "📚",
            "James Clear":           "📚",
            "Frank Herbert":         "📚",
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
    // MARK: - Random content pool

    private struct ContentSeed {
        let appBundleID: String
        let appDisplayName: String
        let artistName: String
        let trackTitle: String
        let albumOrShow: String?
        let durationSeconds: Double
        let isLiveStream: Bool
        let deepLinkURI: String?
    }

    // Spotify music (~30% of sessions)
    private static let spotifySeeds: [ContentSeed] = [
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Brian Eno",   trackTitle: "Music for Airports 1/1",       albumOrShow: "Ambient 1: Music for Airports", durationSeconds: 1171, isLiveStream: false, deepLinkURI: "spotify:track:musicforairports"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Brian Eno",   trackTitle: "The Big Ship",                  albumOrShow: "Another Green World",          durationSeconds:  214, isLiveStream: false, deepLinkURI: "spotify:track:bigship"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Brian Eno",   trackTitle: "2/1 (For David McComb)",         albumOrShow: "Ambient 1: Music for Airports", durationSeconds:  968, isLiveStream: false, deepLinkURI: "spotify:track:twoone"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Max Richter", trackTitle: "On the Nature of Daylight",      albumOrShow: "The Blue Notebooks",           durationSeconds:  396, isLiveStream: false, deepLinkURI: "spotify:track:natureofdaylight"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Max Richter", trackTitle: "November",                       albumOrShow: "The Blue Notebooks",           durationSeconds:  178, isLiveStream: false, deepLinkURI: "spotify:track:november"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Nils Frahm",  trackTitle: "Says",                          albumOrShow: "Spaces",                       durationSeconds:  769, isLiveStream: false, deepLinkURI: "spotify:track:says"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Nils Frahm",  trackTitle: "All Melody",                    albumOrShow: "All Melody",                   durationSeconds:  413, isLiveStream: false, deepLinkURI: "spotify:track:allmelody"),
        ContentSeed(appBundleID: "com.spotify.client", appDisplayName: "Spotify", artistName: "Erik Satie",  trackTitle: "Gymnopédie No.1",               albumOrShow: "Gymnopédies & Gnossiennes",    durationSeconds:  218, isLiveStream: false, deepLinkURI: "spotify:track:gymnopedie1"),
    ]

    // YouTube (~25% of sessions)
    private static let youtubeSeeds: [ContentSeed] = [
        ContentSeed(appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", artistName: "Lofi Girl",       trackTitle: "lofi hip hop radio — beats to relax/study to", albumOrShow: nil, durationSeconds: 0, isLiveStream: true,  deepLinkURI: nil),
        ContentSeed(appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", artistName: "Lofi Girl",       trackTitle: "lofi hip hop radio — beats to sleep/chill to", albumOrShow: nil, durationSeconds: 0, isLiveStream: true,  deepLinkURI: nil),
        ContentSeed(appBundleID: "com.google.ios.youtube", appDisplayName: "YouTube", artistName: "Steezy Gonzalez", trackTitle: "Lo-Fi Beats to relax / study to — live",        albumOrShow: nil, durationSeconds: 0, isLiveStream: true,  deepLinkURI: nil),
    ]

    // Apple Podcasts (~20% of sessions)
    private static let podcastSeeds: [ContentSeed] = [
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Huberman Lab",         trackTitle: "Master Your Sleep & Be More Alert When Awake", albumOrShow: "Huberman Lab",         durationSeconds: 5820, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Huberman Lab",         trackTitle: "Using Light for Health",                       albumOrShow: "Huberman Lab",         durationSeconds: 6300, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Huberman Lab",         trackTitle: "Optimal Morning Routine",                      albumOrShow: "Huberman Lab",         durationSeconds: 5400, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Sleep With Me",        trackTitle: "The Clock Shop — Episode 412",                 albumOrShow: "Sleep With Me",        durationSeconds: 4800, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Sleep With Me",        trackTitle: "A Rambling Tale of Not Much",                  albumOrShow: "Sleep With Me",        durationSeconds: 4500, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Nothing Much Happens", trackTitle: "In a Small Hotel Room",                        albumOrShow: "Nothing Much Happens", durationSeconds: 1800, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.apple.podcasts", appDisplayName: "Podcasts", artistName: "Nothing Much Happens", trackTitle: "A Seaside Village",                            albumOrShow: "Nothing Much Happens", durationSeconds: 1620, isLiveStream: false, deepLinkURI: nil),
    ]

    // Audible (~10% of sessions)
    private static let audibleSeeds: [ContentSeed] = [
        ContentSeed(appBundleID: "com.audible.iphone", appDisplayName: "Audible", artistName: "J.K. Rowling", trackTitle: "Harry Potter and the Philosopher's Stone", albumOrShow: nil, durationSeconds: 26400, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.audible.iphone", appDisplayName: "Audible", artistName: "James Clear",  trackTitle: "Atomic Habits",                           albumOrShow: nil, durationSeconds: 19800, isLiveStream: false, deepLinkURI: nil),
        ContentSeed(appBundleID: "com.audible.iphone", appDisplayName: "Audible", artistName: "Frank Herbert", trackTitle: "Dune",                                   albumOrShow: nil, durationSeconds: 50400, isLiveStream: false, deepLinkURI: nil),
    ]

    // MARK: - Build random SleepSessions

    private static func buildRandomSessions() -> [SleepSession] {
        let cal = Calendar.current
        let now = Date()
        let stages = ["asleepCore", "asleepCore", "asleepCore", "asleepDeep", "asleepREM"]

        // Guaranteed anchors: 3 artists with ≥3 sessions each so they appear unlocked in Artists tab
        let anchors: [ContentSeed] = [
            spotifySeeds[0], spotifySeeds[1], spotifySeeds[2], // Brian Eno ×3
            youtubeSeeds[0], youtubeSeeds[1], youtubeSeeds[0], // Lofi Girl ×3
            podcastSeeds[0], podcastSeeds[1], podcastSeeds[2], // Huberman Lab ×3
        ]

        // Fill remaining slots using weighted random picks
        let total = Int.random(in: 22...28)
        var fillSeeds: [ContentSeed?] = []
        for _ in 0..<(total - anchors.count) {
            let roll = Int.random(in: 0...99)
            switch roll {
            case 0..<15:  fillSeeds.append(nil)                                 // ~15% silence
            case 15..<45: fillSeeds.append(spotifySeeds.randomElement()!)       // ~30% Spotify
            case 45..<70: fillSeeds.append(youtubeSeeds.randomElement()!)       // ~25% YouTube
            case 70..<90: fillSeeds.append(podcastSeeds.randomElement()!)       // ~20% Podcasts
            default:      fillSeeds.append(audibleSeeds.randomElement()!)       // ~10% Audible
            }
        }

        // Merge anchors + fill, shuffle, assign to unique days
        var allSeeds: [ContentSeed?] = anchors.map { Optional($0) } + fillSeeds
        allSeeds.shuffle()

        var usedDays = Set<Int>()
        var days: [Int] = []
        while days.count < allSeeds.count {
            if usedDays.insert(Int.random(in: 0...29)).inserted {
                days.append(usedDays.count - 1)
            }
        }

        return zip(days, allSeeds).map { daysAgo, seed in
            let baseDate = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let bedHour   = [21, 22, 22, 23, 23, 23, 0].randomElement()!
            let bedMinute = [0, 15, 30, 45].randomElement()!
            let bed   = cal.date(bySettingHour: bedHour, minute: bedMinute, second: 0, of: baseDate)!
            let onset = Double(Int.random(in: 5...38))
            let sleep = bed.addingTimeInterval(onset * 60)
            let stage = stages.randomElement()!

            var snap: MediaSnapshot? = nil
            if let s = seed {
                let elapsed: Double
                if s.isLiveStream {
                    elapsed = 0
                } else {
                    let cap = min(s.durationSeconds * 0.9, onset * 60)
                    elapsed = Double.random(in: 30...max(30, cap))
                }
                snap = MediaSnapshot(
                    appBundleID: s.appBundleID,
                    appDisplayName: s.appDisplayName,
                    trackTitle: s.trackTitle,
                    artistName: s.artistName,
                    albumOrShow: s.albumOrShow,
                    elapsedSeconds: elapsed,
                    durationSeconds: s.durationSeconds,
                    isLiveStream: s.isLiveStream,
                    deepLinkURI: s.deepLinkURI,
                    spotifyID: nil
                )
            }
            return SleepSession(bedTime: bed, sleepOnsetTime: sleep, sleepStage: stage, mediaSnapshot: snap)
        }
    }
}
#endif
