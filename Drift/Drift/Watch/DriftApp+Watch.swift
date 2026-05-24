// DriftApp+Watch.swift
// Watch-side helpers compiled into the iOS target.

import MediaPlayer

// MARK: - MediaSnapshotCapture
// Reads MPNowPlayingInfoCenter to capture what was playing at sleep onset.

enum MediaSnapshotCapture {

    static func capture() -> MediaSnapshot? {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        guard let info, !info.isEmpty else { return nil }

        let title    = info[MPMediaItemPropertyTitle] as? String ?? "Unknown"
        let artist   = info[MPMediaItemPropertyArtist] as? String ?? "Unknown"
        let album    = info[MPMediaItemPropertyAlbumTitle] as? String
        let elapsed  = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
        let duration = info[MPMediaItemPropertyPlaybackDuration] as? Double

        let bundleID    = inferBundleID(from: info)
        let displayName = displayName(for: bundleID)

        return MediaSnapshot(
            appBundleID: bundleID,
            appDisplayName: displayName,
            trackTitle: title,
            artistName: artist,
            albumOrShow: album,
            elapsedSeconds: elapsed,
            durationSeconds: duration,
            isLiveStream: duration == nil || duration == 0,
            deepLinkURI: nil,
            spotifyID: nil
        )
    }

    private static func inferBundleID(from info: [String: Any]) -> String {
        return info["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? String
            ?? "com.spotify.client"
    }

    private static func displayName(for bundleID: String) -> String {
        switch bundleID {
        case "com.spotify.client":          return "Spotify"
        case "com.apple.podcasts":          return "Podcasts"
        case "com.apple.Music":             return "Apple Music"
        case "com.google.ios.youtube":      return "YouTube"
        case "com.google.ios.youtubemusic": return "YouTube Music"
        default:                            return "Music"
        }
    }
}

// MARK: - SleepDetectionPayload extension

extension SleepDetectionPayload {
    var estimatedTimeInBedSeconds: Double { 20 * 60 }
}
