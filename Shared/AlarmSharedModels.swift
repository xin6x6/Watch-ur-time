//
//  AlarmSharedModels.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/23/26.
//

import AlarmKit
import Foundation

@available(iOS 26.0, *)
struct ClassAlarmMetadata: AlarmMetadata, Codable, Hashable {
    var subjectName: String
    var eventKind: String
    var placementID: UUID
}
