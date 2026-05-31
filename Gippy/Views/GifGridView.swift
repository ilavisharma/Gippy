import SwiftUI

struct GifGridView: View {
    let gifs: [Gif]

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gifs) { gif in
                    GifCell(gif: gif)
                }
            }
            .padding(8)
        }
    }
}
