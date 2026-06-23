//
//  TimetableStore.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/20/26.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

enum TimeMeridiem: String, Codable, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }
}

enum NotificationMoment: Int, Codable, CaseIterable, Identifiable {
    case classBegins
    case classEnds
    case both

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .classBegins:
            return "Class begins"
        case .classEnds:
            return "Class ends"
        case .both:
            return "Both"
        }
    }
}

struct TimetableSubject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var room: String
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(
        id: UUID = UUID(),
        name: String,
        room: String,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(id: UUID = UUID(), name: String, room: String, swiftUIColor: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1

        UIColor(swiftUIColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        self.init(
            id: id,
            name: name,
            room: room,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    init(id: UUID = UUID(), name: String, room: String, color: CGColor) {
        self.init(id: id, name: name, room: room, swiftUIColor: Color(UIColor(cgColor: color)))
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var cgColor: CGColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha).cgColor
    }
}

struct TimetableTimeSlot: Codable, Identifiable, Hashable {
    var id: UUID
    var startTime: String
    var startMeridiem: TimeMeridiem
    var endTime: String
    var endMeridiem: TimeMeridiem

    init(
        id: UUID = UUID(),
        startTime: String,
        startMeridiem: TimeMeridiem = .am,
        endTime: String,
        endMeridiem: TimeMeridiem = .am
    ) {
        self.id = id
        self.startTime = startTime
        self.startMeridiem = startMeridiem
        self.endTime = endTime
        self.endMeridiem = endMeridiem
    }

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
        startMeridiem = try container.decodeIfPresent(TimeMeridiem.self, forKey: .startMeridiem)
            ?? Self.inferredMeridiem(for: startTime)
        endMeridiem = try container.decodeIfPresent(TimeMeridiem.self, forKey: .endMeridiem)
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

    var endMinutesSinceMidnight: Int? {
        Self.minutesSinceMidnight(time: endTime, meridiem: endMeridiem)
    }

    static func minutesSinceMidnight(time: String, meridiem: TimeMeridiem) -> Int? {
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

    private static func inferredMeridiem(for time: String) -> TimeMeridiem {
        guard let components = parseHourMinute(time.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .am
        }

        return components.hour >= 12 ? .pm : .am
    }

    private static func displayString(time: String, meridiem: TimeMeridiem) -> String {
        guard let minutes = minutesSinceMidnight(time: time, meridiem: meridiem) else {
            return "\(time.trimmingCharacters(in: .whitespacesAndNewlines)) \(meridiem.rawValue)"
        }

        let hour24 = minutes / 60
        let minute = minutes % 60
        let normalizedMeridiem: TimeMeridiem = hour24 >= 12 ? .pm : .am
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

struct TimetablePlacement: Codable, Identifiable, Hashable {
    var id: UUID
    var dayIndex: Int
    var slotIndex: Int
    var subjectID: UUID

    init(id: UUID = UUID(), dayIndex: Int, slotIndex: Int, subjectID: UUID) {
        self.id = id
        self.dayIndex = dayIndex
        self.slotIndex = slotIndex
        self.subjectID = subjectID
    }
}

struct TimetableNotificationSetting: Codable, Identifiable, Hashable {
    var placementID: UUID
    var moment: NotificationMoment
    var minutesBefore: Int

    var id: UUID { placementID }

    init(
        placementID: UUID,
        moment: NotificationMoment = .classEnds,
        minutesBefore: Int = 2
    ) {
        self.placementID = placementID
        self.moment = moment
        self.minutesBefore = minutesBefore
    }
}

struct TimetableAssignment: Codable, Identifiable, Hashable {
    var id: UUID
    var subject: String
    var content: String
    var startDate: Date
    var dueDate: Date
    var createdAt: Date
    var isFinished: Bool

    init(
        id: UUID = UUID(),
        subject: String,
        content: String,
        startDate: Date,
        dueDate: Date,
        createdAt: Date = .now,
        isFinished: Bool = false
    ) {
        self.id = id
        self.subject = subject
        self.content = content
        self.startDate = startDate
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.isFinished = isFinished
    }

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case content
        case startDate
        case dueDate
        case createdAt
        case isFinished
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        subject = try container.decode(String.self, forKey: .subject)
        content = try container.decode(String.self, forKey: .content)
        startDate = try container.decode(Date.self, forKey: .startDate)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? dueDate
        isFinished = try container.decodeIfPresent(Bool.self, forKey: .isFinished) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(subject, forKey: .subject)
        try container.encode(content, forKey: .content)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isFinished, forKey: .isFinished)
    }
}

struct TimetableDayEntry: Identifiable, Hashable {
    let placement: TimetablePlacement
    let subject: TimetableSubject
    let slot: TimetableTimeSlot
    let notificationSetting: TimetableNotificationSetting?

    var id: UUID { placement.id }
}

@Model
final class TimetableStore {
    var updatedAt: Date = Date()
    private var subjectsPayload: Data = Data()
    private var slotsPayload: Data = Data()
    private var placementsPayload: Data = Data()
    private var notificationSettingsPayload: Data = Data()
    private var assignmentsPayload: Data = Data()

    init(
        updatedAt: Date = .now,
        subjects: [TimetableSubject] = [],
        slots: [TimetableTimeSlot] = [],
        placements: [TimetablePlacement] = [],
        notificationSettings: [TimetableNotificationSetting] = [],
        assignments: [TimetableAssignment] = []
    ) {
        self.updatedAt = updatedAt
        self.subjectsPayload = Self.encode(subjects)
        self.slotsPayload = Self.encode(slots)
        self.placementsPayload = Self.encode(placements)
        self.notificationSettingsPayload = Self.encode(notificationSettings)
        self.assignmentsPayload = Self.encode(assignments)
    }

    var subjects: [TimetableSubject] {
        get { Self.decode(subjectsPayload, defaultValue: []) }
        set {
            subjectsPayload = Self.encode(newValue)
            updatedAt = .now
        }
    }

    var slots: [TimetableTimeSlot] {
        get { Self.decode(slotsPayload, defaultValue: []) }
        set {
            slotsPayload = Self.encode(newValue)
            updatedAt = .now
        }
    }

    var placements: [TimetablePlacement] {
        get { Self.decode(placementsPayload, defaultValue: []) }
        set {
            placementsPayload = Self.encode(newValue)
            updatedAt = .now
        }
    }

    var notificationSettings: [TimetableNotificationSetting] {
        get { Self.decode(notificationSettingsPayload, defaultValue: []) }
        set {
            notificationSettingsPayload = Self.encode(newValue)
            updatedAt = .now
        }
    }

    var assignments: [TimetableAssignment] {
        get { Self.decode(assignmentsPayload, defaultValue: []) }
        set {
            assignmentsPayload = Self.encode(newValue)
            updatedAt = .now
        }
    }

    var hasTimetable: Bool {
        !subjects.isEmpty && !slots.isEmpty && !placements.isEmpty
    }

    func replaceAll(
        subjects: [TimetableSubject],
        slots: [TimetableTimeSlot],
        placements: [TimetablePlacement],
        notificationSettings: [TimetableNotificationSetting]
    ) {
        subjectsPayload = Self.encode(subjects)
        slotsPayload = Self.encode(slots)
        placementsPayload = Self.encode(placements)
        notificationSettingsPayload = Self.encode(notificationSettings)
        updatedAt = .now
    }

    func subject(for subjectID: UUID) -> TimetableSubject? {
        subjects.first(where: { $0.id == subjectID })
    }

    func subjectID(dayIndex: Int, slotIndex: Int) -> UUID? {
        placements.first(where: {
            $0.dayIndex == dayIndex && $0.slotIndex == slotIndex
        })?.subjectID
    }

    func notificationSetting(for placementID: UUID) -> TimetableNotificationSetting? {
        notificationSettings.first(where: { $0.placementID == placementID })
    }

    func upsertNotificationSetting(_ setting: TimetableNotificationSetting) {
        var currentSettings = notificationSettings

        if let index = currentSettings.firstIndex(where: { $0.placementID == setting.placementID }) {
            currentSettings[index] = setting
        } else {
            currentSettings.append(setting)
        }

        notificationSettings = currentSettings
    }

    func assignment(with assignmentID: UUID) -> TimetableAssignment? {
        assignments.first(where: { $0.id == assignmentID })
    }

    func upsertAssignment(_ assignment: TimetableAssignment) {
        var currentAssignments = assignments

        if let index = currentAssignments.firstIndex(where: { $0.id == assignment.id }) {
            currentAssignments[index] = assignment
        } else {
            currentAssignments.append(assignment)
        }

        assignments = currentAssignments
    }

    func removeAssignment(_ assignmentID: UUID) {
        assignments = assignments.filter { $0.id != assignmentID }
    }

    func subjectColor(for subject: String) -> Color {
        if let timetableSubject = subjects.first(where: {
            $0.name.localizedCaseInsensitiveCompare(subject) == .orderedSame
        }) {
            return timetableSubject.color
        }

        let palette: [Color] = [.blue, .green, .orange, .pink, .indigo, .teal]
        let hashValue = abs(subject.lowercased().hashValue)
        return palette[hashValue % palette.count]
    }

    func entries(for dayIndex: Int) -> [TimetableDayEntry] {
        placements
            .filter { $0.dayIndex == dayIndex }
            .sorted { $0.slotIndex < $1.slotIndex }
            .compactMap { placement in
                guard slots.indices.contains(placement.slotIndex) else {
                    return nil
                }

                let slot = slots[placement.slotIndex]

                guard let subject = subject(for: placement.subjectID) else {
                    return nil
                }

                return TimetableDayEntry(
                    placement: placement,
                    subject: subject,
                    slot: slot,
                    notificationSetting: notificationSetting(for: placement.id)
                )
            }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ data: Data, defaultValue: T) -> T {
        (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }
}

struct TimetableArchive: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var store: TimetableStoreSnapshot

    init(
        schemaVersion: Int = 2,
        exportedAt: Date = .now,
        store: TimetableStoreSnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.store = store
    }
}

struct TimetableStoreSnapshot: Codable {
    var updatedAt: Date
    var subjects: [TimetableSubject]
    var slots: [TimetableTimeSlot]
    var placements: [TimetablePlacement]
    var notificationSettings: [TimetableNotificationSetting]
    var assignments: [TimetableAssignment]
}

extension TimetableStore {
    var snapshot: TimetableStoreSnapshot {
        TimetableStoreSnapshot(
            updatedAt: updatedAt,
            subjects: subjects,
            slots: slots,
            placements: placements,
            notificationSettings: notificationSettings,
            assignments: assignments
        )
    }

    func apply(snapshot: TimetableStoreSnapshot) {
        subjectsPayload = Self.encode(snapshot.subjects)
        slotsPayload = Self.encode(snapshot.slots)
        placementsPayload = Self.encode(snapshot.placements)
        notificationSettingsPayload = Self.encode(snapshot.notificationSettings)
        assignmentsPayload = Self.encode(snapshot.assignments)
        updatedAt = snapshot.updatedAt
    }
}
