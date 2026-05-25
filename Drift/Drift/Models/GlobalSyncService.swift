// GlobalSyncService.swift
// Drift — Anonymous global leaderboard sync
//
// Architecture: Supabase (Postgres + REST) is the recommended backend.
// Free tier handles ~50k MAU comfortably. Schema in /Backend/supabase_schema.sql
//
// Privacy model:
//   - No user ID, device ID, or personal data is ever sent
//   - Each upload is a contribution_token (random UUID generated once per install,
//     stored in Keychain) — allows upserts without linkability to a person
//   - Only aggregated stats are sent: artist name, app, session count, avg onset, score

import Foundation
import SwiftData

// MARK: - Contribution payload (what gets sent to the server)

struct ArtistContribution: Codable {
    let contributionToken: String   // random per-install UUID, not user-linked
    let artistName: String
    let appBundleID: String
    let appDisplayName: String
    let categoryEmoji: String
    let sessionCount: Int
    let averageOnsetMinutes: Double
    let driftScore: Double
    let appVersion: String
}

// MARK: - Global leaderboard response

struct GlobalLeaderboardEntry: Codable, Identifiable {
    var id: String { artistName + appBundleID }
    let artistName: String
    let appBundleID: String
    let appDisplayName: String
    let categoryEmoji: String
    let totalSessions: Int          // sum across all contributors
    let averageOnsetMinutes: Double // weighted average across contributors
    let globalDriftScore: Double    // aggregate score
    let contributorCount: Int       // how many users have this artist
}

// MARK: - GlobalSyncService

actor GlobalSyncService {

    static let shared = GlobalSyncService()

    private let baseURL = URL(string: Config.supabaseBaseURL)!
    private let anonKey = Config.supabaseAnonKey

    // Random UUID stored in Keychain. Never changes. Not linked to any identity.
    private var contributionToken: String {
        if let stored = KeychainHelper.read(key: "drift_contribution_token") { return stored }
        let token = UUID().uuidString
        KeychainHelper.write(key: "drift_contribution_token", value: token)
        return token
    }

    // MARK: - Sync

    /// Upload any artist stats that have changed since last sync.
    /// Called automatically after each new sleep session.
    func syncIfNeeded() async {
        let store = await DriftStore.shared
        guard let artists = try? await store.topArtists() else { return }

            // Only sync artists that have new sessions since last contribution upload
        for artist in artists {
            let contribution = await lastContribution(for: artist)
            if contribution == nil || artist.confirmedSessionCount > contribution!.submittedSessionCount {
                await uploadContribution(for: artist)
            }
        }
    }

    private func uploadContribution(for artist: ArtistStat) async {
        let payload = ArtistContribution(
            contributionToken: contributionToken,
            artistName: artist.artistName,
            appBundleID: artist.appBundleID,
            appDisplayName: artist.appDisplayName,
            categoryEmoji: artist.categoryEmoji,
            sessionCount: artist.confirmedSessionCount,
            averageOnsetMinutes: artist.averageOnsetMinutes,
            driftScore: artist.driftScore,
            appVersion: Bundle.main.shortVersionString
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("artist_contributions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 {
                await recordContribution(for: artist)
            }
        } catch {
            print("Sync failed for \(artist.artistName): \(error)")
        }
    }

    // MARK: - Fetch global leaderboard

    func fetchLeaderboard(category: LeaderboardCategory, limit: Int = 50) async throws -> [GlobalLeaderboardEntry] {
        var components = URLComponents(url: baseURL.appendingPathComponent("global_leaderboard"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "category", value: "eq.\(category.rawValue)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "global_drift_score.desc")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([GlobalLeaderboardEntry].self, from: data)
    }

    enum LeaderboardCategory: String {
        case artists, podcasts, tracks
    }

    // MARK: - Helpers

    @MainActor
    private func lastContribution(for artist: ArtistStat) -> GlobalContribution? {
        let name = artist.artistName
        let bundle = artist.appBundleID
        let descriptor = FetchDescriptor<GlobalContribution>(
            predicate: #Predicate { $0.artistName == name && $0.appBundleID == bundle }
        )
        return try? DriftStore.shared.context.fetch(descriptor).first
    }

    @MainActor
    private func recordContribution(for artist: ArtistStat) {
        let contribution = GlobalContribution(artistStat: artist)
        DriftStore.shared.context.insert(contribution)
        try? DriftStore.shared.context.save()
    }
}

// MARK: - Keychain helper (minimal)

enum KeychainHelper {
    nonisolated static func write(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Bundle {
    nonisolated var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
