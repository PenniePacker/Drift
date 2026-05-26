// HistoryView.swift
// Drift — Sleep history screen
//
// Shows all recorded sleep sessions, most recent first.
// Each session shows: date, onset time, media playing, position in track.

import SwiftUI
import SwiftData

struct HistoryView: View {

    @Query(
        filter: #Predicate<SleepSession> { $0.isConfirmed == true },
        sort: \SleepSession.sleepOnsetTime,
        order: .reverse
    ) private var sessions: [SleepSession]

    private var averageOnset: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.onsetMinutes).reduce(0, +) / Double(sessions.count)
    }

    private var sessionsByMonth: [(String, [SleepSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: sessions) { formatter.string(from: $0.sleepOnsetTime) }
        return grouped
            .sorted { lhs, rhs in
                // Sort months descending
                let lhsDate = formatter.date(from: lhs.key) ?? .distantPast
                let rhsDate = formatter.date(from: rhs.key) ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Summary row
                    if !sessions.isEmpty {
                        HStack(spacing: 12) {
                            StatCard(label: "Total sessions", value: "\(sessions.count)", icon: "moon.zzz.fill")
                            StatCard(label: "Avg onset", value: "\(Int(averageOnset))m", icon: "timer")
                        }
                        .padding(.horizontal)
                    }

                    // Sessions grouped by month
                    if sessions.isEmpty {
                        EmptyHistoryView()
                            .padding(.horizontal)
                    } else {
                        ForEach(sessionsByMonth, id: \.0) { month, monthSessions in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(month)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                                    .padding(.horizontal)

                                ForEach(monthSessions) { session in
                                    SessionCard(session: session)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 32)
                .padding(.top, 8)
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack {
                Text(session.sleepOnsetTime, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Fell asleep in \(Int(session.onsetMinutes))m")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.indigo.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 14)

            // Media block
            if let media = session.mediaSnapshot {
                MediaDetailBlock(media: media)
                    .padding(14)
            } else {
                Text("No media playing")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(14)
            }

            // Sleep stage badge + quality rating
            HStack {
                Label(friendlySleepStage(session.sleepStage), systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                if let rating = session.qualityRating {
                    Text(String(repeating: "🌙", count: rating))
                        .font(.caption)
                }
                Text(session.sleepOnsetTime, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func friendlySleepStage(_ stage: String) -> String {
        switch stage {
        case "asleepCore":          return "Core sleep detected"
        case "asleepDeep":          return "Deep sleep detected"
        case "asleepREM":           return "REM sleep detected"
        case "asleepUnspecified":   return "Sleep detected"
        default:                    return "Sleep detected"
        }
    }
}

// MARK: - Media Detail Block

struct MediaDetailBlock: View {
    let media: MediaSnapshot

    private var progressFraction: Double? {
        guard let elapsed = media.elapsedSeconds,
              let duration = media.durationSeconds,
              duration > 0 else { return nil }
        return elapsed / duration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // App label
            HStack(spacing: 6) {
                Image(systemName: appIcon(for: media.appBundleID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(media.appDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Track row
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: trackIcon(for: media.appBundleID))
                            .foregroundStyle(.indigo)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(media.trackTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(media.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Position in track
                VStack(alignment: .trailing, spacing: 2) {
                    if media.isLiveStream {
                        Text("Live")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    } else if let elapsed = media.elapsedSeconds {
                        Text(formatSeconds(elapsed))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.indigo)
                    }
                    Text("into track")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            if media.isLiveStream {
                HStack {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 3)
                        .clipShape(Capsule())
                    Text("Live stream · no position tracked")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if let fraction = progressFraction {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.secondary.opacity(0.15))
                                .frame(height: 4)
                            Capsule()
                                .fill(.indigo)
                                .frame(width: geo.size.width * fraction, height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("0:00")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("↑ paused here")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                        Spacer()
                        if let duration = media.durationSeconds {
                            Text(formatSeconds(duration))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Deep link
            if let uri = media.deepLinkURI, let url = URL(string: uri) {
                Link(destination: url) {
                    Label("Open in \(media.appDisplayName)", systemImage: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
            }
        }
    }

    private func formatSeconds(_ s: Double) -> String {
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    private func appIcon(for bundleID: String) -> String {
        switch bundleID {
        case "com.spotify.client":      return "music.note"
        case "com.apple.podcasts":      return "mic.fill"
        case "com.apple.Music":         return "music.note"
        case "com.google.ios.youtube":  return "play.rectangle.fill"
        default:                        return "headphones"
        }
    }

    private func trackIcon(for bundleID: String) -> String {
        switch bundleID {
        case "com.apple.podcasts":      return "mic.fill"
        case "com.google.ios.youtube":  return "play.rectangle"
        default:                        return "music.note"
        }
    }
}

// MARK: - Empty state

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.headline)
            Text("Drift will record your first session tonight. Make sure media is playing when you get into bed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}
