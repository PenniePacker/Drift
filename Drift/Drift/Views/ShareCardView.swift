// ShareCardView.swift
// Drift — Shareable sleep card generation
//
// Three card types, two formats (Stories 9:16, Square 1:1).
// Rendered to UIImage via ImageRenderer, shared via ShareLink
// or deep-linked into Instagram Stories.
//
// Add this file to the main Drift iOS target.

import SwiftData
import SwiftUI

// MARK: - Card type + format

enum ShareCardType {
    case topArtist
    case bestTrack
    case weeklyWrap
}

enum ShareCardFormat {
    case stories    // 1080 × 1920 (9:16)
    case square     // 1080 × 1080 (1:1)

    var size: CGSize {
        switch self {
        case .stories: return CGSize(width: 1080, height: 1920)
        case .square:  return CGSize(width: 1080, height: 1080)
        }
    }

    // Preview size (scaled down for in-app display)
    var previewSize: CGSize {
        switch self {
        case .stories: return CGSize(width: 240, height: 426)
        case .square:  return CGSize(width: 300, height: 300)
        }
    }
}

// MARK: - Share Card View

/// Renders a single share card. Pass scale: 1 for preview, full size for export.
struct ShareCardView: View {

    let type: ShareCardType
    let format: ShareCardFormat
    let artist: ArtistStat?
    let bestTrack: TrackStat?
    let recentSessions: [SleepSession]
    let globalRank: Int

    private var size: CGSize { format.previewSize }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.047, green: 0.051, blue: 0.078)

            // Star field
            StarFieldView()

            // Content
            VStack(alignment: .leading, spacing: 0) {
                switch type {
                case .topArtist:   TopArtistCard(artist: artist, globalRank: globalRank, format: format)
                case .bestTrack:   BestTrackCard(track: bestTrack, format: format)
                case .weeklyWrap:  WeeklyWrapCard(sessions: recentSessions, globalRank: globalRank, format: format)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.055))
    }
}

// MARK: - Star field background

struct StarFieldView: View {
    private let stars: [(CGFloat, CGFloat, CGFloat)] = {
        (0..<50).map { _ in
            (CGFloat.random(in: 0...1),
             CGFloat.random(in: 0...1),
             CGFloat.random(in: 0.04...0.25))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(stars[i].2))
                    .frame(width: i % 3 == 0 ? 3 : 2)
                    .position(
                        x: stars[i].0 * geo.size.width,
                        y: stars[i].1 * geo.size.height
                    )
            }
        }
    }
}

// MARK: - Card 1: Top artist

struct TopArtistCard: View {
    let artist: ArtistStat?
    let globalRank: Int
    let format: ShareCardFormat

    var body: some View {
        let p = format == .stories ? 40.0 : 32.0

        VStack(alignment: .leading, spacing: 0) {
            // App name
            CardHeader()
                .padding(.bottom, format == .stories ? 28 : 20)

            Text("MY SLEEP ARTIST")
                .font(.system(size: format == .stories ? 22 : 18, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 16)

            // Rank pill
            HStack(spacing: 8) {
                Text("#\(globalRank)")
                    .font(.system(size: format == .stories ? 32 : 26, weight: .semibold))
                    .foregroundStyle(Color(red: 0.486, green: 0.557, blue: 0.941))
                Text("worldwide")
                    .font(.system(size: format == .stories ? 18 : 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.098, green: 0.102, blue: 0.18))
            .clipShape(Capsule())
            .padding(.bottom, format == .stories ? 28 : 20)

            if let artist {
                // Artist block
                HStack(spacing: 14) {
                    Text(artist.categoryEmoji)
                        .font(.system(size: format == .stories ? 36 : 28))
                        .frame(width: format == .stories ? 64 : 52,
                               height: format == .stories ? 64 : 52)
                        .background(Color(red: 0.1, green: 0.102, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.artistName)
                            .font(.system(size: format == .stories ? 26 : 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(artist.appDisplayName) · \(artist.confirmedSessionCount) sessions")
                            .font(.system(size: format == .stories ? 18 : 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(artist.averageOnsetMinutes))m")
                            .font(.system(size: format == .stories ? 30 : 24, weight: .semibold))
                            .foregroundStyle(Color(red: 0.298, green: 0.686, blue: 0.455))
                        Text("avg onset")
                            .font(.system(size: format == .stories ? 14 : 11))
                            .foregroundStyle(Color(red: 0.298, green: 0.686, blue: 0.455).opacity(0.7))
                    }
                }
                .padding(format == .stories ? 20 : 16)
                .background(Color(red: 0.071, green: 0.075, blue: 0.118))
                .clipShape(RoundedRectangle(cornerRadius: format == .stories ? 20 : 16))
                .padding(.bottom, format == .stories ? 20 : 14)

                // Stats row
                HStack(spacing: 10) {
                    CardStatBox(label: "Sessions", value: "\(artist.confirmedSessionCount)×", format: format)
                    CardStatBox(label: "Fastest", value: "\(Int(artist.fastestOnsetMinutes))m", format: format)
                    CardStatBox(label: "Drift score", value: String(format: "%.0f", artist.driftScore), format: format)
                }
            }

            Spacer()
            CardFooter()
        }
        .padding(p)
    }
}

// MARK: - Card 2: Best track

struct BestTrackCard: View {
    let track: TrackStat?
    let format: ShareCardFormat

    var body: some View {
        let p = format == .stories ? 40.0 : 32.0

        VStack(alignment: .leading, spacing: 0) {
            CardHeader()
                .padding(.bottom, format == .stories ? 28 : 20)

            Text("MY BEST SLEEPER TRACK")
                .font(.system(size: format == .stories ? 22 : 16, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, format == .stories ? 40 : 24)

            if let track {
                // Big onset number
                VStack(spacing: 8) {
                    Text("ALL-TIME FASTEST")
                        .font(.system(size: format == .stories ? 16 : 12, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(Color(red: 0.298, green: 0.686, blue: 0.455).opacity(0.8))

                    Text("\(Int(track.fastestOnsetMinutes))m")
                        .font(.system(size: format == .stories ? 96 : 72, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.298, green: 0.686, blue: 0.455))
                        .tracking(-3)

                    Text("to fall asleep")
                        .font(.system(size: format == .stories ? 22 : 16))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, format == .stories ? 40 : 28)

                // Track block with progress bar
                VStack(alignment: .leading, spacing: 10) {
                    Text(track.trackTitle)
                        .font(.system(size: format == .stories ? 24 : 18, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.system(size: format == .stories ? 18 : 14))
                        .foregroundStyle(.white.opacity(0.4))

                    if let elapsed = track.averageElapsedSeconds,
                       let total = track.averageElapsedSeconds {
                        let fraction = min(elapsed / max(total * 1.6, 1), 0.95)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Color(red: 0.486, green: 0.557, blue: 0.941))
                                    .frame(width: geo.size.width * fraction, height: 4)
                                Circle()
                                    .fill(Color(red: 0.486, green: 0.557, blue: 0.941))
                                    .frame(width: 10, height: 10)
                                    .offset(x: geo.size.width * fraction - 5, y: -3)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 4)

                        HStack {
                            Text("0:00")
                            Spacer()
                            Text("fell asleep here")
                                .foregroundStyle(Color(red: 0.486, green: 0.557, blue: 0.941))
                            Spacer()
                            Text(formatSeconds(elapsed * 1.6))
                        }
                        .font(.system(size: format == .stories ? 14 : 11))
                        .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(format == .stories ? 22 : 18)
                .background(Color(red: 0.071, green: 0.075, blue: 0.118))
                .clipShape(RoundedRectangle(cornerRadius: format == .stories ? 20 : 16))
            }

            Spacer()
            CardFooter()
        }
        .padding(p)
    }

    private func formatSeconds(_ s: Double) -> String {
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Card 3: Weekly wrap

struct WeeklyWrapCard: View {
    let sessions: [SleepSession]
    let globalRank: Int
    let format: ShareCardFormat

    private var averageOnset: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.onsetMinutes).reduce(0, +) / Double(sessions.count)
    }

    private var bestOnset: Double {
        sessions.map(\.onsetMinutes).min() ?? 0
    }

    private var maxOnset: Double {
        sessions.map(\.onsetMinutes).max() ?? 60
    }

    var body: some View {
        let p = format == .stories ? 40.0 : 32.0

        VStack(alignment: .leading, spacing: 0) {
            CardHeader()
                .padding(.bottom, format == .stories ? 28 : 20)

            Text("MY WEEK IN SLEEP")
                .font(.system(size: format == .stories ? 22 : 16, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, format == .stories ? 32 : 20)

            // Big avg
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int(averageOnset))m")
                    .font(.system(size: format == .stories ? 80 : 60, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.486, green: 0.557, blue: 0.941))
                    .tracking(-2)
                Text("avg onset this week")
                    .font(.system(size: format == .stories ? 20 : 15))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.bottom, format == .stories ? 32 : 20)

            // Bar chart
            HStack(alignment: .bottom, spacing: format == .stories ? 10 : 8) {
                ForEach(Array(sessions.prefix(7).enumerated()), id: \.offset) { index, session in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: session.onsetMinutes))
                            .frame(
                                height: max(16, CGFloat(session.onsetMinutes / maxOnset) * (format == .stories ? 80 : 60))
                            )
                        Text(dayLetter(for: session.sleepOnsetTime))
                            .font(.system(size: format == .stories ? 14 : 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: format == .stories ? 110 : 84)
            .padding(.bottom, format == .stories ? 24 : 16)

            // Stats row
            HStack(spacing: 10) {
                CardStatBox(label: "Nights", value: "\(sessions.prefix(7).count)", format: format)
                CardStatBox(label: "Best night", value: "\(Int(bestOnset))m", format: format)
                CardStatBox(label: "Global rank", value: "#\(globalRank)", format: format)
            }

            Spacer()
            CardFooter()
        }
        .padding(p)
    }

    private func barColor(for onset: Double) -> Color {
        onset < 20
            ? Color(red: 0.486, green: 0.557, blue: 0.941)
            : onset < 35
                ? Color(red: 0.486, green: 0.557, blue: 0.941).opacity(0.5)
                : .white.opacity(0.12)
    }

    private func dayLetter(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }
}

// MARK: - Reusable card components

struct CardHeader: View {
    var body: some View {
        HStack {
            Text("Drift.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            + Text(".")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.486, green: 0.557, blue: 0.941))
            Spacer()
            Text("🌙")
                .font(.system(size: 20))
        }
    }
}

struct CardFooter: View {
    var body: some View {
        Text("Discover what the world sleeps to  ·  drift.app")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.2))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 12)
    }
}

struct CardStatBox: View {
    let label: String
    let value: String
    let format: ShareCardFormat

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: format == .stories ? 26 : 20, weight: .semibold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: format == .stories ? 13 : 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, format == .stories ? 16 : 12)
        .background(Color(red: 0.071, green: 0.075, blue: 0.118))
        .clipShape(RoundedRectangle(cornerRadius: format == .stories ? 16 : 12))
    }
}

// MARK: - Image export + sharing

@MainActor
struct ShareCardExporter {

    /// Renders a ShareCardView to a UIImage at full export resolution.
    static func render(
        type: ShareCardType,
        format: ShareCardFormat,
        artist: ArtistStat?,
        bestTrack: TrackStat?,
        recentSessions: [SleepSession],
        globalRank: Int
    ) -> UIImage? {
        let view = ShareCardView(
            type: type,
            format: format,
            artist: artist,
            bestTrack: bestTrack,
            recentSessions: recentSessions,
            globalRank: globalRank
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }

    /// Opens the native iOS share sheet with the rendered image.
    static func share(
        image: UIImage,
        from viewController: UIViewController? = nil
    ) {
        let activity = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // On iPad, needs a source view for the popover
        if let popover = activity.popoverPresentationController {
            popover.sourceView = viewController?.view
        }

        let presenter = viewController ?? UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController

        presenter?.present(activity, animated: true)
    }

    /// Deep-links into Instagram Stories with the card as a background sticker.
    /// Requires "instagram-stories" added to LSApplicationQueriesSchemes in Info.plist.
    static func shareToInstagramStories(image: UIImage) {
        guard let url = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")"),
              UIApplication.shared.canOpenURL(url),
              let imageData = image.pngData() else {
            // Instagram not installed — fall back to regular share sheet
            share(image: image)
            return
        }

        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]]
        UIPasteboard.general.setItems(pasteboardItems, options: [
            .expirationDate: Date().addingTimeInterval(300)
        ])
        UIApplication.shared.open(url)
    }
}

// MARK: - Share sheet SwiftUI wrapper

struct ShareCardSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ArtistStat> { $0.isUnlocked == true },
           sort: \ArtistStat.driftScore, order: .reverse)
    private var artists: [ArtistStat]

    @Query(filter: #Predicate<SleepSession> { $0.isConfirmed == true },
           sort: \SleepSession.sleepOnsetTime, order: .reverse)
    private var sessions: [SleepSession]

    @State private var selectedType: ShareCardType = .topArtist
    @State private var selectedFormat: ShareCardFormat = .stories
    @State private var currentIndex = 0

    private var topArtist: ArtistStat? { artists.first }
    private var bestTrack: TrackStat? {
        artists.flatMap(\.trackStats).filter(\.isUnlocked).max(by: { $0.driftScore < $1.driftScore })
    }
    private var recentSessions: [SleepSession] { Array(sessions.prefix(7)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Format toggle
                Picker("Format", selection: $selectedFormat) {
                    Text("Stories").tag(ShareCardFormat.stories)
                    Text("Square").tag(ShareCardFormat.square)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Card preview
                TabView(selection: $currentIndex) {
                    ShareCardView(type: .topArtist, format: selectedFormat,
                                  artist: topArtist, bestTrack: bestTrack,
                                  recentSessions: recentSessions, globalRank: 312)
                        .frame(width: selectedFormat.previewSize.width,
                               height: selectedFormat.previewSize.height)
                        .tag(0)

                    ShareCardView(type: .bestTrack, format: selectedFormat,
                                  artist: topArtist, bestTrack: bestTrack,
                                  recentSessions: recentSessions, globalRank: 312)
                        .frame(width: selectedFormat.previewSize.width,
                               height: selectedFormat.previewSize.height)
                        .tag(1)

                    ShareCardView(type: .weeklyWrap, format: selectedFormat,
                                  artist: topArtist, bestTrack: bestTrack,
                                  recentSessions: recentSessions, globalRank: 312)
                        .frame(width: selectedFormat.previewSize.width,
                               height: selectedFormat.previewSize.height)
                        .tag(2)
                }
                .tabViewStyle(.page)
                .frame(height: selectedFormat.previewSize.height + 40)

                // Share buttons
                VStack(spacing: 10) {
                    Button {
                        shareCurrentCard(toInstagram: true)
                    } label: {
                        Label("Share to Instagram Stories", systemImage: "camera.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        shareCurrentCard(toInstagram: false)
                    } label: {
                        Label("Share / Save image", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Share your sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var currentType: ShareCardType {
        switch currentIndex {
        case 0: return .topArtist
        case 1: return .bestTrack
        default: return .weeklyWrap
        }
    }

    private func shareCurrentCard(toInstagram: Bool) {
        guard let image = ShareCardExporter.render(
            type: currentType,
            format: selectedFormat,
            artist: topArtist,
            bestTrack: bestTrack,
            recentSessions: recentSessions,
            globalRank: 312  // replace with real global rank from WorldRankingsView
        ) else { return }

        if toInstagram {
            ShareCardExporter.shareToInstagramStories(image: image)
        } else {
            ShareCardExporter.share(image: image)
        }
    }
}
