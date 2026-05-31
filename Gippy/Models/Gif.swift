import Foundation

struct Gif: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let previewURL: URL
    let gifURL: URL
    let width: Int
    let height: Int
    let description: String

    var aspectRatio: Double {
        height > 0 ? Double(width) / Double(height) : 1
    }
}
