import SwiftUI
import AVKit

/// Full-screen player. Resolves the stream URL, then hands it to the system AVPlayerViewController,
/// which gives the native tvOS transport bar, scrubbing, subtitles and audio-track menus.
struct PlayerView: View {
    @Environment(RTVClient.self) private var client
    @Environment(\.dismiss) private var dismiss
    let item: PlayItem

    @State private var url: URL?
    @State private var error: Error?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                AVPlayerController(url: url, title: item.title, isLive: isLive)
                    .ignoresSafeArea()
            } else if let error {
                StatusView(kind: .error(error, retry: { self.error = nil; Task { await resolve() } }))
            } else {
                ProgressView("Nalaganje …").tint(.white)
            }
        }
        .task { await resolve() }
    }

    private var isLive: Bool {
        if case .live = item { return true }
        return false
    }

    private func resolve() async {
        do {
            switch item {
            case .live(let channel): url = try await client.streamURL(forLive: channel)
            case .recording(let rec): url = try await client.streamURL(forRecording: rec.id)
            }
        } catch {
            self.error = error
        }
    }
}

struct AVPlayerController: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let isLive: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": RTVClient.userAgent]])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.externalMetadata = [metadata(.commonIdentifierTitle, title)]
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        context.coordinator.observation = playerItem.observe(\.status, options: [.new]) { item, _ in
            switch item.status {
            case .readyToPlay: NSLog("RTVPLAYER ready: %@", url.absoluteString)
            case .failed: NSLog("RTVPLAYER failed: %@ error=%@", url.absoluteString, String(describing: item.error))
            default: break
            }
        }
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        vc.requiresLinearPlayback = false
        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var observation: NSKeyValueObservation?
    }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: ()) {
        vc.player?.pause()
        vc.player = nil
    }

    private func metadata(_ id: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }
}
