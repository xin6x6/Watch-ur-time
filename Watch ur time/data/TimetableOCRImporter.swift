//
//  TimetableOCRImporter.swift
//  Watch ur time
//
//  Created By Ng1nx on 7/5/26.
//

import Foundation
import SwiftUI
import UIKit
import Vision

struct ImportedTimetablePayload {
    var subjects: [TimetableSubject]
    var slots: [TimetableTimeSlot]
    var placements: [TimetablePlacement]
}

enum TimetableOCRImportResult {
    case direct(ImportedTimetablePayload)
    case needsReview(TimetableOCRReviewContext)
}

struct TimetableOCRReviewContext: Identifiable {
    let id = UUID()
    let classOptions: [TimetableOCRClassOption]
}

struct TimetableOCRClassOption: Identifiable {
    let id: Int
    let displayName: String
    let payload: ImportedTimetablePayload
}

enum TimetableOCRImportError: LocalizedError {
    case imageDecodeFailed
    case noRecognizedText
    case weekdayHeadersMissing
    case noTimeRowsFound
    case noClassesDetected

    var errorDescription: String? {
        switch self {
        case .imageDecodeFailed:
            return AppLocalizer.localized("The selected image could not be read.")
        case .noRecognizedText:
            return AppLocalizer.localized("No text was recognized in this timetable image.")
        case .weekdayHeadersMissing:
            return AppLocalizer.localized("Could not find weekday headers from Mon. to Fri. in the image.")
        case .noTimeRowsFound:
            return AppLocalizer.localized("Could not find class time rows in the image.")
        case .noClassesDetected:
            return AppLocalizer.localized("No class cells were detected from the timetable image.")
        }
    }
}

enum TimetableOCRImporter {
    static func importTimetable(from imageData: Data) async throws -> TimetableOCRImportResult {
        guard let cgImage = makeCGImage(from: imageData) else {
            throw TimetableOCRImportError.imageDecodeFailed
        }

        let observations = try await recognizeText(in: cgImage)
        guard !observations.isEmpty else {
            throw TimetableOCRImportError.noRecognizedText
        }

        let timeRows = detectTimeRows(from: observations, beforeX: 0.28)
        guard !timeRows.isEmpty else {
            throw TimetableOCRImportError.noTimeRowsFound
        }

        let weekdayHeaders = detectWeekdayHeaders(from: observations)
        let orderedHeaders = if weekdayHeaders.count >= 3 {
            weekdayHeaders.sorted { $0.rect.midX < $1.rect.midX }
        } else if let inferredHeaders = inferWeekdayHeaders(from: observations, timeRows: timeRows) {
            inferredHeaders
        } else {
            throw TimetableOCRImportError.weekdayHeadersMissing
        }

        if let reviewContext = detectMultiClassReviewContext(
            from: observations,
            headers: orderedHeaders,
            timeRows: timeRows
        ) {
            return .needsReview(reviewContext)
        }

        let consumedIDs = Set(orderedHeaders.map(\.id)).union(timeRows.flatMap(\.sourceObservationIDs))
        let cellTexts = detectSimpleCellTexts(
            from: observations,
            headers: orderedHeaders,
            timeRows: timeRows,
            consumedIDs: consumedIDs
        )

        let payload = buildSimplePayload(headers: orderedHeaders, timeRows: timeRows, cellTexts: cellTexts)
        guard !payload.placements.isEmpty else {
            throw TimetableOCRImportError.noClassesDetected
        }

        return .direct(payload)
    }

    private static func detectMultiClassReviewContext(
        from observations: [RecognizedTextBox],
        headers: [WeekdayHeaderBox],
        timeRows: [TimeRowBox]
    ) -> TimetableOCRReviewContext? {
        let dayBounds = buildDayBounds(from: headers)
        let dailyColumns = detectDailyClassColumns(
            from: observations,
            dayBounds: dayBounds,
            timeRows: timeRows
        )

        let populatedDays = dailyColumns.values.filter { $0.count >= 3 }
        guard populatedDays.count >= 3 else {
            return nil
        }

        let averageCount = Double(populatedDays.map(\.count).reduce(0, +)) / Double(populatedDays.count)
        guard averageCount >= 3 else {
            return nil
        }

        let consumedIDs = Set(headers.map(\.id))
            .union(timeRows.flatMap(\.sourceObservationIDs))
            .union(dailyColumns.values.flatMap { $0.flatMap(\.sourceObservationIDs) })

        let multiCellTexts = detectMultiClassCellTexts(
            from: observations,
            dayBounds: dayBounds,
            dayColumns: dailyColumns,
            timeRows: timeRows,
            consumedIDs: consumedIDs
        )

        let maxColumnCount = dailyColumns.values.map(\.count).max() ?? 0
        guard maxColumnCount >= 3 else {
            return nil
        }

        let options: [TimetableOCRClassOption] = (0..<maxColumnCount).compactMap { classIndex in
            let labelCandidates = headers.compactMap { header in
                dailyColumns[header.dayIndex]?[safe: classIndex]?.displayName
            }
            guard !labelCandidates.isEmpty else {
                return nil
            }

            let displayName = bestClassLabel(from: labelCandidates)
            let payload = buildMultiClassPayload(
                classIndex: classIndex,
                headers: headers,
                timeRows: timeRows,
                dayColumns: dailyColumns,
                cellTexts: multiCellTexts
            )

            guard !payload.placements.isEmpty else {
                return nil
            }

            return TimetableOCRClassOption(
                id: classIndex,
                displayName: displayName,
                payload: payload
            )
        }

        guard options.count >= 2 else {
            return nil
        }

        return TimetableOCRReviewContext(classOptions: options)
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        if let cgImage = image.cgImage {
            return cgImage
        }

        guard let ciImage = CIImage(data: data) else {
            return nil
        }

        return CIContext().createCGImage(ciImage, from: ciImage.extent)
    }

    private static func recognizeText(in cgImage: CGImage) async throws -> [RecognizedTextBox] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { observation -> RecognizedTextBox? in
                        guard let candidate = observation.topCandidates(1).first else {
                            return nil
                        }

                        let cleaned = candidate.string
                            .replacingOccurrences(of: "\u{00A0}", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        guard !cleaned.isEmpty else {
                            return nil
                        }

                        return RecognizedTextBox(
                            id: UUID(),
                            text: cleaned,
                            rect: observation.boundingBox
                        )
                    }

                continuation.resume(returning: observations)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func detectWeekdayHeaders(from observations: [RecognizedTextBox]) -> [WeekdayHeaderBox] {
        var bestByDay: [Int: WeekdayHeaderBox] = [:]

        for observation in observations {
            guard let dayIndex = weekdayIndex(for: observation.text) else {
                continue
            }

            let candidate = WeekdayHeaderBox(
                id: observation.id,
                dayIndex: dayIndex,
                title: observation.text,
                rect: observation.rect
            )

            if let existing = bestByDay[dayIndex] {
                if candidate.rect.maxY > existing.rect.maxY {
                    bestByDay[dayIndex] = candidate
                }
            } else {
                bestByDay[dayIndex] = candidate
            }
        }

        return bestByDay.values.sorted { $0.dayIndex < $1.dayIndex }
    }

    private static func inferWeekdayHeaders(
        from observations: [RecognizedTextBox],
        timeRows: [TimeRowBox]
    ) -> [WeekdayHeaderBox]? {
        guard !timeRows.isEmpty else {
            return nil
        }

        let timeRowObservationIDs = Set(timeRows.flatMap(\.sourceObservationIDs))
        let nonTimeObservations = observations.filter { !timeRowObservationIDs.contains($0.id) }

        let leftBoundary = observations
            .filter { timeRowObservationIDs.contains($0.id) }
            .map(\.rect.maxX)
            .max() ?? 0.18

        let contentCandidates = nonTimeObservations.filter {
            $0.rect.midX > leftBoundary + 0.015 &&
            $0.rect.midY > 0.12
        }

        let rightBoundary = contentCandidates.map(\.rect.maxX).max() ?? 0.98
        let usableWidth = rightBoundary - leftBoundary
        guard usableWidth > 0.2 else {
            return nil
        }

        return (0..<5).map { index in
            let segmentWidth = usableWidth / 5
            let minX = leftBoundary + CGFloat(index) * segmentWidth
            let maxX = minX + segmentWidth
            let centerX = (minX + maxX) / 2

            return WeekdayHeaderBox(
                id: UUID(),
                dayIndex: index + 1,
                title: ["Mon.", "Tue.", "Wed.", "Thu.", "Fri."][index],
                rect: CGRect(x: minX, y: 0.96, width: maxX - minX, height: 0.02)
            )
        }
        .map {
            WeekdayHeaderBox(
                id: $0.id,
                dayIndex: $0.dayIndex,
                title: $0.title,
                rect: CGRect(x: $0.rect.minX, y: $0.rect.minY, width: $0.rect.width, height: $0.rect.height)
            )
        }
    }

    private static func buildDayBounds(from headers: [WeekdayHeaderBox]) -> [DayBounds] {
        headers.enumerated().map { index, header in
            let minX: CGFloat = if index == 0 {
                0
            } else {
                (headers[index - 1].rect.midX + header.rect.midX) / 2
            }

            let maxX: CGFloat = if index == headers.count - 1 {
                1
            } else {
                (header.rect.midX + headers[index + 1].rect.midX) / 2
            }

            return DayBounds(dayIndex: header.dayIndex, minX: minX, maxX: maxX)
        }
    }

    private static func detectTimeRows(
        from observations: [RecognizedTextBox],
        beforeX maxX: CGFloat
    ) -> [TimeRowBox] {
        var rows: [TimeRowBox] = []
        var usedObservationIDs: Set<UUID> = []

        let leftSideObservations = observations
            .filter { $0.rect.maxX <= max(maxX + 0.08, 0.4) }
            .sorted { $0.rect.midY > $1.rect.midY }

        for observation in leftSideObservations where !usedObservationIDs.contains(observation.id) {
            let matches = extractTimeComponents(from: observation.text)
            if matches.count >= 2 {
                rows.append(
                    TimeRowBox(
                        startTime: matches[0].time,
                        startMeridiem: matches[0].meridiem,
                        endTime: matches[1].time,
                        endMeridiem: matches[1].meridiem,
                        centerY: observation.rect.midY,
                        sourceObservationIDs: [observation.id]
                    )
                )
                usedObservationIDs.insert(observation.id)
                continue
            }

            guard matches.count == 1 else {
                continue
            }

            let nearby = leftSideObservations.filter {
                $0.id != observation.id &&
                    !usedObservationIDs.contains($0.id) &&
                    abs($0.rect.midY - observation.rect.midY) < 0.028
            }

            guard let partner = nearby.first(where: { !extractTimeComponents(from: $0.text).isEmpty }) else {
                continue
            }

            let partnerMatches = extractTimeComponents(from: partner.text)
            guard let partnerComponent = partnerMatches.first else {
                continue
            }

            let ordered = [matches[0], partnerComponent].sorted { lhs, rhs in
                lhs.absoluteMinutes < rhs.absoluteMinutes
            }

            rows.append(
                TimeRowBox(
                    startTime: ordered[0].time,
                    startMeridiem: ordered[0].meridiem,
                    endTime: ordered[1].time,
                    endMeridiem: ordered[1].meridiem,
                    centerY: (observation.rect.midY + partner.rect.midY) / 2,
                    sourceObservationIDs: [observation.id, partner.id]
                )
            )
            usedObservationIDs.insert(observation.id)
            usedObservationIDs.insert(partner.id)
        }

        return rows.sorted { $0.centerY > $1.centerY }
    }

    private static func detectDailyClassColumns(
        from observations: [RecognizedTextBox],
        dayBounds: [DayBounds],
        timeRows: [TimeRowBox]
    ) -> [Int: [DailyClassColumn]] {
        guard let firstTimeRow = timeRows.first else {
            return [:]
        }

        var result: [Int: [DailyClassColumn]] = [:]
        let headerBandMinY = max(firstTimeRow.centerY + 0.02, 0.76)
        let headerBandMaxY = 0.96

        for dayBound in dayBounds {
            let candidates = observations
                .filter {
                    $0.rect.midX >= dayBound.minX && $0.rect.midX <= dayBound.maxX &&
                    $0.rect.midY <= headerBandMaxY && $0.rect.midY >= headerBandMinY &&
                    isPotentialClassHeaderText($0.text)
                }
                .sorted { lhs, rhs in
                    if abs(lhs.rect.midX - rhs.rect.midX) > 0.01 {
                        return lhs.rect.midX < rhs.rect.midX
                    }
                    return lhs.rect.midY > rhs.rect.midY
                }

            var clusters: [[RecognizedTextBox]] = []

            for candidate in candidates {
                if var lastCluster = clusters.last,
                   let reference = lastCluster.last,
                   abs(reference.rect.midX - candidate.rect.midX) < 0.022 {
                    lastCluster.append(candidate)
                    clusters[clusters.count - 1] = lastCluster
                } else {
                    clusters.append([candidate])
                }
            }

            let columns = clusters.compactMap { cluster -> DailyClassColumn? in
                let displayName = combineClassHeaderLines(from: cluster)
                guard !displayName.isEmpty else {
                    return nil
                }

                let centerX = cluster.map(\.rect.midX).reduce(0, +) / CGFloat(cluster.count)
                return DailyClassColumn(
                    orderIndex: 0,
                    displayName: displayName,
                    centerX: centerX,
                    sourceObservationIDs: cluster.map(\.id)
                )
            }
            .sorted { $0.centerX < $1.centerX }
            .enumerated()
            .map { index, column in
                DailyClassColumn(
                    orderIndex: index,
                    displayName: column.displayName,
                    centerX: column.centerX,
                    sourceObservationIDs: column.sourceObservationIDs
                )
            }

            if columns.count >= 2 {
                result[dayBound.dayIndex] = columns
            }
        }

        return result
    }

    private static func detectSimpleCellTexts(
        from observations: [RecognizedTextBox],
        headers: [WeekdayHeaderBox],
        timeRows: [TimeRowBox],
        consumedIDs: Set<UUID>
    ) -> [SimpleCellCoordinate: [RecognizedTextBox]] {
        let headerCenters = headers.map { $0.rect.midX }
        let rowCenters = timeRows.map(\.centerY)

        var buckets: [SimpleCellCoordinate: [RecognizedTextBox]] = [:]

        for observation in observations where !consumedIDs.contains(observation.id) {
            guard let dayIndex = nearestIndex(for: observation.rect.midX, centers: headerCenters),
                  let slotIndex = nearestIndex(for: observation.rect.midY, centers: rowCenters)
            else {
                continue
            }

            let header = headers[dayIndex]
            let row = timeRows[slotIndex]

            guard abs(observation.rect.midX - header.rect.midX) < columnTolerance(for: headers, index: dayIndex),
                  abs(observation.rect.midY - row.centerY) < rowTolerance(for: timeRows, index: slotIndex)
            else {
                continue
            }

            let coordinate = SimpleCellCoordinate(dayIndex: header.dayIndex, slotIndex: slotIndex)
            buckets[coordinate, default: []].append(observation)
        }

        return buckets
    }

    private static func detectMultiClassCellTexts(
        from observations: [RecognizedTextBox],
        dayBounds: [DayBounds],
        dayColumns: [Int: [DailyClassColumn]],
        timeRows: [TimeRowBox],
        consumedIDs: Set<UUID>
    ) -> [MultiCellCoordinate: [RecognizedTextBox]] {
        let rowCenters = timeRows.map(\.centerY)
        var buckets: [MultiCellCoordinate: [RecognizedTextBox]] = [:]

        for observation in observations where !consumedIDs.contains(observation.id) {
            guard let dayBound = dayBounds.first(where: {
                observation.rect.midX >= $0.minX && observation.rect.midX <= $0.maxX
            }),
            let columns = dayColumns[dayBound.dayIndex],
            let slotIndex = nearestIndex(for: observation.rect.midY, centers: rowCenters)
            else {
                continue
            }

            let row = timeRows[slotIndex]
            guard abs(observation.rect.midY - row.centerY) < rowTolerance(for: timeRows, index: slotIndex),
                  let classIndex = classColumnIndex(
                    for: observation.rect.midX,
                    columns: columns,
                    dayBound: dayBound
                  )
            else {
                continue
            }

            let coordinate = MultiCellCoordinate(dayIndex: dayBound.dayIndex, classIndex: classIndex, slotIndex: slotIndex)
            buckets[coordinate, default: []].append(observation)
        }

        return buckets
    }

    private static func buildSimplePayload(
        headers: [WeekdayHeaderBox],
        timeRows: [TimeRowBox],
        cellTexts: [SimpleCellCoordinate: [RecognizedTextBox]]
    ) -> ImportedTimetablePayload {
        let slots = timeRows.map {
            TimetableTimeSlot(
                startTime: $0.startTime,
                startMeridiem: $0.startMeridiem,
                endTime: $0.endTime,
                endMeridiem: $0.endMeridiem
            )
        }

        var subjects: [TimetableSubject] = []
        var subjectIDsByKey: [String: UUID] = [:]
        var placements: [TimetablePlacement] = []

        for header in headers {
            for slotIndex in timeRows.indices {
                let coordinate = SimpleCellCoordinate(dayIndex: header.dayIndex, slotIndex: slotIndex)
                guard let cellBoxes = cellTexts[coordinate],
                      let parsedCell = parseSubjectCell(from: cellBoxes)
                else {
                    continue
                }

                let subjectID = subjectIDForParsedCell(
                    parsedCell,
                    subjectIDsByKey: &subjectIDsByKey,
                    subjects: &subjects
                )

                placements.append(
                    TimetablePlacement(
                        dayIndex: header.dayIndex,
                        slotIndex: slotIndex,
                        subjectID: subjectID
                    )
                )
            }
        }

        return ImportedTimetablePayload(subjects: subjects, slots: slots, placements: placements)
    }

    private static func buildMultiClassPayload(
        classIndex: Int,
        headers: [WeekdayHeaderBox],
        timeRows: [TimeRowBox],
        dayColumns: [Int: [DailyClassColumn]],
        cellTexts: [MultiCellCoordinate: [RecognizedTextBox]]
    ) -> ImportedTimetablePayload {
        let slots = timeRows.map {
            TimetableTimeSlot(
                startTime: $0.startTime,
                startMeridiem: $0.startMeridiem,
                endTime: $0.endTime,
                endMeridiem: $0.endMeridiem
            )
        }

        var subjects: [TimetableSubject] = []
        var subjectIDsByKey: [String: UUID] = [:]
        var placements: [TimetablePlacement] = []

        for header in headers {
            guard let dayColumn = dayColumns[header.dayIndex]?[safe: classIndex] else {
                continue
            }

            for slotIndex in timeRows.indices {
                let coordinate = MultiCellCoordinate(
                    dayIndex: header.dayIndex,
                    classIndex: dayColumn.orderIndex,
                    slotIndex: slotIndex
                )
                guard let cellBoxes = cellTexts[coordinate],
                      let parsedCell = parseSubjectCell(from: cellBoxes)
                else {
                    continue
                }

                let subjectID = subjectIDForParsedCell(
                    parsedCell,
                    subjectIDsByKey: &subjectIDsByKey,
                    subjects: &subjects
                )

                placements.append(
                    TimetablePlacement(
                        dayIndex: header.dayIndex,
                        slotIndex: slotIndex,
                        subjectID: subjectID
                    )
                )
            }
        }

        return ImportedTimetablePayload(subjects: subjects, slots: slots, placements: placements)
    }

    private static func subjectIDForParsedCell(
        _ parsedCell: ParsedSubjectCell,
        subjectIDsByKey: inout [String: UUID],
        subjects: inout [TimetableSubject]
    ) -> UUID {
        let key = "\(parsedCell.name.lowercased())|\(parsedCell.room.lowercased())"
        if let existingID = subjectIDsByKey[key] {
            return existingID
        }

        let subject = TimetableSubject(
            id: UUID(),
            name: parsedCell.name,
            room: parsedCell.room,
            swiftUIColor: generatedColor(for: key)
        )
        subjectIDsByKey[key] = subject.id
        subjects.append(subject)
        return subject.id
    }

    private static func parseSubjectCell(from observations: [RecognizedTextBox]) -> ParsedSubjectCell? {
        let orderedLines = observations
            .sorted {
                if abs($0.rect.midY - $1.rect.midY) > 0.01 {
                    return $0.rect.midY > $1.rect.midY
                }
                return $0.rect.minX < $1.rect.minX
            }
            .flatMap { splitCellLines($0.text) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                    weekdayIndex(for: $0) == nil &&
                    extractTimeComponents(from: $0).isEmpty &&
                    !looksLikeFreeCell($0) &&
                    !isPotentialClassHeaderText($0)
            }

        guard let firstLine = orderedLines.first else {
            return nil
        }

        let subjectName = cleanedSubjectName(from: firstLine)
        guard !subjectName.isEmpty else {
            return nil
        }

        let room = orderedLines.dropFirst().joined(separator: " ").trimmedNonEmpty
            ?? AppLocalizer.localized("TBD")

        return ParsedSubjectCell(name: subjectName, room: room)
    }

    private static func classColumnIndex(
        for xValue: CGFloat,
        columns: [DailyClassColumn],
        dayBound: DayBounds
    ) -> Int? {
        for (index, column) in columns.enumerated() {
            let minX: CGFloat = if index == 0 {
                dayBound.minX
            } else {
                (columns[index - 1].centerX + column.centerX) / 2
            }

            let maxX: CGFloat = if index == columns.count - 1 {
                dayBound.maxX
            } else {
                (column.centerX + columns[index + 1].centerX) / 2
            }

            if xValue >= minX && xValue <= maxX {
                return column.orderIndex
            }
        }

        return nil
    }

    private static func combineClassHeaderLines(from cluster: [RecognizedTextBox]) -> String {
        cluster
            .sorted {
                if abs($0.rect.midY - $1.rect.midY) > 0.01 {
                    return $0.rect.midY > $1.rect.midY
                }
                return $0.rect.minX < $1.rect.minX
            }
            .flatMap { splitCellLines($0.text) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestClassLabel(from labels: [String]) -> String {
        labels
            .sorted {
                if $0.count == $1.count {
                    return $0.localizedStandardCompare($1) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmedNonEmpty ?? AppLocalizer.localized("Unknown Class")
    }

    private static func splitCellLines(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.newlines.union(.init(charactersIn: "|/")))
            .map { $0.replacingOccurrences(of: "·", with: " ") }
    }

    private static func cleanedSubjectName(from line: String) -> String {
        line
            .replacingOccurrences(of: #"^\d+\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeFreeCell(_ text: String) -> Bool {
        let normalized = normalizedToken(text)
        return [
            "free", "empty", "break", "lunch", "-", "—", "--", "休息", "空", "无", "自习"
        ].contains(normalized)
    }

    private static func isPotentialClassHeaderText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if trimmed.range(of: #"^\d{2,4}$"#, options: .regularExpression) != nil {
            return false
        }

        if weekdayIndex(for: trimmed) != nil || !extractTimeComponents(from: trimmed).isEmpty {
            return false
        }

        if trimmed.contains("班") || trimmed.contains("年级") {
            return true
        }

        if trimmed.range(of: #"^[A-Za-z0-9]{1,5}$"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private static func weekdayIndex(for text: String) -> Int? {
        let normalized = normalizedToken(text)

        if let chineseWeekday = chineseWeekdayIndex(for: normalized) {
            return chineseWeekday
        }

        let mapping: [(Int, [String])] = [
            (1, ["mon", "monday", "mon.", "周一", "星期一"]),
            (2, ["tue", "tues", "tuesday", "tue.", "周二", "星期二"]),
            (3, ["wed", "wednesday", "wed.", "周三", "星期三"]),
            (4, ["thu", "thur", "thurs", "thursday", "thu.", "周四", "星期四"]),
            (5, ["fri", "friday", "fri.", "周五", "星期五"])
        ]

        for (index, candidates) in mapping {
            if candidates.contains(where: { normalized.contains(normalizedToken($0)) }) {
                return index
            }
        }

        return nil
    }

    private static func chineseWeekdayIndex(for normalizedText: String) -> Int? {
        let candidates = [
            normalizedText,
            normalizedText.replacingOccurrences(of: "星期", with: "周"),
            normalizedText.replacingOccurrences(of: "礼拜", with: "周"),
            normalizedText.replacingOccurrences(of: "週", with: "周")
        ].uniqued()

        for candidate in candidates {
            guard candidate.contains("周") else {
                continue
            }

            let suffix = String(candidate.split(separator: "周", maxSplits: 1, omittingEmptySubsequences: false).last ?? "")
            if let mapped = weekdaySuffixIndex(for: suffix) {
                return mapped
            }
        }

        return nil
    }

    private static func weekdaySuffixIndex(for suffix: String) -> Int? {
        let cleaned = suffix
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "=", with: "")

        let mapping: [Int: [String]] = [
            1: ["一", "1", "l", "i", "|", "ー", "—", "-", "yi"],
            2: ["二", "2", "z", "er"],
            3: ["三", "3", "s", "shan", "san"],
            4: ["四", "4", "si"],
            5: ["五", "5", "w", "wu"]
        ]

        for (dayIndex, tokens) in mapping {
            if tokens.contains(where: { cleaned.contains($0) }) {
                return dayIndex
            }
        }

        return nil
    }

    private static func normalizedToken(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "：", with: "")
            .replacingOccurrences(of: "（", with: "")
            .replacingOccurrences(of: "）", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "星期", with: "周")
            .replacingOccurrences(of: "礼拜", with: "周")
            .replacingOccurrences(of: "週", with: "周")
    }

    private static func extractTimeComponents(from text: String) -> [TimeComponent] {
        let pattern = #"(?:(AM|PM)\s*)?(\d{1,2})[:：.](\d{2})(?:\s*(AM|PM))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.compactMap { match in
            guard match.numberOfRanges >= 5 else {
                return nil
            }

            let leadingMeridiem = match.range(at: 1).location != NSNotFound ? nsText.substring(with: match.range(at: 1)) : ""
            let hourString = nsText.substring(with: match.range(at: 2))
            let minuteString = nsText.substring(with: match.range(at: 3))
            let trailingMeridiem = match.range(at: 4).location != NSNotFound ? nsText.substring(with: match.range(at: 4)) : ""

            guard let hour = Int(hourString), let minute = Int(minuteString) else {
                return nil
            }

            let meridiemToken = [leadingMeridiem, trailingMeridiem]
                .first(where: { !$0.isEmpty })?
                .lowercased()

            let meridiem: TimeMeridiem = if meridiemToken == "pm" {
                .pm
            } else if meridiemToken == "am" {
                .am
            } else {
                hour >= 12 ? .pm : .am
            }

            let normalizedTime = "\(hour):" + String(format: "%02d", minute)
            let absoluteHour = if hour > 12 {
                hour
            } else if hour == 12 {
                meridiem == .am ? 0 : 12
            } else {
                meridiem == .pm ? hour + 12 : hour
            }

            return TimeComponent(
                time: normalizedTime,
                meridiem: meridiem,
                absoluteMinutes: absoluteHour * 60 + minute
            )
        }
    }

    private static func nearestIndex(for value: CGFloat, centers: [CGFloat]) -> Int? {
        guard !centers.isEmpty else {
            return nil
        }

        return centers.enumerated().min { lhs, rhs in
            abs(lhs.element - value) < abs(rhs.element - value)
        }?.offset
    }

    private static func columnTolerance(for headers: [WeekdayHeaderBox], index: Int) -> CGFloat {
        if headers.count <= 1 {
            return 0.14
        }

        let current = headers[index].rect.midX
        let neighbors = headers.enumerated().compactMap { offset, header -> CGFloat? in
            guard offset != index else { return nil }
            return abs(header.rect.midX - current)
        }
        let minDistance = neighbors.min() ?? 0.22
        return max(minDistance * 0.48, 0.08)
    }

    private static func rowTolerance(for rows: [TimeRowBox], index: Int) -> CGFloat {
        if rows.count <= 1 {
            return 0.06
        }

        let current = rows[index].centerY
        let neighbors = rows.enumerated().compactMap { offset, row -> CGFloat? in
            guard offset != index else { return nil }
            return abs(row.centerY - current)
        }
        let minDistance = neighbors.min() ?? 0.12
        return max(minDistance * 0.46, 0.04)
    }

    private static func generatedColor(for key: String) -> Color {
        let hashValue = abs(key.hashValue)
        let hue = Double(hashValue % 360) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.92)
    }
}

private struct RecognizedTextBox {
    let id: UUID
    let text: String
    let rect: CGRect
}

private struct WeekdayHeaderBox {
    let id: UUID
    let dayIndex: Int
    let title: String
    let rect: CGRect
}

private struct TimeRowBox {
    let startTime: String
    let startMeridiem: TimeMeridiem
    let endTime: String
    let endMeridiem: TimeMeridiem
    let centerY: CGFloat
    let sourceObservationIDs: [UUID]
}

private struct TimeComponent {
    let time: String
    let meridiem: TimeMeridiem
    let absoluteMinutes: Int
}

private struct ParsedSubjectCell {
    let name: String
    let room: String
}

private struct DayBounds {
    let dayIndex: Int
    let minX: CGFloat
    let maxX: CGFloat
}

private struct DailyClassColumn {
    let orderIndex: Int
    let displayName: String
    let centerX: CGFloat
    let sourceObservationIDs: [UUID]
}

private struct SimpleCellCoordinate: Hashable {
    let dayIndex: Int
    let slotIndex: Int
}

private struct MultiCellCoordinate: Hashable {
    let dayIndex: Int
    let classIndex: Int
    let slotIndex: Int
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
