import AppKit
import Foundation
import SwiftUI

@MainActor
final class OrganizerViewModel: ObservableObject {
    @Published private(set) var database: AppDatabase
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published var selectedCategoryId: UUID?
    @Published var searchText: String = ""

    private var saveTask: Task<Void, Never>?

    init() {
        database = JSONStore.load()
        if database.categories.isEmpty {
            let work = CategoryRecord(id: UUID(), name: "常用", sortOrder: 0, bundleIds: [])
            let dev = CategoryRecord(id: UUID(), name: "开发", sortOrder: 1, bundleIds: [])
            database = AppDatabase(categories: [work, dev])
            persistSoon()
        }
        selectedCategoryId = database.categories.sorted { $0.sortOrder < $1.sortOrder }.first?.id
        refreshInstalledApps()
    }

    func refreshInstalledApps() {
        installedApps = AppScanner.scanInstalledApps()
    }

    var sortedCategories: [CategoryRecord] {
        database.categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    func categoryBinding(for id: UUID) -> CategoryRecord? {
        database.categories.first { $0.id == id }
    }

    func addCategory(name: String) {
        let next = (database.categories.map(\.sortOrder).max() ?? -1) + 1
        let record = CategoryRecord(id: UUID(), name: name, sortOrder: next, bundleIds: [])
        database = AppDatabase(categories: database.categories + [record])
        selectedCategoryId = record.id
        persistSoon()
    }

    func renameCategory(id: UUID, to name: String) {
        guard let i = database.categories.firstIndex(where: { $0.id == id }) else { return }
        var categories = database.categories
        categories[i].name = name
        database = AppDatabase(categories: categories)
        persistSoon()
    }

    func deleteCategory(id: UUID) {
        let remaining = database.categories.filter { $0.id != id }
        database = AppDatabase(categories: remaining)
        if selectedCategoryId == id {
            selectedCategoryId = sortedCategories.first?.id
        }
        normalizeSortOrder()
        persistSoon()
    }

    func deleteAllCategories() {
        database = .empty
        selectedCategoryId = nil
        persistSoon()
    }

    func moveCategory(draggedId: UUID, to targetId: UUID) {
        guard draggedId != targetId else { return }
        var ordered = sortedCategories
        guard
            let from = ordered.firstIndex(where: { $0.id == draggedId }),
            let to = ordered.firstIndex(where: { $0.id == targetId })
        else { return }

        let moved = ordered.remove(at: from)
        ordered.insert(moved, at: to)
        database = AppDatabase(categories: ordered.enumerated().map { index, category in
            var updated = category
            updated.sortOrder = index
            return updated
        })
        persistSoon()
    }

    func addApp(bundleId: String, to categoryId: UUID) {
        guard let i = database.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        var categories = database.categories
        var ids = categories[i].bundleIds
        guard !ids.contains(bundleId) else { return }
        ids.append(bundleId)
        categories[i].bundleIds = ids
        database = AppDatabase(categories: categories)
        persistSoon()
    }

    func removeApp(bundleId: String, from categoryId: UUID) {
        guard let i = database.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        var categories = database.categories
        categories[i].bundleIds.removeAll { $0 == bundleId }
        database = AppDatabase(categories: categories)
        persistSoon()
    }

    func installedApp(for bundleId: String) -> InstalledApp? {
        installedApps.first { $0.bundleId == bundleId }
    }

    var allAssignedBundleIds: Set<String> {
        Set(database.categories.flatMap(\.bundleIds))
    }

    var addableApps: [InstalledApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = installedApps.filter { !allAssignedBundleIds.contains($0.bundleId) }
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.bundleId.localizedCaseInsensitiveContains(q)
        }
    }

    func apps(in categoryId: UUID) -> [InstalledApp] {
        guard let cat = database.categories.first(where: { $0.id == categoryId }) else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var rows: [InstalledApp] = []
        for bid in cat.bundleIds {
            if let app = installedApp(for: bid) {
                rows.append(app)
            }
        }
        if q.isEmpty { return rows }
        return rows.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.bundleId.localizedCaseInsensitiveContains(q)
        }
    }

    func open(_ app: InstalledApp) {
        AppScanner.openApp(at: app.url)
    }

    @discardableResult
    func autoOrganizeApps() -> (newCategories: Int, organizedApps: Int) {
        if installedApps.isEmpty {
            refreshInstalledApps()
        }

        var categories = database.categories
        var newCategoriesCount = 0
        var organizedCount = 0

        let allBundleIds = Set(installedApps.map(\.bundleId))
        for idx in categories.indices {
            categories[idx].bundleIds.removeAll { !allBundleIds.contains($0) }
        }

        for app in installedApps {
            if categoryId(containing: app.bundleId, categories: categories) != nil {
                continue
            }
            let categoryName = classify(app: app)
            let targetIndex: Int
            if let existing = categories.firstIndex(where: { $0.name == categoryName }) {
                targetIndex = existing
            } else {
                let nextOrder = categories.count
                categories.append(
                    CategoryRecord(id: UUID(), name: categoryName, sortOrder: nextOrder, bundleIds: [])
                )
                targetIndex = categories.count - 1
                newCategoriesCount += 1
            }
            categories[targetIndex].bundleIds.append(app.bundleId)
            organizedCount += 1
        }

        database = AppDatabase(categories: categories)
        normalizeSortOrder()
        persistSoon()
        return (newCategoriesCount, organizedCount)
    }

    private func categoryId(containing bundleId: String, categories: [CategoryRecord]) -> UUID? {
        categories.first(where: { $0.bundleIds.contains(bundleId) })?.id
    }

    private func normalizeSortOrder() {
        let normalized = sortedCategories.enumerated().map { index, category in
            var updated = category
            updated.sortOrder = index
            return updated
        }
        database = AppDatabase(categories: normalized)
    }

    private func classify(app: InstalledApp) -> String {
        let key = "\(app.name) \(app.bundleId)".lowercased()

        if containsAny(key, ["xcode", "android studio", "code", "terminal", "iterm", "warp", "postman", "docker", "github desktop", "sourcetree", "insomnia", "cursor", "pycharm", "idea", "clion", "goland"]) {
            return "开发"
        }
        if containsAny(key, ["safari", "chrome", "edge", "firefox", "arc", "browser", "opera"]) {
            return "浏览器"
        }
        if containsAny(key, ["wechat", "qq", "telegram", "discord", "slack", "teams", "feishu", "ding", "line", "message", "mail", "outlook", "zoom"]) {
            return "沟通"
        }
        if containsAny(key, ["word", "excel", "powerpoint", "wps", "note", "notion", "obsidian", "reminder", "calendar", "office", "pages", "numbers", "keynote"]) {
            return "办公"
        }
        if containsAny(key, ["figma", "photoshop", "illustrator", "sketch", "canva", "pixelmator", "davinci", "premiere", "final cut", "lightroom"]) {
            return "设计"
        }
        if containsAny(key, ["music", "spotify", "netease", "qqmusic", "video", "vlc", "iina", "bilibili", "tencentvideo", "youku", "netflix", "steam"]) {
            return "娱乐"
        }
        if containsAny(key, ["finder", "system", "setting", "monitor", "utility", "disk", "preview", "calculator", "screenshot"]) {
            return "系统工具"
        }
        return "其他"
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }

    private func persistSoon() {
        saveTask?.cancel()
        let snapshot = database
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            try? JSONStore.save(snapshot)
        }
    }
}
