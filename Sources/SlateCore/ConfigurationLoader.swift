import Foundation

public struct ConfigurationLoader: Sendable {
    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
    }

    public func load(data: Data) throws -> AppConfiguration {
        let configuration = try decoder.decode(AppConfiguration.self, from: data)
        try configuration.validate()
        return configuration
    }

    public func load(fileURL: URL) throws -> AppConfiguration {
        try load(data: Data(contentsOf: fileURL))
    }
}
