import Foundation

/// Files generated from the Flutter app (see tool/ios/generate_core_resources.py).
public enum CoreResources {
    public static func url(_ path: String) -> URL? {
        // Xcode bundles keep resources under Contents/Resources (macOS) or the
        // bundle root (iOS); SwiftPM on Linux uses the bundle directory.
        let bases = [Bundle.module.resourceURL, Bundle.module.bundleURL].compactMap { $0 }
        for base in bases {
            for url in [base.appendingPathComponent("Resources").appendingPathComponent(path), base.appendingPathComponent(path)]
            where FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    static func data(_ path: String) throws -> Data {
        guard let url = url(path) else { throw CoreError.missingResource(path) }
        return try Data(contentsOf: url)
    }
}

public enum CoreError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)
    case invalidData(String)
    case invalidArgument(String)
    case storage(String)

    public var description: String {
        switch self {
        case .missingResource(let path): return "Missing resource \(path)"
        case .invalidData(let reason), .invalidArgument(let reason), .storage(let reason): return reason
        }
    }
}

/// A value guarded by a lock, for caches shared across threads.
final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ value: Value) { self.value = value }
    func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
