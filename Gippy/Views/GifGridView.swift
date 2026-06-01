import SwiftUI

struct GifGridView: View {
    let gifs: [Gif]
    var searchTerm: String = ""
    var isLoadingMore: Bool = false
    var onLoadMore: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gifs) { gif in
                    GifCell(gif: gif, searchTerm: searchTerm)
                }
            }
            .padding(8)

            if let onLoadMore {
                Group {
                    if isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .onAppear(perform: onLoadMore)
                    }
                }
            }
        }
    }
}
