//
//  ClassAlarmLiveActivity.swift
//  Watch ur time Widget
//
//  Created By Ng1nx on 6/23/26.
//

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@available(iOS 26.0, *)
struct ClassAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ClassAlarmMetadata>.self) { context in
            let metadata = context.attributes.metadata

            VStack(alignment: .leading, spacing: 10) {
                Text(metadata?.eventKind == "start" ? "Class is gonna start!!!" : "Class is gonna over!!!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(metadata?.subjectName ?? "Class Reminder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(context.attributes.tintColor.opacity(0.95))
            )
            .padding(.horizontal, 8)
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let metadata = context.attributes.metadata
            let title = metadata?.subjectName ?? "Class"
            let message = metadata?.eventKind == "start" ? "Starting" : "Ending"

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(message)
                        .font(.caption.weight(.semibold))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Circle()
                        .fill(context.attributes.tintColor)
                        .frame(width: 12, height: 12)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text("⏰")
            } compactTrailing: {
                Text(message == "Starting" ? "Go" : "End")
                    .font(.caption2.weight(.bold))
            } minimal: {
                Circle()
                    .fill(context.attributes.tintColor)
                    .frame(width: 10, height: 10)
            }
        }
    }
}
