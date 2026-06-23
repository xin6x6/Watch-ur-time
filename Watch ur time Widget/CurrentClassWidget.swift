//
//  CurrentClassWidget.swift
//  Watch ur time Widget
//
//  Created By Ng1nx on 6/23/26.
//

import SwiftUI
import WidgetKit

private struct CurrentClassEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
    let state: WidgetScheduleState
}

private struct CurrentClassProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentClassEntry {
        CurrentClassEntry(
            date: .now,
            payload: .empty,
            state: WidgetScheduleState(
                current: WidgetClassSnapshot(
                    id: UUID(),
                    dayIndex: 2,
                    subjectName: "Mathematics",
                    room: "Room 203",
                    startLabel: "9:00 AM",
                    endLabel: "10:15 AM",
                    startMinutes: 540,
                    endMinutes: 615,
                    red: 0.16,
                    green: 0.48,
                    blue: 0.96,
                    alpha: 1
                ),
                next: WidgetClassSnapshot(
                    id: UUID(),
                    dayIndex: 2,
                    subjectName: "Physics",
                    room: "Lab 2",
                    startLabel: "10:30 AM",
                    endLabel: "11:45 AM",
                    startMinutes: 630,
                    endMinutes: 705,
                    red: 0.93,
                    green: 0.49,
                    blue: 0.16,
                    alpha: 1
                )
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentClassEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentClassEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(at: now)
        let refreshDate = entry.payload.nextRefreshDate(after: now)
            ?? Calendar.current.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(900)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(refreshDate)
            )
        )
    }

    private func makeEntry(at date: Date) -> CurrentClassEntry {
        let payload = loadPayload()
        return CurrentClassEntry(
            date: date,
            payload: payload,
            state: payload.scheduleState(at: date)
        )
    }

    private func loadPayload() -> WidgetSnapshotPayload {
        let defaults = UserDefaults(suiteName: WidgetSharedContainer.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: WidgetSharedContainer.snapshotKey),
              let payload = try? JSONDecoder().decode(WidgetSnapshotPayload.self, from: data)
        else {
            return .empty
        }

        return payload
    }
}

struct CurrentClassWidget: Widget {
    private let kind = "CurrentClassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentClassProvider()) { entry in
            CurrentClassWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Current Class")
        .description("Shows the current class and the next one.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct CurrentClassWidgetView: View {
    let entry: CurrentClassEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .accessoryRectangular:
            accessoryBody
        default:
            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader("Now")

            if let current = entry.state.current {
                classCard(current, title: nil)
            } else {
                idleCard
            }

            if let next = entry.state.next {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(next.subjectName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(next.startLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                widgetHeader("Schedule")
                Spacer()
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let current = entry.state.current {
                    classCard(current, title: "Now")
                } else {
                    idleCard
                }

                if let next = entry.state.next {
                    classCard(next, title: "Next")
                } else {
                    emptyNextCard
                }
            }
        }
        .padding(16)
    }

    private var accessoryBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.state.current?.subjectName ?? "No class now")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(entry.state.current?.room ?? entry.state.next?.subjectName ?? "Next class unavailable")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(entry.state.current?.timeLabel ?? entry.state.next?.timeLabel ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func widgetHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .lineLimit(1)
    }

    private func classCard(_ item: WidgetClassSnapshot, title: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 0)

            Text(item.subjectName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(item.timeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Text(item.room)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            item.color.opacity(0.95),
                            item.color.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("No class now")
                .font(.headline.weight(.bold))
            Text(entry.state.next?.subjectName ?? "No more classes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(entry.state.next?.timeLabel ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    private var emptyNextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("No next class")
                .font(.headline.weight(.bold))
            Text("Your timetable is clear.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

#Preview(as: .systemMedium) {
    CurrentClassWidget()
} timeline: {
    CurrentClassEntry(
        date: .now,
        payload: .empty,
        state: WidgetScheduleState(
            current: WidgetClassSnapshot(
                id: UUID(),
                dayIndex: 1,
                subjectName: "Mathematics",
                room: "Room 203",
                startLabel: "9:00 AM",
                endLabel: "10:15 AM",
                startMinutes: 540,
                endMinutes: 615,
                red: 0.18,
                green: 0.42,
                blue: 0.96,
                alpha: 1
            ),
            next: WidgetClassSnapshot(
                id: UUID(),
                dayIndex: 1,
                subjectName: "Physics",
                room: "Lab 2",
                startLabel: "10:30 AM",
                endLabel: "11:45 AM",
                startMinutes: 630,
                endMinutes: 705,
                red: 0.95,
                green: 0.53,
                blue: 0.11,
                alpha: 1
            )
        )
    )
}
