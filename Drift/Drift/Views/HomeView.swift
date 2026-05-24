// HomeView.swift
// Drift — Home / dashboard screen

import SwiftUI
import SwiftData

struct HomeView: View {

    @Query(
        filter: #Predicate<SleepSession> { $0.isConfirmed == true },
        sort: \SleepSession.sleepOnsetTime,
        order: .reverse
    ) private var sessions: [SleepSession]

    @Query(
        filter: #Predicate<ArtistStat> { $0.isUnlocked == true },
        sort: \ArtistStat.driftScore,
        order: .reverse
    ) private var topArtists: [ArtistStat]

    // Last 7 sessions for the onset chart
    private var recentSessions: [SleepSession] {
        Array(sessions.prefix(7))
    }

    private var averageOnset: Double {
        guard !recentSessions.isEmpty else { return 0 }
        return recentSessions.map(\.onsetMinutes).reduce(0, +) / Double(recentSessions.count)
    }

    private var lastSession: SleepSession? { sessions.first }

    private var bestSleeper: TrackStat? {
        topArtists
            .flatMap(\.trackStats)
            .filter(\.isUnlocked)
            .max(by: { $0.driftScore < $1.driftScore })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Detection status card
                    DetectionStatusCard(lastSession: lastSession)

                    // MARK: Onset ring + stats
                    OnsetRingCard(
                        averageOnset: averageOnset,
                        lastSession: lastSession
                    )

                    // MARK: Weekly chart
                    if !recentSessions.isEmpty {
                        WeeklyOnsetChart(sessions: recentSessions)
                    }

                    // MARK: Best sleeper card
                    if let best = bestSleeper {
                        BestSleeperCard(track: best)
                    }

                    // MARK: Quick stats row
                    if !topArtists.isEmpty {
                        QuickStatsRow(
                            totalSessions: sessions.count,
                            topArtist: topArtists.first
                        )
                    }

                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Drift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - Detection Status Card

struct DetectionStatusCard: View {
    let lastSession: SleepSession?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep detection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Watching")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Label("Active", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.green.opacity(0.15), in: Capsule())
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Onset Ring Card

struct OnsetRingCard: View {
    let averageOnset: Double
    let lastSession: SleepSession?

    private var onsetText: String {
        averageOnset > 0 ? "\(Int(averageOnset))m" : "—"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(averageOnset / 60.0, 1.0))
                    .stroke(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: averageOnset)

                VStack(spacing: 2) {
                    Text(onsetText)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("avg onset")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Last night's stats
            if let session = lastSession {
                HStack(spacing: 12) {
                    StatPill(
                        icon: "moon.zzz",
                        label: "Last night",
                        value: "\(Int(session.onsetMinutes))m"
                    )
                    if let media = session.mediaSnapshot {
                        StatPill(
                            icon: "music.note",
                            label: "Paused",
                            value: media.appDisplayName
                        )
                    }
                }
            } else {
                Text("No sessions recorded yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weekly Onset Chart

struct WeeklyOnsetChart: View {
    let sessions: [SleepSession]

    private var maxOnset: Double {
        sessions.map(\.onsetMinutes).max() ?? 60
    }

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: session.onsetMinutes))
                            .frame(
                                width: .infinity,
                                height: max(12, CGFloat(session.onsetMinutes / maxOnset) * 60)
                            )
                        Text(dayLetter(for: session.sleepOnsetTime))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for onset: Double) -> Color {
        onset < 20 ? .indigo : onset < 35 ? .indigo.opacity(0.6) : .secondary.opacity(0.3)
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

// MARK: - Best Sleeper Card

struct BestSleeperCard: View {
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
                Text("avg \(Int(track.averageOnsetMinutes))m onset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.indigo.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text("🎵")
                            .font(.title2)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.trackTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                StatMini(label: "Sessions", value: "\(track.confirmedSessionCount)×")
                StatMini(label: "Fastest", value: "\(Int(track.fastestOnsetMinutes))m")
                StatMini(label: "Avg position", value: track.averageElapsedSeconds.map { formatSeconds($0) } ?? "—")
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
                Label(isPlaying ? "Stop" : "Play my best sleeper", systemImage: isPlaying ? "stop.fill" : "play.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatSeconds(_ s: Double) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let totalSessions: Int
    let topArtist: ArtistStat?

    var body: some View {
        HStack(spacing: 12) {
            StatCard(label: "Total sessions", value: "\(totalSessions)", icon: "moon.zzz.fill")
            if let artist = topArtist {
                StatCard(label: "Top artist", value: artist.artistName, icon: "music.mic")
            }
        }
    }
}

// MARK: - Reusable sub-components

struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatMini: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
