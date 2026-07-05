//
//  PhoneWatchSyncManager.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/22/26.
//

import Combine
import Foundation
import SwiftData
import WatchConnectivity

enum WatchSyncMessageKey {
    static let action = "action"
    static let snapshot = "snapshot"
    static let appFontOption = "appFontOption"
    static let assignment = "assignment"
    static let assignmentID = "assignmentID"
    static let fireTimestamp = "fireTimestamp"

    static let requestSnapshot = "requestSnapshot"
    static let upsertAssignment = "upsertAssignment"
    static let deleteAssignment = "deleteAssignment"
    static let toggleAssignment = "toggleAssignment"
    static let scheduleWatchTestReminder = "scheduleWatchTestReminder"
    static let clearWatchTestReminder = "clearWatchTestReminder"
}

@MainActor
final class PhoneWatchSyncManager: NSObject, ObservableObject {
    private let modelContainer: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContainer: ModelContainer, activateSession: Bool = true) {
        self.modelContainer = modelContainer
        super.init()

        if activateSession {
            activate()
        }
    }

    func activate() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func pushLatestSnapshotIfPossible() {
        guard WCSession.isSupported(),
              let payload = encodedSnapshotPayload()
        else {
            return
        }

        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            return
        }
    }

    func scheduleWatchTestReminder(after interval: TimeInterval = 60) {
        sendWatchMessage([
            WatchSyncMessageKey.action: WatchSyncMessageKey.scheduleWatchTestReminder,
            WatchSyncMessageKey.fireTimestamp: Date().addingTimeInterval(interval).timeIntervalSince1970
        ])
    }

    func clearWatchTestReminder() {
        sendWatchMessage([
            WatchSyncMessageKey.action: WatchSyncMessageKey.clearWatchTestReminder
        ])
    }

    private func encodedSnapshotPayload() -> [String: Any]? {
        guard let data = try? encoder.encode(currentSnapshot()) else {
            return nil
        }

        return [
            WatchSyncMessageKey.snapshot: data,
            WatchSyncMessageKey.appFontOption: UserDefaults.standard.string(forKey: AppFontOption.storageKey)
                ?? AppFontOption.apple.rawValue
        ]
    }

    private func sendWatchMessage(_ payload: [String: Any]) {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func currentSnapshot() -> TimetableStoreSnapshot {
        primaryStore()?.snapshot ?? TimetableStoreSnapshot(
            updatedAt: .now,
            notificationDeliveryMode: .both,
            notificationTimeMode: .custom,
            notificationMomentMode: .custom,
            uniformNotificationMinutesBefore: 2,
            uniformNotificationMoment: .classEnds,
            subjects: [],
            slots: [],
            placements: [],
            notificationSettings: [],
            assignments: []
        )
    }

    private func primaryStore() -> TimetableStore? {
        let descriptor = FetchDescriptor<TimetableStore>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let stores = try? modelContainer.mainContext.fetch(descriptor) else {
            return nil
        }

        if let current = stores.first {
            for duplicate in stores.dropFirst() {
                modelContainer.mainContext.delete(duplicate)
            }
            return current
        }

        return nil
    }

    private func activeStore() -> TimetableStore {
        if let current = primaryStore() {
            return current
        }

        let store = TimetableStore()
        modelContainer.mainContext.insert(store)
        return store
    }

    private func handle(message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let action = message[WatchSyncMessageKey.action] as? String else {
            if let payload = encodedSnapshotPayload() {
                replyHandler?(payload)
            }
            return
        }

        switch action {
        case WatchSyncMessageKey.requestSnapshot:
            if let payload = encodedSnapshotPayload() {
                replyHandler?(payload)
            }

        case WatchSyncMessageKey.upsertAssignment:
            guard let data = message[WatchSyncMessageKey.assignment] as? Data,
                  let assignment = try? decoder.decode(TimetableAssignment.self, from: data)
            else {
                return
            }

            let store = activeStore()
            store.upsertAssignment(assignment)
            try? modelContainer.mainContext.save()
            pushLatestSnapshotIfPossible()

        case WatchSyncMessageKey.deleteAssignment:
            guard let identifier = message[WatchSyncMessageKey.assignmentID] as? String,
                  let assignmentID = UUID(uuidString: identifier)
            else {
                return
            }

            let store = activeStore()
            store.removeAssignment(assignmentID)
            try? modelContainer.mainContext.save()
            pushLatestSnapshotIfPossible()

        case WatchSyncMessageKey.toggleAssignment:
            guard let identifier = message[WatchSyncMessageKey.assignmentID] as? String,
                  let assignmentID = UUID(uuidString: identifier),
                  let assignment = activeStore().assignment(with: assignmentID)
            else {
                return
            }

            let updated = TimetableAssignment(
                id: assignment.id,
                subject: assignment.subject,
                content: assignment.content,
                startDate: assignment.startDate,
                dueDate: assignment.dueDate,
                createdAt: assignment.createdAt,
                isFinished: !assignment.isFinished
            )

            let store = activeStore()
            store.upsertAssignment(updated)
            try? modelContainer.mainContext.save()
            pushLatestSnapshotIfPossible()

        default:
            break
        }
    }
}

extension PhoneWatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.pushLatestSnapshotIfPossible()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handle(message: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handle(message: userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handle(message: message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handle(message: message, replyHandler: replyHandler)
        }
    }
}
