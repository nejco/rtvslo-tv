import SwiftUI

struct LiveView: View {
    @Environment(RTVClient.self) private var client
    @State private var infos: [String: LiveInfo] = [:]
    @State private var playing: PlayItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                section("Televizija", channels: LiveChannel.tv)
                section("Radio", channels: LiveChannel.radio)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .fullScreenCover(item: $playing) { PlayerView(item: $0) }
        .task { await refresh() }
    }

    @ViewBuilder
    private func section(_ title: String, channels: [LiveChannel]) -> some View {
        Text(title).font(.title2).bold()
        LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: 48) {
            ForEach(channels) { channel in
                Button { playing = .live(channel) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .bottomLeading) {
                            Thumbnail(url: infos[channel.id]?.imageURL)
                                .frame(width: 400, height: 225)
                            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                            HStack(spacing: 8) {
                                Circle().fill(.red).frame(width: 12, height: 12)
                                Text("V ŽIVO").font(.caption2).bold()
                            }
                            .padding(12)
                        }
                        .frame(width: 400, height: 225)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(channel.name).font(.callout)
                        Text(infos[channel.id]?.nowPlaying ?? " ")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(width: 400, alignment: .leading)
                }
                .buttonStyle(.card)
            }
        }
    }

    private func refresh() async {
        await withTaskGroup(of: LiveInfo?.self) { group in
            for channel in LiveChannel.tv + LiveChannel.radio {
                group.addTask { try? await client.liveInfo(for: channel) }
            }
            for await info in group {
                if let info { infos[info.channel.id] = info }
            }
        }
    }
}
