// WatchHomeView.swift
// Drift Watch — Watch face UI
//
// Shows monitoring status, last sleep detection, current HR,
// and a one-tap "Play best sleeper" button that deep-links to
// the media app on the paired iPhone.

import SwiftUI
import WatchKit

struct WatchHomeView: View {

    @EnvironmentObject private var detector: WatchSleepDetector
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // MARK: Status header
                StatusHeader(isMonitoring: detector.isMonitoring)

                // MARK: Confidence indicator
                ConfidenceCard(confidence: detector.detectionConfidence)

                // MARK: Live signals
                if detector.isMonitoring {
                    LiveSignalsCard(
                        heartRate: detector.currentHeartRate,
                        isStill: detector.isStill
                    )
                }

                // MARK: Last detection
                if let lastSleep = detector.lastDetectedSleepDate {
                    LastDetectionCard(date: lastSleep)
                }

                // MARK: Best sleeper button
                if !sessionManager.bestSleeperTitle.isEmpty {
                    BestSleeperWatchCard(
                        title: sessionManager.bestSleeperTitle,
                        artist: sessionManager.bestSleeperArtist,
                        onsetMinutes: sessionManager.bestSleeperOnsetMinutes,
                        deepLink: sessionManager.bestSleeperDeepLink
                    )
                }

                // MARK: Toggle monitoring
                Button {
                    if detector.isMonitoring {
                        detector.stopMonitoring()
                    } else {
                        detector.startMonitoring()
                    }
                } label: {
                    Label(
                        detector.isMonitoring ? "Stop watching" : "Start watching",
                        systemImage: detector.isMonitoring ? "stop.fill" : "moon.fill"
                    )
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(detector.isMonitoring ? .red : .indigo)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(detector.isMonitoring ? .red : .indigo)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Drift")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-start monitoring when Watch app opens
            if !detector.isMonitoring {
                detector.startMonitoring()
            }
        }
    }
}

// MARK: - Status Header

struct StatusHeader: View {
    let isMonitoring: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep detection")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(isMonitoring ? "Watching" : "Paused")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            Spacer()
            Circle()
                .fill(isMonitoring ? .green : .secondary)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(isMonitoring ? .green.opacity(0.3) : .clear, lineWidth: 4)
                        .scaleEffect(isMonitoring ? 1.4 : 1)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isMonitoring)
                )
        }
        .padding(10)
        .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Confidence Card

struct ConfidenceCard: View {
    let confidence: WatchSleepDetector.DetectionConfidence

    private var label: String {
        switch confidence {
        case .none:      return "Awake"
        case .possible:  return "Possibly drifting…"
        case .likely:    return "Likely asleep"
        case .confirmed: return "Sleep confirmed"
        }
    }

    private var color: Color {
        switch confidence {
        case .none:      return .secondary
        case .possible:  return .yellow
        case .likely:    return .orange
        case .confirmed: return .green
        }
    }

    private var icon: String {
        switch confidence {
        case .none:      return "eye.fill"
        case .possible:  return "moon"
        case .likely:    return "moon.fill"
        case .confirmed: return "moon.zzz.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(label)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Live Signals Card

struct LiveSignalsCard: View {
    let heartRate: Double
    let isStill: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Heart rate
            VStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                Text(heartRate > 0 ? "\(Int(heartRate))" : "—")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 36)

            // Stillness
            VStack(spacing: 3) {
                Image(systemName: isStill ? "waveform.slash" : "waveform")
                    .font(.footnote)
                    .foregroundStyle(isStill ? .green : .secondary)
                Text(isStill ? "Still" : "Moving")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(isStill ? .green : .primary)
                Text("Wrist")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Last Detection Card

struct LastDetectionCard: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.footnote)
            VStack(alignment: .leading, spacing: 1) {
                Text("Last detected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(date, style: .relative)
                    .font(.footnote)
                    .fontWeight(.medium)
                + Text(" ago")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Best Sleeper Watch Card

struct BestSleeperWatchCard: View {
    let title: String
    let artist: String
    let onsetMinutes: Double
    let deepLink: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Best sleeper")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Spacer()
                Text("avg \(Int(onsetMinutes))m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Play button — opens deep link on the paired iPhone
            Button {
                guard !deepLink.isEmpty, let url = URL(string: deepLink) else { return }
                // On watchOS, openSystemURL opens the URL on the paired phone
                WKExtension.shared().openSystemURL(url)
            } label: {
                Label("Play on iPhone", systemImage: "play.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(10)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.green.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Notification Controller
// Handles the "sleepDetected" local notification shown on the Watch
// when sleep is confirmed, so the user knows media was paused.

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    override var body: NotificationView {
        return NotificationView()
    }
}

struct NotificationView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            Text("Sleep detected")
                .font(.headline)
            Text("Media paused on your iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
