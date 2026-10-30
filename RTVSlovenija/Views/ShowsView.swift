import SwiftUI

/// Browse the archive alphabetically, the same way 365.rtvslo.si does.
struct ShowsView: View {
    @Environment(RTVClient.self) private var client
    @State private var letter = "A"
    @State private var shows: [Show] = []
    @State private var loading = false
    @State private var error: Error?

    private let letters = RTVClient.letters

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(letters, id: \.self) { l in
                            Button(l == "0" ? "0–9" : l) { letter = l }
                                .buttonStyle(.bordered)
                                .tint(l == letter ? Color.accentColor : Color.gray)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                }
                if loading {
                    StatusView(kind: .loading)
                } else if let error {
                    StatusView(kind: .error(error, retry: { Task { await load() } }))
                } else if shows.isEmpty {
                    StatusView(kind: .empty("Ni oddaj na to črko."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: 48) {
                            ForEach(shows) { show in
                                NavigationLink(value: show) { ShowCard(show: show) }
                                    .buttonStyle(.card)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationDestination(for: Show.self) { ShowDetailView(show: $0) }
        }
        .task(id: letter) { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { shows = try await client.shows(startingWith: letter) } catch { self.error = error }
    }
}

struct ShowDetailView: View {
    @Environment(RTVClient.self) private var client
    let show: Show
    @State private var episodes: [Recording] = []
    @State private var page = 0
    @State private var exhausted = false
    @State private var loading = false
    @State private var error: Error?
    @State private var playing: PlayItem?

    var body: some View {
        Group {
            if episodes.isEmpty, loading {
                StatusView(kind: .loading)
            } else if episodes.isEmpty, let error {
                StatusView(kind: .error(error, retry: { Task { await loadMore() } }))
            } else if episodes.isEmpty {
                StatusView(kind: .empty("Ta oddaja še nima posnetkov."))
            } else {
                ScrollView {
                    RecordingGrid(recordings: episodes, onSelect: { playing = .recording($0) }) {
                        Task { await loadMore() }
                    }
                    if loading { ProgressView().padding(40) }
                }
            }
        }
        .navigationTitle(show.title)
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
        .task { if episodes.isEmpty { await loadMore() } }
    }

    private func loadMore() async {
        guard !loading, !exhausted else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let batch = try await client.episodes(showID: show.id, page: page)
            if batch.isEmpty { exhausted = true } else { episodes += batch; page += 1 }
        } catch {
            self.error = error
        }
    }
}
