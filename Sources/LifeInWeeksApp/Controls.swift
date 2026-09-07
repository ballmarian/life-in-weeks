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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.ui(12, weight))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
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
    @Environment(\.palette) private var palette

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(palette.placeholder))
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .foregroundColor(palette.primary)
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.fieldFill))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.fieldHairline, lineWidth: 1))
    }
}
