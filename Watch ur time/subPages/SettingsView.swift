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

private enum TimetableTransferAction {
    case export
    case save
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var classReminderScheduler: ClassReminderScheduler
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager
    @AppStorage("theme") private var themes: Themes = .System
    @AppStorage(AppFontOption.storageKey) private var appFontOption: AppFontOption = .apple
    @AppStorage(AppLanguage.storageKey) private var appLanguage: AppLanguage = .system
    @AppStorage("timetable_ocr_enabled") private var isTimetableOCREnabled = false
    @AppStorage("disable_all_restrictions") private var isRestrictionsDisabled = false
    @AppStorage(AppHaptics.enabledKey) private var isGlobalHapticsEnabled = true
    @AppStorage(AppHapticStrength.storageKey) private var globalHapticStrength: AppHapticStrength = .medium
    @AppStorage("debug_unlocked") private var isDebugUnlocked = false
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var transferDocument = TimetableTransferDocument()
    @State private var transferFilename = "Timetable"
    @State private var transferMessage: String?
    @State private var pendingTransferAction: TimetableTransferAction = .export
    @State private var debugUnlockInput = ""
    @State private var uniformNotificationAdvanceTime = 2
    @State private var uniformNotificationMoment = NotificationMoment.classEnds
    @State private var isShowingNewTimetableConfirmation = false

    private let uniformAdvanceOptions = Array(0...60)

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(
                    selection: $themes,
                    label: settingsLabel("Appearance", systemImage: "circle.lefthalf.filled")
                ) {
                    Text("I Don't Care Just Follow System").tag(Themes.System)
                    Text("Lights On!").tag(Themes.Light)
                    Text("Lights Off!").tag(Themes.Dark)
                }
            }

            Section("Do Something") {
                Button {
                    prepareExport()
                } label: {
                    settingsLabel("Export Timetable", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImporting = true
                } label: {
                    settingsLabel("Import Timetable", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    isShowingNewTimetableConfirmation = true
                } label: {
                    settingsLabel("New Timetable", systemImage: "plus.rectangle.on.folder")
                }

                Button {
                    saveCurrentTimetable()
                } label: {
                    settingsLabel("Save", systemImage: "externaldrive.badge.checkmark")
                }
            }

            Section("Haptics and Sound") {
                Toggle(isOn: $isGlobalHapticsEnabled) {
                    settingsLabel("Haptic Feedback", systemImage: "waveform.path")
                }

                Picker(
                    selection: $globalHapticStrength,
                    label: settingsLabel("Haptic Strength", systemImage: "dot.radiowaves.left.and.right")
                ) {
                    ForEach(AppHapticStrength.allCases) { strength in
                        Text(strength.title).tag(strength)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!isGlobalHapticsEnabled)
            }

            Section("Notification") {
                Picker(
                    selection: notificationDeliveryModeBinding,
                    label: settingsLabel("Notify By", systemImage: "bell.badge")
                ) {
                    ForEach(NotificationDeliveryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Picker(
                    selection: notificationMomentModeBinding,
                    label: settingsLabel("Notify Moment Using", systemImage: "clock.badge")
                ) {
                    ForEach(NotificationMomentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Picker(
                    selection: notificationTimeModeBinding,
                    label: settingsLabel("Notify Time Using", systemImage: "timer")
                ) {
                    ForEach(NotificationTimeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if effectiveNotificationMomentMode == .uniform {
                    Picker(
                        selection: uniformNotificationMomentBinding,
                        label: settingsLabel("Uniform Notify Moment", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    ) {
                        ForEach(NotificationMoment.allCases) { moment in
                            Text(moment.title).tag(moment)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if effectiveNotificationTimeMode == .uniform {
                    Picker(
                        selection: uniformNotificationAdvanceTimeBinding,
                        label: settingsLabel("Uniform Notify Time", systemImage: "hourglass")
                    ) {
                        ForEach(uniformAdvanceOptions, id: \.self) { minute in
                            Text(minute == 0 ? "On time" : "\(minute) mins")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
            }

            Section("Watch ur Time :: Time++") {
                Picker(
                    selection: $appFontOption,
                    label: settingsLabel("Font", systemImage: "textformat")
                ) {
                    ForEach(AppFontOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if !AppFontCatalog.isJetBrainsMonoAvailable {
                    Text("JetBrains Mono is bundled but not active yet. Rebuild and relaunch the app once.")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker(
                    selection: $appLanguage,
                    label: settingsLabel("Language", systemImage: "globe")
                ) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: timetableOCRBinding) {
                    settingsLabel("Timetable OCR Import", systemImage: "text.viewfinder")
                }
                    .disabled(!isRestrictionsDisabled)
            }

            if isDebugUnlocked {
                Section("Debug") {
                    HStack {
                        labelText("Alarm Permission", systemImage: "alarm")
                        Spacer()
                        Text(classReminderScheduler.alarmAuthorizationDebugText())
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        Task {
                            let phoneResult = await classReminderScheduler.clearDebugAlarm()
                            watchSyncManager.clearWatchTestReminder()
                            transferMessage = "\(phoneResult)\n\(AppLocalizer.localized("Watch test reminder clear requested."))"
                        }
                    } label: {
                        settingsLabel("Clear Test Alarm", systemImage: "alarm.waves.left.and.right")
                    }

                    Toggle(isOn: $isRestrictionsDisabled) {
                        settingsLabel("Disable all restrictions", systemImage: "lock.open")
                    }

                    Button {
                        classReminderScheduler.openAppSettings()
                    } label: {
                        settingsLabel("Open App Settings", systemImage: "gearshape")
                    }

                    Button {
                        Task {
                            transferMessage = await classReminderScheduler.requestAlarmAuthorizationDebug()
                        }
                    } label: {
                        settingsLabel("Request Alarm Permission", systemImage: "checkmark.shield")
                    }

                    Button {
                        Task {
                            let phoneResult = await classReminderScheduler.scheduleDebugAlarm()
                            watchSyncManager.scheduleWatchTestReminder()
                            transferMessage = "\(phoneResult)\n\(AppLocalizer.localized("Watch test reminder requested."))"
                        }
                    } label: {
                        settingsLabel("Schedule Test Alarm In 1 Min", systemImage: "plus.badge.clock")
                    }

                    Button {
                        transferMessage = classReminderScheduler.dumpAlarmAuthorizationDebug()
                    } label: {
                        settingsLabel("Show Alarm Auth Status", systemImage: "info.circle")
                    }

                    Button {
                        transferMessage = classReminderScheduler.alarmRuntimeDiagnosticReport()
                    } label: {
                        settingsLabel("Show Alarm Runtime Details", systemImage: "waveform.badge.magnifyingglass")
                    }
                }
            } else {
                Section("Who Are You!") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        TextField("Say something", text: $debugUnlockInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        unlockDebugIfNeeded()
                    } label: {
                        settingsLabel("Submit", systemImage: "paperplane")
                    }
                }
            }

            Section("About") {
                HStack {
                    labelText("App Name", systemImage: "app.badge")
                    Spacer()
                    Text("Watch Ur Time")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    labelText("Version", systemImage: "number")
                    Spacer()
                    Text(appVersionDisplayText)
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
        .confirmationDialog(
            "Create a new empty timetable?",
            isPresented: $isShowingNewTimetableConfirmation,
            titleVisibility: .visible
        ) {
            Button("New Timetable", role: .destructive) {
                createNewTimetable()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears the current timetable, notifications, and assignments.")
        }
        .alert("Timetable Transfer", isPresented: transferMessageBinding) {
            Button("OK", role: .cancel) {
                transferMessage = nil
            }
        } message: {
            Text(transferMessage ?? "")
        }
        .onChange(of: isRestrictionsDisabled) { _, isDisabled in
            if !isDisabled {
                isTimetableOCREnabled = false
            }
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

    private var timetableOCRBinding: Binding<Bool> {
        Binding(
            get: {
                isRestrictionsDisabled ? isTimetableOCREnabled : false
            },
            set: { newValue in
                guard isRestrictionsDisabled else {
                    isTimetableOCREnabled = false
                    return
                }
                isTimetableOCREnabled = newValue
            }
        )
    }

    private func prepareExport() {
        pendingTransferAction = .export
        transferDocument = TimetableTransferDocument(data: makeArchiveData())
        transferFilename = "Timetable-\(exportDateStamp).ttb"
        isExporting = true
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            persistExportLocation(url)
            switch pendingTransferAction {
            case .export:
                transferMessage = AppLocalizer.localized("Exported timetable successfully.")
            case .save:
                transferMessage = AppLocalizer.localized("Saved timetable successfully.")
            }
        case .failure(let error):
            switch pendingTransferAction {
            case .export:
                transferMessage = AppLocalizer.format("Export failed: %@", error.localizedDescription)
            case .save:
                transferMessage = AppLocalizer.format("Save failed: %@", error.localizedDescription)
            }
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
                let importedStore = try importArchive(archive)
                persistExportLocation(url, for: importedStore)
                transferMessage = AppLocalizer.localized("Imported timetable successfully.")
            } catch {
                transferMessage = AppLocalizer.format("Import failed: %@", error.localizedDescription)
            }
        case .failure(let error):
            transferMessage = AppLocalizer.format("Import failed: %@", error.localizedDescription)
        }
    }

    @discardableResult
    private func importArchive(_ archive: TimetableArchive) throws -> TimetableStore {
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
        return targetStore
    }

    private func saveCurrentTimetable() {
        guard let store = currentStoreForMutation() else {
            return
        }

        if let destinationURL = resolvedExportURL(for: store) {
            do {
                let didAccess = destinationURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        destinationURL.stopAccessingSecurityScopedResource()
                    }
                }
                try makeArchiveData().write(to: destinationURL, options: .atomic)
                persistExportLocation(destinationURL, for: store)
                transferMessage = AppLocalizer.localized("Saved timetable successfully.")
            } catch {
                pendingTransferAction = .save
                transferDocument = TimetableTransferDocument(data: makeArchiveData())
                transferFilename = destinationURL.deletingPathExtension().lastPathComponent
                isExporting = true
            }
        } else {
            pendingTransferAction = .save
            transferDocument = TimetableTransferDocument(data: makeArchiveData())
            transferFilename = "Timetable-\(exportDateStamp).ttb"
            isExporting = true
        }
    }

    private func createNewTimetable() {
        let targetStore = currentStoreForMutation() ?? TimetableStore()

        if stores.isEmpty {
            modelContext.insert(targetStore)
        }

        targetStore.apply(snapshot: .empty)
        targetStore.updatedAt = .now
        targetStore.exportBookmarkPayload = nil
        NotificationDeliveryMode.both.persistToDefaults()

        for duplicate in stores.dropFirst() {
            modelContext.delete(duplicate)
        }

        do {
            try modelContext.save()
            watchSyncManager.pushLatestSnapshotIfPossible()
            Task {
                await classReminderScheduler.sync(with: targetStore.snapshot)
            }
            transferMessage = AppLocalizer.localized("Created a new empty timetable.")
        } catch {
            transferMessage = AppLocalizer.format("Unable to save timetable: %@", error.localizedDescription)
        }
    }

    private func currentStoreForMutation() -> TimetableStore? {
        if let store = stores.first {
            return store
        }

        let newStore = TimetableStore()
        modelContext.insert(newStore)
        return newStore
    }

    private func makeArchiveData() -> Data {
        let archive = TimetableArchive(store: stores.first?.snapshot ?? .empty)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(archive)) ?? Data()
    }

    private func persistExportLocation(_ url: URL, for store: TimetableStore? = nil) {
        guard let store = store ?? stores.first else {
            return
        }

        do {
            store.exportBookmarkPayload = try url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            try modelContext.save()
        } catch {
            transferMessage = AppLocalizer.format("Save failed: %@", error.localizedDescription)
        }
    }

    private func resolvedExportURL(for store: TimetableStore) -> URL? {
        guard let bookmarkData = store.exportBookmarkPayload else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            persistExportLocation(url, for: store)
        }

        return url
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

    private var notificationMomentModeBinding: Binding<NotificationMomentMode> {
        Binding(
            get: {
                stores.first?.notificationMomentMode ?? .custom
            },
            set: { newValue in
                let targetStore = stores.first ?? TimetableStore()

                if stores.isEmpty {
                    modelContext.insert(targetStore)
                }

                targetStore.notificationMomentMode = newValue
                try? modelContext.save()
                watchSyncManager.pushLatestSnapshotIfPossible()

                Task {
                    await classReminderScheduler.sync(with: targetStore.snapshot)
                }
            }
        )
    }

    private var uniformNotificationMomentBinding: Binding<NotificationMoment> {
        Binding(
            get: {
                stores.first?.uniformNotificationMoment ?? .classEnds
            },
            set: { newValue in
                let targetStore = stores.first ?? TimetableStore()

                if stores.isEmpty {
                    modelContext.insert(targetStore)
                }

                targetStore.uniformNotificationMoment = newValue
                uniformNotificationMoment = newValue
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

    private var effectiveNotificationMomentMode: NotificationMomentMode {
        stores.first?.notificationMomentMode ?? .custom
    }

    private func unlockDebugIfNeeded() {
        guard debugUnlockInput.trimmingCharacters(in: .whitespacesAndNewlines) == "iamng1nx" else {
            transferMessage = AppLocalizer.localized("Wrong answer.")
            return
        }

        isDebugUnlocked = true
        debugUnlockInput = ""
    }

    private var appVersionDisplayText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return "Unknown"
        }
    }

    @ViewBuilder
    private func settingsLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func labelText(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ClassReminderScheduler())
        .environmentObject(PhoneWatchSyncManager(modelContainer: try! ModelContainer(for: TimetableStore.self), activateSession: false))
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
