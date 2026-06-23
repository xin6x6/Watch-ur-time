//
//  WidgetSnapshotStore.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/23/26.
//

import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotStore {
    static let shared = WidgetSnapshotStore()

    private let defaults = UserDefaults(suiteName: WidgetSharedContainer.appGroupID) ?? .standard
    private let encoder = JSONEncoder()

    private init() { }

    func update(with snapshot: TimetableStoreSnapshot) {
        let payload = buildPayload(from: snapshot)
        guard let data = try? encoder.encode(payload) else {
            return
        }

        defaults.set(data, forKey: WidgetSharedContainer.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func buildPayload(from snapshot: TimetableStoreSnapshot) -> WidgetSnapshotPayload {
        let subjectsByID = Dictionary(uniqueKeysWithValues: snapshot.subjects.map { ($0.id, $0) })

        let items = snapshot.placements.compactMap { placement -> WidgetClassSnapshot? in
            guard (1...5).contains(placement.dayIndex),
                  snapshot.slots.indices.contains(placement.slotIndex),
                  let subject = subjectsByID[placement.subjectID]
            else {
                return nil
            }

            let slot = snapshot.slots[placement.slotIndex]
            guard let startMinutes = slot.startMinutesSinceMidnight,
                  let endMinutes = slot.endMinutesSinceMidnight
            else {
                return nil
            }

            return WidgetClassSnapshot(
                id: placement.id,
                dayIndex: placement.dayIndex,
                subjectName: subject.name,
                room: subject.room,
                startLabel: slot.formattedStartTime,
                endLabel: slot.formattedEndTime,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                red: subject.red,
                green: subject.green,
                blue: subject.blue,
                alpha: subject.alpha
            )
        }
        .sorted {
            if $0.dayIndex == $1.dayIndex {
                return $0.startMinutes < $1.startMinutes
            }
            return $0.dayIndex < $1.dayIndex
        }

        return WidgetSnapshotPayload(updatedAt: snapshot.updatedAt, classes: items)
    }
}
