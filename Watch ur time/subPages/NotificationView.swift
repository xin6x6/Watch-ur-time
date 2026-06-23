//
//  NotificationView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI

var dayToString = [1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday"]

struct NotificationView: View {
    @Binding var day: Int
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Title(text: dayTitle)

                    if dayEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(dayEntries) { entry in
                            NavigationLink(destination: AdjustNotificationView(entry: entry)) {
                                GlassCardNotification(
                                    className: entry.subject.name,
                                    room: entry.subject.room,
                                    startTime: entry.slot.formattedStartTime,
                                    endTime: entry.slot.formattedEndTime,
                                    notificationTime: entry.notificationSummary
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(TapGesture().onEnded { _ in
                UIImpactFeedbackGenerator(style: .heavy)
                    .impactOccurred()
            })
        }
        .tint(.primary)
    }

    private var store: TimetableStore? {
        stores.first
    }

    private var dayEntries: [TimetableDayEntry] {
        store?.entries(for: day) ?? []
    }

    private var dayTitle: String {
        dayToString[day] ?? "Day"
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("No classes for \(dayTitle)")
                    .font(.headline)
                Text("Create or edit your timetable first, then adjust notifications for each class here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        }
    }
}

struct AdjustNotificationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    let entry: TimetableDayEntry

    @State private var selectedMoment: NotificationMoment = .classEnds
    @State private var advanceTime = 2
    @State private var didLoadSetting = false
    @State private var errorMessage: String?

    private let advanceOptions = Array(0...60)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                momentSection
                advanceSection
                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("Adjust notification")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to save notification", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .task {
            loadSettingIfNeeded()
        }
        .onChange(of: selectedMoment) { _, _ in
            saveNotificationSetting()
        }
        .onChange(of: advanceTime) { _, _ in
            saveNotificationSetting()
        }
    }

    private var headerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.subject.name)
                    .font(.title3.bold())
                Text(entry.subject.room)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.slot.displayLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var momentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At")
                .font(.headline)
            Picker("At", selection: $selectedMoment) {
                ForEach(NotificationMoment.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var advanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In advance for")
                .font(.headline)
            Picker("In advance for", selection: $advanceTime) {
                ForEach(advanceOptions, id: \.self) { minute in
                    Text(minute == 0 ? "On time" : "\(minute) mins")
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func loadSettingIfNeeded() {
        guard !didLoadSetting else {
            return
        }
        didLoadSetting = true

        guard let setting = stores.first?.notificationSetting(for: entry.placement.id) else {
            return
        }

        selectedMoment = setting.moment
        advanceTime = setting.minutesBefore
    }

    private func saveNotificationSetting() {
        guard didLoadSetting, let store = stores.first else {
            return
        }

        do {
            store.upsertNotificationSetting(
                TimetableNotificationSetting(
                    placementID: entry.placement.id,
                    moment: selectedMoment,
                    minutesBefore: advanceTime
                )
            )
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NotificationView(day: .constant(1))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}

private extension TimetableDayEntry {
    var effectiveNotificationSetting: TimetableNotificationSetting {
        notificationSetting ?? TimetableNotificationSetting(placementID: placement.id)
    }

    var notificationSummary: String {
        let setting = effectiveNotificationSetting

        switch setting.moment {
        case .classBegins:
            return "Notify \(notificationTime(from: slot.startTime, meridiem: slot.startMeridiem, minutesBefore: setting.minutesBefore) ?? fallbackSummary(for: setting))"
        case .classEnds:
            return "Notify \(notificationTime(from: slot.endTime, meridiem: slot.endMeridiem, minutesBefore: setting.minutesBefore) ?? fallbackSummary(for: setting))"
        case .both:
            let startText = notificationTime(from: slot.startTime, meridiem: slot.startMeridiem, minutesBefore: setting.minutesBefore)
            let endText = notificationTime(from: slot.endTime, meridiem: slot.endMeridiem, minutesBefore: setting.minutesBefore)

            if let startText, let endText {
                return "Notify \(startText) / \(endText)"
            }

            return "Notify \(fallbackSummary(for: setting))"
        }
    }

    private func fallbackSummary(for setting: TimetableNotificationSetting) -> String {
        switch setting.moment {
        case .classBegins:
            return "\(setting.minutesBefore) mins before start"
        case .classEnds:
            return "\(setting.minutesBefore) mins before end"
        case .both:
            return "\(setting.minutesBefore) mins before start & end"
        }
    }

    private func notificationTime(from source: String, meridiem: TimeMeridiem, minutesBefore: Int) -> String? {
        guard let baseMinutes = TimetableTimeSlot.minutesSinceMidnight(time: source, meridiem: meridiem) else {
            return nil
        }

        let normalizedMinutes = (baseMinutes - minutesBefore + 1_440) % 1_440
        let hour24 = normalizedMinutes / 60
        let minute = normalizedMinutes % 60
        let normalizedMeridiem: TimeMeridiem = hour24 >= 12 ? .pm : .am
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return "\(hour12):" + String(format: "%02d", minute) + " \(normalizedMeridiem.rawValue)"
    }
}
