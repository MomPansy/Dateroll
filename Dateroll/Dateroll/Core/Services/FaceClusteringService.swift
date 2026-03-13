import Foundation

actor FaceClusteringService: FaceClusteringServiceProtocol {
    nonisolated let faceStore: any FaceStoreProtocol

    init(faceStore: any FaceStoreProtocol) {
        self.faceStore = faceStore
    }

    func assignToClusters(_ faces: [DetectedFace]) async {
        guard !faces.isEmpty else { return }

        var clusters = await faceStore.allClusters()

        for face in faces {
            let bestMatch = await findBestCluster(for: face, in: clusters)

            if let (index, similarity) = bestMatch,
               similarity > ClusteringConfig.assignmentThreshold {
                clusters[index].faceIDs.append(face.id)
                clusters[index].representativeEmbedding = updatedCentroid(
                    current: clusters[index].representativeEmbedding,
                    newEmbedding: face.embedding,
                    clusterSize: clusters[index].faceIDs.count - 1
                )
            } else {
                let newCluster = await FaceCluster(
                    faceIDs: [face.id],
                    representativeEmbedding: face.embedding
                )
                clusters.append(newCluster)
            }
        }

        await faceStore.setClusters(clusters)
    }

    func reclusterAll() async {
        // Implemented in Task 6
    }

    func clusterCount() async -> Int {
        let clusters = await faceStore.allClusters()
        return clusters.count
    }

    // MARK: - Private

    private nonisolated func findBestCluster(
        for face: DetectedFace,
        in clusters: [FaceCluster]
    ) async -> (index: Int, similarity: Float)? {
        var bestIndex: Int?
        var bestSimilarity: Float = -1

        for (index, cluster) in clusters.enumerated() {
            let similarity = await face.embedding.cosineSimilarity(to: cluster.representativeEmbedding)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestIndex = index
            }
        }

        guard let index = bestIndex else { return nil }
        return (index, bestSimilarity)
    }

    private nonisolated func updatedCentroid(
        current: FaceEmbedding,
        newEmbedding: FaceEmbedding,
        clusterSize: Int
    ) -> FaceEmbedding {
        let effectiveN = min(clusterSize, ClusteringConfig.centroidCap)
        let n = Float(effectiveN)
        let count = current.values.count
        var updated = [Float](repeating: 0, count: count)

        for i in 0..<count {
            updated[i] = (n * current.values[i] + newEmbedding.values[i]) / (n + 1)
        }

        return FaceEmbedding(values: updated)
    }
}
