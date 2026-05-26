// ManualSleepLogger.swift
// Drift — Manual bedtime tracking: persists bedtime, schedules 8am morning reminder.

import Foundation
import UserNotifications

enum ManualSleepLogger {

    static let bedTimeKey = "drift_manual_bedtime"

    static var pendingBedTime: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: bedTimeKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: bedTimeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: bedTimeKey)
            }
        }
    }

    static func startTracking() {
        pendingBedTime = Date()
        scheduleMorningNotification()
    }

    static func cancel() {
        pendingBedTime = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["drift_morning_log"])
    }

    // True when there is a pending bedtime at least 4 hours in the past
    static var shouldShowMorningLog: Bool {
        guard let bedTime = pendingBedTime else { return false }
        return Date().timeIntervalSince(bedTime) > 4 * 3600
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func scheduleMorningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "When did you fall asleep last night? Tap to log it."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = 8
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "drift_morning_log",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
