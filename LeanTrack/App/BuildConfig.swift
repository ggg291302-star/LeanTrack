import Foundation

/// Values the build machine fills in from GitHub Actions secrets (scripts/ci/inject-secrets.py).
/// The repo only ever holds this empty placeholder: never type a real key into this file.
enum BuildConfig {
    /// The owner's USDA FoodData Central key, scrambled so it isn't stored as plain text in the app.
    static let usdaKeyBytes: [UInt8] = []
    private static let mask: [UInt8] = [0x5A, 0x13, 0xC7, 0x2E, 0x91, 0x48, 0xB3, 0x6D]

    static var usdaAPIKey: String? {
        guard !usdaKeyBytes.isEmpty else { return nil }
        let bytes = usdaKeyBytes.enumerated().map { $0.element ^ mask[$0.offset % mask.count] }
        return String(bytes: bytes, encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 }
    }
}
