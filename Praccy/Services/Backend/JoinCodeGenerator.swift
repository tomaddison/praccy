import Foundation

/// 6-char alphanumeric code excluding ambiguous glyphs (`0/O`, `1/I`). Not cryptographic;
/// guess resistance comes from 32⁶ ≈ 10⁹ combos over a short TTL enforced server-side.
enum JoinCodeGenerator {
    /// A–Z minus `O`/`I`, digits 2–9.
    nonisolated static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    nonisolated static let codeLength: Int = 6

    nonisolated static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    nonisolated static func generate(using rng: inout some RandomNumberGenerator) -> String {
        var code = ""
        code.reserveCapacity(codeLength)
        for _ in 0..<codeLength {
            code.append(alphabet.randomElement(using: &rng)!)
        }
        return code
    }

    /// Uppercases and strips whitespace. Returns `nil` on wrong length or non-alphabet chars.
    nonisolated static func normalise(_ raw: String) -> String? {
        let trimmed = raw
            .uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard trimmed.count == codeLength else { return nil }
        let alphabetSet = Set(alphabet)
        guard trimmed.allSatisfy({ alphabetSet.contains($0) }) else { return nil }
        return trimmed
    }
}
