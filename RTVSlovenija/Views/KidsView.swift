import SwiftUI

/// Children's programmes: the newest episodes up top, then every kids' show in the archive.
struct KidsView: View {
    @Environment(RTVClient.self) private var client
    @State private var latest: [Recording] = []
    @State private var shows: [Show] = []
    @State private var loading = false
    @State private var error: Error?
    @State private var playing: PlayItem?

    var body: some View {
        NavigationStack {
            Group {
                if loading, latest.isEmpty, shows.isEmpty {
                    StatusView(kind: .loading)
                } else if let error, latest.isEmpty, shows.isEmpty {
                    StatusView(kind: .error(error, retry: { Task { await load() } }))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            if !latest.isEmpty {
                                Text("Nove epizode").font(.title2).bold().padding(.horizontal, 60)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 48) {
                                        ForEach(latest) { rec in
                                            RecordingCard(recording: rec) { playing = .recording(rec) }
                                        }
                                    }
                                    .padding(.horizontal, 60)
                                    .padding(.vertical, 30)
                                }
                            }
                            if !shows.isEmpty {
                                Text("Vse otroške oddaje").font(.title2).bold().padding(.horizontal, 60)
                                LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: 48) {
                                    ForEach(shows) { show in
                                        NavigationLink(value: show) { ShowCard(show: show) }
                                            .buttonStyle(.card)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 60)
                                .padding(.bottom, 40)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationDestination(for: Show.self) { ShowDetailView(show: $0) }
        }
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
        .task { if shows.isEmpty { await load() } }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let l = client.latestRecordings(showTypeID: RTVClient.kidsShowTypeID, page: 0)
            async let s = client.kidsShows()
            (latest, shows) = try await (l, s)
            #if DEBUG
            // `xcrun simctl launch <device> <bundle> -autoplayKids` opens the newest episode straight away,
            // so archive playback can be checked without a remote.
            if ProcessInfo.processInfo.arguments.contains("-autoplayKids"), let first = latest.first {
                playing = .recording(first)
            }
            #endif
        } catch {
            self.error = error
        }
    }
}
