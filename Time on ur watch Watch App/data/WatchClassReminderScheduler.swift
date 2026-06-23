//
//  WatchClassReminderScheduler.swift
//  Time on ur watch Watch App
//
//  Created By Ng1nx on 6/23/26.
//

import Foundation
import UserNotifications

@MainActor
final class WatchClassReminderScheduler {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let scheduledNotificationKey = "watch_scheduled_class_notification_ids"
    private let debugNotificationIdentifier = "watch-debug-class-reminder"

    func sync(with snapshot: WatchTimetableStoreSnapshot) async {
        let reminders = desiredReminders(for: snapshot)
        let existingIDs = Set(defaults.stringArray(forKey: scheduledNotificationKey) ?? [])
        let desiredIDs = Set(reminders.map(\.identifier))
        let identifiersToClear = Array(existingIDs.union(desiredIDs))

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToClear)
        defaults.set(Array(desiredIDs), forKey: scheduledNotificationKey)

        guard !reminders.isEmpty else {
            return
        }

        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            return
        }

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "watch-class-reminders"
            content.interruptionLevel = .timeSensitive

            var dateComponents = DateComponents()
            dateComponents.weekday = reminder.calendarWeekday
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )

            try? await notificationCenter.add(request)
        }
    }

    func scheduleDebugReminder(at fireDate: Date) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            return
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [debugNotificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Class is gonna over!!!"
        content.body = "Debug Class • Apple Watch"
        content.sound = .default
        content.threadIdentifier = "watch-class-reminders"
        content.interruptionLevel = .timeSensitive

        let interval = max(fireDate.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: debugNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }

    func clearDebugReminder() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [debugNotificationIdentifier])
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func desiredReminders(for snapshot: WatchTimetableStoreSnapshot) -> [WatchScheduledClassReminder] {
        let subjectsByID = Dictionary(uniqueKeysWithValues: snapshot.subjects.map { ($0.id, $0) })
        let settingsByPlacementID = Dictionary(
            uniqueKeysWithValues: snapshot.notificationSettings.map { ($0.placementID, $0) }
        )

        return snapshot.placements.flatMap { placement in
            guard snapshot.slots.indices.contains(placement.slotIndex),
                  let subject = subjectsByID[placement.subjectID]
            else {
                return [WatchScheduledClassReminder]()
            }

            let slot = snapshot.slots[placement.slotIndex]
            let setting = settingsByPlacementID[placement.id]
                ?? WatchTimetableNotificationSetting(
                    placementID: placement.id,
                    moment: .classEnds,
                    minutesBefore: 2
                )

            return reminders(
                for: placement,
                slot: slot,
                subject: subject,
                setting: setting
            )
        }
    }

    private func reminders(
        for placement: WatchTimetablePlacement,
        slot: WatchTimetableTimeSlot,
        subject: WatchTimetableSubject,
        setting: WatchTimetableNotificationSetting
    ) -> [WatchScheduledClassReminder] {
        switch setting.moment {
        case .classBegins:
            return [makeReminder(
                eventKind: .start,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: setting.minutesBefore
            )].compactMap { $0 }
        case .classEnds:
            return [makeReminder(
                eventKind: .end,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: setting.minutesBefore
            )].compactMap { $0 }
        case .both:
            return [
                makeReminder(
                    eventKind: .start,
                    placement: placement,
                    slot: slot,
                    subject: subject,
                    minutesBefore: setting.minutesBefore
                ),
                makeReminder(
                    eventKind: .end,
                    placement: placement,
                    slot: slot,
                    subject: subject,
                    minutesBefore: setting.minutesBefore
                )
            ].compactMap { $0 }
        }
    }

    private func makeReminder(
        eventKind: WatchReminderEventKind,
        placement: WatchTimetablePlacement,
        slot: WatchTimetableTimeSlot,
        subject: WatchTimetableSubject,
        minutesBefore: Int
    ) -> WatchScheduledClassReminder? {
        let sourceMinutes: Int?

        switch eventKind {
        case .start:
            sourceMinutes = slot.startMinutesSinceMidnight
        case .end:
            sourceMinutes = WatchTimetableTimeSlot.minutesSinceMidnight(
                time: slot.endTime,
                meridiem: slot.endMeridiem
            )
        }

        guard let baseMinutes = sourceMinutes else {
            return nil
        }

        var reminderMinutes = baseMinutes - minutesBefore
        var calendarWeekday = calendarWeekday(forDayIndex: placement.dayIndex)

        while reminderMinutes < 0 {
            reminderMinutes += 1_440
            calendarWeekday = previousWeekday(from: calendarWeekday)
        }

        let hour = reminderMinutes / 60
        let minute = reminderMinutes % 60

        return WatchScheduledClassReminder(
            identifier: "watch-class-reminder-\(placement.id.uuidString)-\(eventKind.rawValue)",
            title: eventKind == .start ? "Class is gonna start!!!" : "Class is gonna over!!!",
            body: "\(subject.name) • \(subject.room)",
            calendarWeekday: calendarWeekday.rawValue,
            hour: hour,
            minute: minute
        )
    }

    private func calendarWeekday(forDayIndex dayIndex: Int) -> WatchCalendarWeekday {
        switch dayIndex {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        default: return .monday
        }
    }

    private func previousWeekday(from weekday: WatchCalendarWeekday) -> WatchCalendarWeekday {
        switch weekday {
        case .sunday: return .saturday
        case .monday: return .sunday
        case .tuesday: return .monday
        case .wednesday: return .tuesday
        case .thursday: return .wednesday
        case .friday: return .thursday
        case .saturday: return .friday
        }
    }
}

private struct WatchScheduledClassReminder {
    let identifier: String
    let title: String
    let body: String
    let calendarWeekday: Int
    let hour: Int
    let minute: Int
}

private enum WatchReminderEventKind: String {
    case start
    case end
}

private enum WatchCalendarWeekday: Int {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}
