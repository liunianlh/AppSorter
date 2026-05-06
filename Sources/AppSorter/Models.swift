import Foundation

struct CategoryRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var bundleIds: [String]
}

struct AppDatabase: Codable {
    var categories: [CategoryRecord]

    static let empty = AppDatabase(categories: [])
}

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleId }
    var bundleId: String
    var name: String
    var url: URL
}
