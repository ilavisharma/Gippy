import AppKit
import UniformTypeIdentifiers

enum DragProvider {
    nonisolated static func itemProvider(for gif: Gif) -> NSItemProvider {
        let provider = NSItemProvider()
        let gifURL = gif.gifURL
        let gifId = gif.id
        let name = gif.description

        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.gif.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            Task {
                do {
                    let url = try await downloadToTemp(url: gifURL, id: gifId, name: name)
                    completion(url, true, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
    }

    nonisolated private static func downloadToTemp(url: URL, id: String, name: String) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: url)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gifdropper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeName = String(name.prefix(40)).replacingOccurrences(of: "/", with: "-")
        let file = dir.appendingPathComponent("\(id)_\(safeName).gif")
        try data.write(to: file)
        return file
    }
}
