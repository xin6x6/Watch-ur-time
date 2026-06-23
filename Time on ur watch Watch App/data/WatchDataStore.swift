//
//  WatchDataStore.swift
//  Time on ur watch Watch App
//
//  Created By Ng1nx on 6/22/26.
//

import Combine
import Foundation
import SwiftUI
import WatchConnectivity

enum WatchTimeMeridiem: String, Codable, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }
}

enum WatchSyncMessageKey {
    static let action = "action"
    static let snapshot = "snapshot"
    static let assignment = "assignment"
    static let assignmentID = "assignmentID"
    static let fireTimestamp = "fireTimestamp"

    static let requestSnapshot = "requestSnapshot"
    static let upsertAssignment = "upsertAssignment"
    static let deleteAssignment = "deleteAssignment"
    static let toggleAssignment = "toggleAssignment"
    static let scheduleWatchTestReminder = "scheduleWatchTestReminder"
    static let clearWatchTestReminder = "clearWatchTestReminder"
}

enum WatchNotificationMoment: Int, Codable, CaseIterable, Identifiable {
    case classBegins
    case classEnds
    case both

    var id: Int { rawValue }
}

struct WatchTimetableSubject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var room: String
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct WatchTimetableTimeSlot: Codable, Identifiable, Hashable {
    var id: UUID
    var startTime: String
    var startMeridiem: WatchTimeMeridiem
    var endTime: String
    var endMeridiem: WatchTimeMeridiem

    enum CodingKeys: String, CodingKey {
        case id
        case startTime
        case startMeridiem
        case endTime
        case endMeridiem
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        startMeridiem = try container.decodeIfPresent(WatchTimeMeridiem.self, forKey: .startMeridiem)
            ?? Self.inferredMeridiem(for: startTime)
        endMeridiem = try container.decodeIfPresent(WatchTimeMeridiem.self, forKey: .endMeridiem)
            ?? Self.inferredMeridiem(for: endTime)
    }

    var formattedStartTime: String {
        Self.displayString(time: startTime, meridiem: startMeridiem)
    }

    var formattedEndTime: String {
        Self.displayString(time: endTime, meridiem: endMeridiem)
    }

    var displayLabel: String {
        "\(formattedStartTime) - \(formattedEndTime)"
    }

    var startMinutesSinceMidnight: Int? {
        Self.minutesSinceMidnight(time: startTime, meridiem: startMeridiem)
    }

    static func minutesSinceMidnight(time: String, meridiem: WatchTimeMeridiem) -> Int? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)

        if let components = parseHourMinute(trimmed) {
            let hour = components.hour
            let minute = components.minute

            guard minute >= 0, minute < 60 else {
                return nil
            }

            if hour > 12 {
                guard hour < 24 else {
                    return nil
                }
                return hour * 60 + minute
            }

            guard hour >= 1, hour <= 12 else {
                return nil
            }

            if hour == 12 {
                return (meridiem == .am ? 0 : 12 * 60) + minute
            }

            return (meridiem == .pm ? hour + 12 : hour) * 60 + minute
        }

        return nil
    }

    private static func inferredMeridiem(for time: String) -> WatchTimeMeridiem {
        guard let components = parseHourMinute(time.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .am
        }

        return components.hour >= 12 ? .pm : .am
    }

    private static func displayString(time: String, meridiem: WatchTimeMeridiem) -> String {
        guard let minutes = minutesSinceMidnight(time: time, meridiem: meridiem) else {
            return "\(time.trimmingCharacters(in: .whitespacesAndNewlines)) \(meridiem.rawValue)"
        }

        let hour24 = minutes / 60
        let minute = minutes % 60
        let normalizedMeridiem: WatchTimeMeridiem = hour24 >= 12 ? .pm : .am
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return "\(hour12):" + String(format: "%02d", minute) + " \(normalizedMeridiem.rawValue)"
    }

    private static func parseHourMinute(_ time: String) -> (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let minute = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }

        return (hour, minute)
    }
}

struct WatchTimetablePlacement: Codable, Identifiable, Hashable {
    var id: UUID
    var dayIndex: Int
    var slotIndex: Int
    var subjectID: UUID
}

struct WatchTimetableNotificationSetting: Codable, Identifiable, Hashable {
    var placementID: UUID
    var moment: WatchNotificationMoment
    var minutesBefore: Int

    var id: UUID { placementID }
}

struct WatchTimetableAssignment: Codable, Identifiable, Hashable {
    var id: UUID
    var subject: String
    var content: String
    var startDate: Date
    var dueDate: Date
    var createdAt: Date
    var isFinished: Bool
}

struct WatchTimetableStoreSnapshot: Codable {
    var updatedAt: Date
    var subjects: [WatchTimetableSubject]
    var slots: [WatchTimetableTimeSlot]
    var placements: [WatchTimetablePlacement]
    var notificationSettings: [WatchTimetableNotificationSetting]
    var assignments: [WatchTimetableAssignment]

    static let empty = WatchTimetableStoreSnapshot(
        updatedAt: .now,
        subjects: [],
        slots: [],
        placements: [],
        notificationSettings: [],
        assignments: []
    )
}

struct WatchTimetableDayEntry: Identifiable, Hashable {
    let placement: WatchTimetablePlacement
    let subject: WatchTimetableSubject
    let slot: WatchTimetableTimeSlot
    let notificationSetting: WatchTimetableNotificationSetting?

    var id: UUID { placement.id }
}

struct WatchAssignmentSection: Identifiable {
    let subject: String
    let assignments: [WatchTimetableAssignment]

    var id: String { subject }
}

@MainActor
final class WatchDataStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchTimetableStoreSnapshot
    @Published var selectedDay: Int

    private let storageKey = "watch_timetable_snapshot"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let reminderScheduler = WatchClassReminderScheduler()

    override init() {
        self.snapshot = Self.loadSnapshot(storageKey: storageKey)
        self.selectedDay = Self.currentTimetableDay()
        super.init()
        activateSession()
        Task {
            await reminderScheduler.sync(with: snapshot)
        }
    }

    var availableSubjects: [String] {
        snapshot.subjects.map(\.name).sorted()
    }

    var hasTimetable: Bool {
        !snapshot.subjects.isEmpty && !snapshot.slots.isEmpty && !snapshot.placements.isEmpty
    }

    func refreshCurrentDay() {
        selectedDay = Self.currentTimetableDay()
    }

    func setSelectedDay(_ day: Int) {
        selectedDay = min(max(day, 1), 5)
    }

    func entries(for dayIndex: Int) -> [WatchTimetableDayEntry] {
        snapshot.placements
            .filter { $0.dayIndex == dayIndex }
            .sorted { $0.slotIndex < $1.slotIndex }
            .compactMap { placement in
                guard snapshot.slots.indices.contains(placement.slotIndex),
                      let subject = snapshot.subjects.first(where: { $0.id == placement.subjectID })
                else {
                    return nil
                }

                return WatchTimetableDayEntry(
                    placement: placement,
                    subject: subject,
                    slot: snapshot.slots[placement.slotIndex],
                    notificationSetting: snapshot.notificationSettings.first(where: { $0.placementID == placement.id })
                )
            }
    }

    func currentRelevantEntryID(for dayIndex: Int, at date: Date = Date()) -> UUID? {
        let dayEntries = entries(for: dayIndex)
        guard !dayEntries.isEmpty else {
            return nil
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        var candidate = dayEntries.first

        for entry in dayEntries {
            guard let startMinutes = entry.slot.startMinutesSinceMidnight else {
                continue
            }

            if startMinutes <= currentMinutes {
                candidate = entry
            } else {
                break
            }
        }

        return candidate?.id
    }

    func assignment(with assignmentID: UUID) -> WatchTimetableAssignment? {
        snapshot.assignments.first(where: { $0.id == assignmentID })
    }

    func assignmentSections(filter: WatchAssignmentFilter) -> [WatchAssignmentSection] {
        let filteredAssignments = snapshot.assignments.filter { assignment in
            switch filter {
            case .all:
                return true
            case .subject(let subject):
                return assignment.subject.localizedCaseInsensitiveCompare(subject) == .orderedSame
            }
        }

        let grouped = Dictionary(grouping: filteredAssignments, by: \.subject)

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { subject in
                let assignments = (grouped[subject] ?? []).sorted {
                    if $0.createdAt == $1.createdAt {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return $0.createdAt < $1.createdAt
                }

                return WatchAssignmentSection(subject: subject, assignments: assignments)
            }
    }

    func upsertAssignment(
        id: UUID?,
        subject: String,
        content: String,
        startDate: Date,
        dueDate: Date
    ) {
        let existing = id.flatMap(assignment(with:))
        let assignment = WatchTimetableAssignment(
            id: id ?? UUID(),
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            dueDate: dueDate,
            createdAt: existing?.createdAt ?? .now,
            isFinished: existing?.isFinished ?? false
        )

        var assignments = snapshot.assignments
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index] = assignment
        } else {
            assignments.append(assignment)
        }

        snapshot.assignments = assignments
        snapshot.updatedAt = .now
        persistSnapshot()
        guard let encodedAssignment = try? encoder.encode(assignment) else {
            return
        }
        sendAssignmentMessage(
            action: WatchSyncMessageKey.upsertAssignment,
            payload: [WatchSyncMessageKey.assignment: encodedAssignment]
        )
    }

    func toggleAssignment(_ assignment: WatchTimetableAssignment) {
        var assignments = snapshot.assignments
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else {
            return
        }

        assignments[index].isFinished.toggle()
        snapshot.assignments = assignments
        snapshot.updatedAt = .now
        persistSnapshot()
        sendAssignmentMessage(
            action: WatchSyncMessageKey.toggleAssignment,
            payload: [WatchSyncMessageKey.assignmentID: assignment.id.uuidString]
        )
    }

    func deleteAssignment(_ assignment: WatchTimetableAssignment) {
        snapshot.assignments.removeAll { $0.id == assignment.id }
        snapshot.updatedAt = .now
        persistSnapshot()
        sendAssignmentMessage(
            action: WatchSyncMessageKey.deleteAssignment,
            payload: [WatchSyncMessageKey.assignmentID: assignment.id.uuidString]
        )
    }

    private func activateSession() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func persistSnapshot() {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func applySnapshotData(_ data: Data) {
        guard let decoded = try? decoder.decode(WatchTimetableStoreSnapshot.self, from: data) else {
            return
        }

        snapshot = decoded
        persistSnapshot()
        Task {
            await reminderScheduler.sync(with: decoded)
        }
    }

    private func handle(message: [String: Any]) {
        if let action = message[WatchSyncMessageKey.action] as? String {
            switch action {
            case WatchSyncMessageKey.scheduleWatchTestReminder:
                guard let timestamp = message[WatchSyncMessageKey.fireTimestamp] as? TimeInterval else {
                    return
                }
                Task {
                    await reminderScheduler.scheduleDebugReminder(
                        at: Date(timeIntervalSince1970: timestamp)
                    )
                }
                return

            case WatchSyncMessageKey.clearWatchTestReminder:
                Task {
                    await reminderScheduler.clearDebugReminder()
                }
                return

            default:
                break
            }
        }

        guard let data = message[WatchSyncMessageKey.snapshot] as? Data else {
            return
        }

        applySnapshotData(data)
    }

    private func requestLatestSnapshot() {
        guard WCSession.isSupported() else {
            return
        }

        let message = [WatchSyncMessageKey.action: WatchSyncMessageKey.requestSnapshot]
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(message) { [weak self] response in
                guard let data = response[WatchSyncMessageKey.snapshot] as? Data else {
                    return
                }

                Task { @MainActor in
                    self?.applySnapshotData(data)
                }
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func sendAssignmentMessage(action: String, payload: [String: Any]) {
        guard WCSession.isSupported() else {
            return
        }

        var message = payload
        message[WatchSyncMessageKey.action] = action

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    private static func loadSnapshot(storageKey: String) -> WatchTimetableStoreSnapshot {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WatchTimetableStoreSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    static func currentTimetableDay(for date: Date = Date()) -> Int {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5
        case 7: return 5
        case 1: return 1
        default: return 1
        }
    }

    static func titleForDay(_ day: Int) -> String {
        switch day {
        case 1: return "Mon."
        case 2: return "Tue."
        case 3: return "Wed."
        case 4: return "Thu."
        case 5: return "Fri."
        default: return "Mon."
        }
    }
}

extension WatchDataStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.requestLatestSnapshot()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handle(message: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handle(message: message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            self.handle(message: userInfo)
        }
    }
}

enum WatchAssignmentFilter: Hashable {
    case all
    case subject(String)
}
