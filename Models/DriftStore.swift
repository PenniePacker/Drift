// DriftStore.swift
// Drift — SwiftData store manager
//
// Central coordinator between SleepObserver (HealthKit) and the data models.
// Call DriftStore.shared from anywhere in the app.

import SwiftData
import Foundation

@MainActor
final class DriftStore {

    static let shared = DriftStore()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            SleepSession.self,
            MediaSnapshot.self,
            ArtistStat.self,
            TrackStat.self,
            GlobalContribution.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var context: ModelContext { container.mainContext }

    // MARK: - Record a sleep session
    // Call this from SleepObserver when sleep onset is detected and media is paused.

    func recordSleepSession(
        bedTime: Date,
        sleepOnsetTime: Date,
        sleepStage: String,
        mediaSnapshot: MediaSnapshot?
    ) {
        let session = SleepSession(
            bedTime: bedTime,
            sleepOnsetTime: sleepOnsetTime,
            sleepStage: sleepStage,
            mediaSnapshot: mediaSnapshot
        )
        context.insert(session)

        if let media = mediaSnapshot {
            updateArtistStat(for: media, onsetMinutes: session.onsetMinutes)
        }

        try? context.save()

        // Trigger a global sync for any newly unlocked artists (debounced in practice)
        Task { await GlobalSyncService.shared.syncIfNeeded() }
    }

    // MARK: - Update artist + track aggregates

    private func updateArtistStat(for media: MediaSnapshot, onsetMinutes: Double) {
        let artistName = media.artistName
        let bundleID = media.appBundleID

        // Fetch or create ArtistStat
        let artistStat: ArtistStat
        let artistFetch = FetchDescriptor<ArtistStat>(
            predicate: #Predicate { $0.artistName == artistName && $0.appBundleID == bundleID }
        )
        if let existing = try? context.fetch(artistFetch).first {
            artistStat = existing
        } else {
            artistStat = ArtistStat(
                artistName: artistName,
                appBundleID: bundleID,
                appDisplayName: media.appDisplayName
            )
            context.insert(artistStat)
        }
        artistStat.recordSession(onsetMinutes: onsetMinutes, track: media)

        // Fetch or create TrackStat
        let trackTitle = media.trackTitle
        let trackStat: TrackStat
        if let existing = artistStat.trackStats.first(where: { $0.trackTitle == trackTitle }) {
            trackStat = existing
        } else {
            trackStat = TrackStat(from: media)
            context.insert(trackStat)
            artistStat.trackStats.append(trackStat)
        }
        trackStat.recordSession(onsetMinutes: onsetMinutes, elapsedSeconds: media.elapsedSeconds)
    }

    // MARK: - Queries

    /// All unlocked artists sorted by Drift score descending.
    func topArtists(limit: Int = 50) throws -> [ArtistStat] {
        var descriptor = FetchDescriptor<ArtistStat>(
            predicate: #Predicate { $0.isUnlocked == true },
            sortBy: [SortDescriptor(\.driftScore, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// All artists including locked ones, for the "Almost there" progress section.
    func allArtists() throws -> [ArtistStat] {
        let descriptor = FetchDescriptor<ArtistStat>(
            sortBy: [SortDescriptor(\.confirmedSessionCount, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Best sleeper track globally — highest Drift score across all unlocked tracks.
    func bestSleeperTrack() throws -> TrackStat? {
        var descriptor = FetchDescriptor<TrackStat>(
            predicate: #Predicate { $0.isUnlocked == true },
            sortBy: [SortDescriptor(\.driftScore, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Best sleeper track for a specific artist.
    func bestSleeperTrack(for artistStat: ArtistStat) -> TrackStat? {
        artistStat.trackStats
            .filter { $0.isUnlocked }
            .max(by: { $0.driftScore < $1.driftScore })
    }

    /// Recent sleep sessions, most recent first.
    func recentSessions(limit: Int = 30) throws -> [SleepSession] {
        var descriptor = FetchDescriptor<SleepSession>(
            sortBy: [SortDescriptor(\.sleepOnsetTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Average onset minutes over the last N days.
    func averageOnset(overLastDays days: Int = 7) throws -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate { $0.sleepOnsetTime > cutoff }
        )
        let sessions = try context.fetch(descriptor)
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.onsetMinutes).reduce(0, +) / Double(sessions.count)
    }
}
