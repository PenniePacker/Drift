// DriftApp.swift
// Drift — App entry point
//
// Wires up SwiftData container, SleepObserver, and the root tab view.

import SwiftUI
import SwiftData

@main
struct DriftApp: App {

    @StateObject private var sleepObserver = SleepObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(DriftStore.shared.container)
                .onAppear {
                    sleepObserver.start()
                }
        }
    }
}

// MARK: - ContentView (Tab container)

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "moon.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }

            ArtistStatsView()
                .tabItem {
                    Label("Artists", systemImage: "music.mic")
                }

            WorldRankingsView()
                .tabItem {
                    Label("World", systemImage: "globe")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.indigo)
        .preferredColorScheme(.dark)
    }
}
