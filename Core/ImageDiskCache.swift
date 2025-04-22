import Foundation

final class ImageDiskCache: Codable {
    static let shared = ImageDiskCache.loadCache()
    private static let cacheFileName = "image_disk_cache.json"
    private static let maxEntries = 2000

    private(set) var cache: [String: String] = [:]
    private var order: [String] = []

    private enum CodingKeys: String, CodingKey {
        case cache, order
    }

    private init() {}

    // MARK: - Public API
    func get(for src: String) -> String? {
        return cache[src]
    }

    func set(src: String, base64: String) {
        if cache[src] == nil {
            order.append(src)
        }
        cache[src] = base64
        enforceLimit()
        saveToDisk()
    }

    func clear() {
        cache.removeAll()
        order.removeAll()
        saveToDisk()
    }

    // MARK: - Limit and Eviction
    private func enforceLimit() {
        while cache.count > Self.maxEntries {
            if let oldest = order.first {
                cache.removeValue(forKey: oldest)
                order.removeFirst()
            }
        }
    }

    // MARK: - Disk I/O
    private static func cacheFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(cacheFileName)
    }

    private func saveToDisk() {
        let url = Self.cacheFileURL()
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: url)
        } catch {
            print("[ImageDiskCache] Failed to save cache: \(error)")
        }
    }

    private static func loadCache() -> ImageDiskCache {
        let url = cacheFileURL()
        do {
            let data = try Data(contentsOf: url)
            let cache = try JSONDecoder().decode(ImageDiskCache.self, from: data)
            return cache
        } catch {
            print("[ImageDiskCache] No cache on disk or failed to load: \(error)")
            return ImageDiskCache()
        }
    }
}
