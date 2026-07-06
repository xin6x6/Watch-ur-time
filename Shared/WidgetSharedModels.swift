//
//  WidgetSharedModels.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/23/26.
//

import Foundation
import SwiftUI

enum WidgetSharedContainer {
    static let appGroupID = "group.com.Ng1nx.Watch-ur-time.shared"
    static let snapshotKey = "widget_shared_timetable_snapshot"
}

struct WidgetClassSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var dayIndex: Int
    var subjectName: String
    var room: String
    var startLabel: String
    var endLabel: String
    var startMinutes: Int
    var endMinutes: Int
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var timeLabel: String {
        "\(startLabel) - \(endLabel)"
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct WidgetScheduleState: Hashable {
    var current: WidgetClassSnapshot?
    var next: WidgetClassSnapshot?
}

struct WidgetSnapshotPayload: Codable, Hashable {
    var updatedAt: Date
    var classes: [WidgetClassSnapshot]

    static let empty = WidgetSnapshotPayload(updatedAt: .now, classes: [])

    func classes(for dayIndex: Int) -> [WidgetClassSnapshot] {
        classes
            .filter { $0.dayIndex == dayIndex }
            .sorted {
                if $0.dayIndex == $1.dayIndex {
                    return $0.startMinutes < $1.startMinutes
                }
                return $0.dayIndex < $1.dayIndex
            }
    }

    func scheduleState(at date: Date = .now) -> WidgetScheduleState {
        WidgetScheduleState(
            current: currentClass(at: date),
            next: nextClass(after: date)
        )
    }

    func nextRefreshDate(after date: Date = .now) -> Date? {
        let currentDayIndex = Self.dayIndex(for: date)
        let currentMinute = Self.minuteOfDay(for: date)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)

        let candidateDates = classes.flatMap { item -> [Date] in
            var dates: [Date] = []

            var startOffset = item.dayIndex - currentDayIndex
            if startOffset < 0 || (startOffset == 0 && item.startMinutes <= currentMinute) {
                startOffset += 7
            }
            if let day = calendar.date(byAdding: .day, value: startOffset, to: startOfToday),
               let startDate = calendar.date(byAdding: .minute, value: item.startMinutes, to: day) {
                dates.append(startDate)
            }

            var endOffset = item.dayIndex - currentDayIndex
            if endOffset < 0 || (endOffset == 0 && item.endMinutes <= currentMinute) {
                endOffset += 7
            }
            if let day = calendar.date(byAdding: .day, value: endOffset, to: startOfToday),
               let endDate = calendar.date(byAdding: .minute, value: item.endMinutes, to: day) {
                dates.append(endDate)
            }

            return dates
        }

        return candidateDates
            .filter { $0 > date }
            .min()
            .map { $0.addingTimeInterval(1) }
    }

    private func currentClass(at date: Date) -> WidgetClassSnapshot? {
        let dayIndex = Self.dayIndex(for: date)
        let minute = Self.minuteOfDay(for: date)

        return classes(for: dayIndex).first { item in
            item.startMinutes <= minute && minute < item.endMinutes
        }
    }

    private func nextClass(after date: Date) -> WidgetClassSnapshot? {
        let currentDayIndex = Self.dayIndex(for: date)
        let currentMinute = Self.minuteOfDay(for: date)
        let sortedClasses = classes.sorted {
            if $0.dayIndex == $1.dayIndex {
                return $0.startMinutes < $1.startMinutes
            }
            return $0.dayIndex < $1.dayIndex
        }

        for offset in 0..<7 {
            let day = ((currentDayIndex - 1 + offset) % 7) + 1
            let dailyClasses = sortedClasses.filter { $0.dayIndex == day }

            if offset == 0 {
                if let nextToday = dailyClasses.first(where: { $0.startMinutes > currentMinute }) {
                    return nextToday
                }
            } else if let nextLaterDay = dailyClasses.first {
                return nextLaterDay
            }
        }

        return nil
    }

    private static func dayIndex(for date: Date) -> Int {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5
        case 7: return 6
        case 1: return 7
        default: return 1
        }
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }
}
