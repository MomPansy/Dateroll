import UIKit

protocol ImageLoaderProtocol: Sendable {
    func thumbnail(for assetID: String, targetSize: CGSize) async -> UIImage?
}
