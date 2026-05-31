import SwiftUI

struct GifCell: View {
    let gif: Gif
    var searchTerm: String = ""
    @Environment(Store.self) var store
    @State private var loader = ImageLoader()
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DraggableGifView(gif: gif, imageData: loader.imageData, isHovered: isHovered, searchTerm: searchTerm)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if loader.imageData == nil {
                Color(NSColor.quaternaryLabelColor).opacity(0.4)
            }

            if isHovered {
                Button {
                    store.toggleFavorite(gif)
                } label: {
                    Image(systemName: store.isFavorite(gif) ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(store.isFavorite(gif) ? .yellow : .white)
                        .padding(5)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear { loader.load(url: gif.previewURL) }
    }
}
