import SwiftUI

let appColorPalette: [String] = [
    "#34C759", "#007AFF", "#FF9500", "#AF52DE", "#FF3B30", "#5AC8FA",
    "#FF2D55", "#8E8E93", "#636366", "#FFD60A", "#30B0C7", "#A2845E"
]

/// Shared tappable swatch grid used wherever the app lets you pick a hex color
/// (categories, accounts) — keeps the palette and interaction consistent.
struct ColorSwatchGrid: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(appColorPalette, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
