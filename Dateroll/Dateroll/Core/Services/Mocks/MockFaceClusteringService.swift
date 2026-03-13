import Foundation

actor MockFaceClusteringService: FaceClusteringServiceProtocol {
    private(set) var assignCallCount = 0
    private(set) var reclusterCallCount = 0
    private(set) var lastAssignedFaces: [DetectedFace] = []
    private var _clusterCount: Int = 0

    init(clusterCount: Int = 0) {
        self._clusterCount = clusterCount
    }

    func assignToClusters(_ faces: [DetectedFace]) async {
        assignCallCount += 1
        lastAssignedFaces = faces
    }

    func reclusterAll() async {
        reclusterCallCount += 1
    }

    func clusterCount() async -> Int {
        _clusterCount
    }
}
