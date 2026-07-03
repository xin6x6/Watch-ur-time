//
//  SettingsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum Themes: String, CaseIterable {
    case Light = "Light"
    case Dark = "Dark"
    case System = "System"
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var classReminderScheduler: ClassReminderScheduler
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager
    @AppStorage("theme") private var themes: Themes = .System
    @AppStorage(AppFontOption.storageKey) private var appFontOption: AppFontOption = .apple
    @AppStorage(AppLanguage.storageKey) private var appLanguage: AppLanguage = .system
    @AppStorage("debug_unlocked") private var isDebugUnlocked = false
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var transferDocument = TimetableTransferDocument()
    @State private var transferFilename = "Timetable"
    @State private var transferMessage: String?
    @State private var debugUnlockInput = ""
    @State private var uniformNotificationAdvanceTime = 2

    private let uniformAdvanceOptions = Array(0...60)

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $themes) {
                    Text("I Don't Care Just Follow System").tag(Themes.System)
                    Text("Lights On!").tag(Themes.Light)
                    Text("Lights Off!").tag(Themes.Dark)
                }
            }

            Section("Notification") {
                Picker("Notify By", selection: notificationDeliveryModeBinding) {
                    ForEach(NotificationDeliveryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Picker("Notify Time Using", selection: notificationTimeModeBinding) {
                    ForEach(NotificationTimeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if effectiveNotificationTimeMode == .uniform {
                    Picker("Uniform Notify Time", selection: uniformNotificationAdvanceTimeBinding) {
                        ForEach(uniformAdvanceOptions, id: \.self) { minute in
                            Text(minute == 0 ? "On time" : "\(minute) mins")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
            }

            Section("Do Something") {
                Button("Export Timetable") {
                    prepareExport()
                }

                Button("Import Timetable") {
                    isImporting = true
                }
            }

            Section("Watch ur Time :: Time++") {
                Picker("Font", selection: $appFontOption) {
                    ForEach(AppFontOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if !AppFontCatalog.isJetBrainsMonoAvailable {
                    Text("JetBrains Mono is bundled but not active yet. Rebuild and relaunch the app once.")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if isDebugUnlocked {
                Section("Debug") {
                    HStack {
                        Text("Alarm Permission")
                        Spacer()
                        Text(classReminderScheduler.alarmAuthorizationDebugText())
                            .foregroundStyle(.secondary)
                    }

                    Button("Request Alarm Permission") {
                        Task {
                            transferMessage = await classReminderScheduler.requestAlarmAuthorizationDebug()
                        }
                    }

                    Button("Show Alarm Auth Status") {
                        transferMessage = classReminderScheduler.dumpAlarmAuthorizationDebug()
                    }

                    Button("Show Alarm Runtime Details") {
                        transferMessage = classReminderScheduler.alarmRuntimeDiagnosticReport()
                    }

                    Button("Schedule Test Alarm In 1 Min") {
                        Task {
                            let phoneResult = await classReminderScheduler.scheduleDebugAlarm()
                            watchSyncManager.scheduleWatchTestReminder()
                            transferMessage = "\(phoneResult)\n\(AppLocalizer.localized("Watch test reminder requested."))"
                        }
                    }

                    Button("Clear Test Alarm", role: .destructive) {
                        Task {
                            let phoneResult = await classReminderScheduler.clearDebugAlarm()
                            watchSyncManager.clearWatchTestReminder()
                            transferMessage = "\(phoneResult)\n\(AppLocalizer.localized("Watch test reminder clear requested."))"
                        }
                    }

                    Button("Open App Settings") {
                        classReminderScheduler.openAppSettings()
                    }
                }
            } else {
                Section("Who Are You!") {
                    TextField("Say something", text: $debugUnlockInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Submit") {
                        unlockDebugIfNeeded()
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Watch Ur Time")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text("Dev 0.67")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appDefaultFont()
        .fileExporter(
            isPresented: $isExporting,
            document: transferDocument,
            contentType: .timetableBundle,
            defaultFilename: transferFilename
        ) { result in
            handleExport(result)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.data, .json]
        ) { result in
            handleImport(result)
        }
        .alert("Timetable Transfer", isPresented: transferMessageBinding) {
            Button("OK", role: .cancel) {
                transferMessage = nil
            }
        } message: {
            Text(transferMessage ?? "")
        }
    }

    private var transferMessageBinding: Binding<Bool> {
        Binding(
            get: { transferMessage != nil },
            set: { isPresented in
                if !isPresented {
                    transferMessage = nil
                }
            }
        )
    }

    private func prepareExport() {
        let archive = TimetableArchive(store: stores.first?.snapshot ?? .empty)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(archive)) ?? Data()
        transferDocument = TimetableTransferDocument(data: data)
        transferFilename = "Timetable-\(exportDateStamp).ttb"
        isExporting = true
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            transferMessage = AppLocalizer.localized("Exported timetable successfully.")
        case .failure(let error):
            transferMessage = AppLocalizer.format("Export failed: %@", error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let archive = try decoder.decode(TimetableArchive.self, from: data)
                try importArchive(archive)
                transferMessage = AppLocalizer.localized("Imported timetable successfully.")
            } catch {
                transferMessage = AppLocalizer.format("Import failed: %@", error.localizedDescription)
            }
        case .failure(let error):
            transferMessage = AppLocalizer.format("Import failed: %@", error.localizedDescription)
        }
    }

    private func importArchive(_ archive: TimetableArchive) throws {
        let targetStore = stores.first ?? TimetableStore()

        if stores.isEmpty {
            modelContext.insert(targetStore)
        }

        targetStore.apply(snapshot: archive.store)
        archive.store.notificationDeliveryMode.persistToDefaults()

        for duplicate in stores.dropFirst() {
            modelContext.delete(duplicate)
        }

        try modelContext.save()
        watchSyncManager.pushLatestSnapshotIfPossible()
        Task {
            await classReminderScheduler.sync(with: targetStore.snapshot)
        }
    }

    private var exportDateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private var notificationDeliveryModeBinding: Binding<NotificationDeliveryMode> {
        Binding(
            get: {
                stores.first?.notificationDeliveryMode ?? NotificationDeliveryMode.loadFromDefaults()
            },
            set: { newValue in
                let targetStore = stores.first ?? TimetableStore()

                if stores.isEmpty {
                    modelContext.insert(targetStore)
                }

                targetStore.notificationDeliveryMode = newValue
                newValue.persistToDefaults()
                try? modelContext.save()
                watchSyncManager.pushLatestSnapshotIfPossible()

                Task {
                    await classReminderScheduler.sync(with: targetStore.snapshot)
                }
            }
        )
    }

    private var notificationTimeModeBinding: Binding<NotificationTimeMode> {
        Binding(
            get: {
                stores.first?.notificationTimeMode ?? .custom
            },
            set: { newValue in
                let targetStore = stores.first ?? TimetableStore()

                if stores.isEmpty {
                    modelContext.insert(targetStore)
                }

                targetStore.notificationTimeMode = newValue
                try? modelContext.save()
                watchSyncManager.pushLatestSnapshotIfPossible()

                Task {
                    await classReminderScheduler.sync(with: targetStore.snapshot)
                }
            }
        )
    }

    private var uniformNotificationAdvanceTimeBinding: Binding<Int> {
        Binding(
            get: {
                stores.first?.clampedUniformNotificationMinutesBefore ?? 2
            },
            set: { newValue in
                let targetStore = stores.first ?? TimetableStore()

                if stores.isEmpty {
                    modelContext.insert(targetStore)
                }

                targetStore.clampedUniformNotificationMinutesBefore = newValue
                uniformNotificationAdvanceTime = newValue
                try? modelContext.save()
                watchSyncManager.pushLatestSnapshotIfPossible()

                Task {
                    await classReminderScheduler.sync(with: targetStore.snapshot)
                }
            }
        )
    }

    private var effectiveNotificationTimeMode: NotificationTimeMode {
        stores.first?.notificationTimeMode ?? .custom
    }

    private func unlockDebugIfNeeded() {
        guard debugUnlockInput.trimmingCharacters(in: .whitespacesAndNewlines) == "iamng1nx" else {
            transferMessage = AppLocalizer.localized("Wrong answer.")
            return
        }

        isDebugUnlocked = true
        debugUnlockInput = ""
    }
}

#Preview {
    SettingsView()
        .environmentObject(ClassReminderScheduler())
        .environmentObject(PhoneWatchSyncManager(modelContainer: try! ModelContainer(for: TimetableStore.self), activateSession: false))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
