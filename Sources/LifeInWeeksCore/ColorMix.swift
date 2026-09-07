import Foundation

/// A plain sRGB colour, 0…1 per channel. No UI framework involved, so the
/// mixing the grid depends on stays testable alongside the rest of Core.
public struct SRGBColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#RGB`, `#RRGGBB`, with or without the hash. `nil` for anything else,
    /// so a typo in a hand-edited `blocks.yaml` degrades rather than crashes.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        let digits = Array(text)
        guard digits.allSatisfy({ $0.isHexDigit }) else { return nil }

        func value(_ characters: [Character]) -> Double? {
            guard let raw = UInt8(String(characters), radix: 16) else { return nil }
            return Double(raw) / 255
        }

        switch digits.count {
        case 3:
            guard let r = value([digits[0], digits[0]]),
                  let g = value([digits[1], digits[1]]),
                  let b = value([digits[2], digits[2]]) else { return nil }
            self.init(red: r, green: g, blue: b)
        case 6:
            guard let r = value([digits[0], digits[1]]),
                  let g = value([digits[2], digits[3]]),
                  let b = value([digits[4], digits[5]]) else { return nil }
            self.init(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    public var hex: String {
        func channel(_ value: Double) -> String {
            String(format: "%02X", Int((min(max(value, 0), 1) * 255).rounded()))
        }
        return "#\(channel(red))\(channel(green))\(channel(blue))"
    }
}

/// Perceptual colour mixing, matching the prototype's
/// `color-mix(in oklab, <chapter colour>, <canvas> <amount>%)`.
///
/// Oklab rather than plain sRGB interpolation because that is what the design
/// was drawn against: mixing a mid-tone chapter 26% toward `#1C1C1E` in sRGB
/// comes out noticeably muddier than the same step in Oklab.
public enum ColorMix {

    /// `amount` is how far to move from `color` toward `other`, 0…1.
    public static func oklab(_ color: SRGBColor, toward other: SRGBColor, amount: Double) -> SRGBColor {
        let t = min(max(amount, 0), 1)
        // Short-circuit the endpoints: a round trip through Oklab is lossy in
        // the last bit, and an untouched colour should stay untouched.
        if t == 0 { return color }
        if t == 1 { return other }
        let a = toOklab(color)
        let b = toOklab(other)
        return fromOklab((
            L: a.L + (b.L - a.L) * t,
            a: a.a + (b.a - a.a) * t,
            b: a.b + (b.b - a.b) * t
        ))
    }

    // MARK: - sRGB <-> Oklab (Björn Ottosson's matrices)

    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func delinearize(_ channel: Double) -> Double {
        channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(channel, 1 / 2.4) - 0.055
    }

    private static func toOklab(_ color: SRGBColor) -> (L: Double, a: Double, b: Double) {
        let r = linearize(color.red)
        let g = linearize(color.green)
        let b = linearize(color.blue)

        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

        return (
            L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func fromOklab(_ lab: (L: Double, a: Double, b: Double)) -> SRGBColor {
        let l = pow(lab.L + 0.3963377774 * lab.a + 0.2158037573 * lab.b, 3)
        let m = pow(lab.L - 0.1055613458 * lab.a - 0.0638541728 * lab.b, 3)
        let s = pow(lab.L - 0.0894841775 * lab.a - 1.2914855480 * lab.b, 3)

        func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
        return SRGBColor(
            red: clamp(delinearize(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)),
            green: clamp(delinearize(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)),
            blue: clamp(delinearize(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
        )
    }
}
