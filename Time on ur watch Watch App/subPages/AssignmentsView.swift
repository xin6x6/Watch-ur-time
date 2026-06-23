//
//  AssignmentsView.swift
//  Time on ur watch Watch App
//
//  Created By Ng1nx on 6/22/26.
//

import SwiftUI

struct AssignmentsView: View {
    @EnvironmentObject private var dataStore: WatchDataStore
    @State private var selectedFilter: WatchAssignmentFilter = .all

    var body: some View {
        List {
            if assignmentSections.isEmpty {
                Text("No assignments")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignmentSections) { section in
                    Section(section.subject) {
                        ForEach(section.assignments) { assignment in
                            NavigationLink {
                                WatchAssignmentEditorView(assignmentID: assignment.id)
                            } label: {
                                assignmentRow(assignment)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(assignment.isFinished ? "Mark Active" : "Complete") {
                                    dataStore.toggleAssignment(assignment)
                                }
                                .tint(.green)

                                Button("Delete", role: .destructive) {
                                    dataStore.deleteAssignment(assignment)
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Assignments")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !dataStore.availableSubjects.isEmpty {
                    NavigationLink {
                        WatchAssignmentFilterView(selectedFilter: $selectedFilter)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchAssignmentEditorView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var assignmentSections: [WatchAssignmentSection] {
        dataStore.assignmentSections(filter: selectedFilter)
    }

    private func assignmentRow(_ assignment: WatchTimetableAssignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.subject)
                .font(.headline)
                .strikethrough(assignment.isFinished)

            Text(assignment.content)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .strikethrough(assignment.isFinished)

            Text("Due \(watchFormatDate(assignment.dueDate))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .opacity(assignment.isFinished ? 0.55 : 1)
    }
}

private struct WatchAssignmentFilterView: View {
    @EnvironmentObject private var dataStore: WatchDataStore
    @Binding var selectedFilter: WatchAssignmentFilter

    var body: some View {
        List {
            Button {
                selectedFilter = .all
            } label: {
                HStack {
                    Text("All")
                    Spacer()
                    if case .all = selectedFilter {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }

            ForEach(dataStore.availableSubjects, id: \.self) { subject in
                Button {
                    selectedFilter = .subject(subject)
                } label: {
                    HStack {
                        Text(subject)
                        Spacer()
                        if case .subject(let current) = selectedFilter,
                           current == subject {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Filter")
    }
}

struct WatchAssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: WatchDataStore

    let assignmentID: UUID?

    @State private var subject = ""
    @State private var content = ""
    @State private var startDate = Date()
    @State private var dueDate = Date()
    @State private var didLoadExistingAssignment = false

    init(assignmentID: UUID? = nil) {
        self.assignmentID = assignmentID
    }

    var body: some View {
        Form {
            Section("Assignment") {
                if dataStore.availableSubjects.isEmpty {
                    Text("Add subjects on iPhone first")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Subject", selection: $subject) {
                        ForEach(dataStore.availableSubjects, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                TextField("Homework", text: $content)
            }

            Section("Schedule") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("Due", selection: $dueDate, in: startDate..., displayedComponents: .date)
            }
        }
        .navigationTitle(assignmentID == nil ? "Add" : "Edit")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .task {
            loadExistingAssignmentIfNeeded()
            syncDefaultSubjectIfNeeded()
        }
    }

    private var canSave: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        dataStore.availableSubjects.contains(subject)
    }

    private func loadExistingAssignmentIfNeeded() {
        guard !didLoadExistingAssignment else {
            return
        }
        didLoadExistingAssignment = true

        guard let assignmentID,
              let assignment = dataStore.assignment(with: assignmentID)
        else {
            return
        }

        subject = assignment.subject
        content = assignment.content
        startDate = assignment.startDate
        dueDate = assignment.dueDate
    }

    private func syncDefaultSubjectIfNeeded() {
        if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let first = dataStore.availableSubjects.first {
            subject = first
        } else if !dataStore.availableSubjects.contains(subject),
                  let first = dataStore.availableSubjects.first {
            subject = first
        }
    }

    private func save() {
        dataStore.upsertAssignment(
            id: assignmentID,
            subject: subject,
            content: content,
            startDate: startDate,
            dueDate: dueDate
        )
        dismiss()
    }
}

private func watchFormatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M.d"
    return formatter.string(from: date)
}

#Preview {
    NavigationStack {
        AssignmentsView()
            .environmentObject(WatchDataStore())
    }
}
