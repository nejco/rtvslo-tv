import Foundation
import Observation

enum RTVError: LocalizedError {
    case badStatus(Int)
    case noStream
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Strežnik je vrnil napako \(code)."
        case .noStream: return "Za to vsebino ni na voljo pretoka. Morda je geografsko omejena ali zaščitena z DRM."
        case .apiMessage(let m): return m
        }
    }
}

/// Client for RTV Slovenija's unofficial "ava" API, the same one the 365.rtvslo.si web player uses.
@Observable
final class RTVClient {
    static let shared = RTVClient()

    private let base = URL(string: "https://api.rtvslo.si/ava/")!
    /// Public client ID embedded in the RTV web player. Not a secret.
    private let clientID = "82013fb3a531d5414f478747c1aca622"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        // Some RTV endpoints check that the API caller and the stream player use the same agent string.
        config.httpAdditionalHeaders = ["User-Agent": RTVClient.userAgent, "Accept": "application/json"]
        session = URLSession(configuration: config)
    }

    static let userAgent = "Mozilla/5.0 (AppleTV; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) RTV365tvOS/1.0"

    // MARK: Live

    func liveInfo(for channel: LiveChannel) async throws -> LiveInfo {
        let json = try await get("getLiveStream/\(channel.id)")
        return LiveInfo(channel: channel, json: json)
    }

    // MARK: Archive

    /// RTV's show type for children's programmes ("Otroške" in getShowTypes).
    static let kidsShowTypeID = "31"
    static let letters = ["A", "B", "C", "Č", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "R", "S", "Š", "T", "U", "V", "Z", "Ž", "0"]

    /// Shows whose title starts with `letter` ("A"..."Ž", "0" for digits).
    func shows(startingWith letter: String) async throws -> [Show] {
        let json = try await get("getShowsSearch", [
            "sort": "title", "order": "asc", "pageSize": "200", "hidden": "0", "start": letter,
        ])
        return showItems(in: json).compactMap(Show.init(json:)).filter { !$0.isRadio }
    }

    /// All children's TV shows. Asks the server to filter by type first; if that parameter is
    /// ignored or returns nothing, walks the alphabet and filters client-side.
    func kidsShows() async throws -> [Show] {
        let kids = Self.kidsShowTypeID
        let json = try await get("getShowsSearch", [
            "sort": "title", "order": "asc", "pageSize": "500", "hidden": "0", "showTypeId": kids,
        ])
        var result = showItems(in: json).compactMap(Show.init(json:)).filter { !$0.isRadio && $0.showTypeID == kids }
        if result.isEmpty {
            for letter in Self.letters {
                let page = try await shows(startingWith: letter)
                result += page.filter { $0.showTypeID == kids }
            }
        }
        return result
    }

    /// Newest recordings in a category, newest first. Pages are 0-based.
    func latestRecordings(showTypeID: String, page: Int, pageSize: Int = 30) async throws -> [Recording] {
        let json = try await get("getSearch", [
            "q": "", "showTypeId": showTypeID, "sort": "date", "order": "desc",
            "pageSize": String(pageSize), "pageNumber": String(page), "source": "", "hearingAid": "0",
            "clip": "show", "from": "", "to": "", "WPId": "", "zkp": "0",
        ])
        return recordings(in: json).filter { !$0.isRadio }
    }

    private func showItems(in json: JSON) -> [JSON] {
        let nested = json["response"]["response"].array
        return nested.isEmpty ? json["response"].array : nested
    }

    /// Episodes of a show, newest first. Pages are 0-based.
    func episodes(showID: String, page: Int, pageSize: Int = 24) async throws -> [Recording] {
        let json = try await get("getSearch", [
            "sort": "date", "order": "desc", "pageSize": String(pageSize), "pageNumber": String(page),
            "from": "1991-01-01", "clip": "show", "showId": showID,
        ])
        return recordings(in: json)
    }

    /// Everything broadcast on a given day, newest first.
    func recordings(on day: Date) async throws -> [Recording] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Ljubljana")
        let d = f.string(from: day)
        let json = try await get("getSearch", [
            "q": "", "sort": "date", "order": "desc", "pageSize": "200", "source": "", "hearingAid": "0",
            "clip": "show", "from": d, "to": d, "WPId": "", "zkp": "0",
        ])
        return recordings(in: json).filter { !$0.isRadio }
    }

    func search(_ query: String, page: Int = 0) async throws -> [Recording] {
        let json = try await get("getSearch", [
            "q": query, "sort": "date", "order": "desc", "pageSize": "40", "pageNumber": String(page),
            "source": "", "hearingAid": "0", "clip": "show", "from": "", "to": "", "WPId": "", "zkp": "0",
        ])
        return recordings(in: json).filter { !$0.isRadio }
    }

    func searchShows(_ query: String) async throws -> [Show] {
        let json = try await get("getShowsSearch", ["q": query, "sort": "title", "order": "asc", "pageSize": "50", "hidden": "0"])
        return showItems(in: json).compactMap(Show.init(json:)).filter { !$0.isRadio }
    }

    private func recordings(in json: JSON) -> [Recording] {
        let r = json["response"]
        let list = !r["recordings"].array.isEmpty ? r["recordings"].array : r.array
        return list.compactMap(Recording.init(json:))
    }

    // MARK: Playback

    /// Resolves a recording to a playable HLS URL.
    /// The modern path is getRecordingDrm → jwt → getMedia; older items work with getRecording directly.
    func streamURL(forRecording id: String) async throws -> URL {
        if let drm = try? await get("getRecordingDrm/\(id)"), let jwt = drm["response"]["jwt"].string {
            let media = try await get("getMedia/\(id)", ["jwt": jwt])
            if let url = Media.hlsURL(from: media["response"]) { return url }
        }
        let rec = try await get("getRecording/\(id)")
        if let url = Media.hlsURL(from: rec["response"]) { return url }
        throw RTVError.noStream
    }

    func streamURL(forLive channel: LiveChannel) async throws -> URL {
        let info = try await liveInfo(for: channel)
        guard let url = info.hlsURL else { throw RTVError.noStream }
        return url
    }

    // MARK: Development diagnostics (DEBUG builds only)

    #if DEBUG
    /// Logs how the API classifies shows (showTypeId / genre) so the children's category can be identified.
    func logShowClassification() async {
        for ep in ["getShowTypes", "getGenres"] {
            if let j = try? await get(ep) {
                NSLog("RTVINFO %@ -> %@", ep, String(String(describing: j).prefix(3000)))
            } else {
                NSLog("RTVINFO %@ -> unavailable", ep)
            }
        }
        var byType: [String: [String]] = [:]
        var genres: [String: Int] = [:]
        for letter in Self.letters {
            guard let j = try? await get("getShowsSearch", ["sort": "title", "order": "asc", "pageSize": "200", "hidden": "0", "start": letter]) else { continue }
            for item in j["response"]["response"].array where item["mediaType"].string == "tv" {
                let t = item["showTypeId"].string ?? "?"
                byType[t, default: []].append(item["title"].string ?? "")
                for g in item["genre"].array { genres[g.string ?? String(describing: g), default: 0] += 1 }
            }
        }
        for (t, titles) in byType.sorted(by: { $0.value.count > $1.value.count }) {
            NSLog("RTVINFO showTypeId=%@ count=%d sample=%@", t, titles.count, titles.prefix(12).joined(separator: " | "))
        }
        NSLog("RTVINFO genres=%@", genres.sorted { $0.value > $1.value }.map { "\($0.key):\($0.value)" }.joined(separator: ", "))
    }
    #endif

    // MARK: Transport

    private func get(_ path: String, _ params: [String: String] = [:]) async throws -> JSON {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "client_id", value: clientID)]
        items += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        comps.queryItems = items
        let (data, response) = try await session.data(from: comps.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RTVError.badStatus(http.statusCode)
        }
        let json = try JSON.parse(data)
        if let status = json["status"].int, status >= 400 {
            throw RTVError.apiMessage(json["message"].string ?? "Napaka API-ja (\(status)).")
        }
        return json
    }
}
