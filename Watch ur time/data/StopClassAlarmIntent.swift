//
//  StopClassAlarmIntent.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/23/26.
//

import AlarmKit
import AppIntents
import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct StopClassAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Class Alarm"

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() { }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        guard let identifier = UUID(uuidString: alarmID) else {
            return .result()
        }

        try? AlarmManager.shared.stop(id: identifier)
        try? AlarmManager.shared.cancel(id: identifier)
        return .result()
    }
}
