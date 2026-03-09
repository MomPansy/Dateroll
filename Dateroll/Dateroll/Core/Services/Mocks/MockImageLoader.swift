import UIKit

actor MockImageLoader: ImageLoaderProtocol {
    private nonisolated static let palette: [UIColor] = [
        .systemPink, .systemPurple, .systemIndigo,
        .systemTeal, .systemOrange, .systemMint,
        .systemCyan, .systemBrown
    ]

    func thumbnail(for assetID: String, targetSize: CGSize) async -> UIImage? {
        let colorIndex = abs(assetID.hashValue) % Self.palette.count
        let color = Self.palette[colorIndex]

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let heartSize = min(targetSize.width, targetSize.height) * 0.4
            let heartRect = CGRect(
                x: (targetSize.width - heartSize) / 2,
                y: (targetSize.height - heartSize) / 2,
                width: heartSize,
                height: heartSize
            )

            if let heartImage = UIImage(systemName: "heart.fill") {
                UIColor.white.withAlphaComponent(0.3).setFill()
                heartImage.withTintColor(.white.withAlphaComponent(0.3), renderingMode: .alwaysOriginal)
                    .draw(in: heartRect)
            }
        }
    }
}
