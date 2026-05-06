import AppKit
import Foundation

enum AppScanner {
    private static let applicationDirs: [URL] = {
        var urls: [URL] = []
        if let u = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first {
            urls.append(u)
        }
        if let u = try? FileManager.default.url(
            for: .applicationDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            urls.append(u)
        }
        return urls
    }()

    static func scanInstalledApps() -> [InstalledApp] {
        var byId: [String: InstalledApp] = [:]
        let fm = FileManager.default

        for root in applicationDirs {
            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir, url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url) else { continue }
                let bid = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
                let name =
                    bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let app = InstalledApp(bundleId: bid, name: name, url: url)
                if let existing = byId[bid] {
                    if app.url.path.count < existing.url.path.count {
                        byId[bid] = app
                    }
                } else {
                    byId[bid] = app
                }
            }
        }

        return byId.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func openApp(at url: URL) {
        NSWorkspace.shared.open(url)
    }
}
