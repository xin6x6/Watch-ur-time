//
//  ContentView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct TimeTableView: View {
    @Binding var day: Int
    @State private var isAddingTimetable = false
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GlassCard {
                    VStack {
                        dayPicker
                        .padding(.bottom, 20)
                        .shadow(radius: 10)

                        DayView(selectedDay: day)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 12)
            }
            .padding(.top, 6)
            .padding(.bottom)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            AppHaptics.trigger(.tap)
                            isAddingTimetable = true
                        } label: {
                            Label(menuActionTitle, systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .appFont(.title3, weight: .semibold)
                    }
                }
            }
            .navigationDestination(isPresented: $isAddingTimetable) {
                AddTimeTable()
            }
        }
        .appDefaultFont()
        .tint(.primary)
        .onAppear {
            normalizeSelectedDayIfNeeded()
        }
        .onChange(of: stores.first?.updatedAt) { _, _ in
            normalizeSelectedDayIfNeeded()
        }
        .onChange(of: day) { _, _ in
            AppHaptics.trigger(.selection)
        }
    }

    private var menuActionTitle: String {
        stores.first?.hasTimetable == true
            ? AppLocalizer.localized("Edit Timetable")
            : AppLocalizer.localized("Add Timetable")
    }

    private var availableDayColumns: [WeekdayColumn] {
        let configuredDays = Set(stores.first?.placements.map(\.dayIndex) ?? [])
        return timetableWeekdayColumns(enabledWeekendDayIndices: configuredDays)
    }

    @ViewBuilder
    private var dayPicker: some View {
        if availableDayColumns.count <= 5 {
            Picker(selection: $day, label: Text("Select day")) {
                ForEach(availableDayColumns) { column in
                    Text(column.title).tag(column.id)
                }
            }
            .pickerStyle(.segmented)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableDayColumns) { column in
                        Button {
                            AppHaptics.trigger(.selection)
                            day = column.id
                        } label: {
                            Text(column.title)
                                .appFont(.subheadline, weight: .semibold)
                                .foregroundStyle(day == column.id ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(day == column.id ? Color.accentColor : Color.secondary.opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func normalizeSelectedDayIfNeeded() {
        let availableDays = availableDayColumns.map(\.id)
        guard !availableDays.isEmpty else {
            return
        }

        if !availableDays.contains(day) {
            day = availableDays.first ?? 1
        }
    }
}

struct DayView: View {
    var selectedDay: Int

    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    var body: some View {
        if let store = stores.first, !store.slots.isEmpty {
            ScrollView {
                VStack(spacing: 4) {
                    headerRow

                    ForEach(Array(store.slots.enumerated()), id: \.element.id) { index, slot in
                        let subject = store.subjectID(dayIndex: selectedDay, slotIndex: index)
                            .flatMap { store.subject(for: $0) }

                        lessonRow(
                            timeText: slot.displayLabel,
                            lessonText: subject?.name ?? AppLocalizer.localized("Free"),
                            lessonSubtitle: subject?.room,
                            strokeColor: subject?.color ?? .gray,
                            fillColor: subject?.color.opacity(0.24) ?? .clear
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .appFont(size: 42)
                    .foregroundStyle(.secondary)
                Text("No timetable yet")
                    .appFont(.headline)
                Text("Tap the plus button to create your timetable.")
                    .appFont(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
    }

    private var headerRow: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(140)),
                GridItem(.flexible())
            ],
            spacing: 4
        ) {
            tableCell(AppLocalizer.localized("Time"), isHeader: true)
            tableCell(AppLocalizer.localized("Lesson"), isHeader: true)
        }
        .padding(.bottom, 2)
    }

    private func lessonRow(
        timeText: String,
        lessonText: String,
        lessonSubtitle: String?,
        strokeColor: Color,
        fillColor: Color
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(140)),
                GridItem(.flexible())
            ],
            spacing: 4
        ) {
            tableCell(timeText)
            tableCell(
                lessonText,
                subtitle: lessonSubtitle,
                strokeColor: strokeColor,
                fillColor: fillColor
            )
        }
    }

    func tableCell(
        _ text: String,
        subtitle: String? = nil,
        isHeader: Bool = false,
        strokeColor: Color = .gray,
        fillColor: Color = .clear
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(fillColor)
            RoundedRectangle(cornerRadius: 25)
                .stroke(strokeColor.opacity(0.4), lineWidth: 2)
                .shadow(radius: 10)
            VStack(spacing: isHeader ? 0 : 6) {
                Text(text)
                    .appFont(isHeader ? .headline : .subheadline, weight: isHeader ? nil : .bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let subtitle, !isHeader {
                    Text(subtitle)
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, isHeader ? 0 : 6)
            .frame(maxWidth: .infinity, minHeight: 64)
        }
    }
}

struct AddTimeTable: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("timetable_ocr_enabled") private var isTimetableOCREnabled = false
    @AppStorage("disable_all_restrictions") private var isRestrictionsDisabled = false
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    @State private var step: AddTimeTableStep = .subjects
    @State private var subjectDrafts: [SubjectDraft] = [SubjectDraft()]
    @State private var timeSlotDrafts: [TimeSlotDraft] = [TimeSlotDraft()]
    @State private var selectedSubjectsBySlot: [UUID: [Int: UUID]] = [:]
    @State private var didLoadStoredTimetable = false
    @State private var errorMessage: String?
    @State private var invalidTimeField: TimeFieldFocus?
    @State private var selectedTimetableImage: PhotosPickerItem?
    @State private var isImportingTimetableImage = false
    @State private var importStatusMessage: String?
    @State private var ocrReviewContext: TimetableOCRReviewContext?
    @State private var scheduleZoomResetToken = UUID()
    @State private var enabledWeekendDayIndices: Set<Int> = []
    @FocusState private var focusedTimeField: TimeFieldFocus?

    private let scheduleTimeColumnWidth: CGFloat = 220
    private let scheduleDayColumnWidth: CGFloat = 120

    var body: some View {
        Group {
            if step == .subjects {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        subjectEntrySection
                    }
                    .padding(.vertical)
                    .padding(.horizontal, 16)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    scheduleEntrySection
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(step == .schedule ? .hidden : .visible, for: .tabBar)
        .appDefaultFont()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    AppHaptics.trigger(.tap)
                    handleBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }

            if step == .schedule && canSaveTimetable {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassButton(img: "checkmark") {
                        saveTimetable()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if step == .subjects && canProceedToSchedule {
                Button {
                    AppHaptics.trigger(.tap)
                    persistSubjectsAndContinue()
                } label: {
                    Text("Next")
                        .appFont(.headline)
                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .compatibleProminentGlassButtonStyle()
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }
        .alert("Unable to save timetable", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? AppLocalizer.localized("Unknown error"))
        }
        .alert("invalid time format", isPresented: invalidTimeAlertBinding) {
            Button("OK", role: .cancel) {
                focusedTimeField = invalidTimeField
                invalidTimeField = nil
            }
        } message: {
            Text(AppLocalizer.localized("Please use H:MM or HH:MM."))
        }
        .alert("Timetable OCR Import", isPresented: importStatusBinding) {
            Button("OK", role: .cancel) {
                importStatusMessage = nil
            }
        } message: {
            Text(importStatusMessage ?? "")
        }
        .onChange(of: focusedTimeField) { oldValue, newValue in
            guard oldValue != newValue, let oldValue else {
                return
            }
            validateTimeFieldIfNeeded(oldValue)
        }
        .task {
            loadStoredTimetableIfNeeded()
        }
        .task(id: selectedTimetableImage) {
            await importSelectedTimetableImageIfNeeded()
        }
        .sheet(item: $ocrReviewContext) { context in
            TimetableOCRImportReviewSheet(context: context) { payload in
                applyImportedTimetable(payload)
                importStatusMessage = AppLocalizer.localized("Timetable image imported. Review the result and tap Next when ready.")
            }
        }
    }

    private var subjectEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your subjects first. Each subject needs a name, a room, and a color.")
                .appFont(.subheadline)
                .foregroundStyle(.secondary)

            if isRestrictionsDisabled && isTimetableOCREnabled {
                timetableOCRImportSection
            }

            ForEach(subjectDrafts.indices, id: \.self) { index in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(AppLocalizer.format("Subject %d", index + 1))
                                .appFont(.headline)
                            Spacer()
                            if subjectDrafts.count > 1 {
                                Button(role: .destructive) {
                                    AppHaptics.trigger(.warning)
                                    removeSubject(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }

                        TextField("Subject name", text: $subjectDrafts[index].name)
                            .textInputAutocapitalization(.words)

                        TextField("Room", text: $subjectDrafts[index].room)
                            .textInputAutocapitalization(.words)

                        ColorPicker("Color", selection: $subjectDrafts[index].color, supportsOpacity: false)
                    }
                }
            }

            Button {
                AppHaptics.trigger(.tap)
                subjectDrafts.append(SubjectDraft())
            } label: {
                Label("Add Subject", systemImage: "plus.circle.fill")
                    .appFont(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var timetableOCRImportSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Import timetable from image")
                    .appFont(.headline)

                Text("Pick a timetable screenshot or photo. The app will OCR the image and prefill subjects, rooms, time slots, and weekly classes.")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)

                PhotosPicker(
                    selection: $selectedTimetableImage,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 10) {
                        if isImportingTimetableImage {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "text.viewfinder")
                        }

                        Text(isImportingTimetableImage ? "Importing..." : "Recognize Timetable Image")
                            .appFont(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .disabled(isImportingTimetableImage)
            }
        }
    }

    private var scheduleEntrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add each class period first, then fill the classes you actually have. Empty cells stay free.")
                .appFont(.subheadline)
                .foregroundStyle(.secondary)

            ZoomableScheduleScrollView(
                minZoomScale: 0.42,
                maxZoomScale: 1.75,
                resetToken: scheduleZoomResetToken
            ) {
                scheduleEditorGrid
            }
            .id(scheduleZoomResetToken)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack(spacing: 16) {
                Button {
                    AppHaptics.trigger(.tap)
                    timeSlotDrafts.append(TimeSlotDraft())
                } label: {
                    Label("Add Period", systemImage: "plus.circle.fill")
                        .appFont(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    AppHaptics.trigger(.tap)
                    scheduleZoomResetToken = UUID()
                } label: {
                    Label("Reset Zoom", systemImage: "arrow.counterclockwise")
                        .appFont(.subheadline, weight: .semibold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scheduleEditorGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                scheduleHeaderCell(AppLocalizer.localized("Time"))
                    .frame(width: scheduleTimeColumnWidth)

                ForEach(weekdayColumns) { column in
                    scheduleHeaderCell(column.title)
                        .overlay(alignment: .topTrailing) {
                            if column.isOptionalWeekend {
                                Button(role: .destructive) {
                                    AppHaptics.trigger(.warning)
                                    disableWeekendColumn(column.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: scheduleDayColumnWidth)
                }

                ForEach(disabledWeekendColumns) { column in
                    weekendAddHeaderCell(for: column)
                        .frame(width: scheduleDayColumnWidth)
                }
            }

            ForEach(timeSlotDrafts.indices, id: \.self) { index in
                GridRow {
                    timeSlotEditor(for: index)
                        .frame(width: scheduleTimeColumnWidth)

                    ForEach(weekdayColumns) { column in
                        scheduleCell(
                            slot: timeSlotDrafts[index],
                            dayIndex: column.id
                        )
                        .frame(width: scheduleDayColumnWidth)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
    }

    private func scheduleHeaderCell(_ title: String) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                Text(title)
                    .appFont(.headline)
                    .padding(.horizontal, 8)
            }
            .frame(height: 54)
    }

    private func weekendAddHeaderCell(for column: WeekdayColumn) -> some View {
        Button {
            AppHaptics.trigger(.tap)
            enableWeekendColumn(column.id)
        } label: {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                .overlay {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(column.title)
                            .lineLimit(1)
                    }
                    .appFont(.subheadline, weight: .semibold)
                    .padding(.horizontal, 8)
                }
                .frame(height: 54)
        }
        .buttonStyle(.plain)
    }

    private func timeSlotEditor(for index: Int) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(AppLocalizer.format("Period %d", index + 1))
                        .appFont(.subheadline, weight: .semibold)
                    Spacer()
                    if timeSlotDrafts.count > 1 {
                        Button(role: .destructive) {
                            AppHaptics.trigger(.warning)
                            removeTimeSlot(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                    }
                }

                timeInputRow(
                    title: AppLocalizer.localized("Start"),
                    text: $timeSlotDrafts[index].startTime,
                    meridiem: $timeSlotDrafts[index].startMeridiem,
                    focus: TimeFieldFocus(slotID: timeSlotDrafts[index].id, kind: .start)
                )

                timeInputRow(
                    title: AppLocalizer.localized("End"),
                    text: $timeSlotDrafts[index].endTime,
                    meridiem: $timeSlotDrafts[index].endMeridiem,
                    focus: TimeFieldFocus(slotID: timeSlotDrafts[index].id, kind: .end)
                )
            }
        }
    }

    private func timeInputRow(
        title: String,
        text: Binding<String>,
        meridiem: Binding<TimeMeridiem>,
        focus: TimeFieldFocus
    ) -> some View {
        HStack(spacing: 8) {
            TextField(title, text: text)
                .keyboardType(.numbersAndPunctuation)
                .focused($focusedTimeField, equals: focus)

            if shouldShowMeridiemPicker(for: text.wrappedValue) {
                Picker("\(title) meridiem", selection: meridiem) {
                    ForEach(TimeMeridiem.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 88)
            }
        }
    }

    private func scheduleCell(slot: TimeSlotDraft, dayIndex: Int) -> some View {
        let subject = selectedSubject(for: slot.id, dayIndex: dayIndex)

        return Menu {
            Button(AppLocalizer.localized("No Course")) {
                AppHaptics.trigger(.tap)
                clearSelectedSubject(for: slot.id, dayIndex: dayIndex)
            }

            ForEach(completedSubjects) { subject in
                Button("\(subject.name) · \(subject.room)") {
                    AppHaptics.trigger(.tap)
                    setSelectedSubject(subject.id, for: slot.id, dayIndex: dayIndex)
                }
            }
        } label: {
            RoundedRectangle(cornerRadius: 18)
                .fill(subject?.color.opacity(0.35) ?? Color.secondary.opacity(0.08))
                .overlay {
                    VStack(spacing: 6) {
                        Text(subject?.name ?? localizedSelectTitle)
                            .appFont(.subheadline, weight: .bold)
                            .foregroundStyle(subject == nil ? .secondary : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        if let subject {
                            Text(subject.room)
                                .appFont(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(subject?.color.opacity(0.5) ?? .secondary.opacity(0.18), lineWidth: 1.5)
                }
                .frame(height: 92)
        }
        .disabled(!slot.isComplete || completedSubjects.isEmpty)
    }

    private var localizedSelectTitle: String {
        AppLocalizer.localized("Select")
    }

    private var canProceedToSchedule: Bool {
        !completedSubjects.isEmpty && subjectDrafts.allSatisfy { $0.isBlank || $0.isComplete }
    }

    private var canSaveTimetable: Bool {
        let filledSlots = completedTimeSlots

        guard !filledSlots.isEmpty else {
            return false
        }

        guard timeSlotDrafts.allSatisfy({ $0.isBlank || $0.isComplete }) else {
            return false
        }

        return filledSlots.contains { slot in
            let selections = selectedSubjectsBySlot[slot.id] ?? [:]
            return selections.values.contains { subjectID in
                completedSubjects.contains(where: { $0.id == subjectID })
            }
        }
    }

    private var completedSubjects: [TimetableSubject] {
        subjectDrafts.compactMap { $0.persistentValue }
    }

    private var completedTimeSlots: [TimeSlotDraft] {
        timeSlotDrafts.filter(\.isComplete)
    }

    private var weekdayColumns: [WeekdayColumn] {
        timetableWeekdayColumns(enabledWeekendDayIndices: enabledWeekendDayIndices)
    }

    private var disabledWeekendColumns: [WeekdayColumn] {
        timetableWeekendColumns.filter { !enabledWeekendDayIndices.contains($0.id) }
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

    private var invalidTimeAlertBinding: Binding<Bool> {
        Binding(
            get: { invalidTimeField != nil },
            set: { isPresented in
                if !isPresented {
                    invalidTimeField = nil
                }
            }
        )
    }

    private var importStatusBinding: Binding<Bool> {
        Binding(
            get: { importStatusMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importStatusMessage = nil
                }
            }
        )
    }

    private func handleBack() {
        if step == .schedule {
            step = .subjects
        } else {
            dismiss()
        }
    }

    private func removeSubject(at index: Int) {
        let removedID = subjectDrafts[index].id
        subjectDrafts.remove(at: index)
        if subjectDrafts.isEmpty {
            subjectDrafts = [SubjectDraft()]
        }
        pruneSelections(removing: removedID)
    }

    private func removeTimeSlot(at index: Int) {
        let slotID = timeSlotDrafts[index].id
        timeSlotDrafts.remove(at: index)
        selectedSubjectsBySlot.removeValue(forKey: slotID)
        if timeSlotDrafts.isEmpty {
            timeSlotDrafts = [TimeSlotDraft()]
        }
    }

    private func setSelectedSubject(_ subjectID: UUID, for slotID: UUID, dayIndex: Int) {
        var selections = selectedSubjectsBySlot[slotID] ?? [:]
        selections[dayIndex] = subjectID
        selectedSubjectsBySlot[slotID] = selections
    }

    private func clearSelectedSubject(for slotID: UUID, dayIndex: Int) {
        var selections = selectedSubjectsBySlot[slotID] ?? [:]
        selections.removeValue(forKey: dayIndex)

        if selections.isEmpty {
            selectedSubjectsBySlot.removeValue(forKey: slotID)
        } else {
            selectedSubjectsBySlot[slotID] = selections
        }
    }

    private func selectedSubject(for slotID: UUID, dayIndex: Int) -> TimetableSubject? {
        guard let subjectID = selectedSubjectsBySlot[slotID]?[dayIndex] else {
            return nil
        }
        return completedSubjects.first(where: { $0.id == subjectID })
    }

    private func enableWeekendColumn(_ dayIndex: Int) {
        guard (6...7).contains(dayIndex) else {
            return
        }
        enabledWeekendDayIndices.insert(dayIndex)
    }

    private func disableWeekendColumn(_ dayIndex: Int) {
        guard enabledWeekendDayIndices.remove(dayIndex) != nil else {
            return
        }

        for slotID in Array(selectedSubjectsBySlot.keys) {
            var selections = selectedSubjectsBySlot[slotID] ?? [:]
            selections.removeValue(forKey: dayIndex)

            if selections.isEmpty {
                selectedSubjectsBySlot.removeValue(forKey: slotID)
            } else {
                selectedSubjectsBySlot[slotID] = selections
            }
        }
    }

    private func pruneSelections(removing removedID: UUID) {
        let validSubjectIDs = Set(completedSubjects.map(\.id)).subtracting([removedID])

        for slotID in selectedSubjectsBySlot.keys {
            let filtered = (selectedSubjectsBySlot[slotID] ?? [:]).filter { validSubjectIDs.contains($0.value) }
            selectedSubjectsBySlot[slotID] = filtered
        }
    }

    private func loadStoredTimetableIfNeeded() {
        guard !didLoadStoredTimetable else {
            return
        }
        didLoadStoredTimetable = true

        guard let store = stores.first else {
            return
        }

        let storedSubjects = store.subjects.map { SubjectDraft(subject: $0) }
        subjectDrafts = storedSubjects.isEmpty ? [SubjectDraft()] : storedSubjects

        let storedSlots = store.slots.map { TimeSlotDraft(slot: $0) }
        timeSlotDrafts = storedSlots.isEmpty ? [TimeSlotDraft()] : storedSlots
        enabledWeekendDayIndices = Set(store.placements.map(\.dayIndex)).intersection([6, 7])

        var selectionMap: [UUID: [Int: UUID]] = [:]
        for placement in store.placements {
            guard store.slots.indices.contains(placement.slotIndex) else {
                continue
            }

            let slotID = store.slots[placement.slotIndex].id
            var daySelections = selectionMap[slotID] ?? [:]
            daySelections[placement.dayIndex] = placement.subjectID
            selectionMap[slotID] = daySelections
        }
        selectedSubjectsBySlot = selectionMap
    }

    private func importSelectedTimetableImageIfNeeded() async {
        guard let selectedTimetableImage else {
            return
        }

        isImportingTimetableImage = true
        defer {
            isImportingTimetableImage = false
            self.selectedTimetableImage = nil
        }

        do {
            guard let data = try await selectedTimetableImage.loadTransferable(type: Data.self) else {
                throw TimetableOCRImportError.imageDecodeFailed
            }

            switch try await TimetableOCRImporter.importTimetable(from: data) {
            case .direct(let payload):
                applyImportedTimetable(payload)
                importStatusMessage = AppLocalizer.localized("Timetable image imported. Review the result and tap Next when ready.")
            case .needsReview(let context):
                ocrReviewContext = context
            }
        } catch {
            importStatusMessage = error.localizedDescription
        }
    }

    private func applyImportedTimetable(_ payload: ImportedTimetablePayload) {
        subjectDrafts = payload.subjects.isEmpty
            ? [SubjectDraft()]
            : payload.subjects.map { SubjectDraft(subject: $0) }

        timeSlotDrafts = payload.slots.isEmpty
            ? [TimeSlotDraft()]
            : payload.slots.map { TimeSlotDraft(slot: $0) }

        var selectionMap: [UUID: [Int: UUID]] = [:]
        for placement in payload.placements {
            guard payload.slots.indices.contains(placement.slotIndex) else {
                continue
            }

            let slotID = payload.slots[placement.slotIndex].id
            var daySelections = selectionMap[slotID] ?? [:]
            daySelections[placement.dayIndex] = placement.subjectID
            selectionMap[slotID] = daySelections
        }
        selectedSubjectsBySlot = selectionMap
        enabledWeekendDayIndices = Set(payload.placements.map(\.dayIndex)).intersection([6, 7])
        step = .subjects
    }

    private func validateTimeFieldIfNeeded(_ focus: TimeFieldFocus) {
        guard let slotIndex = timeSlotDrafts.firstIndex(where: { $0.id == focus.slotID }) else {
            return
        }

        let rawText = switch focus.kind {
        case .start:
            timeSlotDrafts[slotIndex].startTime
        case .end:
            timeSlotDrafts[slotIndex].endTime
        }

        let trimmed = rawText.trimmed
        guard !trimmed.isEmpty else {
            return
        }

        guard TimeSlotDraft.isValidTimeFormat(trimmed) else {
            invalidTimeField = focus
            return
        }
    }

    private func shouldShowMeridiemPicker(for timeText: String) -> Bool {
        guard let components = TimeSlotDraft.timeComponents(from: timeText.trimmed),
              components.hour >= 1,
              components.hour <= 12
        else {
            return false
        }

        return true
    }

    private func persistSubjectsAndContinue() {
        let subjects = completedSubjects
        guard !subjects.isEmpty else {
            return
        }

        do {
            let store = activeStore()
            store.subjects = subjects
            try modelContext.save()
            pruneSelectionsAfterSubjectSave()
            step = .schedule
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneSelectionsAfterSubjectSave() {
        let validSubjectIDs = Set(completedSubjects.map(\.id))

        for slotID in selectedSubjectsBySlot.keys {
            let filtered = (selectedSubjectsBySlot[slotID] ?? [:]).filter { validSubjectIDs.contains($0.value) }
            selectedSubjectsBySlot[slotID] = filtered
        }
    }

    private func saveTimetable() {
        focusedTimeField = nil

        guard validateScheduleBeforeSave() else {
            return
        }

        let subjects = completedSubjects
        let slots = completedTimeSlots.map {
            TimetableTimeSlot(
                id: $0.id,
                startTime: $0.startTime.trimmed,
                startMeridiem: $0.startMeridiem,
                endTime: $0.endTime.trimmed,
                endMeridiem: $0.endMeridiem
            )
        }

        do {
            let store = activeStore()
            let existingPlacements = Dictionary(
                uniqueKeysWithValues: store.placements.map {
                    (PlacementCoordinate(dayIndex: $0.dayIndex, slotIndex: $0.slotIndex), $0)
                }
            )

            let placements: [TimetablePlacement] = slots.enumerated().flatMap { index, slot in
                weekdayColumns.compactMap { column in
                    guard let subjectID = selectedSubjectsBySlot[slot.id]?[column.id] else {
                        return nil
                    }

                    let coordinate = PlacementCoordinate(dayIndex: column.id, slotIndex: index)
                    let existingPlacement = existingPlacements[coordinate]

                    return TimetablePlacement(
                        id: existingPlacement?.id ?? UUID(),
                        dayIndex: column.id,
                        slotIndex: index,
                        subjectID: subjectID
                    )
                }
            }

            let validPlacementIDs = Set(placements.map(\.id))
            let notificationSettings = store.notificationSettings.filter {
                validPlacementIDs.contains($0.placementID)
            }

            store.replaceAll(
                subjects: subjects,
                slots: slots,
                placements: placements,
                notificationSettings: notificationSettings
            )
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateScheduleBeforeSave() -> Bool {
        if let invalidField = firstInvalidTimeField() {
            invalidTimeField = invalidField
            return false
        }

        guard !completedTimeSlots.isEmpty else {
            return false
        }

        guard timeSlotDrafts.allSatisfy({ $0.isBlank || $0.isComplete }) else {
            return false
        }

        return true
    }

    private func firstInvalidTimeField() -> TimeFieldFocus? {
        for slot in timeSlotDrafts {
            let startText = slot.startTime.trimmed
            if !startText.isEmpty, !TimeSlotDraft.isValidTimeFormat(startText) {
                return TimeFieldFocus(slotID: slot.id, kind: .start)
            }

            let endText = slot.endTime.trimmed
            if !endText.isEmpty, !TimeSlotDraft.isValidTimeFormat(endText) {
                return TimeFieldFocus(slotID: slot.id, kind: .end)
            }
        }

        return nil
    }

    private func activeStore() -> TimetableStore {
        if let current = stores.first {
            for duplicate in stores.dropFirst() {
                modelContext.delete(duplicate)
            }
            return current
        }

        let store = TimetableStore()
        modelContext.insert(store)
        return store
    }
}

private struct PlacementCoordinate: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

private enum AddTimeTableStep {
    case subjects
    case schedule

    var title: String {
        switch self {
        case .subjects:
            return AppLocalizer.localized("Add Subjects")
        case .schedule:
            return AppLocalizer.localized("Build Timetable")
        }
    }
}

private struct WeekdayColumn: Identifiable {
    let id: Int
    let title: String
    let isOptionalWeekend: Bool
}

private var timetableWeekdayBaseColumns: [WeekdayColumn] {
    [
        WeekdayColumn(id: 1, title: AppLocalizer.localized("Mon."), isOptionalWeekend: false),
        WeekdayColumn(id: 2, title: AppLocalizer.localized("Tue."), isOptionalWeekend: false),
        WeekdayColumn(id: 3, title: AppLocalizer.localized("Wed."), isOptionalWeekend: false),
        WeekdayColumn(id: 4, title: AppLocalizer.localized("Thu."), isOptionalWeekend: false),
        WeekdayColumn(id: 5, title: AppLocalizer.localized("Fri."), isOptionalWeekend: false)
    ]
}

private var timetableWeekendColumns: [WeekdayColumn] {
    [
        WeekdayColumn(id: 6, title: AppLocalizer.localized("Sat."), isOptionalWeekend: true),
        WeekdayColumn(id: 7, title: AppLocalizer.localized("Sun."), isOptionalWeekend: true)
    ]
}

private func timetableWeekdayColumns(enabledWeekendDayIndices: Set<Int>) -> [WeekdayColumn] {
    timetableWeekdayBaseColumns + timetableWeekendColumns.filter { enabledWeekendDayIndices.contains($0.id) }
}

private class TouchPriorityZoomScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }
}

private final class ZoomHostingScrollView: TouchPriorityZoomScrollView, UIScrollViewDelegate {
    let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
    let wrapperView = UIView()
    var lastResetToken: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        delegate = self
        zoomScale = 1
        bounces = false
        bouncesZoom = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never
        delaysContentTouches = true
        canCancelContentTouches = true
        panGestureRecognizer.cancelsTouchesInView = true
        pinchGestureRecognizer?.cancelsTouchesInView = true

        wrapperView.backgroundColor = .clear
        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        wrapperView.addSubview(hostedView)
        addSubview(wrapperView)
    }

    func applyConfiguration(
        content: AnyView,
        minZoomScale: CGFloat,
        maxZoomScale: CGFloat,
        resetToken: UUID
    ) {
        let previousContentOffset = contentOffset
        let previousZoomScale = zoomScale

        minimumZoomScale = minZoomScale
        maximumZoomScale = maxZoomScale
        hostingController.rootView = content

        let fittingSize = hostingController.sizeThatFits(
            in: CGSize(width: 10_000, height: 10_000)
        )

        let nextContentSize = CGSize(
            width: max(fittingSize.width, 1),
            height: max(fittingSize.height, 1)
        )

        wrapperView.frame = CGRect(origin: .zero, size: nextContentSize)
        hostingController.view.frame = CGRect(origin: .zero, size: nextContentSize)
        contentSize = nextContentSize
        wrapperView.setNeedsLayout()
        wrapperView.layoutIfNeeded()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        layoutIfNeeded()

        if zoomScale < minZoomScale || zoomScale > maxZoomScale {
            zoomScale = min(max(zoomScale, minZoomScale), maxZoomScale)
        }

        if lastResetToken != resetToken {
            lastResetToken = resetToken
            performReset()
            return
        }

        updateInsetsAndClampOffset(desiredContentOffset: previousContentOffset)
        stabilizeContentOffset(
            desiredContentOffset: previousContentOffset,
            desiredZoomScale: previousZoomScale
        )
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        wrapperView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateInsetsAndClampOffset()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        clampOffset()
    }

    func performReset() {
        resetToOrigin()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.resetToOrigin()

            DispatchQueue.main.async { [weak self] in
                self?.resetToOrigin()
            }
        }
    }

    func stabilizeContentOffset(
        desiredContentOffset: CGPoint,
        desiredZoomScale: CGFloat
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.wrapperView.setNeedsLayout()
            self.wrapperView.layoutIfNeeded()
            self.hostingController.view.setNeedsLayout()
            self.hostingController.view.layoutIfNeeded()
            self.layoutIfNeeded()
            if abs(self.zoomScale - desiredZoomScale) > 0.0001 {
                self.zoomScale = desiredZoomScale
            }
            self.updateInsetsAndClampOffset(desiredContentOffset: desiredContentOffset)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.wrapperView.setNeedsLayout()
                self.wrapperView.layoutIfNeeded()
                self.hostingController.view.setNeedsLayout()
                self.hostingController.view.layoutIfNeeded()
                self.layoutIfNeeded()
                if abs(self.zoomScale - desiredZoomScale) > 0.0001 {
                    self.zoomScale = desiredZoomScale
                }
                self.updateInsetsAndClampOffset(desiredContentOffset: desiredContentOffset)
            }
        }
    }

    private func resetToOrigin() {
        wrapperView.setNeedsLayout()
        wrapperView.layoutIfNeeded()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        layoutIfNeeded()
        contentInset = .zero
        setZoomScale(1, animated: false)
        contentOffset = .zero
        updateInsetsAndClampOffset(desiredContentOffset: .zero)
    }

    func updateInsetsAndClampOffset(
        desiredContentOffset: CGPoint? = nil
    ) {
        contentInset = .zero

        if let desiredContentOffset {
            clampOffset(proposedOffset: desiredContentOffset)
        } else {
            clampOffset()
        }
    }

    private func clampOffset() {
        clampOffset(proposedOffset: contentOffset)
    }

    private func clampOffset(proposedOffset: CGPoint) {
        let minOffsetX = -contentInset.left
        let maxOffsetX = max(
            contentSize.width - bounds.width + contentInset.right,
            minOffsetX
        )
        let minOffsetY = -contentInset.top
        let maxOffsetY = max(
            contentSize.height - bounds.height + contentInset.bottom,
            minOffsetY
        )

        let clampedOffset = CGPoint(
            x: min(max(proposedOffset.x, minOffsetX), maxOffsetX),
            y: min(max(proposedOffset.y, minOffsetY), maxOffsetY)
        )

        if contentOffset != clampedOffset {
            contentOffset = clampedOffset
        }
    }
}

private struct ZoomableScheduleScrollView<Content: View>: UIViewRepresentable {
    let minZoomScale: CGFloat
    let maxZoomScale: CGFloat
    let resetToken: UUID
    let content: Content

    init(
        minZoomScale: CGFloat,
        maxZoomScale: CGFloat,
        resetToken: UUID,
        @ViewBuilder content: () -> Content
    ) {
        self.minZoomScale = minZoomScale
        self.maxZoomScale = maxZoomScale
        self.resetToken = resetToken
        self.content = content()
    }

    func makeUIView(context: Context) -> ZoomHostingScrollView {
        let scrollView = ZoomHostingScrollView()
        scrollView.applyConfiguration(
            content: AnyView(content),
            minZoomScale: minZoomScale,
            maxZoomScale: maxZoomScale,
            resetToken: resetToken
        )
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomHostingScrollView, context: Context) {
        scrollView.applyConfiguration(
            content: AnyView(content),
            minZoomScale: minZoomScale,
            maxZoomScale: maxZoomScale,
            resetToken: resetToken
        )
    }
}

private enum TimeFieldKind: Hashable {
    case start
    case end
}

private struct TimeFieldFocus: Hashable {
    let slotID: UUID
    let kind: TimeFieldKind
}

private struct SubjectDraft: Identifiable {
    var id: UUID
    var name: String
    var room: String
    var color: Color

    init(id: UUID = UUID(), name: String = "", room: String = "", color: Color = .blue) {
        self.id = id
        self.name = name
        self.room = room
        self.color = color
    }

    init(subject: TimetableSubject) {
        self.id = subject.id
        self.name = subject.name
        self.room = subject.room
        self.color = subject.color
    }

    var isBlank: Bool {
        name.trimmed.isEmpty && room.trimmed.isEmpty
    }

    var isComplete: Bool {
        !name.trimmed.isEmpty && !room.trimmed.isEmpty
    }

    var persistentValue: TimetableSubject? {
        guard isComplete else {
            return nil
        }
        return TimetableSubject(id: id, name: name.trimmed, room: room.trimmed, swiftUIColor: color)
    }
}

private struct TimeSlotDraft: Identifiable {
    var id: UUID
    var startTime: String
    var startMeridiem: TimeMeridiem
    var endTime: String
    var endMeridiem: TimeMeridiem

    init(
        id: UUID = UUID(),
        startTime: String = "",
        startMeridiem: TimeMeridiem = .am,
        endTime: String = "",
        endMeridiem: TimeMeridiem = .am
    ) {
        self.id = id
        self.startTime = startTime
        self.startMeridiem = startMeridiem
        self.endTime = endTime
        self.endMeridiem = endMeridiem
    }

    init(slot: TimetableTimeSlot) {
        self.id = slot.id
        self.startTime = slot.startTime
        self.startMeridiem = slot.startMeridiem
        self.endTime = slot.endTime
        self.endMeridiem = slot.endMeridiem
    }

    var isBlank: Bool {
        startTime.trimmed.isEmpty && endTime.trimmed.isEmpty
    }

    var isComplete: Bool {
        !startTime.trimmed.isEmpty &&
        !endTime.trimmed.isEmpty &&
        Self.isValidTimeFormat(startTime.trimmed) &&
        Self.isValidTimeFormat(endTime.trimmed)
    }

    static func isValidTimeFormat(_ text: String) -> Bool {
        guard let components = timeComponents(from: text) else {
            return false
        }

        return components.hour >= 0 &&
            components.hour <= 23 &&
            components.minute >= 0 &&
            components.minute <= 59
    }

    static func timeComponents(from text: String) -> (hour: Int, minute: Int)? {
        let trimmed = text.trimmed
        let parts = trimmed.split(separator: ":")

        guard parts.count == 2,
              parts[0].count >= 1,
              parts[0].count <= 2,
              parts[1].count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }

        return (hour, minute)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    TimeTableView(day: .constant(1))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
