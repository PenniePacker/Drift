// ArtistStatsView.swift
// Drift — Artist leaderboard + per-artist track drill-down

import SwiftUI
import SwiftData

struct ArtistStatsView: View {

    @Query(
        filter: #Predicate<ArtistStat> { $0.isUnlocked == true },
        sort: \ArtistStat.driftScore,
        order: .reverse
    ) private var unlockedArtists: [ArtistStat]

    @Query(
        filter: #Predicate<ArtistStat> { $0.isUnlocked == false },
        sort: \ArtistStat.confirmedSessionCount,
        order: .reverse
    ) private var lockedArtists: [ArtistStat]

    private var bestSleeperTrack: TrackStat? {
        unlockedArtists
            .flatMap(\.trackStats)
            .filter(\.isUnlocked)
            .max(by: { $0.driftScore < $1.driftScore })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Discover which artists and shows help you drift off fastest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Global best sleeper banner
                    if let best = bestSleeperTrack {
                        GlobalBestSleeperBanner(track: best)
                            .padding(.horizontal)
                    }

                    // Unlocked artists
                    if !unlockedArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "All artists")
                                .padding(.horizontal)

                            ForEach(Array(unlockedArtists.enumerated()), id: \.element.id) { index, artist in
                                NavigationLink(destination: ArtistDrillDownView(artist: artist)) {
                                    ArtistRow(rank: index + 1, artist: artist, maxScore: unlockedArtists.first?.driftScore ?? 1)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Locked / in-progress artists
                    if !lockedArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Almost there")
                                .padding(.horizontal)

                            ForEach(lockedArtists.prefix(3)) { artist in
                                LockedArtistCard(artist: artist)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Empty state
                    if unlockedArtists.isEmpty && lockedArtists.isEmpty {
                        EmptyArtistsView()
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Sleep artists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - Global Best Sleeper Banner

struct GlobalBestSleeperBanner: View {
    let track: TrackStat
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your best sleeper", systemImage: "star.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                Spacer()
                Text("avg \(Int(track.averageOnsetMinutes))m to drift off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.green)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.trackTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                StatMini(label: "Drifts", value: "\(track.confirmedSessionCount)×")
                StatMini(label: "avg to drift off", value: "\(Int(track.averageOnsetMinutes))m")
                StatMini(label: "Fastest", value: "\(Int(track.fastestOnsetMinutes))m")
            }

            Button {
                isPlaying.toggle()
                if let uri = track.deepLinkURI, let url = URL(string: uri) {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            } label: {
                Label(
                    isPlaying ? "Stop" : "Play my best sleeper",
                    systemImage: isPlaying ? "stop.fill" : "play.fill"
                )
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.green.opacity(0.2), lineWidth: 0.5)
        }
    }
}

// MARK: - Artist Row

struct ArtistRow: View {
    let rank: Int
    let artist: ArtistStat
    let maxScore: Double

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.7, green: 0.4, blue: 0.2)
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 20)

            Text(artist.categoryEmoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(.secondary.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.artistName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(artist.appDisplayName) · \(artist.confirmedSessionCount) \(artist.confirmedSessionCount == 1 ? "Drift" : "Drifts")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(artist.confirmedSessionCount)×")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                Text("avg \(Int(artist.averageOnsetMinutes))m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Locked Artist Card

struct LockedArtistCard: View {
    let artist: ArtistStat

    private var progress: Double {
        Double(artist.confirmedSessionCount) / 3.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(artist.categoryEmoji)
                    .font(.title3)
                    .opacity(0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.artistName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("\(artist.confirmedSessionCount) of 3 Drifts needed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                HStack {
                    Text("Drifts confirmed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(artist.confirmedSessionCount) / 3")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.indigo)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut, value: progress)
                    }
                }
                .frame(height: 6)

                // Pip dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i < artist.confirmedSessionCount ? Color.indigo : Color.secondary.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                    }
                }

                Text("Sleep to this artist one more time to unlock full stats")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Artist Drill-Down View

struct ArtistDrillDownView: View {
    let artist: ArtistStat
    @State private var isPlaying = false

    private var sortedTracks: [TrackStat] {
        artist.trackStats
            .filter { $0.confirmedSessionCount > 0 }
            .sorted { $0.averageOnsetMinutes < $1.averageOnsetMinutes }
    }

    private var bestTrack: TrackStat? {
        artist.trackStats
            .filter(\.isUnlocked)
            .min(by: { $0.averageOnsetMinutes < $1.averageOnsetMinutes })
    }

    private var maxOnset: Double {
        sortedTracks.map(\.averageOnsetMinutes).max() ?? 30
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Stat trio
                HStack(spacing: 10) {
                    StatCard(label: "Drifts", value: "\(artist.confirmedSessionCount)", icon: "moon.zzz.fill")
                    StatCard(label: "avg to drift off", value: "\(Int(artist.averageOnsetMinutes))m", icon: "timer")
                    StatCard(label: "Best", value: "\(Int(artist.fastestOnsetMinutes))m", icon: "bolt.fill")
                }
                .padding(.horizontal)

                // Best sleeper for this artist
                if let best = bestTrack {
                    ArtistBestSleeperCard(track: best)
                        .padding(.horizontal)
                }

                // Track list
                if !sortedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "What puts you to sleep fastest")
                            .padding(.horizontal)

                        ForEach(Array(sortedTracks.enumerated()), id: \.element.id) { index, track in
                            TrackEntryRow(rank: index + 1, track: track, maxOnset: maxOnset, isBest: track.id == bestTrack?.id)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle(artist.artistName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Artist Best Sleeper Card (compact, in drill-down)

struct ArtistBestSleeperCard: View {
    let track: TrackStat
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Best sleeper in this artist", systemImage: "star.fill")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)

            Text(track.trackTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text("avg \(Int(track.averageOnsetMinutes))m to drift off · \(track.confirmedSessionCount) \(track.confirmedSessionCount == 1 ? "Drift" : "Drifts")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isPlaying.toggle()
                if let uri = track.deepLinkURI, let url = URL(string: uri) {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            } label: {
                Label(
                    isPlaying ? "Stop" : "Play my best sleeper",
                    systemImage: isPlaying ? "stop.fill" : "play.fill"
                )
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.green, in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding()
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.green.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Track Entry Row

struct TrackEntryRow: View {
    let rank: Int
    let track: TrackStat
    let maxOnset: Double
    let isBest: Bool

    private var barFraction: Double {
        guard maxOnset > 0 else { return 0 }
        return track.averageOnsetMinutes / maxOnset
    }

    private var barColor: Color {
        isBest ? .green : (barFraction < 0.5 ? .indigo : .secondary.opacity(0.4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                RoundedRectangle(cornerRadius: 6)
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.trackTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("Drifted off \(track.averageElapsedSeconds.map { roughTime($0) } ?? "—") · \(track.confirmedSessionCount) \(track.confirmedSessionCount == 1 ? "Drift" : "Drifts")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(track.averageOnsetMinutes))m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isBest ? .green : .primary)
                    Text("avg to drift off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.12)).frame(height: 3)
                        Capsule().fill(barColor).frame(width: geo.size.width * barFraction, height: 3)
                    }
                }
                .frame(height: 3)

                Text("\(track.confirmedSessionCount) \(track.confirmedSessionCount == 1 ? "Drift" : "Drifts")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)

                if isBest {
                    Label("Best", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private func roughTime(_ s: Double) -> String {
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 { return "around \(h)h \(m)m in" }
        if m >= 10 { return "around \(m)m in" }
        return "around \(m)m \(sec)s in"
    }
}

// MARK: - Empty state

struct EmptyArtistsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.mic")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No artists yet")
                .font(.headline)
            Text("Artists appear after Drift records Drifts. You need 3 confirmed Drifts per artist to unlock their stats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
