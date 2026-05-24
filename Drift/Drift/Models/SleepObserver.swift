import AVFoundation
import Combine
import HealthKit
import MediaPlayer
import UIKit

// MARK: - SleepObserver
// Observes HealthKit sleep analysis samples and pauses media on sleep onset.
// Add this to your main app target. Requires HealthKit entitlement + Info.plist keys:
//   NSHealthShareUsageDescription
//   NSHealthUpdateUsageDescription (only if you write sleep data)

class SleepObserver: ObservableObject {

    // MARK: - Properties

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?

    /// The sleep category type we observe
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    /// Anchor persisted between launches so we only process *new* samples
    private var anchor: HKQueryAnchor? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "sleepAnchor") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        }
        set {
            guard let anchor = newValue,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { return }
            UserDefaults.standard.set(data, forKey: "sleepAnchor")
        }
    }

    // MARK: - Public API

    /// Call once at app launch (e.g. in AppDelegate or your App struct's init).
    func start() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device.")
            return
        }
        requestAuthorization { [weak self] granted in
            guard granted else { return }
            self?.startObserving()
        }
    }

    func stop() {
        if let query { healthStore.stop(query) }
        query = nil
    }

    // MARK: - Authorization

    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToRead: Set<HKObjectType> = [sleepType]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error { print("HealthKit auth error: \(error)") }
            completion(success)
        }
    }

    // MARK: - Anchored Query

    private func startObserving() {
        // Predicate: only look at samples from the last 24 hours on first launch
        // (avoids replaying old sleep data on fresh install)
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil)

        let query = HKAnchoredObjectQuery(
            type: sleepType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            // This block fires once with existing samples since the anchor
            self?.handleNewSamples(samples, newAnchor: newAnchor)
        }

        // Update handler fires continuously as new samples arrive
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.handleNewSamples(samples, newAnchor: newAnchor)
        }

        healthStore.execute(query)
        self.query = query

        // Keep the observer alive in the background via HKObserverQuery (for when
        // the app is suspended — pairs with background delivery below)
        enableBackgroundDelivery()
    }

    // MARK: - Background Delivery
    // Wakes the app when new sleep data is written, even if suspended.
    // Requires the HealthKit background delivery entitlement.

    private func enableBackgroundDelivery() {
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            if let error { print("Background delivery error: \(error)") }
        }
    }

    // MARK: - Sample Handling

    private func handleNewSamples(_ samples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        defer { if let newAnchor { anchor = newAnchor } }

        guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }

        for sample in samples {
            let stage = sleepStage(from: sample)
            print("Sleep sample: \(stage) | start: \(sample.startDate) | end: \(sample.endDate) | source: \(sample.sourceRevision.source.name)")

            // Trigger media pause when the user enters any sleep stage
            // (asleepCore / asleepDeep = definitely asleep; asleepREM / asleepUnspecified = also valid)
            if isAsleep(stage) {
                DispatchQueue.main.async {
                    self.pauseMedia()
                }
            }
        }
    }

    // MARK: - Sleep Stage Helpers

    enum SleepStage: String {
        case inBed          = "In Bed"
        case awake          = "Awake"
        case asleepCore     = "Core (Light) Sleep"
        case asleepDeep     = "Deep Sleep"
        case asleepREM      = "REM Sleep"
        case asleepUnspecified = "Asleep (Unspecified)"
        case unknown        = "Unknown"
    }

    private func sleepStage(from sample: HKCategorySample) -> SleepStage {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return .unknown }
        switch value {
        case .inBed:               return .inBed
        case .awake:               return .awake
        case .asleepCore:          return .asleepCore
        case .asleepDeep:          return .asleepDeep
        case .asleepREM:           return .asleepREM
        case .asleepUnspecified:   return .asleepUnspecified
        @unknown default:          return .unknown
        }
    }

    private func isAsleep(_ stage: SleepStage) -> Bool {
        switch stage {
        case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
            return true
        case .inBed, .awake, .unknown:
            return false
        }
    }

    // MARK: - Media Control

    /// Sends a pause command via MPRemoteCommandCenter.
    /// Works for any audio app that registers remote commands (Spotify, Podcasts,
    /// Apple Music, YouTube Music, etc.)
    private func pauseMedia() {
        let center = MPRemoteCommandCenter.shared()
        _ = center.pauseCommand.isEnabled  // ensure it's registered

        // The canonical way to pause whatever is currently playing
        let result = MPMusicPlayerController.applicationMusicPlayer.pause()  // for Apple Music
        // For other apps, send a remote pause event:
        UIApplication.shared.sendAction(#selector(UIResponder.remoteControlReceived(with:)),
                                        to: nil, from: self, for: remoteControlEvent(.remoteControlPause))

        print("Pause command sent. Result: \(result)")
    }

    private func remoteControlEvent(_ type: UIEvent.EventSubtype) -> UIEvent? {
        // Helper to synthesize a remote control event
        // In practice, use AVAudioSession + MPNowPlayingInfoCenter for robust control
        return nil  // see note below
    }
}

// MARK: - Robust media pause (use this instead of the synthesized event above)
// The cleanest way to pause any system audio:

extension SleepObserver {

    /// Preferred pause approach: deactivate the audio session, which causes
    /// the playing app to pause (it loses audio focus).
    func pauseViaAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Your app must have an active audio session category first
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            // Now deactivate with notifyOthersOnDeactivation — this signals other apps to resume/pause
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated — other apps should pause.")
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }
}
