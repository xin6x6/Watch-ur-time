//
//  NotificationView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI

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
                                    notificationTime: notificationSummary(for: entry)
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
        .appDefaultFont()
        .tint(.primary)
    }

    private var store: TimetableStore? {
        stores.first
    }

    private var dayEntries: [TimetableDayEntry] {
        store?.entries(for: day) ?? []
    }

    private var dayTitle: String {
        switch day {
        case 1:
            return AppLocalizer.localized("Monday")
        case 2:
            return AppLocalizer.localized("Tuesday")
        case 3:
            return AppLocalizer.localized("Wednesday")
        case 4:
            return AppLocalizer.localized("Thursday")
        case 5:
            return AppLocalizer.localized("Friday")
        default:
            return AppLocalizer.localized("Day")
        }
    }

    private func notificationSummary(for entry: TimetableDayEntry) -> String {
        entry.notificationSummary(
            timeMode: store?.notificationTimeMode ?? .custom,
            uniformMinutesBefore: store?.clampedUniformNotificationMinutesBefore ?? 2
        )
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "bell.slash")
                    .appFont(size: 30)
                    .foregroundStyle(.secondary)
                Text(AppLocalizer.format("No classes for %@", dayTitle))
                    .appFont(.headline)
                Text("Create or edit your timetable first, then adjust notifications for each class here.")
                    .appFont(.subheadline)
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
                if isUsingUniformTime {
                    uniformInfoSection
                } else {
                    advanceSection
                }
                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("Adjust notification")
        .navigationBarTitleDisplayMode(.inline)
        .appDefaultFont()
        .alert("Unable to save notification", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? AppLocalizer.localized("Unknown error"))
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
                    .appFont(.title3, weight: .bold)
                Text(entry.subject.room)
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.slot.displayLabel)
                    .appFont(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var momentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At")
                .appFont(.headline)
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
                .appFont(.headline)
            Picker("In advance for", selection: $advanceTime) {
                ForEach(advanceOptions, id: \.self) { minute in
                    Text(AppLocalizer.minuteSummary(minute))
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
    }

    private var uniformInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In advance for")
                .appFont(.headline)
            Text(AppLocalizer.format("Using uniform reminder time from Settings: %@", uniformAdvanceSummary))
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
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

    private var isUsingUniformTime: Bool {
        stores.first?.notificationTimeMode == .uniform
    }

    private var uniformAdvanceSummary: String {
        let minute = stores.first?.clampedUniformNotificationMinutesBefore ?? 2
        return AppLocalizer.minuteSummary(minute)
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

    func notificationSummary(
        timeMode: NotificationTimeMode,
        uniformMinutesBefore: Int
    ) -> String {
        let setting = effectiveNotificationSetting
        let minutesBefore = timeMode == .uniform ? uniformMinutesBefore : setting.minutesBefore

        switch setting.moment {
        case .classBegins:
            return AppLocalizer.format(
                "Notify %@",
                notificationTime(from: slot.startTime, meridiem: slot.startMeridiem, minutesBefore: minutesBefore)
                    ?? fallbackSummary(for: setting, minutesBefore: minutesBefore)
            )
        case .classEnds:
            return AppLocalizer.format(
                "Notify %@",
                notificationTime(from: slot.endTime, meridiem: slot.endMeridiem, minutesBefore: minutesBefore)
                    ?? fallbackSummary(for: setting, minutesBefore: minutesBefore)
            )
        case .both:
            let startText = notificationTime(from: slot.startTime, meridiem: slot.startMeridiem, minutesBefore: minutesBefore)
            let endText = notificationTime(from: slot.endTime, meridiem: slot.endMeridiem, minutesBefore: minutesBefore)

            if let startText, let endText {
                return AppLocalizer.format("Notify %@ / %@", startText, endText)
            }

            return AppLocalizer.format("Notify %@", fallbackSummary(for: setting, minutesBefore: minutesBefore))
        }
    }

    private func fallbackSummary(
        for setting: TimetableNotificationSetting,
        minutesBefore: Int
    ) -> String {
        switch setting.moment {
        case .classBegins:
            return AppLocalizer.format("%d mins before start", minutesBefore)
        case .classEnds:
            return AppLocalizer.format("%d mins before end", minutesBefore)
        case .both:
            return AppLocalizer.format("%d mins before start & end", minutesBefore)
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
