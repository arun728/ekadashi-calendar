import Foundation

/// The small preferences store the Android app keeps in SharedPreferences.
/// Keys are shared with Android so behaviour and documentation line up.
public protocol KeyValueStore: AnyObject {
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool?
    func stringArray(forKey key: String) -> [String]?
    @discardableResult func set(_ value: String, forKey key: String) -> Bool
    @discardableResult func set(_ value: Bool, forKey key: String) -> Bool
    @discardableResult func set(_ value: [String], forKey key: String) -> Bool
    func remove(_ key: String)
    func keys() -> [String]
}

public final class InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: Any] = [:]
    private let lock = NSLock()
    /// Makes every write fail, to test storage failures.
    public var failWrites = false

    public init(_ values: [String: Any] = [:]) { self.values = values }

    public func string(forKey key: String) -> String? { lock.withLock { values[key] as? String } }
    public func bool(forKey key: String) -> Bool? { lock.withLock { values[key] as? Bool } }
    public func stringArray(forKey key: String) -> [String]? { lock.withLock { values[key] as? [String] } }
    public func set(_ value: String, forKey key: String) -> Bool { write(value, key) }
    public func set(_ value: Bool, forKey key: String) -> Bool { write(value, key) }
    public func set(_ value: [String], forKey key: String) -> Bool { write(value, key) }
    public func remove(_ key: String) { lock.withLock { _ = values.removeValue(forKey: key) } }
    public func keys() -> [String] { lock.withLock { Array(values.keys) } }

    private func write(_ value: Any, _ key: String) -> Bool {
        lock.withLock {
            if failWrites { return false }
            values[key] = value
            return true
        }
    }
}

/// UserDefaults, optionally in the App Group shared with the widgets.
public final class UserDefaultsKeyValueStore: KeyValueStore {
    public let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    public func bool(forKey key: String) -> Bool? { defaults.object(forKey: key) as? Bool }
    public func stringArray(forKey key: String) -> [String]? { defaults.stringArray(forKey: key) }
    public func set(_ value: String, forKey key: String) -> Bool { defaults.set(value, forKey: key); return defaults.string(forKey: key) == value }
    public func set(_ value: Bool, forKey key: String) -> Bool { defaults.set(value, forKey: key); return true }
    public func set(_ value: [String], forKey key: String) -> Bool { defaults.set(value, forKey: key); return true }
    public func remove(_ key: String) { defaults.removeObject(forKey: key) }
    public func keys() -> [String] { Array(defaults.dictionaryRepresentation().keys) }
}
