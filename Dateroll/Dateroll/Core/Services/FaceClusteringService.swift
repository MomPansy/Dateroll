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
        let clusters = await faceStore.allClusters()
        let allFaces = await faceStore.allFaces()

        guard !clusters.isEmpty else { return }

        // Separate large (confident) clusters from small ones
        let largeClusters = clusters.filter { $0.faceIDs.count >= ClusteringConfig.smallClusterLimit }
        let smallClusters = clusters.filter { $0.faceIDs.count < ClusteringConfig.smallClusterLimit }

        guard !smallClusters.isEmpty else { return }

        // Build face lookup
        let faceLookup = Dictionary(uniqueKeysWithValues: allFaces.map { ($0.id, $0) })

        // Collect all faces from small clusters for re-clustering
        let facesToRecluster: [DetectedFace] = smallClusters.flatMap { cluster in
            cluster.faceIDs.compactMap { faceLookup[$0] }
        }

        guard !facesToRecluster.isEmpty else { return }

        // HAC: start with each face as its own cluster
        var hacClusters: [(faceIDs: [String], embedding: FaceEmbedding)] = facesToRecluster.map {
            (faceIDs: [$0.id], embedding: $0.embedding)
        }

        // Repeatedly merge closest pair until no pair exceeds threshold
        while hacClusters.count > 1 {
            var bestI = 0
            var bestJ = 1
            var bestSimilarity: Float = -1

            for i in 0..<hacClusters.count {
                for j in (i + 1)..<hacClusters.count {
                    let similarity = await hacClusters[i].embedding.cosineSimilarity(
                        to: hacClusters[j].embedding
                    )
                    if similarity > bestSimilarity {
                        bestSimilarity = similarity
                        bestI = i
                        bestJ = j
                    }
                }
            }

            guard bestSimilarity > ClusteringConfig.reclusterThreshold else { break }

            // Merge bestJ into bestI
            let mergedFaceIDs = hacClusters[bestI].faceIDs + hacClusters[bestJ].faceIDs
            let mergedEmbedding = averageEmbedding(
                hacClusters[bestI].embedding, count: hacClusters[bestI].faceIDs.count,
                hacClusters[bestJ].embedding, count: hacClusters[bestJ].faceIDs.count
            )
            hacClusters[bestI] = (faceIDs: mergedFaceIDs, embedding: mergedEmbedding)
            hacClusters.remove(at: bestJ)
        }

        // Convert HAC results back to FaceCluster structs
        var newSmallClusters: [FaceCluster] = []
        for item in hacClusters {
            let cluster = await FaceCluster(
                faceIDs: item.faceIDs,
                representativeEmbedding: item.embedding
            )
            newSmallClusters.append(cluster)
        }

        await faceStore.setClusters(largeClusters + newSmallClusters)
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

    private nonisolated func averageEmbedding(
        _ a: FaceEmbedding, count countA: Int,
        _ b: FaceEmbedding, count countB: Int
    ) -> FaceEmbedding {
        let totalCount = Float(countA + countB)
        let count = a.values.count
        var values = [Float](repeating: 0, count: count)
        for i in 0..<count {
            values[i] = (Float(countA) * a.values[i] + Float(countB) * b.values[i]) / totalCount
        }
        return FaceEmbedding(values: values)
    }
}
