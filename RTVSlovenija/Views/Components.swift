import SwiftUI

/// What the player should open.
enum PlayItem: Identifiable, Hashable {
    case live(LiveChannel)
    case recording(Recording)

    var id: String {
        switch self {
        case .live(let c): return "live-\(c.id)"
        case .recording(let r): return "rec-\(r.id)"
        }
    }

    var title: String {
        switch self {
        case .live(let c): return c.name
        case .recording(let r): return r.title
        }
    }
}

struct Thumbnail: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default:
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "play.tv").font(.system(size: 48)).foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .clipped()
    }
}

struct RecordingCard: View {
    let recording: Recording
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Thumbnail(url: recording.imageURL)
                    .frame(width: 400, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(recording.title).font(.callout).lineLimit(2)
                HStack(spacing: 6) {
                    if let d = recording.dateText { Text(d) }
                    if let dur = recording.durationText { Text("·"); Text(dur) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 400, alignment: .leading)
        }
        .buttonStyle(.card)
    }
}

struct ShowCard: View {
    let show: Show
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Thumbnail(url: show.imageURL)
                .frame(width: 400, height: 225)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(show.title).font(.callout).lineLimit(2)
        }
        .frame(width: 400, alignment: .leading)
    }
}

enum Layout {
    /// Four 400pt cards per row, left-aligned, matching the horizontal rows.
    static let columns = Array(repeating: GridItem(.fixed(400), spacing: 48, alignment: .topLeading), count: 4)
}

struct RecordingGrid: View {
    let recordings: [Recording]
    let onSelect: (Recording) -> Void
    var onReachEnd: (() -> Void)? = nil

    var body: some View {
        LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: 48) {
            ForEach(recordings) { rec in
                RecordingCard(recording: rec) { onSelect(rec) }
                    .onAppear { if rec.id == recordings.last?.id { onReachEnd?() } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
    }
}

struct StatusView: View {
    enum Kind { case loading, empty(String), error(Error, retry: () -> Void) }
    let kind: Kind

    var body: some View {
        VStack(spacing: 20) {
            switch kind {
            case .loading:
                ProgressView()
            case .empty(let text):
                Image(systemName: "tray").font(.system(size: 60)).foregroundStyle(.secondary)
                Text(text).foregroundStyle(.secondary)
            case .error(let error, let retry):
                Image(systemName: "exclamationmark.triangle").font(.system(size: 60)).foregroundStyle(.secondary)
                Text(error.localizedDescription).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 900)
                Button("Poskusi znova", action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
