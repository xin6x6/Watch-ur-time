//
//  Watch_ur_time_WidgetBundle.swift
//  Watch ur time Widget
//
//  Created By Ng1nx on 6/23/26.
//

import SwiftUI
import WidgetKit

@main
struct Watch_ur_time_WidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        CurrentClassWidget()

        if #available(iOSApplicationExtension 26.0, *) {
            ClassAlarmLiveActivity()
        }
    }
}
