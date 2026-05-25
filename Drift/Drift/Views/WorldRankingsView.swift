// WorldRankingsView.swift
// Drift — Global leaderboard screen
//
// Fetches the global_leaderboard view from Supabase and displays
// ranked artists, podcasts, and tracks. Annotates entries that
// match the user's own artists with a "you" badge.

import SwiftUI
import SwiftData

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
                        Text("\(contributorCount.formatted()) users contributing worldwide")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    // Category tabs
                    CategoryTabBar(selected: $selectedCategory) {
                        loadLeaderboard()
                    }
                    .padding(.horizontal)

                    // Leaderboard entries
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        ErrorView(message: error) { loadLeaderboard() }
                            .padding(.horizontal)
                    } else if entries.isEmpty {
                        EmptyLeaderboardView()
                            .padding(.horizontal)
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

    private func loadLeaderboard() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await GlobalSyncService.shared.fetchLeaderboard(category: selectedCategory)
                await MainActor.run {
                    entries = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't load rankings. Pull to retry."
                    isLoading = false
                }
            }
        }
    }

    private func loadStats() async {
        // leaderboard_stats RPC — optional, graceful failure
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
                    Text("avg onset")
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
                Text("\(entry.appDisplayName) · \(entry.contributorCount) contributors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.totalSessions.formatted())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("sessions")
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
            Text("Be the first to contribute to the world rankings by recording sleep sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
