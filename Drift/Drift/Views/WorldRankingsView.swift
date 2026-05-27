// WorldRankingsView.swift
// Drift — Global leaderboard screen
//
// Fetches the global_leaderboard view from Supabase and displays
// ranked artists, podcasts, and tracks. Annotates entries that
// match the user's own artists with a "you" badge.

import SwiftUI
import SwiftData

// Set to false once real users are contributing to Supabase.
private let useMockData = true

// MARK: - Mock leaderboard data

private enum MockLeaderboard {

    static func entries(for category: GlobalSyncService.LeaderboardCategory) -> [GlobalLeaderboardEntry] {
        switch category {
        case .artists:  return artists
        case .podcasts: return podcasts
        case .tracks:   return tracks
        }
    }

    // Drift score = sessions × (30 / avgOnset) — higher is better
    // Score is pre-rounded to 1 decimal for realism

    static let artists: [GlobalLeaderboardEntry] = [
        .mock("Brian Eno",       app: "Spotify",      emoji: "🎹", sessions: 3_842, contributors: 512, avgOnset: 11.4, score: 10_110),
        .mock("Nils Frahm",      app: "Spotify",      emoji: "🎹", sessions: 2_907, contributors: 389, avgOnset: 13.2, score: 6_607),
        .mock("Max Richter",     app: "Apple Music",  emoji: "🎻", sessions: 2_561, contributors: 341, avgOnset: 14.8, score: 5_192),
        .mock("Lofi Girl",       app: "YouTube",      emoji: "🎧", sessions: 4_103, contributors: 621, avgOnset: 18.6, score: 6_618),
        .mock("James Blake",     app: "Spotify",      emoji: "🎹", sessions: 1_874, contributors: 253, avgOnset: 16.9, score: 3_328),
        .mock("Taylor Swift",    app: "Spotify",      emoji: "🎶", sessions: 1_492, contributors: 198, avgOnset: 22.4, score: 1_997),
        .mock("Aphex Twin",      app: "Spotify",      emoji: "🎵", sessions: 1_203, contributors: 167, avgOnset: 17.3, score: 2_086),
        .mock("Ólafur Arnalds",  app: "Apple Music",  emoji: "🎻", sessions:   988, contributors: 134, avgOnset: 19.7, score: 1_504),
        .mock("Johann Johannsson", app: "Spotify",    emoji: "🎻", sessions:   741, contributors: 102, avgOnset: 21.1, score: 1_054),
        .mock("Erik Satie",      app: "Apple Music",  emoji: "🎹", sessions:   604, contributors:  89, avgOnset: 15.3, score: 1_184),
    ]

    static let podcasts: [GlobalLeaderboardEntry] = [
        .mock("Huberman Lab",    app: "Apple Podcasts", emoji: "🧠", sessions: 5_219, contributors: 743, avgOnset: 17.2, score: 9_103),
        .mock("Joe Rogan (JRE)", app: "Spotify",        emoji: "🎙️", sessions: 4_887, contributors: 698, avgOnset: 20.4, score: 7_191),
        .mock("Sleep With Me",   app: "Apple Podcasts", emoji: "😴", sessions: 3_654, contributors: 501, avgOnset: 12.8, score: 8_563),
        .mock("Lex Fridman",     app: "Spotify",        emoji: "🤖", sessions: 2_931, contributors: 412, avgOnset: 22.1, score: 3_980),
        .mock("Serial",          app: "Apple Podcasts", emoji: "🔍", sessions: 1_847, contributors: 261, avgOnset: 24.7, score: 2_244),
        .mock("Nothing Much Happens", app: "Apple Podcasts", emoji: "🌿", sessions: 1_603, contributors: 229, avgOnset: 14.1, score: 3_413),
        .mock("Daily Meditation", app: "Spotify",       emoji: "🧘", sessions: 1_244, contributors: 177, avgOnset: 16.3, score: 2_289),
        .mock("Stuff You Missed in History", app: "Apple Podcasts", emoji: "📜", sessions: 1_089, contributors: 155, avgOnset: 23.8, score: 1_372),
        .mock("Conan O'Brien Needs a Friend", app: "Spotify", emoji: "😂", sessions:   876, contributors: 124, avgOnset: 26.2, score: 1_003),
        .mock("Philosophy Bites", app: "Apple Podcasts", emoji: "💭", sessions:   712, contributors: 101, avgOnset: 19.4, score: 1_101),
    ]

    static let tracks: [GlobalLeaderboardEntry] = [
        .mock("Weightless",                  app: "Spotify",      emoji: "🎵", sessions: 6_102, contributors: 891, avgOnset:  8.3, score: 22_057),
        .mock("On the Nature of Daylight",   app: "Apple Music",  emoji: "🎻", sessions: 3_874, contributors: 541, avgOnset: 10.7, score: 10_856),
        .mock("Retrograde",                  app: "Spotify",      emoji: "🎹", sessions: 2_941, contributors: 407, avgOnset: 14.1, score: 6_257),
        .mock("Gymnopédie No.1",             app: "Apple Music",  emoji: "🎹", sessions: 2_487, contributors: 352, avgOnset: 12.4, score: 6_021),
        .mock("Spiegel im Spiegel",          app: "Spotify",      emoji: "🎻", sessions: 1_993, contributors: 283, avgOnset: 11.8, score: 5_067),
        .mock("experience",                  app: "Apple Music",  emoji: "🎹", sessions: 1_744, contributors: 248, avgOnset: 13.5, score: 3_876),
        .mock("Avril 14th",                  app: "Spotify",      emoji: "🎵", sessions: 1_502, contributors: 214, avgOnset: 15.2, score: 2_962),
        .mock("Comptine d'un autre été",     app: "Apple Music",  emoji: "🎹", sessions: 1_287, contributors: 183, avgOnset: 16.7, score: 2_312),
        .mock("Sleep",                       app: "Spotify",      emoji: "🎻", sessions: 1_044, contributors: 149, avgOnset: 18.3, score: 1_712),
        .mock("Night Owl",                   app: "Spotify",      emoji: "🦉", sessions:   831, contributors: 119, avgOnset: 20.1, score: 1_241),
    ]
}

private extension GlobalLeaderboardEntry {
    static func mock(
        _ name: String,
        app: String,
        emoji: String,
        sessions: Int,
        contributors: Int,
        avgOnset: Double,
        score: Int
    ) -> GlobalLeaderboardEntry {
        GlobalLeaderboardEntry(
            artistName: name,
            appBundleID: bundleID(for: app),
            appDisplayName: app,
            categoryEmoji: emoji,
            totalSessions: sessions,
            averageOnsetMinutes: avgOnset,
            globalDriftScore: Double(score),
            contributorCount: contributors
        )
    }

    private static func bundleID(for app: String) -> String {
        switch app {
        case "Spotify":        return "com.spotify.client"
        case "Apple Music":    return "com.apple.Music"
        case "Apple Podcasts": return "com.apple.podcasts"
        case "YouTube":        return "com.google.ios.youtube"
        default:               return "com.drift.unknown"
        }
    }
}

struct WorldRankingsView: View {

    @Query(
        filter: #Predicate<ArtistStat> { $0.isUnlocked == true },
        sort: \ArtistStat.driftScore,
        order: .reverse
    ) private var myArtists: [ArtistStat]

    @State private var selectedCategory: GlobalSyncService.LeaderboardCategory = .artists
    @State private var entries: [GlobalLeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contributorCount: Int = 0
    @State private var searchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    private var myArtistNames: Set<String> {
        Set(myArtists.map(\.artistName))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Privacy note
                    PrivacyNoteView()
                        .padding(.horizontal)

                    // Your rank card
                    if let myRank = myRank {
                        MyRankCard(rank: myRank, artist: myArtists.first)
                            .padding(.horizontal)
                    }

                    // Contributor count
                    if contributorCount > 0 {
                        Text("\(contributorCount.formatted()) Drifters worldwide")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    // Search field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        TextField("Search artists, podcasts, tracks…", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .onChange(of: searchText) { _, newValue in
                        searchDebounceTask?.cancel()
                        searchDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            loadLeaderboard(search: newValue.isEmpty ? nil : newValue)
                        }
                    }

                    // Category tabs
                    CategoryTabBar(selected: $selectedCategory) {
                        searchText = ""
                        loadLeaderboard()
                    }
                    .padding(.horizontal)
                    .opacity(searchText.isEmpty ? 1 : 0.4)

                    // Leaderboard entries
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        ErrorView(message: error) { loadLeaderboard() }
                            .padding(.horizontal)
                    } else if entries.isEmpty {
                        if searchText.isEmpty {
                            EmptyLeaderboardView()
                                .padding(.horizontal)
                        } else {
                            NoSearchMatchInvitation(query: searchText)
                                .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                GlobalEntryRow(
                                    rank: index + 1,
                                    entry: entry,
                                    isYou: myArtistNames.contains(entry.artistName)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("World rankings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task { await loadAll() }
            .refreshable { await loadAll() }
        }
    }

    // Find this user's best artist rank in the global list
    private var myRank: Int? {
        guard !myArtistNames.isEmpty else { return nil }
        return entries.firstIndex(where: { myArtistNames.contains($0.artistName) }).map { $0 + 1 }
    }

    @MainActor
    private func loadAll() async {
        loadLeaderboard()
        await loadStats()
    }

    private func loadLeaderboard(search: String? = nil) {
        isLoading = true
        errorMessage = nil
        let isSearch = search != nil && !search!.isEmpty
        Task {
            do {
                let result = try await GlobalSyncService.shared.fetchLeaderboard(category: selectedCategory, search: search)
                await MainActor.run {
                    entries = (useMockData && result.isEmpty && !isSearch)
                        ? MockLeaderboard.entries(for: selectedCategory)
                        : result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    entries = (useMockData && !isSearch) ? MockLeaderboard.entries(for: selectedCategory) : []
                    errorMessage = useMockData ? nil : "Couldn't load rankings. Pull to retry."
                    isLoading = false
                }
            }
        }
    }

    private func loadStats() async {
        if useMockData && contributorCount == 0 {
            // Sum unique contributors across the mock artists tab as a placeholder
            let total = MockLeaderboard.artists.map(\.contributorCount).reduce(0, +)
            await MainActor.run { contributorCount = total }
            return
        }
        guard let url = URL(string: "\(Config.supabaseBaseURL)/rpc/leaderboard_stats") else { return }
        var request = URLRequest(url: url)
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpMethod = "POST"
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let json = try? JSONDecoder().decode([String: Int].self, from: data),
           let count = json["total_contributors"] {
            await MainActor.run { contributorCount = count }
        }
    }
}

// MARK: - Privacy Note

struct PrivacyNoteView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Text("Anonymous only. Drift shares your artist counts and averages — never your name, device, or sleep times.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - My Rank Card

struct MyRankCard: View {
    let rank: Int
    let artist: ArtistStat?

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your global rank")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let artist = artist {
                    Text("via \(artist.artistName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let artist = artist {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(artist.averageOnsetMinutes))m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text("avg to drift off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.indigo.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Category Tab Bar

struct CategoryTabBar: View {
    @Binding var selected: GlobalSyncService.LeaderboardCategory
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach([
                GlobalSyncService.LeaderboardCategory.artists,
                .podcasts,
                .tracks
            ], id: \.rawValue) { category in
                Button {
                    selected = category
                    onChange()
                } label: {
                    Text(category.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(selected == category ? .semibold : .regular)
                        .foregroundStyle(selected == category ? .indigo : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected == category
                                ? Color.indigo.opacity(0.12)
                                : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Global Entry Row

struct GlobalEntryRow: View {
    let rank: Int
    let entry: GlobalLeaderboardEntry
    let isYou: Bool

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
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 28)

            Text(entry.categoryEmoji)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(.secondary.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.artistName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if isYou {
                        Text("you")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.indigo.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(entry.appDisplayName) · \(entry.contributorCount) Drifters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.totalSessions.formatted())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Drifts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("avg \(Int(entry.averageOnsetMinutes))m")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            isYou
                ? Color.indigo.opacity(0.08)
                : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            isYou
                ? RoundedRectangle(cornerRadius: 14).stroke(.indigo.opacity(0.2), lineWidth: 0.5)
                : nil
        )
    }
}

// MARK: - Supporting views

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No entries yet")
                .font(.headline)
            Text("Be the first to contribute to the world rankings by recording sleep Drifts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct NoSearchMatchInvitation: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("No Drifter has drifted off to anything matching '\(query)' yet.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Drift off to them tonight and you'll be the first to put them on the map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
