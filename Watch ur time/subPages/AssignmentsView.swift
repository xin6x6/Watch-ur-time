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
    @State private var isEditingAssignment = false
    @State private var editingAssignmentID: UUID?
    @State private var timelineScrollRequestID = UUID()
    @State private var drawerStop: AssignmentDrawerStop = .collapsed
    @State private var interactiveDrawerHeight: CGFloat?
    @State private var dragStartDrawerHeight: CGFloat?

    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let drawerMetrics = drawerMetrics(for: geo)
                let visibleDrawerHeight = currentDrawerHeight(for: drawerMetrics)
                let drawerRevealProgress = revealProgress(
                    visibleHeight: visibleDrawerHeight,
                    metrics: drawerMetrics
                )
                let primaryContentHeight = max(
                    geo.size.height
                        - drawerMetrics.bottomClearance
                        - drawerMetrics.bottomMargin
                        - visibleDrawerHeight,
                    0
                )

                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if primaryContentHeight > 0 {
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
                                    .frame(maxHeight: .infinity, alignment: .top)
                                }
                            }
                            .frame(height: primaryContentHeight, alignment: .top)
                        }
                        Spacer(minLength: 0)
                    }

                    drawerView(
                        metrics: drawerMetrics,
                        visibleHeight: visibleDrawerHeight,
                        revealProgress: drawerRevealProgress
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, drawerMetrics.horizontalInset)
                    .padding(.bottom, drawerMetrics.bottomClearance + drawerMetrics.bottomMargin)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassButton(img: "plus") {
                        editingAssignmentID = nil
                        isAddingAssignment = true
                    }
                }
            }
            .navigationDestination(isPresented: $isAddingAssignment) {
                AddAssignmentsView()
            }
            .navigationDestination(isPresented: $isEditingAssignment) {
                if let editingAssignmentID {
                    AddAssignmentsView(assignmentID: editingAssignmentID)
                }
            }
        }
        .appDefaultFont()
        .tint(.primary)
    }

    private var store: TimetableStore? {
        stores.first
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
            .appFont(.headline)
    }

    private var weekRangeLabel: String {
        guard let firstDay = weekDates.first, let lastDay = weekDates.last else {
            return AppLocalizer.localized("This Week")
        }
        return "\(formatDate(firstDay)) - \(formatDate(lastDay))"
    }

    private func drawerView(
        metrics: AssignmentDrawerMetrics,
        visibleHeight: CGFloat,
        revealProgress: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            drawerHeader(revealProgress: revealProgress, metrics: metrics)

            Group {
                if filteredAssignments.isEmpty {
                    drawerEmptyState
                } else {
                    assignmentsList
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .opacity(revealProgress > 0.08 ? 1 : 0)
            .allowsHitTesting(revealProgress > 0.2)
            .clipped()
        }
        .frame(height: visibleHeight, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(max(revealProgress, 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .stroke(.white.opacity(max(0.12, revealProgress * 0.14)), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.14 * revealProgress), radius: 16, y: -2)
        .transaction { transaction in
            if interactiveDrawerHeight != nil {
                transaction.animation = nil
            }
        }
    }

    private func drawerHeader(
        revealProgress: CGFloat,
        metrics: AssignmentDrawerMetrics
    ) -> some View {
        let titleReveal = max(0, min((revealProgress - 0.12) / 0.32, 1))

        return ZStack(alignment: .top) {
            Capsule()
                .fill(.secondary.opacity(0.55))
                .frame(width: 36, height: 4)
                .padding(.top, 6)

            HStack {
                Text("Assignments")
                    .appFont(.title2, weight: .bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .opacity(titleReveal)
            .offset(y: (1 - titleReveal) * 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.headerHeight, alignment: .top)
        .contentShape(Rectangle())
        .highPriorityGesture(drawerGesture(for: metrics))
        .onTapGesture {
            AppHaptics.trigger(.selection)
            withAnimation(drawerAnimation) {
                drawerStop = nextDrawerStop(after: drawerStop)
            }
        }
    }

    private var drawerEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .appFont(size: 30)
                .foregroundStyle(.secondary)
            Text("No assignments this week")
                .appFont(.headline)
            Text("Add an assignment from the top-right button, or switch the week and subject filter.")
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func drawerMetrics(for geo: GeometryProxy) -> AssignmentDrawerMetrics {
        let horizontalInset: CGFloat = 12
        let bottomMargin: CGFloat = 100
        let handleAreaHeight: CGFloat = 16
        let collapsedVisibleHeight: CGFloat = 16
        let headerHeight: CGFloat = 60
        let tabBarClearance = -max(0, geo.safeAreaInsets.bottom)
        let expandedHeight = max(geo.size.height - tabBarClearance - bottomMargin, headerHeight)
        let middleHeight = min(
            max(expandedHeight * 0.42, 260),
            max(expandedHeight - 140, collapsedVisibleHeight + 120)
        )

        return AssignmentDrawerMetrics(
            expandedHeight: expandedHeight,
            middleHeight: middleHeight,
            handleAreaHeight: handleAreaHeight,
            headerHeight: headerHeight,
            collapsedVisibleHeight: collapsedVisibleHeight,
            horizontalInset: horizontalInset,
            bottomClearance: tabBarClearance,
            bottomMargin: bottomMargin,
            cornerRadius: 30
        )
    }

    private func currentDrawerHeight(for metrics: AssignmentDrawerMetrics) -> CGFloat {
        if let interactiveDrawerHeight {
            return clampedDrawerHeight(interactiveDrawerHeight, metrics: metrics)
        }
        return height(for: drawerStop, metrics: metrics)
    }

    private func clampedDrawerHeight(
        _ proposedHeight: CGFloat,
        metrics: AssignmentDrawerMetrics
    ) -> CGFloat {
        min(max(proposedHeight, metrics.collapsedVisibleHeight), metrics.expandedHeight)
    }

    private func height(for stop: AssignmentDrawerStop, metrics: AssignmentDrawerMetrics) -> CGFloat {
        switch stop {
        case .collapsed:
            metrics.collapsedVisibleHeight
        case .middle:
            metrics.middleHeight
        case .expanded:
            metrics.expandedHeight
        }
    }

    private func revealProgress(
        visibleHeight: CGFloat,
        metrics: AssignmentDrawerMetrics
    ) -> CGFloat {
        let denominator = max(metrics.expandedHeight - metrics.collapsedVisibleHeight, 1)
        return min(max((visibleHeight - metrics.collapsedVisibleHeight) / denominator, 0), 1)
    }

    private func nearestDrawerStop(
        for targetHeight: CGFloat,
        metrics: AssignmentDrawerMetrics
    ) -> AssignmentDrawerStop {
        AssignmentDrawerStop.allCases.min { lhs, rhs in
            abs(height(for: lhs, metrics: metrics) - targetHeight)
                < abs(height(for: rhs, metrics: metrics) - targetHeight)
        } ?? .collapsed
    }

    private func nextDrawerStop(after stop: AssignmentDrawerStop) -> AssignmentDrawerStop {
        switch stop {
        case .collapsed:
            .middle
        case .middle:
            .expanded
        case .expanded:
            .collapsed
        }
    }

    private func drawerGesture(for metrics: AssignmentDrawerMetrics) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let startHeight = dragStartDrawerHeight ?? currentDrawerHeight(for: metrics)
                if dragStartDrawerHeight == nil {
                    dragStartDrawerHeight = startHeight
                }
                interactiveDrawerHeight = clampedDrawerHeight(
                    startHeight - value.translation.height,
                    metrics: metrics
                )
            }
            .onEnded { value in
                let startHeight = dragStartDrawerHeight ?? currentDrawerHeight(for: metrics)
                let projectedHeight = clampedDrawerHeight(
                    startHeight - value.predictedEndTranslation.height,
                    metrics: metrics
                )
                let targetStop = nearestDrawerStop(for: projectedHeight, metrics: metrics)

                AppHaptics.trigger(.selection)
                withAnimation(drawerAnimation) {
                    drawerStop = targetStop
                    interactiveDrawerHeight = nil
                }

                dragStartDrawerHeight = nil
            }
    }

    private var drawerAnimation: Animation {
        .interactiveSpring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.1)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "checklist")
                    .appFont(size: 30)
                    .foregroundStyle(.secondary)
                Text("No assignments this week")
                    .appFont(.headline)
                Text("Add an assignment from the top-right button, or switch the week and subject filter.")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        }
    }

    private func assignmentRow(for assignment: TimetableAssignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(assignment.subject)
                    .appFont(.headline)
                    .strikethrough(assignment.isFinished)
                Spacer()
                Text(AppLocalizer.format("Due %@", formatDate(assignment.dueDate)))
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(assignment.content)
                .appFont(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .strikethrough(assignment.isFinished)

            Text(AppLocalizer.format("Start %@", formatDate(assignment.startDate)))
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(Array(groupedAssignments.enumerated()), id: \.element.id) { index, group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.subject)
                            .appFont(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(group.assignments) { assignment in
                            SwipeableAssignmentRow(
                                onTap: {
                                    editingAssignmentID = assignment.id
                                    isEditingAssignment = true
                                },
                                onComplete: {
                                    toggleCompletion(for: assignment)
                                },
                                onDelete: {
                                    deleteAssignment(assignment)
                                }
                            ) {
                                assignmentRow(for: assignment)
                            }
                        }

                        if index < groupedAssignments.count - 1 {
                            Divider()
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 18)
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
    @State private var lastObservedWeekStart = startOfWeek(for: Date())
    @State private var ignoreOffsetUpdatesUntil: Date?
    @State private var currentScrollOffset: CGFloat = 0
    @State private var pinchBaseZoomScale: CGFloat?
    @State private var pinchStartScrollOffset: CGFloat?

    private let barHeight: CGFloat = 44
    private let laneSpacing: CGFloat = 10
    private let subjectSpacing: CGFloat = 16
    private let zoomAnchorSegmentsPerDay = 12

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geo in
                let columnWidth = max((geo.size.width / 7) * zoomScale, 28)
                let totalWidth = CGFloat(timelineDates.count) * columnWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        timelineAnchorRow(columnWidth: columnWidth)
                            .frame(height: 0)

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
                .simultaneousGesture(zoomGesture(proxy: proxy, viewportWidth: geo.size.width))
                .onAppear {
                    lastObservedWeekStart = startOfWeek(for: visibleWeekStart)
                    programmaticScroll(to: startOfWeek(for: visibleWeekStart), proxy: proxy)
                }
                .onChange(of: scrollRequestID) { _, _ in
                    programmaticScroll(to: startOfWeek(for: visibleWeekStart), proxy: proxy)
                }
                .onPreferenceChange(TimelineScrollOffsetKey.self) { offset in
                    currentScrollOffset = max(offset, 0)
                    updateVisibleWeek(for: offset, columnWidth: columnWidth, viewportWidth: geo.size.width)
                }
            }
            .frame(minHeight: chartHeight + 34, maxHeight: .infinity)
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
            .appFont(.caption, weight: .semibold)
            .frame(width: columnWidth)
            .id(headerAnchorID(for: date, dayIndex: dayIndex))
    }

    private func timelineAnchorRow(columnWidth: CGFloat) -> some View {
        let segmentWidth = columnWidth / CGFloat(zoomAnchorSegmentsPerDay)
        let segmentCount = max(timelineDates.count * zoomAnchorSegmentsPerDay, 1)

        return HStack(spacing: 0) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Color.clear
                    .frame(width: segmentWidth, height: 0)
                    .id(zoomAnchorID(index))
            }
        }
    }

    private func zoomGesture(
        proxy: ScrollViewProxy,
        viewportWidth: CGFloat
    ) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                let baseZoomScale = pinchBaseZoomScale ?? zoomScale
                if pinchBaseZoomScale == nil {
                    pinchBaseZoomScale = baseZoomScale
                }

                let startOffset = pinchStartScrollOffset ?? currentScrollOffset
                if pinchStartScrollOffset == nil {
                    pinchStartScrollOffset = startOffset
                }

                let nextZoomScale = min(max(baseZoomScale * value.magnification, 1), 3)
                let startColumnWidth = max((viewportWidth / 7) * baseZoomScale, 28)
                let nextColumnWidth = max((viewportWidth / 7) * nextZoomScale, 28)
                let anchorTimelineX = startOffset + value.startLocation.x
                let scaledAnchorTimelineX = anchorTimelineX * (nextColumnWidth / startColumnWidth)
                let desiredOffset = scaledAnchorTimelineX - value.startLocation.x

                zoomScale = nextZoomScale
                setTimelineOffset(
                    desiredOffset,
                    proxy: proxy,
                    columnWidth: nextColumnWidth,
                    viewportWidth: viewportWidth,
                    animated: false
                )
            }
            .onEnded { value in
                let baseZoomScale = pinchBaseZoomScale ?? zoomScale
                let startOffset = pinchStartScrollOffset ?? currentScrollOffset
                let finalZoomScale = min(max(baseZoomScale * value.magnification, 1), 3)
                let startColumnWidth = max((viewportWidth / 7) * baseZoomScale, 28)
                let finalColumnWidth = max((viewportWidth / 7) * finalZoomScale, 28)
                let anchorTimelineX = startOffset + value.startLocation.x
                let scaledAnchorTimelineX = anchorTimelineX * (finalColumnWidth / startColumnWidth)
                let desiredOffset = scaledAnchorTimelineX - value.startLocation.x

                zoomScale = finalZoomScale
                setTimelineOffset(
                    desiredOffset,
                    proxy: proxy,
                    columnWidth: finalColumnWidth,
                    viewportWidth: viewportWidth,
                    animated: false
                )

                pinchBaseZoomScale = nil
                pinchStartScrollOffset = nil
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
        let selectedWeekStart = startOfWeek(for: visibleWeekStart)
        let selectedWeekEnd = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
        let relevantDates = assignments.flatMap { [min($0.startDate, $0.dueDate), max($0.startDate, $0.dueDate)] }
            + [Date(), selectedWeekStart, selectedWeekEnd]

        guard let minDate = relevantDates.min(), let maxDate = relevantDates.max() else {
            let start = selectedWeekStart
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

    private func zoomAnchorID(_ index: Int) -> String {
        "zoom-anchor-\(index)"
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
        if let ignoreOffsetUpdatesUntil, ignoreOffsetUpdatesUntil > .now {
            return
        }
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

    private func programmaticScroll(to weekStart: Date, proxy: ScrollViewProxy) {
        ignoreOffsetUpdatesUntil = Date().addingTimeInterval(0.35)
        scrollToWeekStart(weekStart, proxy: proxy)
    }

    private func setTimelineOffset(
        _ desiredOffset: CGFloat,
        proxy: ScrollViewProxy,
        columnWidth: CGFloat,
        viewportWidth: CGFloat,
        animated: Bool
    ) {
        let segmentWidth = columnWidth / CGFloat(zoomAnchorSegmentsPerDay)
        let totalWidth = CGFloat(timelineDates.count) * columnWidth
        let maxOffset = max(totalWidth - viewportWidth, 0)
        let clampedOffset = min(max(desiredOffset, 0), maxOffset)
        let maxSegmentIndex = max(timelineDates.count * zoomAnchorSegmentsPerDay - 1, 0)
        let targetIndex = min(max(Int(round(clampedOffset / max(segmentWidth, 1))), 0), maxSegmentIndex)

        ignoreOffsetUpdatesUntil = Date().addingTimeInterval(0.12)
        currentScrollOffset = clampedOffset

        var transaction = Transaction()
        transaction.animation = animated ? .easeInOut(duration: 0.18) : nil
        withTransaction(transaction) {
            proxy.scrollTo(zoomAnchorID(targetIndex), anchor: .leading)
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
        .navigationTitle(
            assignmentID == nil
                ? AppLocalizer.localized("Add Assignment")
                : AppLocalizer.localized("Edit Assignment")
        )
        .navigationBarTitleDisplayMode(.inline)
        .appDefaultFont()
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

private enum AssignmentDrawerStop: CaseIterable {
    case collapsed
    case middle
    case expanded
}

private struct SwipeableAssignmentRow<Content: View>: View {
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var settledOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat?
    @State private var suppressTap = false

    private let actionWidth: CGFloat = 92
    private let cornerRadius: CGFloat = 22

    var body: some View {
        let totalActionWidth = actionWidth * 2

        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                actionButton(
                    title: AppLocalizer.localized("已完成"),
                    color: .green,
                    width: actionWidth
                ) {
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                        settledOffset = 0
                    }
                    onComplete()
                }

                actionButton(
                    title: AppLocalizer.localized("删除"),
                    color: .red,
                    width: actionWidth
                ) {
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                        settledOffset = 0
                    }
                    onDelete()
                }
            }
            .frame( maxHeight: .infinity, alignment: .trailing)
            .opacity(settledOffset < -1 ? 1 : 0)
            .allowsHitTesting(settledOffset < -1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            content()
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onTapGesture {
                    guard !suppressTap else {
                        return
                    }
                    if settledOffset < -8 {
                        AppHaptics.trigger(.selection)
                        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                            settledOffset = 0
                        }
                    } else {
                        AppHaptics.trigger(.tap)
                        onTap()
                    }
                }
                .offset(x: settledOffset)
                .allowsHitTesting(true)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .highPriorityGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }

                    if abs(value.translation.width) > 6 {
                        suppressTap = true
                    }

                    let startOffset = dragStartOffset ?? settledOffset
                    if dragStartOffset == nil {
                        dragStartOffset = startOffset
                    }

                    settledOffset = min(
                        max(startOffset + value.translation.width, -totalActionWidth),
                        0
                    )
                }
                .onEnded { value in
                    defer {
                        dragStartOffset = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            suppressTap = false
                        }
                    }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }

                    let startOffset = dragStartOffset ?? settledOffset
                    let projectedOffset = min(
                        max(startOffset + value.predictedEndTranslation.width, -totalActionWidth),
                        0
                    )

                    AppHaptics.trigger(.selection)
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                        settledOffset = projectedOffset < -(actionWidth * 0.9) ? -totalActionWidth : 0
                    }
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                if suppressTap {
                    return
                }
            }
        )
    }

    private func actionButton(
        title: String,
        color: Color,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                AppHaptics.trigger(.tap)
            }
        )
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(color)
    }
}

private struct AssignmentDrawerMetrics {
    let expandedHeight: CGFloat
    let middleHeight: CGFloat
    let handleAreaHeight: CGFloat
    let headerHeight: CGFloat
    let collapsedVisibleHeight: CGFloat
    let horizontalInset: CGFloat
    let bottomClearance: CGFloat
    let bottomMargin: CGFloat
    let cornerRadius: CGFloat
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

#Preview {
    AssignmentsView(tabSelection: .constant(.assignments))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
