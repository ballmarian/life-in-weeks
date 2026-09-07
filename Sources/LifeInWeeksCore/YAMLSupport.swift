import Foundation

// MARK: - CalendarDate <-> YAML/JSON

extension CalendarDate: Codable {
    /// Decodes `1994-01-15` whether YAML tagged it a timestamp or a quoted
    /// string — Yams hands both to a `String` container as the raw scalar.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = CalendarDate(iso: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a YYYY-MM-DD date, got \"\(raw)\""
            ))
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}

// MARK: - Hand-rolled emission

/// The app writes three YAML shapes (`config.yaml`, `blocks.yaml`, week-file
/// frontmatter), all tiny and fixed. Emitting them by hand rather than through
/// `YAMLEncoder` keeps key order stable, dates unquoted, and the output byte-for-byte
/// what the PRD's examples show — these files are meant to be read and hand-edited
/// (PRD §5), so churn in an encoder's formatting would be visible to the user.
/// Parsing still goes through Yams (PRD §5.5).
enum YAMLEmit {
    /// A double-quoted YAML scalar, safe for any content.
    static func quoted(_ string: String) -> String {
        var out = "\""
        for character in string.unicodeScalars {
            switch character {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.unicodeScalars.append(character)
            }
        }
        return out + "\""
    }
}
