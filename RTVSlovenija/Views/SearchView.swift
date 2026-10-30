import SwiftUI

struct SearchView: View {
    @Environment(RTVClient.self) private var client
    @State private var query = ""
    @State private var shows: [Show] = []
    @State private var recordings: [Recording] = []
    @State private var loading = false
    @State private var error: Error?
    @State private var playing: PlayItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView().padding(60)
                } else if let error {
                    StatusView(kind: .error(error, retry: { Task { await run() } })).frame(height: 400)
                } else if query.count >= 2, shows.isEmpty, recordings.isEmpty {
                    StatusView(kind: .empty("Ni zadetkov za »\(query)«.")).frame(height: 400)
                } else {
                    VStack(alignment: .leading, spacing: 40) {
                        if !shows.isEmpty {
                            Text("Oddaje").font(.title2).bold().padding(.horizontal, 60)
                            LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: 48) {
                                ForEach(shows) { show in
                                    NavigationLink(value: show) { ShowCard(show: show) }.buttonStyle(.card)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 60)
                        }
                        if !recordings.isEmpty {
                            Text("Posnetki").font(.title2).bold().padding(.horizontal, 60)
                            RecordingGrid(recordings: recordings, onSelect: { playing = .recording($0) })
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .searchable(text: $query, prompt: "Išči oddaje in posnetke")
            .navigationDestination(for: Show.self) { ShowDetailView(show: $0) }
        }
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await run()
        }
    }

    private func run() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { shows = []; recordings = []; return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let s = client.searchShows(q)
            async let r = client.search(q)
            (shows, recordings) = try await (s, r)
        } catch {
            self.error = error
        }
    }
}
