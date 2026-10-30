import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            KidsView()
                .tabItem { Label("Risanke", systemImage: "face.smiling") }
            LiveView()
                .tabItem { Label("V živo", systemImage: "dot.radiowaves.left.and.right") }
            NewestView()
                .tabItem { Label("Najnovejše", systemImage: "clock") }
            ShowsView()
                .tabItem { Label("Oddaje", systemImage: "square.grid.2x2") }
            SearchView()
                .tabItem { Label("Iskanje", systemImage: "magnifyingglass") }
        }
    }
}
