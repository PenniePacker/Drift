// WatchSleepDetector.swift
// Drift Watch — On-device sleep detection
//
// Strategy: three-signal fusion for reliable sleep onset detection.
//
//   Signal 1 — HealthKit sleep samples (most accurate, but latency ~2-10 min)
//              Apple Watch writes sleep stage data as it processes sensor readings.
//              We observe via HKAnchoredObjectQuery, same pattern as the phone.
//
//   Signal 2 — Heart rate monitoring (continuous, low latency)
//              HR dropping below resting threshold AND stabilising for 3+ minutes
//              is a strong sleep onset signal. Sampled every 60s via HKObserverQuery.
//
//   Signal 3 — Accelerometer stillness (CoreMotion, immediate)
//              Wrist stillness for 5+ minutes (no significant movement) combined
//              with the above confirms sleep. Avoids false positives from reading
//              or watching TV in bed.
//
//   Fusion rule:
//     - HealthKit sleep sample alone → always triggers (highest confidence)
//     - HR drop + stillness together → triggers (good confidence, faster)
//     - Either signal alone → does NOT trigger (avoids false positives)
//
//   On trigger: sends a WatchConnectivity message to the iPhone, which then
//   calls DriftStore.recordSleepSession() and pauses media.

import Foundation
import HealthKit
import CoreMotion
import WatchKit
import Combine

@MainActor
final class WatchSleepDetector: ObservableObject {

    static let shared = WatchSleepDetector()

    // MARK: - Published state (drives WatchHomeView)

    @Published var isMonitoring = false
    @Published var lastDetectedSleepDate: Date?
    @Published var currentHeartRate: Double = 0
    @Published var isStill: Bool = false
    @Published var detectionConfidence: DetectionConfidence = .none

    enum DetectionConfidence {
        case none           // nothing detected
        case possible       // one signal (HR or stillness alone)
        case likely         // HR + stillness, no HealthKit yet
        case confirmed      // HealthKit sleep sample written
    }

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private var sleepQuery: HKAnchoredObjectQuery?
    private var hrQuery: HKObserverQuery?
    private var cancellables = Set<AnyCancellable>()

    // Thresholds — tunable
    private let hrDropThresholdBPM: Double = 10     // HR must drop ≥10 BPM below recent baseline
    private let hrStabilityWindowSeconds: Double = 180  // HR must be stable for 3 minutes
    private let stillnessWindowSeconds: Double = 300    // No significant movement for 5 minutes
    private let accelerometerThreshold: Double = 0.02   // g-force variance threshold for "still"

    // Rolling buffers
    private var recentHRSamples: [(date: Date, bpm: Double)] = []
    private var accelerometerBuffer: [Double] = []
    private var lastMotionTimestamp = Date()
    private var stillnessStartDate: Date?

    // Anchor for sleep query (persisted between launches)
    private var sleepAnchor: HKQueryAnchor? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchSleepAnchor") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        }
        set {
            guard let anchor = newValue,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { return }
            UserDefaults.standard.set(data, forKey: "watchSleepAnchor")
        }
    }

    // MARK: - Public API

    func startMonitoring() {
        guard !isMonitoring else { return }
        requestAuthorization { [weak self] granted in
            guard granted, let self else { return }
            Task { @MainActor in
                self.isMonitoring = true
                self.startSleepQuery()
                self.startHeartRateMonitoring()
                self.startAccelerometerMonitoring()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        if let sleepQuery { healthStore.stop(sleepQuery) }
        if let hrQuery { healthStore.stop(hrQuery) }
        motionManager.stopAccelerometerUpdates()
        sleepQuery = nil
        hrQuery = nil
    }

    // MARK: - Authorization

    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [sleepType, hrType]) { success, error in
            if let error { print("Watch HealthKit auth error: \(error)") }
            completion(success)
        }
    }

    // MARK: - Signal 1: HealthKit sleep query

    private func startSleepQuery() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let startDate = Calendar.current.date(byAdding: .hour, value: -12, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil)

        let query = HKAnchoredObjectQuery(
            type: sleepType,
            predicate: predicate,
            anchor: sleepAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.handleSleepSamples(samples, anchor: newAnchor)
        }
        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.handleSleepSamples(samples, anchor: newAnchor)
        }
        healthStore.execute(query)
        self.sleepQuery = query

        // Background delivery so we wake even when suspended
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, error in
            if let error { print("Watch background delivery error: \(error)") }
        }
    }

    private func handleSleepSamples(_ samples: [HKSample]?, anchor: HKQueryAnchor?) {
        defer { if let anchor { sleepAnchor = anchor } }
        guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }

        for sample in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            let isAsleep: Bool
            switch value {
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
                isAsleep = true
            default:
                isAsleep = false
            }

            if isAsleep {
                let stage = sleepStageName(from: value)
                print("Watch: HealthKit sleep sample — \(stage) at \(sample.startDate)")
                Task { @MainActor in
                    self.detectionConfidence = .confirmed
                    self.triggerSleepDetected(at: sample.startDate, stage: stage, source: .healthKit)
                }
                return  // one trigger per batch is enough
            }
        }
    }

    // MARK: - Signal 2: Heart rate monitoring

    private func startHeartRateMonitoring() {
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        // Use HKObserverQuery to wake on new HR samples, then fetch the latest
        let hrObserver = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            self?.fetchLatestHeartRate()
        }
        healthStore.execute(hrObserver)
        self.hrQuery = hrObserver

        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in }
    }

    private func fetchLatestHeartRate() {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 5, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self,
                  let samples = samples as? [HKQuantitySample],
                  let latest = samples.first else { return }

            let bpm = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
            Task { @MainActor in
                self.currentHeartRate = bpm
                self.recentHRSamples.append((date: latest.startDate, bpm: bpm))
                // Keep only last 10 minutes of samples
                let cutoff = Date().addingTimeInterval(-600)
                self.recentHRSamples = self.recentHRSamples.filter { $0.date > cutoff }
                self.evaluateFusedSignals()
            }
        }
        healthStore.execute(query)
    }

    private var hrBaseline: Double {
        // Baseline = average of samples from 10–20 mins ago (before any drop)
        let now = Date()
        let window = recentHRSamples.filter {
            $0.date > now.addingTimeInterval(-1200) && $0.date < now.addingTimeInterval(-600)
        }
        guard !window.isEmpty else { return currentHeartRate }
        return window.map(\.bpm).reduce(0, +) / Double(window.count)
    }

    private var hrHasDropped: Bool {
        guard recentHRSamples.count >= 3 else { return false }
        return (hrBaseline - currentHeartRate) >= hrDropThresholdBPM
    }

    private var hrIsStable: Bool {
        let recent = recentHRSamples.filter { $0.date > Date().addingTimeInterval(-hrStabilityWindowSeconds) }
        guard recent.count >= 3 else { return false }
        let values = recent.map(\.bpm)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return variance < 9  // std dev < 3 BPM = stable
    }

    // MARK: - Signal 3: Accelerometer stillness

    private func startAccelerometerMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 2.0  // sample every 2 seconds

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let magnitude = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            // Subtract gravity (≈1g) to get net movement
            let movement = abs(magnitude - 1.0)
            self.accelerometerBuffer.append(movement)
            if self.accelerometerBuffer.count > 150 { self.accelerometerBuffer.removeFirst() }

            let avgMovement = self.accelerometerBuffer.reduce(0, +) / Double(self.accelerometerBuffer.count)
            let wasStill = self.isStill
            self.isStill = avgMovement < self.accelerometerThreshold

            if self.isStill && !wasStill {
                self.stillnessStartDate = Date()
            } else if !self.isStill {
                self.stillnessStartDate = nil
            }

            self.evaluateFusedSignals()
        }
    }

    private var isStillLongEnough: Bool {
        guard let start = stillnessStartDate else { return false }
        return Date().timeIntervalSince(start) >= stillnessWindowSeconds
    }

    // MARK: - Fusion evaluation

    private func evaluateFusedSignals() {
        // HealthKit triggers are handled directly in handleSleepSamples
        // Here we evaluate the HR + motion fusion

        guard detectionConfidence != .confirmed else { return }

        let hrSignal = hrHasDropped && hrIsStable
        let motionSignal = isStillLongEnough

        if hrSignal && motionSignal {
            // Both non-HealthKit signals agree — high confidence
            if detectionConfidence != .likely {
                detectionConfidence = .likely
                print("Watch: HR + motion fusion trigger — likely asleep")
                triggerSleepDetected(at: Date(), stage: "asleepUnspecified", source: .fusion)
            }
        } else if hrSignal || motionSignal {
            detectionConfidence = .possible
        } else {
            detectionConfidence = .none
        }
    }

    // MARK: - Trigger sleep detected

    enum DetectionSource { case healthKit, fusion }

    private func triggerSleepDetected(at date: Date, stage: String, source: DetectionSource) {
        guard lastDetectedSleepDate == nil ||
              date.timeIntervalSince(lastDetectedSleepDate!) > 3600 else {
            // Debounce: don't fire again within 1 hour
            return
        }

        lastDetectedSleepDate = date

        // Haptic feedback on the Watch
        WKInterfaceDevice.current().play(.stop)

        // Send to iPhone via WatchConnectivity
        WatchSessionManager.shared.sendSleepDetected(
            onsetDate: date,
            sleepStage: stage,
            heartRate: currentHeartRate,
            source: source.rawValue
        )

        print("Watch: sleep detected at \(date) via \(source) — stage: \(stage)")
    }

    // MARK: - Helpers

    private func sleepStageName(from value: HKCategoryValueSleepAnalysis) -> String {
        switch value {
        case .asleepCore:          return "asleepCore"
        case .asleepDeep:          return "asleepDeep"
        case .asleepREM:           return "asleepREM"
        case .asleepUnspecified:   return "asleepUnspecified"
        default:                   return "asleepUnspecified"
        }
    }
}

extension WatchSleepDetector.DetectionSource {
    var rawValue: String {
        switch self {
        case .healthKit: return "healthKit"
        case .fusion:    return "hrMotionFusion"
        }
    }
}
