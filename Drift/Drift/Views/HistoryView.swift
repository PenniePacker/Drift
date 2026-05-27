// HistoryView.swift
// Drift — Sleep history screen
//
// Shows all recorded sleep sessions, most recent first.
// Each session shows: date, onset time, media playing, position in track.

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct HistoryView: View {

    @Query(
        filter: #Predicate<SleepSession> { $0.isConfirmed == true && $0.onsetMinutes > 0 },
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
                            StatCard(label: "Total Drifts", value: "\(sessions.count)", icon: "moon.zzz.fill")
                            StatCard(label: "avg to drift off", value: "\(Int(averageOnset))m", icon: "timer")
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
                Text("Drifted off in \(Int(session.onsetMinutes))m")
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
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.08))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "moon.zzz.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fell asleep to silence")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("No media was playing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
            }

            // Sleep stage badge + quality rating
            HStack {
                Label(friendlySleepStage(session.sleepStage), systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                if let rating = session.qualityRating {
                    HStack(spacing: 2) {
                        ForEach(0..<rating, id: \.self) { _ in
                            Image("DriftCrescent")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
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

            // Track row — title tap opens track, artist name tap opens artist/show page
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: trackIcon(for: media.appBundleID))
                            .foregroundStyle(.indigo)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    // Track title — opens track (with timestamp where applicable)
                    Button {
                        if let url = trackDeepLink(media: media) {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #else
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        Text(media.trackTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    // Artist/show name — opens artist/channel/show page
                    Button {
                        if let url = artistDeepLink(name: media.artistName, appBundleID: media.appBundleID) {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #else
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(media.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Position in track
                VStack(alignment: .trailing, spacing: 2) {
                    if media.isLiveStream {
                        Text("Live")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Text("into track")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let elapsed = media.elapsedSeconds {
                        Text("drifted off at")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatSeconds(elapsed))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.indigo)
                    }
                }
            }

            // Progress bar — fill end and "paused here" label are the same point
            if media.isLiveStream {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 3)
                    Text("Live stream · no position tracked")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if let frac = progressFraction {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let barW    = geo.size.width
                        let fillW   = barW * frac
                        let lw: CGFloat = 78
                        // Center label on the dot, clamped to bar bounds
                        let dotCenter: CGFloat = min(max(fillW, 4), barW - 4)
                        let labelX  = min(max(dotCenter - lw / 2, 0), barW - lw)
                        let aboveBar = frac > 0.85
                        ZStack(alignment: .topLeading) {
                            Capsule().fill(.secondary.opacity(0.15))
                                .frame(width: barW, height: 4)
                            Capsule().fill(.indigo)
                                .frame(width: max(fillW, 0), height: 4)
                            Circle().fill(.indigo)
                                .frame(width: 8, height: 8)
                                .offset(x: max(fillW - 4, 0), y: -2)
                            Text("drifted off")
                                .font(.caption2).foregroundStyle(.indigo)
                                .frame(width: lw, alignment: .center)
                                .offset(x: labelX, y: aboveBar ? -18 : 12)
                        }
                    }
                    .frame(height: 28)
                    if let dur = media.durationSeconds {
                        HStack {
                            Spacer()
                            Text(formatSeconds(dur))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 12)
                    }
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

    private func trackDeepLink(media: MediaSnapshot) -> URL? {
        let elapsed = Int(media.elapsedSeconds ?? 0)
        let duration = media.durationSeconds ?? 0
        let isShort = duration > 0 && duration < 600

        if let uri = media.deepLinkURI, !uri.isEmpty {
            if media.appBundleID == "com.google.ios.youtube", !media.isLiveStream, !isShort, elapsed > 0 {
                let separator = uri.contains("?") ? "&" : "?"
                if let url = URL(string: uri + separator + "t=\(elapsed)s") { return url }
            }
            return URL(string: uri)
        }
        guard let encoded = media.trackTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        switch media.appBundleID {
        case "com.spotify.client":
            return URL(string: "spotify:search:\(encoded)")
        case "com.apple.podcasts":
            let encodedArtist = media.artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? encoded
            return URL(string: "https://podcasts.apple.com/search?term=\(encodedArtist)")
        case "com.apple.Music":
            return URL(string: "https://music.apple.com/search?term=\(encoded)")
        case "com.google.ios.youtube":
            let encodedArtist = media.artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.youtube.com/results?search_query=\(encodedArtist)")
        default:
            return URL(string: "https://music.apple.com/search?term=\(encoded)")
        }
    }

    private func artistDeepLink(name: String, appBundleID: String) -> URL? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        switch appBundleID {
        case "com.spotify.client":      return URL(string: "spotify:search:\(encoded)")
        case "com.apple.podcasts":      return URL(string: "https://podcasts.apple.com/search?term=\(encoded)")
        case "com.apple.Music":         return URL(string: "https://music.apple.com/search?term=\(encoded)")
        default:                        return URL(string: "https://music.apple.com/search?term=\(encoded)")
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
            Text("Drift will record your first Drift tonight. Make sure media is playing when you get into bed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}
