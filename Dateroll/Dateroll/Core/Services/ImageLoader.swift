import Photos
import UIKit

actor ImageLoader: ImageLoaderProtocol {
    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for assetID: String, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(assetID)-\(Int(targetSize.width))x\(Int(targetSize.height))"
        if let cached = cache.object(forKey: cacheKey as NSString) { return cached }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let image: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize,
                contentMode: .aspectFill, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        if let image {
            cache.setObject(image, forKey: cacheKey as NSString)
        }
        return image
    }
}
