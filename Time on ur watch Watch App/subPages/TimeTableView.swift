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
        Group {
            if dataStore.hasTimetable {
                TabView(selection: selectedDayBinding) {
                    ForEach(1...5, id: \.self) { day in
                        dayPage(for: day)
                            .tag(day)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
        .navigationTitle(WatchDataStore.titleForDay(dataStore.selectedDay))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if dataStore.selectedDay != WatchDataStore.currentTimetableDay() {
                    Button {
                        dataStore.refreshCurrentDay()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchDayPickerView()
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
    }

    private var selectedDayBinding: Binding<Int> {
        Binding(
            get: { dataStore.selectedDay },
            set: { dataStore.setSelectedDay($0) }
        )
    }

    private func dayPage(for day: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(dataStore.entries(for: day)) { entry in
                        timetableRow(entry)
                            .id(entry.id)
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
                    .compatibleGlassSurface(cornerRadius: 24)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 6)
            }
            .onAppear {
                scrollToRelevantEntryIfNeeded(day: day, proxy: proxy, animated: false)
            }
            .onChange(of: dataStore.selectedDay) { _, _ in
                scrollToRelevantEntryIfNeeded(day: day, proxy: proxy)
            }
            .onChange(of: dataStore.snapshot.updatedAt) { _, _ in
                scrollToRelevantEntryIfNeeded(day: day, proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToRelevantEntryIfNeeded(
        day: Int,
        proxy: ScrollViewProxy,
        animated: Bool = true
    ) {
        guard day == dataStore.selectedDay,
              day == WatchDataStore.currentTimetableDay(),
              let targetID = dataStore.currentRelevantEntryID(for: day)
        else {
            return
        }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            } else {
                proxy.scrollTo(targetID, anchor: .center)
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
                    Text(entry.slot.formattedStartTime)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text("-")
                    Text(entry.slot.formattedEndTime)
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
        .compatibleGlassSurface(cornerRadius: 30, tint: entry.subject.color)
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
