import Foundation
import Yams

/// `config.yaml` at the storage root (PRD §5.3).
///
/// ```yaml
/// name: "MBM"
/// birth_date: 1994-01-15
/// end_age: 90
/// ```
public struct LifeConfig: Codable, Equatable, Sendable {
    public var name: String
    public var birthDate: CalendarDate
    public var endAge: Int

    public static let defaultEndAge = 90

    public init(name: String, birthDate: CalendarDate, endAge: Int = LifeConfig.defaultEndAge) {
        self.name = name
        self.birthDate = birthDate
        self.endAge = endAge
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case birthDate = "birth_date"
        case endAge = "end_age"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthDate = try c.decode(CalendarDate.self, forKey: .birthDate)
        endAge = try c.decodeIfPresent(Int.self, forKey: .endAge) ?? LifeConfig.defaultEndAge
    }

    public static func parse(yaml: String) throws -> LifeConfig {
        try YAMLDecoder().decode(LifeConfig.self, from: yaml)
    }

    public func serialized() -> String {
        """
        name: \(YAMLEmit.quoted(name))
        birth_date: \(birthDate.iso)
        end_age: \(endAge)

        """
    }
}
