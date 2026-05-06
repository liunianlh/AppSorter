import SwiftUI

@main
struct AppSorterApp: App {
    @StateObject private var organizer = OrganizerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(organizer)
        }
        .defaultSize(width: 900, height: 600)
    }
}
