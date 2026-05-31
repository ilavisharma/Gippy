import AppKit
import Observation

@Observable
final class ImageLoader {
    private static let cache = NSCache<NSString, NSData>()

    var imageData: Data?

    func load(url: URL) {
        let key = url.absoluteString as NSString
        if let cached = Self.cache.object(forKey: key) {
            imageData = cached as Data
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            Self.cache.setObject(data as NSData, forKey: key)
            self.imageData = data
        }
    }
}
