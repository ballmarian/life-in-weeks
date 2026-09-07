import Testing
@testable import LifeInWeeksCore

@Suite("Colour parsing and mixing")
struct ColorMixTests {

    @Test("Hex parsing accepts the forms blocks.yaml can contain")
    func hexParsing() {
        #expect(SRGBColor(hex: "#FFFFFF") == SRGBColor(red: 1, green: 1, blue: 1))
        #expect(SRGBColor(hex: "000000") == SRGBColor(red: 0, green: 0, blue: 0))
        #expect(SRGBColor(hex: "#fff") == SRGBColor(red: 1, green: 1, blue: 1))
        #expect(SRGBColor(hex: "  #4A90D9  ")?.hex == "#4A90D9")
    }

    @Test("A malformed colour degrades to nil rather than crashing")
    func hexRejection() {
        #expect(SRGBColor(hex: "#GGGGGG") == nil)
        #expect(SRGBColor(hex: "#12345") == nil)
        #expect(SRGBColor(hex: "") == nil)
        #expect(SRGBColor(hex: "rebeccapurple") == nil)
    }

    @Test("Hex round-trips through the parser")
    func hexRoundTrip() {
        for swatch in ChapterPalette.all {
            #expect(SRGBColor(hex: swatch)?.hex == swatch.uppercased())
        }
    }

    @Test("Mixing 0% and 100% are the endpoints")
    func mixEndpoints() {
        let chapter = SRGBColor(hex: "#C6E8C6")!
        let canvas = SRGBColor(hex: "#1C1C1E")!
        #expect(ColorMix.oklab(chapter, toward: canvas, amount: 0) == chapter)
        #expect(ColorMix.oklab(chapter, toward: canvas, amount: 1) == canvas)
    }

    @Test("Mixing toward the canvas darkens monotonically with the amount")
    func mixDarkensMonotonically() {
        let chapter = SRGBColor(hex: "#C6E8C6")!
        let canvas = SRGBColor(hex: "#1C1C1E")!
        // Ascending mix amount → progressively darker: L at 0.20 is the
        // brightest band, 0.40 the dimmest.
        var previous = 1.0
        for amount in ZoomLevel.allCases.map({ ChapterPalette.gridMix(for: $0) }).sorted() {
            let mixed = ColorMix.oklab(chapter, toward: canvas, amount: amount)
            let brightness = (mixed.red + mixed.green + mixed.blue) / 3
            #expect(brightness < previous, "mix \(amount) should be darker than the previous step")
            previous = brightness
        }
    }

    @Test("Out-of-range amounts clamp instead of extrapolating")
    func mixClamps() {
        let a = SRGBColor(hex: "#C6E8C6")!
        let b = SRGBColor(hex: "#1C1C1E")!
        #expect(ColorMix.oklab(a, toward: b, amount: -1) == a)
        #expect(ColorMix.oklab(a, toward: b, amount: 5) == b)
    }

    @Test("Per-zoom mix amounts match the design: bands darken as the grid densifies")
    func zoomMixAmounts() {
        #expect(ChapterPalette.gridMix(for: .small) == 0.40)
        #expect(ChapterPalette.gridMix(for: .medium) == 0.26)
        #expect(ChapterPalette.gridMix(for: .large) == 0.20)
    }
}
