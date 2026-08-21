import SwiftUI

/// Shows the real brand logo for a recognized bank/fintech account name (fetched at runtime from
/// Google's public favicon service by domain — the same mechanism browsers use to show a site's
/// icon, so no trademarked artwork ships inside the app bundle). Falls back to the existing
/// colored-circle initial while the logo loads, on failure, or when the name isn't a recognized brand.
struct BankLogoView: View {
    let name: String
    var fallbackColor: Color
    var diameter: CGFloat = 34
    var fallbackSystemImage: String? = nil

    private var brand: BankBrand? { BankBrandCatalog.match(for: name) }

    private var logoURL: URL? {
        guard let brand else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(brand.domain)&sz=128")
    }

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        Circle()
                            .fill(.white)
                            .overlay {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(diameter * 0.16)
                            }
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(fallbackColor)
            .overlay {
                if let fallbackSystemImage {
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: diameter * 0.42))
                        .foregroundStyle(.white)
                } else {
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: diameter * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}
