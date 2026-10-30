import SwiftUI

@main
struct RTVSlovenijaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(RTVClient.shared)
        }
    }
}
