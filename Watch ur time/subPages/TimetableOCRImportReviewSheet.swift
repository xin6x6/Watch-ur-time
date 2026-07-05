//
//  TimetableOCRImportReviewSheet.swift
//  Watch ur time
//
//  Created By Ng1nx on 7/5/26.
//

import SwiftUI

struct TimetableOCRImportReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: TimetableOCRReviewContext
    let onConfirm: (ImportedTimetablePayload) -> Void

    @State private var selectedClassID: Int
    @State private var enabledSubjectIDs: Set<UUID>

    init(
        context: TimetableOCRReviewContext,
        onConfirm: @escaping (ImportedTimetablePayload) -> Void
    ) {
        self.context = context
        self.onConfirm = onConfirm

        let initialClass = context.classOptions.first
        _selectedClassID = State(initialValue: initialClass?.id ?? 0)
        _enabledSubjectIDs = State(initialValue: Set(initialClass?.payload.subjects.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This timetable image looks like a multi-class master schedule. Choose your class first, then keep only the courses you actually take.")
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Class") {
                    Picker("Class", selection: $selectedClassID) {
                        ForEach(context.classOptions) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let option = selectedOption {
                    Section("Courses") {
                        ForEach(option.payload.subjects.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { subject in
                            Toggle(isOn: subjectEnabledBinding(for: subject.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subject.name)
                                        .appFont(.headline)
                                    Text(subject.room)
                                        .appFont(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppLocalizer.localized("Timetable OCR Import"))
            .navigationBarTitleDisplayMode(.inline)
            .appDefaultFont()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        confirmImport()
                    }
                    .disabled(filteredPayload == nil)
                }
            }
            .onChange(of: selectedClassID) { _, newValue in
                guard let option = context.classOptions.first(where: { $0.id == newValue }) else {
                    enabledSubjectIDs = []
                    return
                }
                enabledSubjectIDs = Set(option.payload.subjects.map(\.id))
            }
        }
    }

    private var selectedOption: TimetableOCRClassOption? {
        context.classOptions.first(where: { $0.id == selectedClassID })
    }

    private var filteredPayload: ImportedTimetablePayload? {
        guard let selectedOption else {
            return nil
        }

        let allowedSubjectIDs = enabledSubjectIDs
        let subjects = selectedOption.payload.subjects.filter { allowedSubjectIDs.contains($0.id) }
        let placements = selectedOption.payload.placements.filter { allowedSubjectIDs.contains($0.subjectID) }

        guard !subjects.isEmpty, !placements.isEmpty else {
            return nil
        }

        return ImportedTimetablePayload(
            subjects: subjects,
            slots: selectedOption.payload.slots,
            placements: placements
        )
    }

    private func subjectEnabledBinding(for subjectID: UUID) -> Binding<Bool> {
        Binding(
            get: { enabledSubjectIDs.contains(subjectID) },
            set: { isEnabled in
                if isEnabled {
                    enabledSubjectIDs.insert(subjectID)
                } else {
                    enabledSubjectIDs.remove(subjectID)
                }
            }
        )
    }

    private func confirmImport() {
        guard let filteredPayload else {
            return
        }

        onConfirm(filteredPayload)
        dismiss()
    }
}
