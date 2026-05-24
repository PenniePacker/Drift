// WatchSessionManager.swift
// Drift Watch — WatchConnectivity bridge
//
// Runs on BOTH targets (add to both the iOS and watchOS targets in Xcode).
// Handles bidirectional messaging:
//
//   Watch → iPhone:
//     "sleepDetected"  — triggers DriftStore.recordSleepSession() on the phone
//                        which captures the MPNowPlayingInfo snapshot and pauses media
//
//   iPhone → Watch:
//     "bestSleeper"    — pushes the user's current best sleeper track to the Watch
//                        face so it can be displayed and played from the wrist
//     "sessionCount"   — total session count for the Watch complication
//
// The Watch cannot directly access SwiftData (it's in the phone's app group),
// so all writes go through this bridge.

import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    // MARK: - Published state

    // On Watch: populated when iPhone sends back best sleeper info
    @Published var bestSleeperTitle: String = ""
    @Published var bestSleeperArtist: String = ""
    @Published var bestSleeperDeepLink: String = ""
    @Published var bestSleeperOnsetMinutes: Double = 0
    @Published var totalSessionCount: Int = 0

    // On iPhone: populated when Watch sends a sleep detected message
    @Published var pendingSleepDetection: SleepDetectionPayload?

    // MARK: - Message keys (shared constants)

    enum MessageKey {
        static let type             = "type"
        static let sleepDetected    = "sleepDetected"
        static let bestSleeper      = "bestSleeper"
        static let sessionCount     = "sessionCount"

        // sleepDetected payload
        static let onsetTimestamp   = "onsetTimestamp"
        static let sleepStage       = "sleepStage"
        static let heartRate        = "heartRate"
        static let detectionSource  = "detectionSource"

        // bestSleeper payload
        static let trackTitle       = "trackTitle"
        static let artistName       = "artistName"
        static let deepLinkURI      = "deepLinkURI"
        static let avgOnsetMinutes  = "avgOnsetMinutes"
        static let sessionCountKey  = "count"
    }

    // MARK: - Init

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Watch → iPhone: send sleep detected

    /// Called from WatchSleepDetector when sleep onset is confirmed.
    /// The iPhone receives this and calls DriftStore.recordSleepSession().
    func sendSleepDetected(
        onsetDate: Date,
        sleepStage: String,
        heartRate: Double,
        source: String
    ) {
        guard WCSession.default.isReachable else {
            // Phone not reachable — queue via transferUserInfo (guaranteed delivery)
            WCSession.default.transferUserInfo([
                MessageKey.type:             MessageKey.sleepDetected,
                MessageKey.onsetTimestamp:   onsetDate.timeIntervalSince1970,
                MessageKey.sleepStage:       sleepStage,
                MessageKey.heartRate:        heartRate,
                MessageKey.detectionSource:  source
            ])
            return
        }

        WCSession.default.sendMessage([
            MessageKey.type:             MessageKey.sleepDetected,
            MessageKey.onsetTimestamp:   onsetDate.timeIntervalSince1970,
            MessageKey.sleepStage:       sleepStage,
            MessageKey.heartRate:        heartRate,
            MessageKey.detectionSource:  source
        ], replyHandler: nil) { error in
            print("WatchConnectivity send error: \(error)")
        }
    }

    // MARK: - iPhone → Watch: push best sleeper

    /// Call this from the iPhone side after DriftStore updates ArtistStat.
    /// Updates the Watch face with the user's current best sleeper.
    func pushBestSleeper(
        trackTitle: String,
        artistName: String,
        deepLinkURI: String?,
        avgOnsetMinutes: Double,
        sessionCount: Int
    ) {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = [
            MessageKey.type:            MessageKey.bestSleeper,
            MessageKey.trackTitle:      trackTitle,
            MessageKey.artistName:      artistName,
            MessageKey.deepLinkURI:     deepLinkURI ?? "",
            MessageKey.avgOnsetMinutes: avgOnsetMinutes,
            MessageKey.sessionCountKey: sessionCount
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            // Use application context for non-urgent updates
            // (delivered next time Watch app is foregrounded)
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    // MARK: - Private: handle incoming messages

    private func handleMessage(_ message: [String: Any]) {
        guard let type = message[MessageKey.type] as? String else { return }

        switch type {

        case MessageKey.sleepDetected:
            // Running on iPhone — record the session
            guard let timestamp = message[MessageKey.onsetTimestamp] as? TimeInterval,
                  let stage = message[MessageKey.sleepStage] as? String else { return }

            let payload = SleepDetectionPayload(
                onsetDate: Date(timeIntervalSince1970: timestamp),
                sleepStage: stage,
                heartRate: message[MessageKey.heartRate] as? Double ?? 0,
                source: message[MessageKey.detectionSource] as? String ?? "watch"
            )
            DispatchQueue.main.async {
                self.pendingSleepDetection = payload
                // DriftStore picks this up via .onChange(of: pendingSleepDetection) in DriftApp
                NotificationCenter.default.post(name: .watchSleepDetected, object: payload)
            }

        case MessageKey.bestSleeper:
            // Running on Watch — update the complication / home view
            DispatchQueue.main.async {
                self.bestSleeperTitle   = message[MessageKey.trackTitle] as? String ?? ""
                self.bestSleeperArtist  = message[MessageKey.artistName] as? String ?? ""
                self.bestSleeperDeepLink = message[MessageKey.deepLinkURI] as? String ?? ""
                self.bestSleeperOnsetMinutes = message[MessageKey.avgOnsetMinutes] as? Double ?? 0
            }

        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error { print("WCSession activation error: \(error)") }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Guaranteed-delivery messages sent when phone was unreachable
        handleMessage(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleMessage(applicationContext)
    }

    // iPhone-only delegate methods (not available on Watch)
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}


#endif // canImport(WatchConnectivity)

// MARK: - Supporting types (available on all platforms)

struct SleepDetectionPayload {
    let onsetDate: Date
    let sleepStage: String
    let heartRate: Double
    let source: String
}

extension Notification.Name {
    static let watchSleepDetected = Notification.Name("drift.watchSleepDetected")
}
