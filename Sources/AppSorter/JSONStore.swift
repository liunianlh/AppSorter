import Foundation

enum JSONStore {
    private static let fileName = "library.json"

    private static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("AppSorter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var fileURL: URL {
        supportDirectory.appendingPathComponent(fileName)
    }

    static func load() -> AppDatabase {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppDatabase.self, from: data)
        } catch {
            return .empty
        }
    }

    static func save(_ database: AppDatabase) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(database)
        try data.write(to: fileURL, options: [.atomic])
    }
}
