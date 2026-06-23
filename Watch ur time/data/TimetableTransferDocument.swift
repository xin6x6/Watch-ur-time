//
//  TimetableTransferDocument.swift
//  Watch ur time
//
//  Created By Ng1nx on 6/20/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let timetableBundle = UTType(exportedAs: "com.watchurtime.timetable", conformingTo: .json)
}

struct TimetableTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.timetableBundle, .json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}
