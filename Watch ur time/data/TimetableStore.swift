//
//  TimetableStore.swift
//  Watch ur time
//
//  Created by Codex on 6/20/26.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

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
    var endTime: String

    init(id: UUID = UUID(), startTime: String, endTime: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }

    var displayLabel: String {
        "\(startTime) - \(endTime)"
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
        moment: NotificationMoment = .classBegins,
        minutesBefore: Int = 5
    ) {
        self.placementID = placementID
        self.moment = moment
        self.minutesBefore = minutesBefore
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
    var updatedAt: Date
    private var subjectsPayload: Data
    private var slotsPayload: Data
    private var placementsPayload: Data
    private var notificationSettingsPayload: Data

    init(
        updatedAt: Date = .now,
        subjects: [TimetableSubject] = [],
        slots: [TimetableTimeSlot] = [],
        placements: [TimetablePlacement] = [],
        notificationSettings: [TimetableNotificationSetting] = []
    ) {
        self.updatedAt = updatedAt
        self.subjectsPayload = Self.encode(subjects)
        self.slotsPayload = Self.encode(slots)
        self.placementsPayload = Self.encode(placements)
        self.notificationSettingsPayload = Self.encode(notificationSettings)
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
