import SwiftUI

struct YearCardView: View {
    let entry: YearEntry
    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.geocodingService) private var geocodingService
    @State private var currentPage = 0
    @State private var locationName: String?

    private static let thumbnailSize = CGSize(width: 400, height: 400)

    var body: some View {
        ZStack(alignment: .bottom) {
            carousel
            gradient
            labels
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task(id: entry.id) {
            guard let coord = entry.representativeCoordinate else { return }
            locationName = await geocodingService.placeName(for: coord)
        }
    }

    @ViewBuilder
    private var carousel: some View {
        let photos = entry.carouselPhotos
        if photos.isEmpty {
            Rectangle()
                .fill(.secondary.opacity(0.2))
        } else {
            TabView(selection: $currentPage) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    CarouselPageView(
                        assetID: photo.id,
                        imageLoader: imageLoader,
                        targetSize: Self.thumbnailSize
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.65)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var labels: some View {
        HStack(alignment: .bottom) {
            Text(locationName ?? String(entry.year))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                badge(icon: "calendar", text: String(entry.year))
                badge(icon: "photo.fill", count: entry.totalPhotos)
            }
        }
        .padding(12)
    }

    private func badge(icon: String, count: Int) -> some View {
        badge(icon: icon, text: "\(count)")
    }

    private func badge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct CarouselPageView: View {
    let assetID: String
    let imageLoader: any ImageLoaderProtocol
    let targetSize: CGSize
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task {
            image = await imageLoader.thumbnail(for: assetID, targetSize: targetSize)
        }
    }
}
