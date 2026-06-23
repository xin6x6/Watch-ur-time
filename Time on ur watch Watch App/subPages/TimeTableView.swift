//
//  TimeTableView.swift
//  Time on ur watch Watch App
//
//  Created By Ng1nx on 6/22/26.
//

import SwiftUI

struct TimeTableView: View {
    @EnvironmentObject private var dataStore: WatchDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if dataStore.hasTimetable {
                    ForEach(dataStore.entries(for: dataStore.selectedDay)) { entry in
                        timetableRow(entry)
                    }

                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Continue scrolling for assignments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                } else {
                    GlassCard {
                        VStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title3)
                            Text("No timetable yet")
                                .font(.headline)
                            Text("Add subjects on iPhone first.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle(WatchDataStore.titleForDay(dataStore.selectedDay))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchDayPickerView()
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
    }

    private func timetableRow(_ entry: WatchTimetableDayEntry) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.subject.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 4) {
                    Text(entry.slot.startTime)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text("-")
                    Text(entry.slot.endTime)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 6)

                Spacer(minLength: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(entry.subject.room)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.trailing, 2)
                .padding(.bottom, 1)
        }
        .frame(maxWidth: .infinity)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            entry.subject.color.opacity(0.26),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .glassEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(entry.subject.color.opacity(0.5), lineWidth: 1)
        }
        .padding(.horizontal)
    }
}

private struct WatchDayPickerView: View {
    @EnvironmentObject private var dataStore: WatchDataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(1...5, id: \.self) { day in
                Button {
                    dataStore.setSelectedDay(day)
                    dismiss()
                } label: {
                    HStack {
                        Text(WatchDataStore.titleForDay(day))
                        Spacer()
                        if dataStore.selectedDay == day {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Weekday")
    }
}

#Preview {
    NavigationStack {
        TimeTableView()
            .environmentObject(WatchDataStore())
    }
}
