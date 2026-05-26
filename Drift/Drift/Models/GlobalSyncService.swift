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

struct ArtistContribution: Sendable {
    let contributionToken: String
    let artistName: String
    let appBundleID: String
    let appDisplayName: String
    let categoryEmoji: String
    let sessionCount: Int
    let averageOnsetMinutes: Double
    let driftScore: Double
    let appVersion: String
}

extension ArtistContribution: Encodable {
    private enum CodingKeys: String, CodingKey {
        case contributionToken  = "contribution_token"
        case artistName         = "artist_name"
        case appBundleID        = "app_bundle_id"
        case appDisplayName     = "app_display_name"
        case categoryEmoji      = "category_emoji"
        case sessionCount       = "session_count"
        case averageOnsetMinutes = "average_onset_minutes"
        case driftScore         = "drift_score"
        case appVersion         = "app_version"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(contributionToken,   forKey: .contributionToken)
        try c.encode(artistName,          forKey: .artistName)
        try c.encode(appBundleID,         forKey: .appBundleID)
        try c.encode(appDisplayName,      forKey: .appDisplayName)
        try c.encode(categoryEmoji,       forKey: .categoryEmoji)
        try c.encode(sessionCount,        forKey: .sessionCount)
        try c.encode(averageOnsetMinutes, forKey: .averageOnsetMinutes)
        try c.encode(driftScore,          forKey: .driftScore)
        try c.encode(appVersion,          forKey: .appVersion)
    }
}

// MARK: - Global leaderboard response

struct GlobalLeaderboardEntry: Identifiable, Sendable {
    var id: String { artistName + appBundleID }
    let artistName: String
    let appBundleID: String
    let appDisplayName: String
    let categoryEmoji: String
    let totalSessions: Int
    let averageOnsetMinutes: Double
    let globalDriftScore: Double
    let contributorCount: Int
}

extension GlobalLeaderboardEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case artistName         = "artist_name"
        case appBundleID        = "app_bundle_id"
        case appDisplayName     = "app_display_name"
        case categoryEmoji      = "category_emoji"
        case totalSessions      = "total_sessions"
        case averageOnsetMinutes = "average_onset_minutes"
        case globalDriftScore   = "global_drift_score"
        case contributorCount   = "contributor_count"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        artistName          = try c.decode(String.self, forKey: .artistName)
        appBundleID         = try c.decode(String.self, forKey: .appBundleID)
        appDisplayName      = try c.decode(String.self, forKey: .appDisplayName)
        categoryEmoji       = try c.decode(String.self, forKey: .categoryEmoji)
        totalSessions       = try c.decode(Int.self,    forKey: .totalSessions)
        averageOnsetMinutes = try c.decode(Double.self, forKey: .averageOnsetMinutes)
        globalDriftScore    = try c.decode(Double.self, forKey: .globalDriftScore)
        contributorCount    = try c.decode(Int.self,    forKey: .contributorCount)
    }
}

// MARK: - GlobalSyncService

@MainActor
final class GlobalSyncService {

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
        guard let artists = try? DriftStore.shared.topArtists() else { return }

        for artist in artists {
            let contribution = lastContribution(for: artist)
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
                recordContribution(for: artist)
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

    private func lastContribution(for artist: ArtistStat) -> GlobalContribution? {
        let name = artist.artistName
        let bundle = artist.appBundleID
        let descriptor = FetchDescriptor<GlobalContribution>(
            predicate: #Predicate { $0.artistName == name && $0.appBundleID == bundle }
        )
        return try? DriftStore.shared.context.fetch(descriptor).first
    }

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
