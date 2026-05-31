import Foundation
import Observation

@Observable
final class Store {
    var recentSearches: [String] = []
    var favorites: [Gif] = []

    private let recentsKey = "recentSearches"
    private let favoritesKey = "favorites"

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([Gif].self, from: data) {
            favorites = saved
        }
    }

    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        UserDefaults.standard.set(recentSearches, forKey: recentsKey)
    }

    func toggleFavorite(_ gif: Gif) {
        if let idx = favorites.firstIndex(of: gif) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(gif, at: 0)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    func isFavorite(_ gif: Gif) -> Bool {
        favorites.contains(gif)
    }
}
