import SwiftUI

/// Everything broadcast in the last few days, newest first. Loads one day at a time as you scroll.
struct NewestView: View {
    @Environment(RTVClient.self) private var client
    @State private var recordings: [Recording] = []
    @State private var daysLoaded = 0
    @State private var loading = false
    @State private var error: Error?
    @State private var playing: PlayItem?

    private let maxDays = 14

    var body: some View {
        Group {
            if recordings.isEmpty, loading {
                StatusView(kind: .loading)
            } else if recordings.isEmpty, let error {
                StatusView(kind: .error(error, retry: { Task { await loadMore(reset: true) } }))
            } else if recordings.isEmpty {
                StatusView(kind: .empty("Ni vsebin."))
            } else {
                ScrollView {
                    RecordingGrid(recordings: recordings, onSelect: { playing = .recording($0) }) {
                        Task { await loadMore() }
                    }
                    if loading { ProgressView().padding(40) }
                }
            }
        }
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
        .task { if recordings.isEmpty { await loadMore(reset: true) } }
    }

    private func loadMore(reset: Bool = false) async {
        guard !loading else { return }
        if reset { recordings = []; daysLoaded = 0; error = nil }
        guard daysLoaded < maxDays else { return }
        loading = true
        defer { loading = false }
        // Keep fetching days until we have something new to show (weekends can be sparse).
        var fetched: [Recording] = []
        while fetched.isEmpty, daysLoaded < maxDays {
            let day = Calendar.current.date(byAdding: .day, value: -daysLoaded, to: .now)!
            do {
                fetched = try await client.recordings(on: day)
            } catch {
                self.error = error
                return
            }
            daysLoaded += 1
        }
        let known = Set(recordings.map(\.id))
        recordings += fetched.filter { !known.contains($0.id) }
    }
}
