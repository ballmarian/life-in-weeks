import AppKit
import SwiftUI

/// The toolbar's segmented controls. Built rather than using SwiftUI's `Picker`,
/// because the design pins the track, segment, and shadow treatment exactly
/// (README §2) and the stock control doesn't offer them.
struct SegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var fixedSegmentWidth: CGFloat?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Typography.ui(12, isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? palette.primary : palette.secondary)
                        .frame(width: fixedSegmentWidth, height: 22)
                        .padding(.horizontal, fixedSegmentWidth == nil ? 13 : 0)
                        .background(segmentBackground(isSelected: isSelected))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(palette.controlFill))
    }

    @ViewBuilder
    private func segmentBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 5)
                .fill(palette.controlSelected)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        } else {
            Color.clear
        }
    }
}

/// The blue primary action (Save, Create, Edit week).
struct FilledButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color
    var height: CGFloat = 26
    var weight: Font.Weight = .medium
    /// Full-width by default, as the footer and sheets use it; the inspector's
    /// header button sizes to its label instead.
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.ui(12, weight))
            .foregroundColor(foreground)
            .frame(maxWidth: expands ? .infinity : nil)
            .padding(.horizontal, expands ? 0 : 10)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

/// A 1px separator in the separator token.
struct Hairline: View {
    var axis: Axis = .horizontal
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// A text field with the design's field treatment rather than the stock one.
struct StyledField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = Typography.ui(12.5)
    var height: CGFloat = 26
    var alignment: TextAlignment = .leading
    /// Set by a caller that needs to know when the field holds focus — the
    /// emoji field, which opens the Character Viewer on the way in.
    var focus: FocusState<Bool>.Binding?
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if let focus {
                field.focused(focus)
            } else {
                field
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 6).fill(palette.fieldFill))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.fieldHairline, lineWidth: 1))
    }

    private var field: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(palette.placeholder))
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .foregroundColor(palette.primary)
    }
}

/// The week's one-glyph emoji, sitting beside the date heading: the glyph
/// itself when the week has one, a dimmed smiley when it hasn't, and an
/// editable field either way.
///
/// Clicking (or tabbing) into it pops the system Character Viewer, which
/// inserts into whatever text field holds focus — so an emoji can be picked
/// from the standard palette, and still typed or pasted by hand.
///
/// The field empties itself on the way in and reports the first glyph that
/// lands, rather than editing the week's value in place: a pick always
/// replaces what was there, wherever the caret happened to sit, and the field
/// never has to talk a live editor out of a second glyph.
struct EmojiField: View {
    /// The week's emoji as it stands. The field never writes to it; it hands
    /// a pick to `onPick` and waits to be given the new value back.
    let emoji: String
    let onPick: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var hovering = false
    @Environment(\.palette) private var palette

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .multilineTextAlignment(.center)
            .frame(width: 26)
            // An SF Symbol doesn't survive a field's `prompt`, so the dimmed
            // smiley is drawn over the empty field instead.
            .overlay {
                if text.isEmpty {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 15))
                        .foregroundColor(palette.placeholder)
                        .allowsHitTesting(false)
                }
            }
            // Clearing the week's emoji, which the picker itself can't do.
            .overlay(alignment: .topTrailing) {
                if !emoji.isEmpty, hovering || focused {
                    Button {
                        focused = false
                        onPick("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(palette.tertiary)
                            .background(Circle().fill(palette.sidebar))
                    }
                    .buttonStyle(.plain)
                    .help("Remove this week's emoji")
                    .offset(x: 5, y: -3)
                }
            }
            .onHover { hovering = $0 }
            .focused($focused)
            .help("Click to pick an emoji for this week")
            .onAppear { text = emoji }
            .onChange(of: emoji) { text = $0 }
            .onChange(of: focused) { isFocused in
                if isFocused {
                    // Empty on the way in, so whatever is picked stands alone
                    // and the placeholder shows what the field is waiting for.
                    text = ""
                    NSApp.orderFrontCharacterPalette(nil)
                } else {
                    // Left without picking: the week keeps what it had.
                    text = emoji
                }
            }
            .onChange(of: text) { value in
                // `Character` is a grapheme cluster, so one of them keeps an
                // emoji's variation selector, skin tone or ZWJ sequence intact
                // (README §7's "max 2 characters" counts UTF-16 units).
                guard focused, let glyph = value.first else { return }
                text = String(glyph)
                // Reported before focus goes, so leaving the field restores
                // the week's new emoji rather than briefly the old one.
                onPick(text)
                focused = false
            }
    }
}

/// A full-width row that lights up under the cursor, painting edge to edge
/// rather than inside a rounded well: the inspector's back bar, a search result.
struct HoverRowButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hovering ? palette.primary.opacity(0.06) : .clear)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onHover { hovering = $0 }
    }
}

/// A borderless square for an SF Symbol action (the menu bar's gear), with the
/// same hover surface the inspector's note block uses.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 24
    @Environment(\.palette) private var palette
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(hovering ? palette.primary : palette.tertiary)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? palette.primary.opacity(0.08) : .clear))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
