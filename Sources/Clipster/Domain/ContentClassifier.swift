import Foundation
import CryptoKit

enum ContentClassifier {
    static func classify(_ content: String, fileTypes: [String] = []) -> Category {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if isURL(trimmed) { return .link }
        if isCode(trimmed) { return .code }
        return .text
    }

    private static func isURL(_ s: String) -> Bool {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(s.startIndex..., in: s)
            let matches = detector.matches(in: s, range: range)
            if let first = matches.first, first.range.length == range.length {
                return true
            }
        }
        return s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://")
    }

    private static func isCode(_ s: String) -> Bool {
        let lines = s.split(separator: "\n")
        guard lines.count >= 2 else { return false }
        let codeIndicators = [
            "func ", "var ", "let ", "class ", "struct ", "import ",
            "public ", "private ", "return ", "if ", "for ", "while ",
            "def ", "print(", "console.log", "#include", "void ",
            "->", "=>", "==", "!=", "{", "}", ";",
        ]
        var hits = 0
        for line in lines.prefix(8) {
            let l = line.lowercased()
            if codeIndicators.contains(where: { l.contains($0) }) { hits += 1 }
        }
        let hasIndent = lines.contains { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        return hits >= 2 || (hits >= 1 && hasIndent)
    }

    static func sha256(_ text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
