import Foundation

public enum KeychainServiceError: Error { case notFound, unexpected }

public protocol KeychainServicing {
    func set(_ value: Data, forKey key: String) throws
    func get(_ key: String) throws -> Data
    func remove(_ key: String) throws
}

// Placeholder implementation stub; replace with real Keychain calls in app target.
public final class KeychainService: KeychainServicing {
    private var mem: [String: Data] = [:]
    public init() {}
    public func set(_ value: Data, forKey key: String) throws { mem[key] = value }
    public func get(_ key: String) throws -> Data { guard let v = mem[key] else { throw KeychainServiceError.notFound }; return v }
    public func remove(_ key: String) throws { mem.removeValue(forKey: key) }
}

