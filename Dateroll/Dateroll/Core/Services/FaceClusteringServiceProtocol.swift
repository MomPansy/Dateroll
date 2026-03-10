import Foundation

enum ClusteringConfig {
    static let assignmentThreshold: Float = 0.55
    static let reclusterThreshold: Float = 0.45
    static let centroidCap: Int = 50
    static let reclusterInterval: Int = 500
    static let smallClusterLimit: Int = 5
}

protocol FaceClusteringServiceProtocol: Sendable {
    func assignToClusters(_ faces: [DetectedFace]) async
    func reclusterAll() async
    func clusterCount() async -> Int
}
