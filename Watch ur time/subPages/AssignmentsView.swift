//
//  AssignmentsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI

struct AssignmentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var tabSelection: AppTab
    @State private var selectedSubjectFilter = AssignmentFilter.all
    @State private var selectedWeekStart = startOfWeek(for: Date())
    @State private var isAddingAssignment = false
    @State private var timelineScrollRequestID = UUID()
    @State private var isBottomSheetPresented = true
    @State private var selectedSheetDetent: PresentationDetent = .height(100)
    @State private var isSheetExpanded = false

    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    private let compactSheetHeight: CGFloat = 100

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        controlsRow
                        weekSummary
                        BarAssignmentsView(
                            assignments: weekAssignments,
                            visibleWeekStart: $selectedWeekStart,
                            scrollRequestID: timelineScrollRequestID,
                            subjectColor: assignmentColor(for:)
                        )
                    }
                }
                Spacer(minLength: 0)
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassButton(img: "plus") {
                        isAddingAssignment = true
                    }
                }
            }
            .navigationDestination(isPresented: $isAddingAssignment) {
                AddAssignmentsView()
            }
            .sheet(isPresented: $isBottomSheetPresented) {
                bottomSheetContent
                    .presentationDetents([compactSheetDetent, .fraction(0.78)], selection: $selectedSheetDetent)
                    .presentationBackground(.clear)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationCornerRadius(52)
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled()
                    .onAppear {
                        selectedSheetDetent = compactSheetDetent
                        isSheetExpanded = false
                    }
                    .onChange(of: selectedSheetDetent) { _, newValue in
                        isSheetExpanded = newValue != compactSheetDetent
                    }
            }
            .onAppear {
                if tabSelection == .assignments, !isBottomSheetPresented {
                    isBottomSheetPresented = true
                }
            }
            .onChange(of: tabSelection) { _, newValue in
                if newValue == .assignments {
                    isBottomSheetPresented = true
                    selectedSheetDetent = compactSheetDetent
                    isSheetExpanded = false
                } else {
                    isBottomSheetPresented = false
                }
            }
        }
        .tint(.primary)
    }

    private var store: TimetableStore? {
        stores.first
    }

    private var compactSheetDetent: PresentationDetent {
        .height(compactSheetHeight)
    }

    private var allAssignments: [TimetableAssignment] {
        store?.assignments ?? []
    }

    private var availableSubjects: [String] {
        let assignmentSubjects = allAssignments.map(\.subject)
        let timetableSubjects = store?.subjects.map(\.name) ?? []
        return Array(Set(assignmentSubjects + timetableSubjects)).sorted()
    }

    private var subjectFilteredAssignments: [TimetableAssignment] {
        let assignments = allAssignments.filter { assignment in
            switch selectedSubjectFilter {
            case .all:
                return true
            case .subject(let subject):
                return assignment.subject.localizedCaseInsensitiveCompare(subject) == .orderedSame
            }
        }

        return assignments
    }

    private var filteredAssignments: [TimetableAssignment] {
        subjectFilteredAssignments.filter { assignment in
            intervalsOverlap(normalizedDateRange(for: assignment), weekRange)
        }
    }

    private var groupedAssignments: [AssignmentSection] {
        let grouped = Dictionary(grouping: filteredAssignments) { $0.subject }

        return grouped.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { subject in
                let assignments = (grouped[subject] ?? []).sorted {
                    if $0.createdAt == $1.createdAt {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return $0.createdAt < $1.createdAt
                }

                return AssignmentSection(subject: subject, assignments: assignments)
            }
    }

    private var weekAssignments: [TimetableAssignment] {
        subjectFilteredAssignments
    }

    private var weekDates: [Date] {
        datesForWeek(startingAt: selectedWeekStart)
    }

    private var weekRange: DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedWeekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Picker("Show", selection: $selectedSubjectFilter) {
                Text("All").tag(AssignmentFilter.all)
                ForEach(availableSubjects, id: \.self) { subject in
                    Text(subject).tag(AssignmentFilter.subject(subject))
                }
            }
            .pickerStyle(.menu)

            Spacer()

            GlassButton(img: "arrow.counterclockwise") {
                selectedWeekStart = startOfWeek(for: Date())
                timelineScrollRequestID = UUID()
            }

            GlassButton(img: "chevron.left") {
                selectedWeekStart = shiftWeek(from: selectedWeekStart, by: -1)
                timelineScrollRequestID = UUID()
            }

            GlassButton(img: "chevron.right") {
                selectedWeekStart = shiftWeek(from: selectedWeekStart, by: 1)
                timelineScrollRequestID = UUID()
            }
        }
    }

    private var weekSummary: some View {
        Text(weekRangeLabel)
            .font(.headline)
    }

    private var weekRangeLabel: String {
        guard let firstDay = weekDates.first, let lastDay = weekDates.last else {
            return "This Week"
        }
        return "\(formatDate(firstDay)) - \(formatDate(lastDay))"
    }

    @ViewBuilder
    private var bottomSheetContent: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                sheetBody
            }
        } else {
            sheetBody
        }
    }

    private var sheetBody: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack {
                if isSheetExpanded {
                    expandedSheetBackground
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    if isSheetExpanded {
                        sheetGrabber
                        expandedSheetContent(bottomInset: bottomInset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        collapsedSheetBar(bottomInset: bottomInset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isSheetExpanded)
    }

    private func expandedSheetContent(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            expandedSheetHeader
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 14)

            Group {
                if filteredAssignments.isEmpty {
                    sheetEmptyState
                } else {
                    assignmentsList
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, bottomInset + 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .zIndex(0)
        }
    }

    private var expandedSheetBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 120)
                    .mask {
                        LinearGradient(
                            colors: [.white.opacity(0.95), .white.opacity(0.55), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .ignoresSafeArea()
    }

    private var sheetGrabber: some View {
        Capsule()
            .fill(.white.opacity(0.5))
            .frame(width: 70, height: 7)
            .padding(.top, 7)
            .padding(.bottom, 2)
    }

    private func collapsedSheetBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            sheetGrabber

            sheetTabMenu(bottomInset: bottomInset)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .background {
            let shape = RoundedRectangle(cornerRadius: 48, style: .continuous)

            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape
                        .fill(.black.opacity(0.6))
                }
                .overlay {
                    shape
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        }
    }

    private var expandedSheetHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assignments")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text(weekRangeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(filteredAssignments.count)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .frame(minWidth: 60, minHeight: 60)
                    .liquidGlassSurface(cornerRadius: 22, tint: .blue.opacity(0.14))
            }

            HStack(spacing: 10) {
                sheetInfoChip(title: selectedSubjectFilterTitle, systemImage: "line.3.horizontal.decrease.circle")
                sheetInfoChip(title: "\(groupedAssignments.count) subjects", systemImage: "square.grid.2x2")
            }
        }
    }

    private func sheetInfoChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlassSurface(cornerRadius: 20, tint: .white.opacity(0.06))
    }

    private var selectedSubjectFilterTitle: String {
        switch selectedSubjectFilter {
        case .all:
            return "All Subjects"
        case .subject(let subject):
            return subject
        }
    }

    private func sheetTabMenu(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            FindMyCollapsedTabBar(selection: $tabSelection)
                .frame(height: 58)
                .padding(.horizontal, 10)
                .padding(.top, 1)

            Spacer(minLength: max(bottomInset - 4, 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66 + bottomInset)
    }

    private var sheetEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No assignments this week")
                .font(.headline)
            Text("Add an assignment from the top-right button, or switch the week and subject filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 14)
        .padding(.vertical, 20)
        .liquidGlassSurface(cornerRadius: 28, tint: .white.opacity(0.04))
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("No assignments this week")
                    .font(.headline)
                Text("Add an assignment from the top-right button, or switch the week and subject filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        }
    }

    private func assignmentRow(for assignment: TimetableAssignment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(assignmentColor(for: assignment.subject))
                .frame(width: 6, height: 52)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(assignment.content)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .strikethrough(assignment.isFinished)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text("Due \(formatDate(assignment.dueDate))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                HStack(spacing: 8) {
                    Text(assignment.subject)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .strikethrough(assignment.isFinished)

                    Circle()
                        .fill(.secondary.opacity(0.35))
                        .frame(width: 3, height: 3)

                    Text("Start \(formatDate(assignment.startDate))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .liquidGlassSurface(cornerRadius: 24, tint: assignmentColor(for: assignment.subject).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .opacity(assignment.isFinished ? 0.6 : 1)
    }

    private func assignmentColor(for subject: String) -> Color {
        store?.subjectColor(for: subject) ?? .blue
    }

    private func normalizedDateRange(for assignment: TimetableAssignment) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(assignment.startDate, assignment.dueDate))
        let inclusiveEnd = calendar.startOfDay(for: max(assignment.startDate, assignment.dueDate))
        let end = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd
        return DateInterval(start: start, end: end)
    }

    private func intervalsOverlap(_ lhs: DateInterval, _ rhs: DateInterval) -> Bool {
        lhs.start < rhs.end && lhs.end > rhs.start
    }

    private var assignmentsList: some View {
        List {
            ForEach(groupedAssignments) { group in
                Section {
                    ForEach(group.assignments) { assignment in
                        NavigationLink(destination: AddAssignmentsView(assignmentID: assignment.id)) {
                            assignmentRow(for: assignment)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(assignment.isFinished ? "Mark Active" : "Set as Completed") {
                                toggleCompletion(for: assignment)
                            }
                            .tint(.green)

                            Button("Delete", role: .destructive) {
                                deleteAssignment(assignment)
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    Text(group.subject)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func toggleCompletion(for assignment: TimetableAssignment) {
        let updatedAssignment = TimetableAssignment(
            id: assignment.id,
            subject: assignment.subject,
            content: assignment.content,
            startDate: assignment.startDate,
            dueDate: assignment.dueDate,
            createdAt: assignment.createdAt,
            isFinished: !assignment.isFinished
        )

        let store = activeStore()
        store.upsertAssignment(updatedAssignment)
        try? modelContext.save()
    }

    private func deleteAssignment(_ assignment: TimetableAssignment) {
        let store = activeStore()
        store.removeAssignment(assignment.id)
        try? modelContext.save()
    }

    private func activeStore() -> TimetableStore {
        if let current = stores.first {
            return current
        }

        let store = TimetableStore()
        modelContext.insert(store)
        return store
    }
}

struct BarAssignmentsView: View {
    let assignments: [TimetableAssignment]
    @Binding var visibleWeekStart: Date
    let scrollRequestID: UUID
    let subjectColor: (String) -> Color

    @State private var zoomScale: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1
    @State private var lastObservedWeekStart = startOfWeek(for: Date())

    private let barHeight: CGFloat = 44
    private let laneSpacing: CGFloat = 10
    private let subjectSpacing: CGFloat = 16

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geo in
                let columnWidth = max((geo.size.width / 7) * clampedZoomScale, 28)
                let totalWidth = CGFloat(timelineDates.count) * columnWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        headerRow(columnWidth: columnWidth)

                        ZStack(alignment: .topLeading) {
                            timelineGrid(width: totalWidth, height: chartHeight, columnWidth: columnWidth)

                            VStack(alignment: .leading, spacing: subjectSpacing) {
                                ForEach(groupedAssignments) { group in
                                    VStack(alignment: .leading, spacing: laneSpacing) {
                                        ForEach(Array(group.lanes.enumerated()), id: \.offset) { _, laneAssignments in
                                            ZStack(alignment: .leading) {
                                                ForEach(laneAssignments) { assignment in
                                                    let metrics = barMetrics(
                                                        for: assignment,
                                                        columnWidth: columnWidth
                                                    )

                                                    AssignmentBar(
                                                        subject: assignment.subject,
                                                        assignment: assignment.content,
                                                        color: subjectColor(assignment.subject),
                                                        width: metrics.width,
                                                        height: barHeight,
                                                        x: metrics.offset,
                                                        isFinished: assignment.isFinished
                                                    )
                                                }
                                            }
                                            .frame(height: barHeight)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(width: totalWidth, height: chartHeight, alignment: .topLeading)
                    }
                    .frame(width: totalWidth, alignment: .leading)
                    .background(offsetTracker())
                }
                .coordinateSpace(name: "AssignmentsTimelineScroll")
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .simultaneousGesture(zoomGesture)
                .onAppear {
                    lastObservedWeekStart = startOfWeek(for: visibleWeekStart)
                    scrollToWeekStart(startOfWeek(for: visibleWeekStart), proxy: proxy)
                }
                .onChange(of: visibleWeekStart) { _, newValue in
                    let normalized = startOfWeek(for: newValue)
                    guard normalized != lastObservedWeekStart else { return }
                    scrollToWeekStart(normalized, proxy: proxy)
                }
                .onChange(of: clampedZoomScale) { _, _ in
                    scrollToWeekStart(startOfWeek(for: visibleWeekStart), proxy: proxy)
                }
                .onChange(of: scrollRequestID) { _, _ in
                    scrollToWeekStart(startOfWeek(for: visibleWeekStart), proxy: proxy)
                }
                .onPreferenceChange(TimelineScrollOffsetKey.self) { offset in
                    updateVisibleWeek(for: offset, columnWidth: columnWidth, viewportWidth: geo.size.width)
                }
            }
            .frame(height: chartHeight + 34)
        }
    }

    private func headerRow(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(timelineDates.enumerated()), id: \.offset) { index, date in
                headerCell(for: date, dayIndex: index, columnWidth: columnWidth)
            }
        }
    }

    private func headerCell(for date: Date, dayIndex: Int, columnWidth: CGFloat) -> some View {
        Text(headerLabel(for: date, dayIndex: dayIndex))
            .font(.caption.weight(.semibold))
            .frame(width: columnWidth)
            .id(headerAnchorID(for: date, dayIndex: dayIndex))
    }

    private var clampedZoomScale: CGFloat {
        min(max(zoomScale * pinchScale, 1), 3)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoomScale = min(max(zoomScale * value, 1), 3)
            }
    }

    private var chartHeight: CGFloat {
        let totalLaneCount = groupedAssignments.reduce(0) { $0 + $1.lanes.count }
        let laneSpace = CGFloat(max(totalLaneCount - groupedAssignments.count, 0)) * laneSpacing
        let subjectSpace = CGFloat(max(groupedAssignments.count - 1, 0)) * subjectSpacing
        let height = CGFloat(totalLaneCount) * barHeight + laneSpace + subjectSpace + 16
        return max(height, 90)
    }

    private func timelineGrid(width: CGFloat, height: CGFloat, columnWidth: CGFloat) -> some View {
        ZStack {
            Path { path in
                for index in 0...timelineDates.count {
                    let x = CGFloat(index) * columnWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(.gray.opacity(0.24), lineWidth: 1)

            Path { path in
                for index in 0...timelineDates.count {
                    guard index == 0 || index % 7 == 0 else { continue }
                    let x = CGFloat(index) * columnWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(.gray.opacity(0.45), lineWidth: 1.6)
        }
    }

    private func offsetTracker() -> some View {
        GeometryReader { proxy in
            let offset = -proxy.frame(in: .named("AssignmentsTimelineScroll")).minX
            Color.clear.preference(key: TimelineScrollOffsetKey.self, value: offset)
        }
    }

    private var timelineBounds: (start: Date, endExclusive: Date) {
        let calendar = Calendar.current
        let relevantDates = assignments.flatMap { [min($0.startDate, $0.dueDate), max($0.startDate, $0.dueDate)] } + [Date()]

        guard let minDate = relevantDates.min(), let maxDate = relevantDates.max() else {
            let start = startOfWeek(for: Date())
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        }

        let start = startOfWeek(for: minDate)
        let lastWeekStart = startOfWeek(for: maxDate)
        let end = calendar.date(byAdding: .day, value: 7, to: lastWeekStart) ?? lastWeekStart

        return (start, end)
    }

    private var timelineDates: [Date] {
        let calendar = Calendar.current
        let totalDays = max(calendar.dateComponents([.day], from: timelineBounds.start, to: timelineBounds.endExclusive).day ?? 0, 0)

        return (0..<max(totalDays, 1)).compactMap { index in
            calendar.date(byAdding: .day, value: index, to: timelineBounds.start)
        }
    }

    private func headerLabel(for date: Date, dayIndex: Int) -> String {
        let calendar = Calendar.current
        if dayIndex % 7 == 0 {
            return formatDate(date)
        }
        return "\(calendar.component(.day, from: date))"
    }

    private func headerAnchorID(for date: Date, dayIndex: Int) -> String {
        if dayIndex % 7 == 0 {
            return weekAnchorID(startOfWeek(for: date))
        }
        return "day-\(dayIndex)"
    }

    private func weekAnchorID(_ weekStart: Date) -> String {
        "week-\(Int(weekStart.timeIntervalSinceReferenceDate))"
    }

    private var groupedAssignments: [SubjectAssignmentGroup] {
        let subjectOrder = Array(Set(assignments.map { $0.subject }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        return subjectOrder.compactMap { subject in
            let subjectAssignments = assignments
                .filter { $0.subject == subject }
                .sorted { lhs, rhs in
                    let lhsStart = min(lhs.startDate, lhs.dueDate)
                    let rhsStart = min(rhs.startDate, rhs.dueDate)
                    if lhsStart == rhsStart {
                        let lhsEnd = max(lhs.startDate, lhs.dueDate)
                        let rhsEnd = max(rhs.startDate, rhs.dueDate)
                        return lhsEnd < rhsEnd
                    }
                    return lhsStart < rhsStart
                }

            guard !subjectAssignments.isEmpty else {
                return nil
            }

            return SubjectAssignmentGroup(
                subject: subject,
                lanes: buildLanes(for: subjectAssignments)
            )
        }
    }

    private func buildLanes(for subjectAssignments: [TimetableAssignment]) -> [[TimetableAssignment]] {
        var lanes: [[TimetableAssignment]] = []

        for assignment in subjectAssignments {
            if let laneIndex = lanes.firstIndex(where: { laneAssignments in
                guard let lastAssignment = laneAssignments.last else {
                    return true
                }
                return !timelineRange(for: lastAssignment)
                    .overlaps(timelineRange(for: assignment))
            }) {
                lanes[laneIndex].append(assignment)
            } else {
                lanes.append([assignment])
            }
        }

        return lanes
    }

    private func timelineRange(for assignment: TimetableAssignment) -> Range<Int> {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: min(assignment.startDate, assignment.dueDate))
        let normalizedEndInclusive = calendar.startOfDay(for: max(assignment.startDate, assignment.dueDate))
        let normalizedEndExclusive = calendar.date(byAdding: .day, value: 1, to: normalizedEndInclusive) ?? normalizedEndInclusive

        let startOffset = max(
            calendar.dateComponents([.day], from: timelineBounds.start, to: normalizedStart).day ?? 0,
            0
        )
        let endOffsetExclusive = max(
            calendar.dateComponents([.day], from: timelineBounds.start, to: normalizedEndExclusive).day ?? startOffset + 1,
            startOffset + 1
        )

        return startOffset..<endOffsetExclusive
    }

    private func barMetrics(
        for assignment: TimetableAssignment,
        columnWidth: CGFloat
    ) -> (offset: CGFloat, width: CGFloat) {
        let range = timelineRange(for: assignment)

        return (
            CGFloat(range.lowerBound) * columnWidth,
            max(CGFloat(range.count) * columnWidth, columnWidth * 0.7)
        )
    }

    private func updateVisibleWeek(for offset: CGFloat, columnWidth: CGFloat, viewportWidth: CGFloat) {
        guard !timelineDates.isEmpty else { return }

        let leadingDayIndex = max(Int(round(offset / max(columnWidth, 1))), 0)
        let clampedIndex = min(leadingDayIndex, timelineDates.count - 1)
        let observedWeekStart = startOfWeek(for: timelineDates[clampedIndex])

        guard observedWeekStart != lastObservedWeekStart else { return }

        lastObservedWeekStart = observedWeekStart
        visibleWeekStart = observedWeekStart
    }

    private func scrollToWeekStart(_ weekStart: Date, proxy: ScrollViewProxy) {
        let normalized = startOfWeek(for: weekStart)
        lastObservedWeekStart = normalized
        withAnimation(.easeInOut(duration: 0.22)) {
            proxy.scrollTo(weekAnchorID(normalized), anchor: .leading)
        }
    }
}

struct AddAssignmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

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
                if subjectOptions.isEmpty {
                    Text("Add subjects in Timetable first")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Subject", selection: $subject) {
                        ForEach(subjectOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                TextField("Homework", text: $content, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Schedule") {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("Due Date", selection: $dueDate, in: startDate..., displayedComponents: .date)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(assignmentID == nil ? "Add Assignment" : "Edit Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveAssignment()
                }
                .disabled(!canSaveAssignment)
            }
        }
        .task {
            loadExistingAssignmentIfNeeded()
            syncDefaultSubjectIfNeeded()
        }
    }

    private var canSaveAssignment: Bool {
        !subject.trimmed.isEmpty && !content.trimmed.isEmpty && subjectOptions.contains(subject)
    }

    private var subjectOptions: [String] {
        let timetableSubjects = stores.first?.subjects.map(\.name) ?? []

        if timetableSubjects.contains(subject) || subject.trimmed.isEmpty {
            return timetableSubjects.sorted()
        }

        return Array(Set(timetableSubjects + [subject])).sorted()
    }

    private func loadExistingAssignmentIfNeeded() {
        guard !didLoadExistingAssignment else {
            return
        }
        didLoadExistingAssignment = true

        guard let assignmentID,
              let assignment = stores.first?.assignment(with: assignmentID)
        else {
            return
        }

        subject = assignment.subject
        content = assignment.content
        startDate = assignment.startDate
        dueDate = assignment.dueDate
        syncDefaultSubjectIfNeeded()
    }

    private func saveAssignment() {
        let assignment = TimetableAssignment(
            id: assignmentID ?? UUID(),
            subject: subject.trimmed,
            content: content.trimmed,
            startDate: startDate,
            dueDate: dueDate,
            createdAt: existingAssignment?.createdAt ?? .now,
            isFinished: existingAssignment?.isFinished ?? false
        )

        let store = activeStore()
        store.upsertAssignment(assignment)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            return
        }
    }

    private func syncDefaultSubjectIfNeeded() {
        if subject.trimmed.isEmpty, let firstSubject = subjectOptions.first {
            subject = firstSubject
        } else if !subject.trimmed.isEmpty,
                  !subjectOptions.contains(subject),
                  let firstSubject = subjectOptions.first {
            subject = firstSubject
        }
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

    private var existingAssignment: TimetableAssignment? {
        guard let assignmentID else {
            return nil
        }

        return stores.first?.assignment(with: assignmentID)
    }
}

private enum AssignmentFilter: Hashable {
    case all
    case subject(String)
}

private struct AssignmentSection: Identifiable {
    let subject: String
    let assignments: [TimetableAssignment]

    var id: String { subject }
}

private struct SubjectAssignmentGroup: Identifiable {
    let subject: String
    let lanes: [[TimetableAssignment]]

    var id: String { subject }
}

private struct TimelineScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

func startOfWeek(for date: Date) -> Date {
    let calendar = Calendar.current
    let normalizedDate = calendar.startOfDay(for: date)
    return calendar.dateInterval(of: .weekOfYear, for: normalizedDate)?.start ?? normalizedDate
}

func datesForWeek(startingAt weekStart: Date) -> [Date] {
    let calendar = Calendar.current
    let normalizedWeekStart = startOfWeek(for: weekStart)

    return (0..<7).compactMap { day in
        calendar.date(byAdding: .day, value: day, to: normalizedWeekStart)
    }
}

func shiftWeek(from weekStart: Date, by weeks: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: weeks * 7, to: startOfWeek(for: weekStart))
        .map { startOfWeek(for: $0) } ?? startOfWeek(for: weekStart)
}

func weekInterval(startingAt weekStart: Date) -> DateInterval {
    let calendar = Calendar.current
    let start = startOfWeek(for: weekStart)
    let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
    return DateInterval(start: start, end: end)
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M.d"
    return formatter.string(from: date)
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension View {
    @ViewBuilder
    func liquidGlassSurface(
        cornerRadius: CGFloat,
        tint: Color = .clear,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(
                    .regular.tint(tint).interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                self.glassEffect(
                    .regular.tint(tint),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
        } else {
            self
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

private struct FindMyCollapsedTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 21, weight: tab == selection ? .semibold : .medium))
                            .symbolRenderingMode(.monochrome)
                            .frame(height: 24, alignment: .bottom)

                        Text(tab.title)
                            .font(.system(size: 12, weight: tab == selection ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tab == selection ? Color.blue : Color.white.opacity(0.94))
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .padding(.top, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NativeSheetTabBar: UIViewRepresentable {
    @Binding var selection: AppTab

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UITabBar {
        let tabBar = UITabBar(frame: .zero)
        tabBar.delegate = context.coordinator
        tabBar.items = AppTab.allCases.map(\.tabBarItem)
        tabBar.selectedItem = selection.tabBarItem
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.selectionIndicatorImage = UIImage()

        let normalColor = UIColor.white.withAlphaComponent(0.92)
        let selectedColor = UIColor.systemBlue
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = normalAttributes
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = selectedAttributes
        }

        tabBar.standardAppearance = appearance
        tabBar.itemPositioning = .fill
        tabBar.itemSpacing = 0
        tabBar.itemWidth = 0
        tabBar.backgroundColor = .clear
        tabBar.isTranslucent = true
        tabBar.tintColor = selectedColor
        tabBar.unselectedItemTintColor = normalColor
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        return tabBar
    }

    func updateUIView(_ uiView: UITabBar, context: Context) {
        let items = AppTab.allCases.map(\.tabBarItem)
        if uiView.items?.map(\.tag) != items.map(\.tag) {
            uiView.items = items
        }
        uiView.selectedItem = uiView.items?.first(where: { $0.tag == selection.rawValue })
        context.coordinator.selection = $selection
    }

    final class Coordinator: NSObject, UITabBarDelegate {
        var selection: Binding<AppTab>

        init(selection: Binding<AppTab>) {
            self.selection = selection
        }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            guard let tab = AppTab(rawValue: item.tag) else { return }
            selection.wrappedValue = tab
        }
    }
}

private extension AppTab {
    var tabBarItem: UITabBarItem {
        let item = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: UIImage(systemName: systemImage)
        )
        item.tag = rawValue
        return item
    }
}

#Preview {
    AssignmentsView(tabSelection: .constant(.assignments))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
