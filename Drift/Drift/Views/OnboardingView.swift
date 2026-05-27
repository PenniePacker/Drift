// OnboardingView.swift
// Drift — First-launch onboarding (3 screens)

import SwiftUI

// MARK: - Container

struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content — slides left on advance
                Group {
                    if page == 0 {
                        OnboardingPage1()
                    } else if page == 1 {
                        OnboardingPage2()
                    } else {
                        OnboardingPage3()
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.35), value: page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom chrome: dots + primary action
                bottomChrome
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 44)
            }

            // Skip button — pages 1 and 2 only
            if page < 2 {
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.35)) { page = 2 }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 58)
                .padding(.trailing, 24)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(!hasCompleted)
    }

    // MARK: Bottom chrome

    private var bottomChrome: some View {
        VStack(spacing: 20) {
            // Progress capsule dots
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == page ? Color.white : Color.white.opacity(0.25))
                        .frame(width: i == page ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
                }
            }

            if page < 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
                } label: {
                    Text("Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: allowAndComplete) {
                        Label("Allow sleep detection", systemImage: "heart.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Text("You can change this anytime in Settings")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func allowAndComplete() {
        SleepObserver().start()
        hasCompleted = true
        dismiss()
    }
}

// MARK: - Page 1: The Pitch

struct OnboardingPage1: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                // Moon illustration
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.indigo.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        ))
                        .frame(width: 180, height: 180)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 14) {
                    Text("Drift off.\nWe'll handle the rest.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Drift automatically pauses your music or podcast the moment you fall asleep — then tells you what content helps you sleep fastest.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Page 2: Compatible Devices

struct OnboardingPage2: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                Spacer().frame(height: 8)

                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 38))
                        .foregroundStyle(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )

                    Text("Works with\nyour gear")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Drift works best with a wearable — the more accurate your sleep data, the better your insights.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                // Most accurate tier
                VStack(alignment: .leading, spacing: 2) {
                    Label("MOST ACCURATE", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.bottom, 8)

                    DeviceRow(icon: "applewatch",         name: "Apple Watch")
                    Divider().overlay(.white.opacity(0.07))
                    DeviceRow(icon: "circle.fill",        name: "Oura Ring")
                    Divider().overlay(.white.opacity(0.07))
                    DeviceRow(icon: "figure.walk",        name: "Fitbit")
                    Divider().overlay(.white.opacity(0.07))
                    DeviceRow(icon: "location.fill",      name: "Garmin")
                    Divider().overlay(.white.opacity(0.07))
                    DeviceRow(icon: "waveform.path.ecg",  name: "Whoop")
                }
                .padding()
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 0.5))

                // Also works tier
                VStack(alignment: .leading, spacing: 2) {
                    Label("ALSO WORKS", systemImage: "iphone")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 8)

                    DeviceRow(
                        icon: "iphone",
                        name: "iPhone only",
                        note: "Uses motion sensor — lower accuracy"
                    )
                }
                .padding()
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 0.5))

                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct DeviceRow: View {
    let icon: String
    let name: String
    var note: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.indigo)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Page 3: Privacy + HealthKit

struct OnboardingPage3: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.indigo.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                            )
                    }

                    Text("Your sleep data\nstays yours")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    PrivacyBullet(
                        icon: "lock.fill",
                        color: .indigo,
                        text: "Sleep data never leaves your device"
                    )
                    Divider().overlay(.white.opacity(0.07))
                    PrivacyBullet(
                        icon: "globe",
                        color: .blue,
                        text: "Only anonymous stats shared globally — never your identity"
                    )
                    Divider().overlay(.white.opacity(0.07))
                    PrivacyBullet(
                        icon: "heart.fill",
                        color: .red,
                        text: "HealthKit lets Drift detect sleep automatically"
                    )
                }
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 0.5))

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct PrivacyBullet: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
