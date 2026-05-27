// SettingsView.swift
// Drift — Settings screen
//
// HealthKit permission status, global leaderboard opt-in/out,
// wind-down routine configuration, and data management.

import SwiftUI
import SwiftData
import HealthKit

struct SettingsView: View {

    // Leaderboard opt-in — persisted in UserDefaults
    @AppStorage("leaderboard_opted_in") private var leaderboardOptedIn = true
    @AppStorage("winddown_enabled") private var winddownEnabled = false
    @AppStorage("winddown_time") private var winddownTime = 22 * 60 + 30 // 10:30 pm in minutes from midnight
    @AppStorage("smart_alarm_enabled") private var smartAlarmEnabled = false
    @AppStorage("morning_checkin_rating_enabled") private var ratingEnabled = true

    @State private var healthKitStatus: HKAuthorizationStatus = .notDetermined
    @State private var showDeleteConfirm = false
    @State private var showContributionConfirm = false
    @State private var showOnboarding = false
    #if DEBUG
    @State private var debugTapCount = 0
    @State private var debugMenuVisible = false
    @State private var showSampleDataConfirm = false
    #endif

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {

                // MARK: Sleep detection
                Section {
                    HKPermissionRow(status: healthKitStatus)
                    Button("Re-request HealthKit access") {
                        SleepObserver().start()
                    }
                    .foregroundStyle(.indigo)
                } header: {
                    Text("Sleep detection")
                } footer: {
                    Text("Drift reads your HealthKit sleep analysis to detect when you fall asleep. No sleep data is ever uploaded.")
                }

                // MARK: Wind-down routine
                Section {
                    Toggle("Wind-down mode", isOn: $winddownEnabled)
                        .tint(.indigo)

                    if winddownEnabled {
                        WindDownTimePicker(minutesFromMidnight: $winddownTime)

                        Toggle("Smart alarm", isOn: $smartAlarmEnabled)
                            .tint(.indigo)
                    }
                } header: {
                    Text("Wind-down routine")
                } footer: {
                    Text("Drift will play your best sleeper at the selected time and fade volume before sleep is detected.")
                }

                // MARK: Morning check-in
                Section {
                    Toggle("Sleep quality rating", isOn: $ratingEnabled)
                        .tint(.indigo)
                } header: {
                    Text("Morning check-in")
                } footer: {
                    Text("When enabled, the morning log sheet asks you to rate your sleep on a 1–5 moon scale.")
                }

                // MARK: World rankings
                Section {
                    Toggle("Contribute to world rankings", isOn: $leaderboardOptedIn)
                        .tint(.indigo)
                        .onChange(of: leaderboardOptedIn) { _, newValue in
                            if !newValue { showContributionConfirm = true }
                        }

                    if leaderboardOptedIn {
                        HStack {
                            Text("What's shared")
                            Spacer()
                            Text("Artist names, session counts, avg onset")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("What's never shared")
                            Spacer()
                            Text("Your identity, device ID, sleep times")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("World rankings")
                } footer: {
                    Text("Contributions are 100% anonymous. Each device has a random token — never linked to you.")
                }

                // MARK: About
                Section("About") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("View introduction", systemImage: "sparkles")
                    }
                    .foregroundStyle(.indigo)

                    LabeledContent("Version", value: Bundle.main.shortVersionString)
                    #if DEBUG
                        .onTapGesture {
                            debugTapCount += 1
                            if debugTapCount >= 5 {
                                debugMenuVisible = true
                                debugTapCount = 0
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                            }
                        }
                    #endif
                    LabeledContent("Drift score formula", value: "sessions × (30 ÷ avg onset)")
                    LabeledContent("Drifts to unlock artist", value: "3 confirmed")

                    Link("Privacy policy", destination: URL(string: "https://yourdomain.com/privacy")!)
                        .foregroundStyle(.indigo)
                    Link("Support", destination: URL(string: "https://yourdomain.com/support")!)
                        .foregroundStyle(.indigo)
                }

                // MARK: Debug (hidden — 5-tap on version row to reveal)
                #if DEBUG
                if debugMenuVisible {
                    Section {
                        Button {
                            showSampleDataConfirm = true
                        } label: {
                            Label("Load sample data", systemImage: "sparkles")
                        }
                        .foregroundStyle(.indigo)

                        Button(role: .destructive) {
                            deleteAllData()
                        } label: {
                            Label("Clear all data", systemImage: "xmark.circle")
                        }
                    } header: {
                        Text("Debug")
                    } footer: {
                        Text("Inserts 26 Drifts: Joe Rogan, Lofi Girl, Huberman Lab, James Blake, Taylor Swift. Debug only.")
                    }
                }
                #endif

                // MARK: Data management
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Reset my sleep data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Permanently removes all sleep Drifts, artist stats, and track history from this device. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task { checkHealthKitStatus() }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all sleep Drifts, artist stats, and track history from this device.")
            }
            #if DEBUG
            .confirmationDialog(
                "Load sample data?",
                isPresented: $showSampleDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Load 26 sessions") {
                    SampleDataLoader.load(into: context)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace all existing data with realistic fake sessions for 5 artists.")
            }
            #endif
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .alert("Opt out of world rankings?", isPresented: $showContributionConfirm) {
                Button("Opt out", role: .destructive) { leaderboardOptedIn = false }
                Button("Keep contributing", role: .cancel) { leaderboardOptedIn = true }
            } message: {
                Text("Your existing contributions will remain in the anonymous aggregate but no new data will be sent.")
            }
        }
    }

    private func checkHealthKitStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        healthKitStatus = store.authorizationStatus(for: sleepType)
    }

    private func deleteAllData() {
        try? context.delete(model: SleepSession.self)
        try? context.delete(model: ArtistStat.self)
        try? context.delete(model: TrackStat.self)
        try? context.delete(model: GlobalContribution.self)
        try? context.save()
    }
}

// MARK: - HealthKit permission row

struct HKPermissionRow: View {
    let status: HKAuthorizationStatus

    private var statusLabel: String {
        switch status {
        case .sharingAuthorized:    return "Authorized"
        case .sharingDenied:        return "Denied — tap to fix in Settings"
        case .notDetermined:        return "Not requested yet"
        @unknown default:           return "Unknown"
        }
    }

    private var statusColor: Color {
        switch status {
        case .sharingAuthorized:    return .green
        case .sharingDenied:        return .red
        default:                    return .orange
        }
    }

    var body: some View {
        HStack {
            Label("HealthKit access", systemImage: "heart.fill")
            Spacer()
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }
}

// MARK: - Wind-down time picker

struct WindDownTimePicker: View {
    @Binding var minutesFromMidnight: Int

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let h = minutesFromMidnight / 60
                let m = minutesFromMidnight % 60
                return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
            },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutesFromMidnight = (components.hour ?? 22) * 60 + (components.minute ?? 30)
            }
        )
    }

    var body: some View {
        DatePicker(
            "Wind-down starts",
            selection: timeBinding,
            displayedComponents: .hourAndMinute
        )
        .tint(.indigo)
    }
}
