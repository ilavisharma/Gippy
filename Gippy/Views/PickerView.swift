import SwiftUI

struct PickerView: View {
    @Environment(Store.self) var store
    @State private var query = ""
    @State private var results: [Gif] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

    private let tenor = TenorService()

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .frame(width: 420, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { searchFocused = true }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("Search GIFs…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .onSubmit { performSearch() }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 16)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Content area

    @ViewBuilder
    private var content: some View {
        if let error = errorMessage {
            errorView(error)
        } else if !results.isEmpty {
            GifGridView(gifs: results)
        } else if isLoading {
            loadingView
        } else {
            emptyStateView
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !store.recentSearches.isEmpty {
                    sectionHeader("Recent")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(store.recentSearches, id: \.self) { term in
                                Button(term) {
                                    query = term
                                    performSearch()
                                }
                                .buttonStyle(ChipButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }

                if !store.favorites.isEmpty {
                    sectionHeader("Favorites")
                    GifGridView(gifs: store.favorites)
                }

                if store.recentSearches.isEmpty && store.favorites.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 44))
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        Text("Search for a GIF above")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text("Then drag one straight into Slack")
                            .font(.caption)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
            .padding(.top, 16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
            .tracking(0.8)
            .padding(.horizontal, 12)
    }

    // MARK: - Actions

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        results = []
        store.addRecentSearch(trimmed)
        Task {
            do {
                results = try await tenor.search(trimmed)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Chip button

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlColor))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
