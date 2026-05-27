// HomeView.swift
// Drift — Home / dashboard screen

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct HomeView: View {

    @Query(
        filter: #Predicate<SleepSession> { $0.isConfirmed == true },
        sort: \SleepSession.sleepOnsetTime,
        order: .reverse
    ) private var sessions: [SleepSession]

    @Query(
        filter: #Predicate<ArtistStat> { $0.isUnlocked == true },
        sort: \ArtistStat.driftScore,
        order: .reverse
    ) private var topArtists: [ArtistStat]

    // Last 7 sessions for the onset chart
    private var recentSessions: [SleepSession] {
        Array(sessions.prefix(7))
    }

    private var averageOnset: Double {
        guard !recentSessions.isEmpty else { return 0 }
        return recentSessions.map(\.onsetMinutes).reduce(0, +) / Double(recentSessions.count)
    }

    private var lastSession: SleepSession? { sessions.first }

    @AppStorage("drift_manual_bedtime") private var bedTimeInterval: Double = 0
    @State private var showMorningLog = false
    @State private var morningLogBedTime: Date? = nil
    @Environment(\.scenePhase) private var scenePhase

    private func checkForMorningLog() {
        if ManualSleepLogger.shouldShowMorningLog,
           let bedTime = ManualSleepLogger.pendingBedTime {
            morningLogBedTime = bedTime
            showMorningLog = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Detection status card
                    DetectionStatusCard(lastSession: lastSession)

                    // MARK: Bedtime tracking
                    BedtimeTrackingCard(
                        bedTimeInterval: bedTimeInterval,
                        onStart: {
                            ManualSleepLogger.startTracking()
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                        },
                        onCancel: { ManualSleepLogger.cancel() }
                    )

                    // MARK: Onset ring + stats
                    OnsetRingCard(
                        averageOnset: averageOnset,
                        lastSession: lastSession
                    )

                    // MARK: Weekly chart
                    if !recentSessions.isEmpty {
                        WeeklyOnsetChart(sessions: sessions)
                    }

                    // MARK: Tonight's Drift
                    TonightsDriftCard(confirmedSessionCount: sessions.count)

                    // MARK: Quick stats row
                    if !topArtists.isEmpty {
                        QuickStatsRow(
                            totalSessions: sessions.count,
                            topArtist: topArtists.first
                        )
                    }

                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Drift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .onAppear { checkForMorningLog() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { checkForMorningLog() }
            }
            .sheet(isPresented: $showMorningLog) {
                if let bedTime = morningLogBedTime {
                    MorningLogSheet(bedTime: bedTime)
                }
            }
        }
    }
}

// MARK: - Detection Status Card

struct DetectionStatusCard: View {
    let lastSession: SleepSession?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep detection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Watching")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Label("Active", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.green.opacity(0.15), in: Capsule())
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Onset Ring Card

struct OnsetRingCard: View {
    let averageOnset: Double
    let lastSession: SleepSession?

    private var progressFraction: Double {
        averageOnset > 0 ? max(0, 1.0 - averageOnset / 30.0) : 0
    }

    private var onsetText: String {
        averageOnset > 0 ? "\(Int(averageOnset))m" : "—"
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // AppIcon at 35% opacity behind arc
                #if os(iOS)
                if let icon = UIImage(named: "AppIcon") {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .opacity(0.35)
                }
                #endif

                // Progress arc: full = 0m (best), empty = 30m+ (worst)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: averageOnset)

                VStack(spacing: 2) {
                    Text(onsetText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("avg (7 nights)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Last night's stats
            if let session = lastSession {
                HStack(spacing: 8) {
                    StatPill(
                        icon: "moon.zzz",
                        label: "Last night",
                        value: "\(Int(session.onsetMinutes))m"
                    )
                    StatPill(
                        icon: "music.note",
                        label: "Paused",
                        value: session.mediaSnapshot?.appDisplayName ?? "Silence 🌙"
                    )
                    StatPill(
                        icon: "clock",
                        label: "Asleep at",
                        value: session.sleepOnsetTime.formatted(date: .omitted, time: .shortened)
                    )
                }
            } else {
                Text("No Drifts recorded yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weekly Onset Chart

private struct DaySlot: Identifiable {
    let id: Int  // days ago (0 = today)
    let date: Date
    let session: SleepSession?
}

struct WeeklyOnsetChart: View {
    let sessions: [SleepSession]

    @State private var selectedSlot: DaySlot? = nil

    private var maxOnset: Double {
        sessions.map(\.onsetMinutes).max() ?? 60
    }

    private var daySlots: [DaySlot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let session = sessions.first {
                calendar.isDate($0.sleepOnsetTime, inSameDayAs: date)
            }
            return DaySlot(id: daysAgo, date: date, session: session)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(daySlots) { slot in
                    VStack(spacing: 4) {
                        if let session = slot.session {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: session.onsetMinutes))
                                .frame(height: max(12, CGFloat(session.onsetMinutes / maxOnset) * 60))
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedSlot = selectedSlot?.id == slot.id ? nil : slot
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                .frame(height: 12)
                                .frame(maxWidth: .infinity)
                        }
                        Text(dayLetter(for: slot.date))
                            .font(.caption2)
                            .foregroundStyle(slot.session != nil ? .secondary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)

            if let slot = selectedSlot, let session = slot.session {
                barPopup(for: session)
                    .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedSlot != nil {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedSlot = nil }
            }
        }
    }

    @ViewBuilder
    private func barPopup(for session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(session.sleepOnsetTime, format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .fontWeight(.semibold)
            HStack(spacing: 6) {
                Text("Drifted off in \(Int(session.onsetMinutes))m")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                    .fontWeight(.medium)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(session.sleepOnsetTime, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let media = session.mediaSnapshot {
                Text(media.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Label(friendlySleepStage(session.sleepStage), systemImage: "moon.zzz.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func barColor(for onset: Double) -> Color {
        onset < 20 ? .indigo : onset < 35 ? .indigo.opacity(0.6) : .secondary.opacity(0.3)
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func friendlySleepStage(_ stage: String) -> String {
        switch stage {
        case "asleepCore":          return "Core sleep"
        case "asleepDeep":          return "Deep sleep"
        case "asleepREM":           return "REM sleep"
        default:                    return "Sleep detected"
        }
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let totalSessions: Int
    let topArtist: ArtistStat?

    var body: some View {
        HStack(spacing: 12) {
            StatCard(label: "Total Drifts", value: "\(totalSessions)", icon: "moon.zzz.fill")
            if let artist = topArtist {
                StatCard(label: "Top artist", value: artist.artistName, icon: "music.mic")
            }
        }
    }
}

// MARK: - Reusable sub-components

struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatMini: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Bedtime Tracking Card

struct BedtimeTrackingCard: View {
    let bedTimeInterval: Double
    let onStart: () -> Void
    let onCancel: () -> Void

    @State private var showCancelConfirm = false

    private var pendingBedTime: Date? {
        bedTimeInterval > 0 ? Date(timeIntervalSince1970: bedTimeInterval) : nil
    }

    var body: some View {
        if let bedTime = pendingBedTime {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sleep tracking active")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Bed at \(bedTime.formatted(date: .omitted, time: .shortened)) · Reminder at 8:00 AM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") { showCancelConfirm = true }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.indigo.opacity(0.2), lineWidth: 0.5))
            .confirmationDialog(
                "Stop tracking?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Stop tracking", role: .destructive) { onCancel() }
                Button("Keep tracking", role: .cancel) {}
            } message: {
                Text("Your morning reminder will be cancelled.")
            }
        } else {
            Button(action: onStart) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("I'm going to bed 🌙")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Drift will remind you at 8am to log your onset time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.indigo.opacity(0.12), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Morning Log Sheet

struct MorningLogSheet: View {
    let bedTime: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedOnsetTime: Date
    @AppStorage("morning_checkin_rating_enabled") private var ratingEnabled = true
    @State private var qualityRating: Int? = nil
    @State private var showInsight = false
    @State private var insightText = ""
    @State private var dismissTask: Task<Void, Never>? = nil

    init(bedTime: Date) {
        self.bedTime = bedTime
        _selectedOnsetTime = State(initialValue: bedTime.addingTimeInterval(30 * 60))
    }

    private var onsetMinutes: Int {
        max(0, Int(selectedOnsetTime.timeIntervalSince(bedTime) / 60))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showInsight {
                    insightView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    formView
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showInsight)
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    return ToolbarItemPlacement.topBarTrailing
                    #else
                    return ToolbarItemPlacement.automatic
                    #endif
                }()) {
                    Button {
                        dismissTask?.cancel()
                        if !showInsight { ManualSleepLogger.cancel() }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onDisappear { dismissTask?.cancel() }
    }

    // MARK: Form

    @ViewBuilder
    private var formView: some View {
        VStack(spacing: 28) {

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.indigo)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                }
                .font(.title2)

                Text("Good morning")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You went to bed at \(bedTime.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("When did you fall asleep?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                DatePicker(
                    "",
                    selection: $selectedOnsetTime,
                    in: bedTime...(bedTime.addingTimeInterval(12 * 3600)),
                    displayedComponents: [.hourAndMinute]
                )
                #if os(iOS)
                .datePickerStyle(.wheel)
                #else
                .datePickerStyle(.graphical)
                #endif
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            if ratingEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How was your sleep?")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                qualityRating = qualityRating == i ? nil : i
                            } label: {
                                Image(systemName: i <= (qualityRating ?? 0) ? "moon.fill" : "moon")
                                    .font(.title)
                                    .foregroundStyle(i <= (qualityRating ?? 0) ? .indigo : .secondary.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: qualityRating)
                        }
                    }
                }
                .padding()
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Text("\(selectedOnsetTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(onsetMinutes)m after bed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
            }
            .padding(.horizontal, 4)

            Spacer()

            VStack(spacing: 10) {
                Button { logAndShowInsight() } label: {
                    Text("Log it")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                }

                Button("Skip for now") {
                    ManualSleepLogger.cancel()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: Insight card

    @ViewBuilder
    private var insightView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)
                .symbolEffect(.bounce, options: .nonRepeating, value: showInsight)

            Text(insightText)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Tap to dismiss")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissTask?.cancel()
            dismiss()
        }
    }

    // MARK: Helpers

    private func logAndShowInsight() {
        DriftStore.shared.recordSleepSession(
            bedTime: bedTime,
            sleepOnsetTime: selectedOnsetTime,
            sleepStage: "asleepUnspecified",
            mediaSnapshot: nil,
            qualityRating: ratingEnabled ? qualityRating : nil
        )
        ManualSleepLogger.cancel()
        ManualSleepLogger.scheduleMorningSummary(artistName: nil, onsetMinutes: Double(onsetMinutes))

        insightText = computeInsight(newOnsetMinutes: Double(onsetMinutes))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showInsight = true
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { dismiss() }
        }
    }

    private func computeInsight(newOnsetMinutes: Double) -> String {
        let descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate { $0.isConfirmed == true },
            sortBy: [SortDescriptor(\.sleepOnsetTime, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []

        // Streak: ≥ 3 consecutive nights
        let streak = consecutiveNightStreak(in: sessions)
        if streak >= 3 {
            return "You're on a \(streak) night streak 🔥"
        }

        // Best this week (needs ≥ 2 sessions this week to be meaningful)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let thisWeek = sessions.filter { $0.sleepOnsetTime > weekAgo }
        if thisWeek.count >= 2,
           let fastest = thisWeek.map(\.onsetMinutes).min(),
           newOnsetMinutes <= fastest + 0.1 {
            return "Your best night this week 🏆"
        }

        // Faster than personal average (prior sessions only, needs ≥ 2)
        let prior = Array(sessions.dropFirst())
        if prior.count >= 2 {
            let avg = prior.map(\.onsetMinutes).reduce(0, +) / Double(prior.count)
            let diff = avg - newOnsetMinutes
            if diff >= 5 {
                return "You drifted off \(Int(diff.rounded())) minutes faster than your average 🌙"
            }
        }

        // First ever session
        if sessions.count <= 1 {
            return "First Drift logged — the journey begins 🌙"
        }

        return "Drift logged — sleep well tonight 🌙"
    }

    private func consecutiveNightStreak(in sessions: [SleepSession]) -> Int {
        let calendar = Calendar.current
        guard !sessions.isEmpty else { return 0 }
        var streak = 1
        var prevDay = calendar.startOfDay(for: sessions[0].sleepOnsetTime)
        for session in sessions.dropFirst() {
            let day = calendar.startOfDay(for: session.sleepOnsetTime)
            let diff = calendar.dateComponents([.day], from: day, to: prevDay).day ?? 999
            if diff == 1 {
                streak += 1
                prevDay = day
            } else if diff > 1 {
                break
            }
        }
        return streak
    }
}

// MARK: - Tonight's Drift Card

struct TonightsDriftCard: View {
    let confirmedSessionCount: Int

    @Query(
        filter: #Predicate<ArtistStat> { $0.confirmedSessionCount > 0 },
        sort: \ArtistStat.averageOnsetMinutes
    ) private var artistStats: [ArtistStat]

    @State private var globalAlternative: GlobalLeaderboardEntry? = nil
    @State private var globalAlternativeRank: Int = 0
    @State private var isFetchingGlobal = false

    private static let threshold = 3

    private var isEvening: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 18
    }

    // Artist with the lowest average onset minutes
    private var personalBest: ArtistStat? { artistStats.first }

    private var eveningGreeting: String {
        Calendar.current.component(.hour, from: Date()) < 21 ? "Good evening" : "Good night"
    }

    private var knownNames: Set<String> {
        Set(artistStats.map { $0.artistName.lowercased() })
    }

    var body: some View {
        if isEvening {
            if confirmedSessionCount < Self.threshold {
                lockedCard
            } else {
                activeCard
                    .task(id: confirmedSessionCount) {
                        guard !isFetchingGlobal, globalAlternative == nil else { return }
                        await fetchGlobalAlternative()
                    }
            }
        }
    }

    // MARK: Locked state

    private var lockedCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Tonight's Drift", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
                Spacer()
            }

            VStack(spacing: 12) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 32))
                    .foregroundStyle(.indigo.opacity(0.5))

                VStack(spacing: 4) {
                    let remaining = Self.threshold - confirmedSessionCount
                    Text("Sleep \(remaining) more \(remaining == 1 ? "night" : "nights") to unlock")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    Text("Tonight's Drift")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(0..<Self.threshold, id: \.self) { i in
                        Circle()
                            .fill(i < confirmedSessionCount ? Color.indigo : Color.secondary.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: confirmedSessionCount)
                    }
                }

                Text("\(confirmedSessionCount) of \(Self.threshold) nights recorded")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Active state

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Tonight's Drift", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
                Spacer()
                Text(eveningGreeting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let best = personalBest {
                let bestTrack = best.trackStats
                    .filter(\.isUnlocked)
                    .min(by: { $0.averageOnsetMinutes < $1.averageOnsetMinutes })

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.indigo.opacity(0.3), .purple.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay {
                            Text(best.categoryEmoji)
                                .font(.title2)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(best.artistName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text("Puts you to drift off in \(Int(best.averageOnsetMinutes))m on average · \(best.confirmedSessionCount) \(best.confirmedSessionCount == 1 ? "Drift" : "Drifts")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        let url = bestTrack.flatMap { URL(string: $0.deepLinkURI ?? "") }
                            ?? artistDeepLink(name: best.artistName, appBundleID: best.appBundleID)
                        if let url {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #else
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        Label("Drift off", systemImage: "play.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }

                    if let alt = globalAlternative {
                        Button {
                            if let url = artistDeepLink(name: alt.artistName, appBundleID: alt.appBundleID) {
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #else
                                NSWorkspace.shared.open(url)
                                #endif
                            }
                        } label: {
                            Text("Try something new →")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Helpers

    private func artistDeepLink(name: String, appBundleID: String) -> URL? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        switch appBundleID {
        case "com.spotify.client":
            return URL(string: "spotify:search:\(encoded)")
        case "com.apple.podcasts":
            return URL(string: "https://podcasts.apple.com/search?term=\(encoded)")
        case "com.apple.Music":
            return URL(string: "https://music.apple.com/search?term=\(encoded)")
        default:
            return URL(string: "https://music.apple.com/search?term=\(encoded)")
        }
    }

    private func fetchGlobalAlternative() async {
        isFetchingGlobal = true
        let known = knownNames
        for category in [GlobalSyncService.LeaderboardCategory.artists, .podcasts] {
            guard let entries = try? await GlobalSyncService.shared.fetchLeaderboard(category: category) else { continue }
            for (i, entry) in entries.enumerated() {
                if !known.contains(entry.artistName.lowercased()) {
                    globalAlternative = entry
                    globalAlternativeRank = i + 1
                    isFetchingGlobal = false
                    return
                }
            }
        }
        isFetchingGlobal = false
    }
}

