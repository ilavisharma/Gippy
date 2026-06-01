import Foundation

struct TenorSearchPage: Sendable {
    let gifs: [Gif]
    let next: String?
}

struct TenorService: Sendable {
    private let clientKey = "gippy"
    private let limit = 50

    func search(_ query: String, after cursor: String? = nil) async throws -> TenorSearchPage {
        guard let apiKey = Keychain.read(key: "tenorAPIKey"), !apiKey.isEmpty else {
            throw TenorError.noAPIKey
        }
        var components = URLComponents(string: "https://tenor.googleapis.com/v2/search")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "media_filter", value: "tinygif,gif"),
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "pos", value: cursor))
        }
        components.queryItems = items
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TenorResponse.self, from: data)
        let next = response.next.flatMap { $0.isEmpty ? nil : $0 }
        return TenorSearchPage(gifs: response.results.compactMap(Gif.init(tenorResult:)), next: next)
    }
}

enum TenorError: LocalizedError {
    case noAPIKey
    var errorDescription: String? {
        "No Tenor API key. Open Settings (gear icon) to add one."
    }
}

// MARK: - Tenor response shapes

private struct TenorResponse: Decodable {
    let results: [TenorResult]
    let next: String?
}

private struct TenorResult: Decodable {
    let id: String
    let content_description: String
    let media_formats: [String: TenorMediaFormat]
}

private struct TenorMediaFormat: Decodable {
    let url: String
    let dims: [Int]
}

private extension Gif {
    init?(tenorResult r: TenorResult) {
        guard
            let tiny = r.media_formats["tinygif"],
            let full = r.media_formats["gif"],
            let previewURL = URL(string: tiny.url),
            let gifURL = URL(string: full.url)
        else { return nil }
        self.id = r.id
        self.previewURL = previewURL
        self.gifURL = gifURL
        self.width = full.dims.first ?? 0
        self.height = full.dims.dropFirst().first ?? 0
        self.description = r.content_description
    }
}
