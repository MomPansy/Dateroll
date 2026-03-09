import Foundation

actor MockFaceStore: FaceStoreProtocol {
    private var faces: [String: DetectedFace] = [:]
    private var clusters: [FaceCluster] = []
    private var scannedIDs: Set<String> = []

    init(
        faces: [DetectedFace] = [],
        clusters: [FaceCluster] = [],
        scannedIDs: Set<String> = []
    ) {
        for face in faces {
            self.faces[face.id] = face
        }
        self.clusters = clusters
        self.scannedIDs = scannedIDs
    }

    func addFaces(_ newFaces: [DetectedFace]) {
        for face in newFaces {
            faces[face.id] = face
        }
    }

    func allFaces() -> [DetectedFace] {
        Array(faces.values)
    }

    func faces(forAssetID assetID: String) -> [DetectedFace] {
        faces.values.filter { $0.assetID == assetID }
    }

    func setClusters(_ newClusters: [FaceCluster]) {
        clusters = newClusters
    }

    func allClusters() -> [FaceCluster] {
        clusters
    }

    func markScanned(assetIDs: Set<String>) {
        scannedIDs.formUnion(assetIDs)
    }

    func isScanned(assetID: String) -> Bool {
        scannedIDs.contains(assetID)
    }

    func scannedAssetIDs() -> Set<String> {
        scannedIDs
    }

    func reset() {
        faces.removeAll()
        clusters.removeAll()
        scannedIDs.removeAll()
    }
}
