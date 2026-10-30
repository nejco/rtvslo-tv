import Foundation

struct LiveChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let isRadio: Bool

    static let tv: [LiveChannel] = [
        .init(id: "tv.slo1", name: "TV SLO 1", isRadio: false),
        .init(id: "tv.slo2", name: "TV SLO 2", isRadio: false),
        .init(id: "tv.slo3", name: "TV SLO 3", isRadio: false),
        .init(id: "tv.kp1", name: "TV Koper-Capodistria", isRadio: false),
        .init(id: "tv.mb1", name: "TV Maribor", isRadio: false),
        .init(id: "tv.mmctv", name: "MMC TV", isRadio: false),
    ]

    static let radio: [LiveChannel] = [
        .init(id: "ra.a1", name: "Radio Prvi", isRadio: true),
        .init(id: "ra.val202", name: "Val 202", isRadio: true),
        .init(id: "ra.ars", name: "Radio Ars", isRadio: true),
        .init(id: "ra.mb1", name: "Radio Maribor", isRadio: true),
        .init(id: "ra.kp", name: "Radio Koper", isRadio: true),
        .init(id: "ra.capo", name: "Radio Capodistria", isRadio: true),
        .init(id: "ra.rsi", name: "Radio Slovenia International", isRadio: true),
        .init(id: "ra.mmr", name: "Radio MMR", isRadio: true),
    ]
}

/// A live-stream status for one channel, used to show "now playing".
struct LiveInfo {
    let channel: LiveChannel
    let nowPlaying: String?
    let imageURL: URL?
    let hlsURL: URL?

    init(channel: LiveChannel, json: JSON) {
        self.channel = channel
        let r = json["response"]
        nowPlaying = r.firstString([["onair", "current", "broadcast", "title"], ["title"]])
        imageURL = Media.imageURL(from: r["images"])
        hlsURL = Media.hlsURL(from: r)
    }
}

struct Show: Identifiable, Hashable {
    let id: String
    let title: String
    let imageURL: URL?
    let isRadio: Bool
    /// RTV's editorial category, e.g. "31" = Otroške (children's).
    let showTypeID: String?

    init?(json: JSON) {
        guard let id = json["id"].string, let title = json["title"].string else { return nil }
        self.id = id
        self.title = title
        self.showTypeID = json["showTypeId"].string
        self.isRadio = (json["mediaType"].string ?? "tv") == "radio" || json["mediaType"].string == "audio"
        self.imageURL = json.firstString([["thumbnail", "show"], ["thumbnail", "orig"], ["images", "wide1"], ["images", "orig"], ["image"]])
            .flatMap(URL.init(string:))
    }
}

struct Recording: Identifiable, Hashable {
    let id: String
    let title: String
    let showName: String?
    let description: String?
    let imageURL: URL?
    let broadcastDate: String?
    let duration: Int?
    let isRadio: Bool
    let showID: String?

    init?(json: JSON) {
        guard let id = json["id"].string else { return nil }
        self.id = id
        self.title = json["title"].string ?? "Brez naslova"
        self.showName = json["showName"].string
        self.description = json["description"].string ?? json["showDescription"].string
        self.imageURL = Media.imageURL(from: json["images"]) ?? json["thumbnail"].string.flatMap(URL.init(string:))
        self.broadcastDate = json["broadcastDate"].string ?? json["date"].string
        self.duration = json["duration"].int
        self.isRadio = json["mediaType"].string == "audio"
        self.showID = json["showId"].string
    }

    var durationText: String? {
        guard let d = duration, d > 0 else { return nil }
        let h = d / 3600, m = (d % 3600) / 60
        return h > 0 ? "\(h) h \(m) min" : "\(m) min"
    }

    var dateText: String? {
        guard let s = broadcastDate, s.count >= 10 else { return broadcastDate }
        let parts = s.prefix(10).split(separator: "-")
        guard parts.count == 3 else { return s }
        return "\(Int(parts[2]) ?? 0). \(Int(parts[1]) ?? 0). \(parts[0])"
    }
}

enum Media {
    /// Finds an HLS URL in any of the shapes the API has used over the years.
    static func hlsURL(from r: JSON) -> URL? {
        if let s = r["addaptiveMedia"]["hls"].string, let u = URL(string: s) { return u }
        if let s = r["addaptiveMedia"]["hls_sec"].string, let u = URL(string: s) { return u }
        if let s = r["adaptiveMedia"]["hls"].string, let u = URL(string: s) { return u }
        for file in r["mediaFiles"].array {
            if let s = file["streams"]["hls"].string ?? file["streams"]["https"].string ?? file["streams"]["http"].string,
               let u = URL(string: s) { return u }
            if let streamer = file["streamer"].string, let f = file["file"].string {
                return URL(string: streamer.hasSuffix("/") ? streamer + f : streamer + "/" + f)
            }
            if let streamer = file["streamers"]["https"].string ?? file["streamers"]["http"].string, let f = file["filename"].string {
                return URL(string: streamer + "/" + f)
            }
        }
        return nil
    }

    static func imageURL(from images: JSON) -> URL? {
        images.firstString([["wide1"], ["wide2"], ["orig"], ["fp3"], ["fp1"]]).flatMap(URL.init(string:))
    }
}
