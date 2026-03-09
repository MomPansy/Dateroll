import Foundation

actor FaceStore: FaceStoreProtocol {
    private var faces: [String: DetectedFace] = [:]
    private var clusters: [FaceCluster] = []
    private var scannedIDs: Set<String> = []

    private let baseURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = documentsURL.appendingPathComponent("face-data", isDirectory: true)
        self.baseURL = base

        let decoder = JSONDecoder()

        if let data = try? Data(contentsOf: base.appendingPathComponent("faces.json")),
           let decoded = try? decoder.decode([DetectedFace].self, from: data) {
            for face in decoded {
                faces[face.id] = face
            }
        }

        if let data = try? Data(contentsOf: base.appendingPathComponent("clusters.json")),
           let decoded = try? decoder.decode([FaceCluster].self, from: data) {
            clusters = decoded
        }

        if let data = try? Data(contentsOf: base.appendingPathComponent("scanned.json")),
           let decoded = try? decoder.decode(Set<String>.self, from: data) {
            scannedIDs = decoded
        }
    }

    // MARK: - Faces

    func addFaces(_ newFaces: [DetectedFace]) {
        for face in newFaces {
            faces[face.id] = face
        }
        scheduleSave()
    }

    func allFaces() -> [DetectedFace] {
        Array(faces.values)
    }

    func faces(forAssetID assetID: String) -> [DetectedFace] {
        faces.values.filter { $0.assetID == assetID }
    }

    // MARK: - Clusters

    func setClusters(_ newClusters: [FaceCluster]) {
        clusters = newClusters
        scheduleSave()
    }

    func allClusters() -> [FaceCluster] {
        clusters
    }

    // MARK: - Scanned Assets

    func markScanned(assetIDs: Set<String>) {
        scannedIDs.formUnion(assetIDs)
        scheduleSave()
    }

    func isScanned(assetID: String) -> Bool {
        scannedIDs.contains(assetID)
    }

    func scannedAssetIDs() -> Set<String> {
        scannedIDs
    }

    // MARK: - Reset

    func reset() {
        faces.removeAll()
        clusters.removeAll()
        scannedIDs.removeAll()
        saveTask?.cancel()
        saveTask = nil

        let fm = FileManager.default
        try? fm.removeItem(at: baseURL)
    }

    // MARK: - Persistence

    private var facesURL: URL { baseURL.appendingPathComponent("faces.json") }
    private var clustersURL: URL { baseURL.appendingPathComponent("clusters.json") }
    private var scannedURL: URL { baseURL.appendingPathComponent("scanned.json") }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await self?.saveToDisk()
        }
    }

    private func saveToDisk() {
        let fm = FileManager.default
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(Array(faces.values)) {
            try? data.write(to: facesURL, options: .atomic)
        }
        if let data = try? encoder.encode(clusters) {
            try? data.write(to: clustersURL, options: .atomic)
        }
        if let data = try? encoder.encode(scannedIDs) {
            try? data.write(to: scannedURL, options: .atomic)
        }
    }
}
