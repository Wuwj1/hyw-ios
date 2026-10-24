import SwiftUI

struct GameCardView: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let img = CoverStore.load(path: game.cover) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(white: 0.96)
                            Image(systemName: "gamecontroller")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.subText)
                        }
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(game.subtitle)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }

            Text(game.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(Theme.text)
        }
    }
}
