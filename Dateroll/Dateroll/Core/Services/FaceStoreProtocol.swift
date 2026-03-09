import Foundation

protocol FaceStoreProtocol: Sendable {
    func addFaces(_ faces: [DetectedFace]) async
    func allFaces() async -> [DetectedFace]
    func faces(forAssetID assetID: String) async -> [DetectedFace]

    func setClusters(_ clusters: [FaceCluster]) async
    func allClusters() async -> [FaceCluster]

    func markScanned(assetIDs: Set<String>) async
    func isScanned(assetID: String) async -> Bool
    func scannedAssetIDs() async -> Set<String>

    func reset() async
}
