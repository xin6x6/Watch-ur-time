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
    @AppStorage("theme") private var themes: Themes = .System
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var transferDocument = TimetableTransferDocument()
    @State private var transferFilename = "Timetable"
    @State private var transferMessage: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $themes) {
                    Text("I Don't Care Just Follow System").tag(Themes.System)
                    Text("Lights On!").tag(Themes.Light)
                    Text("Lights Off!").tag(Themes.Dark)
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
        .preferredColorScheme(preferredScheme)
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

    private var preferredScheme: ColorScheme? {
        switch themes {
        case .Dark:
            return .dark
        case .Light:
            return .light
        case .System:
            return nil
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
            transferMessage = "Exported timetable successfully."
        case .failure(let error):
            transferMessage = "Export failed: \(error.localizedDescription)"
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
                transferMessage = "Imported timetable successfully."
            } catch {
                transferMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            transferMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func importArchive(_ archive: TimetableArchive) throws {
        let targetStore = stores.first ?? TimetableStore()

        if stores.isEmpty {
            modelContext.insert(targetStore)
        }

        targetStore.apply(snapshot: archive.store)

        for duplicate in stores.dropFirst() {
            modelContext.delete(duplicate)
        }

        try modelContext.save()
    }

    private var exportDateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}

private extension TimetableStoreSnapshot {
    static let empty = TimetableStoreSnapshot(
        updatedAt: .now,
        subjects: [],
        slots: [],
        placements: [],
        notificationSettings: [],
        assignments: []
    )
}

#Preview {
    SettingsView()
        .modelContainer(for: [TimetableStore.self], inMemory: true)
}
