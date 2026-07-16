import Foundation
import SlateCore

struct ConfigurationStore {
    let fileURL: URL

    init(fileManager: FileManager = .default, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        if let configuredPath = environment["SLATE_CONFIG"], !configuredPath.isEmpty {
            fileURL = URL(fileURLWithPath: configuredPath).standardizedFileURL
            return
        }

        fileURL = fileManager.homeDirectoryForCurrentUser.appending(path: "slate.json")
    }

    func loadOrCreateDefault(fileManager: FileManager = .default) throws -> AppConfiguration {
        if !fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(DefaultConfiguration.value).write(to: fileURL, options: .atomic)
        }
        return try ConfigurationLoader().load(fileURL: fileURL)
    }
}
