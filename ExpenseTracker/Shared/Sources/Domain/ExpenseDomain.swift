import Foundation
import CryptoKit

/// Namespace for the pure, persistence-agnostic expense categorization domain.
///
/// Everything under `ExpenseDomain` is a Swift value type with no SwiftData /
/// CloudKit dependency, so the domain logic is unit-testable in isolation and
/// can later be mapped to a `@Model` / CloudKit record without being rewritten.
///
/// The existing `Category` / `Transaction` persistence types live at module
/// scope; the two-level model lives here under its own namespace to keep the
/// two concerns from colliding.
public enum ExpenseDomain {}

extension ExpenseDomain {
    /// Generates RFC 4122 version-5 (namespaced, SHA-1) UUIDs.
    ///
    /// Seed entities derive their `id` from a stable string key so the ids are
    /// both **unique** (distinct keys → distinct hashes) and **stable** (the
    /// same key always yields the same UUID across launches and processes).
    /// This matters for persistence: a seeded category keeps its identity.
    enum StableID {
        /// Fixed namespace for everything in the expense domain seed.
        private static let namespace = UUID(uuidString: "B7C8F4A2-1E3D-4F5A-9B6C-2D8E0A1F3C5B")!

        static func make(_ key: String) -> UUID {
            var hasher = Insecure.SHA1()
            withUnsafeBytes(of: namespace.uuid) { hasher.update(bufferPointer: $0) }
            hasher.update(data: Data(key.utf8))
            var bytes = Array(hasher.finalize().prefix(16))

            // Set the version (5) and the RFC 4122 variant bits.
            bytes[6] = (bytes[6] & 0x0F) | 0x50
            bytes[8] = (bytes[8] & 0x3F) | 0x80

            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }
}
