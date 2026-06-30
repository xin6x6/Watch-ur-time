//
//  ClassReminderScheduler.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/23/26.
//

import AlarmKit
import Combine
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class ClassReminderScheduler: ObservableObject {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let scheduledAlarmKey = "scheduled_class_alarm_ids"
    private let scheduledNotificationKey = "scheduled_class_notification_ids"
    private let debugNotificationIdentifier = "debug-class-reminder"
    private let debugAlarmID = UUID(uuidString: "2B0B4F89-8D56-4AA1-B6F8-8E72AB7F0D41")!

    func sync(with snapshot: TimetableStoreSnapshot) async {
        let reminders = desiredReminders(for: snapshot)
        snapshot.notificationDeliveryMode.persistToDefaults()

        await syncPhoneNotifications(
            snapshot.notificationDeliveryMode.allowsBanner ? reminders : []
        )

        if #available(iOS 26.0, *) {
            await syncAlarmKit(
                snapshot.notificationDeliveryMode.allowsAlarm ? reminders : []
            )
        }
    }

    func scheduleDebugAlarm(after interval: TimeInterval = 60) async -> String {
        let fireDate = Date().addingTimeInterval(interval)
        let reminder = ScheduledClassReminder(
            placementID: UUID(),
            subjectName: "Debug Class",
            eventKind: .end,
            alarmID: debugAlarmID,
            notificationIdentifier: debugNotificationIdentifier,
            title: "Class is gonna over!!!",
            phoneMessage: "Class Debug Class is gonna over!!!\nWatch Ur Time bro",
            hour: Calendar.current.component(.hour, from: fireDate),
            minute: Calendar.current.component(.minute, from: fireDate),
            calendarWeekday: Calendar.current.component(.weekday, from: fireDate),
            localeWeekday: localeWeekday(from: calendarWeekday(from: Calendar.current.component(.weekday, from: fireDate))),
            tintColor: .orange,
            fireDate: fireDate
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [debugNotificationIdentifier])
        await schedulePhoneNotification(for: reminder)

        if #available(iOS 26.0, *) {
            let alarmMessage = await scheduleSingleAlarm(reminder)
            return "Debug reminder set for \(formattedDebugTime(fireDate)). \(alarmMessage)"
        }

        return "Debug local notification set for \(formattedDebugTime(fireDate)). AlarmKit unavailable."
    }

    func clearDebugAlarm() async -> String {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [debugNotificationIdentifier])

        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.stop(id: debugAlarmID)
            try? AlarmManager.shared.cancel(id: debugAlarmID)
        }

        return "Cleared debug reminder."
    }

    func alarmAuthorizationDebugText() -> String {
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized:
                return "Authorized"
            case .denied:
                return "Denied"
            case .notDetermined:
                return "Not Determined"
            @unknown default:
                return "Unknown"
            }
        }

        return "Unavailable"
    }

    func requestAlarmAuthorizationDebug() async -> String {
        guard #available(iOS 26.0, *) else {
            return "AlarmKit unavailable."
        }

        let before = alarmAuthorizationDebugText()

        do {
            let result = try await AlarmManager.shared.requestAuthorization()
            let after = alarmAuthorizationText(for: result)
            return "Alarm permission request result: \(after) (before: \(before))"
        } catch {
            return "Alarm permission request failed: \(error.localizedDescription) (before: \(before))"
        }
    }

    func requestAlarmAuthorizationIfNeededOnLaunch() async {
        guard #available(iOS 26.0, *) else {
            return
        }

        guard AlarmManager.shared.authorizationState == .notDetermined else {
            return
        }

        _ = try? await AlarmManager.shared.requestAuthorization()
    }

    func dumpAlarmAuthorizationDebug() -> String {
        "Current Alarm authorization: \(alarmAuthorizationDebugText())"
    }

    func alarmRuntimeDiagnosticReport() -> String {
        let usageDescription = Bundle.main.object(forInfoDictionaryKey: "NSAlarmKitUsageDescription") as? String
        let liveActivitiesFlag = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool
        let widgetBundleIdentifier = "com.xin.Watch-ur-time.widget"
        let widgetPluginURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("Watch ur time Widget.appex")
        let widgetExists = widgetPluginURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let sharedDefaults = UserDefaults(suiteName: WidgetSharedContainer.appGroupID)

        return """
        Alarm auth state: \(alarmAuthorizationDebugText())
        NSAlarmKitUsageDescription: \(usageDescription ?? "missing")
        NSSupportsLiveActivities: \(liveActivitiesFlag.map { $0 ? "YES" : "NO" } ?? "missing")
        Widget bundle expected: \(widgetBundleIdentifier)
        Widget embedded: \(widgetExists ? "YES" : "NO")
        App group suite open: \(sharedDefaults == nil ? "NO" : "YES")
        App group id: \(WidgetSharedContainer.appGroupID)
        """
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else {
            return
        }

        UIApplication.shared.open(url)
    }

    @available(iOS 26.0, *)
    private func alarmAuthorizationText(for state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func syncPhoneNotifications(_ reminders: [ScheduledClassReminder]) async {
        let existingIDs = Set(defaults.stringArray(forKey: scheduledNotificationKey) ?? [])
        let desiredIDs = Set(reminders.map(\.notificationIdentifier))
        let identifiersToRemove = Array(existingIDs.union(desiredIDs))

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        defaults.set(Array(desiredIDs), forKey: scheduledNotificationKey)

        guard !reminders.isEmpty else {
            return
        }

        let granted = await requestNotificationAuthorizationIfNeeded()
        guard granted else {
            return
        }

        for reminder in reminders {
            await schedulePhoneNotification(for: reminder, repeats: true)
        }
    }

    @available(iOS 26.0, *)
    private func syncAlarmKit(_ reminders: [ScheduledClassReminder]) async {
        let manager = AlarmManager.shared
        let existingIDs = Set(
            (defaults.stringArray(forKey: scheduledAlarmKey) ?? []).compactMap(UUID.init(uuidString:))
        )
        let desiredIDs = Set(reminders.map(\.alarmID))
        let identifiersToClear = Array(existingIDs.union(desiredIDs))

        for identifier in identifiersToClear {
            try? manager.stop(id: identifier)
            try? manager.cancel(id: identifier)
        }

        defaults.set(desiredIDs.map(\.uuidString), forKey: scheduledAlarmKey)

        guard !reminders.isEmpty else {
            return
        }

        let authorizationState: AlarmManager.AuthorizationState
        switch manager.authorizationState {
        case .notDetermined:
            authorizationState = (try? await manager.requestAuthorization()) ?? .denied
        case .authorized:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }

        guard authorizationState == .authorized else {
            return
        }

        var successfullyScheduledIDs: [String] = []

        let sortedReminders = reminders.sorted { $0.fireDate < $1.fireDate }

        for reminder in sortedReminders {
            let result = await scheduleSingleAlarm(reminder)
            if result.contains("maximum limit") {
                break
            }
            if result.contains("scheduled") {
                successfullyScheduledIDs.append(reminder.alarmID.uuidString)
            }
        }

        defaults.set(successfullyScheduledIDs, forKey: scheduledAlarmKey)
    }

    private func requestNotificationAuthorizationIfNeeded() async -> Bool {
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

    private func schedulePhoneNotification(
        for reminder: ScheduledClassReminder,
        repeats: Bool = false
    ) async {
        let granted = await requestNotificationAuthorizationIfNeeded()
        guard granted else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = ""
        content.body = reminder.phoneMessage
        content.sound = .default

        let trigger: UNNotificationTrigger
        if repeats {
            var dateComponents = DateComponents()
            dateComponents.weekday = reminder.calendarWeekday
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            let interval = max(reminder.fireDate.timeIntervalSinceNow, 1)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: reminder.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }

    @available(iOS 26.0, *)
    private func scheduleSingleAlarm(_ reminder: ScheduledClassReminder) async -> String {
        let manager = AlarmManager.shared

        let authorizationState: AlarmManager.AuthorizationState
        switch manager.authorizationState {
        case .notDetermined:
            authorizationState = (try? await manager.requestAuthorization()) ?? .denied
        case .authorized:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }

        guard authorizationState == .authorized else {
            return "Alarm permission denied."
        }

        try? manager.stop(id: reminder.alarmID)
        try? manager.cancel(id: reminder.alarmID)

        let stopIntent = StopClassAlarmIntent(alarmID: reminder.alarmID.uuidString)
        let attributes = AlarmAttributes(
            presentation: reminder.presentation,
            metadata: ClassAlarmMetadata(
                subjectName: reminder.subjectName,
                eventKind: reminder.eventKind.rawValue,
                placementID: reminder.placementID
            ),
            tintColor: reminder.tintColor
        )

        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(reminder.fireDate),
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: reminder.supportsCustomStopLabel ? stopIntent : nil
        )

        do {
            _ = try await manager.schedule(id: reminder.alarmID, configuration: configuration)
            return "AlarmKit alarm scheduled."
        } catch AlarmManager.AlarmError.maximumLimitReached {
            return "AlarmKit maximum limit reached."
        } catch {
            return "AlarmKit failed: \(error.localizedDescription)"
        }
    }

    private func desiredReminders(for snapshot: TimetableStoreSnapshot) -> [ScheduledClassReminder] {
        let subjectsByID = Dictionary(uniqueKeysWithValues: snapshot.subjects.map { ($0.id, $0) })
        let notificationSettingsByPlacementID = Dictionary(
            uniqueKeysWithValues: snapshot.notificationSettings.map { ($0.placementID, $0) }
        )

        return snapshot.placements.flatMap { placement in
            guard snapshot.slots.indices.contains(placement.slotIndex),
                  let subject = subjectsByID[placement.subjectID]
            else {
                return [ScheduledClassReminder]()
            }

            let slot = snapshot.slots[placement.slotIndex]
            let setting = notificationSettingsByPlacementID[placement.id]
                ?? TimetableNotificationSetting(placementID: placement.id)
            let minutesBefore = snapshot.notificationTimeMode == .uniform
                ? snapshot.uniformNotificationMinutesBefore
                : setting.minutesBefore

            return events(
                for: placement,
                slot: slot,
                subject: subject,
                setting: setting,
                minutesBefore: minutesBefore
            )
        }
    }

    private func events(
        for placement: TimetablePlacement,
        slot: TimetableTimeSlot,
        subject: TimetableSubject,
        setting: TimetableNotificationSetting,
        minutesBefore: Int
    ) -> [ScheduledClassReminder] {
        var reminders: [ScheduledClassReminder] = []

        switch setting.moment {
        case .classBegins:
            if let reminder = reminder(
                eventKind: .start,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: minutesBefore
            ) {
                reminders.append(reminder)
            }
        case .classEnds:
            if let reminder = reminder(
                eventKind: .end,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: minutesBefore
            ) {
                reminders.append(reminder)
            }
        case .both:
            if let startReminder = reminder(
                eventKind: .start,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: minutesBefore
            ) {
                reminders.append(startReminder)
            }

            if let endReminder = reminder(
                eventKind: .end,
                placement: placement,
                slot: slot,
                subject: subject,
                minutesBefore: minutesBefore
            ) {
                reminders.append(endReminder)
            }
        }

        return reminders
    }

    private func reminder(
        eventKind: ReminderEventKind,
        placement: TimetablePlacement,
        slot: TimetableTimeSlot,
        subject: TimetableSubject,
        minutesBefore: Int
    ) -> ScheduledClassReminder? {
        let sourceMinutes: Int?

        switch eventKind {
        case .start:
            sourceMinutes = slot.startMinutesSinceMidnight
        case .end:
            sourceMinutes = slot.endMinutesSinceMidnight
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

        guard let fireDate = nextFireDate(
            weekday: calendarWeekday,
            hour: hour,
            minute: minute
        ) else {
            return nil
        }

        return ScheduledClassReminder(
            placementID: placement.id,
            subjectName: subject.name,
            eventKind: eventKind,
            alarmID: deterministicUUID(seed: "alarm-\(placement.id.uuidString)-\(eventKind.rawValue)"),
            notificationIdentifier: "class-reminder-\(placement.id.uuidString)-\(eventKind.rawValue)",
            title: eventKind == .start ? "Class is gonna start!!!" : "Class is gonna over!!!",
            phoneMessage: "Class \(subject.name) is gonna \(eventKind == .start ? "start" : "over")!!!\nWatch Ur Time bro",
            hour: hour,
            minute: minute,
            calendarWeekday: calendarWeekday.rawValue,
            localeWeekday: localeWeekday(from: calendarWeekday),
            tintColor: subject.color,
            fireDate: fireDate
        )
    }

    private func nextFireDate(
        weekday: CalendarWeekday,
        hour: Int,
        minute: Int,
        from referenceDate: Date = .now
    ) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday.rawValue
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.nextDate(
            after: referenceDate.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func calendarWeekday(forDayIndex dayIndex: Int) -> CalendarWeekday {
        switch dayIndex {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        default: return .monday
        }
    }

    private func previousWeekday(from weekday: CalendarWeekday) -> CalendarWeekday {
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

    private func localeWeekday(from weekday: CalendarWeekday) -> Locale.Weekday {
        switch weekday {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }

    private func deterministicUUID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest)

        let uuid = uuidBytes(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], (bytes[6] & 0x0F) | 0x50, bytes[7],
            (bytes[8] & 0x3F) | 0x80, bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuid)
    }

    private func uuidBytes(
        _ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8,
        _ b4: UInt8, _ b5: UInt8, _ b6: UInt8, _ b7: UInt8,
        _ b8: UInt8, _ b9: UInt8, _ b10: UInt8, _ b11: UInt8,
        _ b12: UInt8, _ b13: UInt8, _ b14: UInt8, _ b15: UInt8
    ) -> uuid_t {
        (b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15)
    }

    private func formattedDebugTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func calendarWeekday(from rawValue: Int) -> CalendarWeekday {
        CalendarWeekday(rawValue: rawValue) ?? .monday
    }
}

private struct ScheduledClassReminder {
    let placementID: UUID
    let subjectName: String
    let eventKind: ReminderEventKind
    let alarmID: UUID
    let notificationIdentifier: String
    let title: String
    let phoneMessage: String
    let hour: Int
    let minute: Int
    let calendarWeekday: Int
    let localeWeekday: Locale.Weekday
    let tintColor: Color
    let fireDate: Date

    @available(iOS 26.0, *)
    var supportsCustomStopLabel: Bool {
        if #available(iOS 26.1, *) {
            return true
        }
        return false
    }

    @available(iOS 26.0, *)
    var presentation: AlarmPresentation {
        let customStopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Shut The Hell Up"),
            textColor: .white,
            systemImageName: "speaker.slash.fill"
        )

        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                secondaryButton: customStopButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: customStopButton
            )
        }

        return AlarmPresentation(alert: alert)
    }
}

private enum ReminderEventKind: String {
    case start
    case end
}

private enum CalendarWeekday: Int {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}
