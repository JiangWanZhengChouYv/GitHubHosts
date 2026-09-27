import SwiftUI

@main
struct GitHubHostsApp: App {

    @StateObject private var store = HostsStore()

    var body: some Scene {
        Window("GitHubHosts", id: "main") {
            ContentView()
                .environmentObject(store)
        }

        MenuBarExtra("GitHubHosts", systemImage: "bolt.horizontal.circle") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.menu)
    }
}
