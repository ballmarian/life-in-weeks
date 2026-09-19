import LifeInWeeksCore
import SwiftUI

/// The chapters rail: a 40px strip by default, 222px when opened (README §3).
struct ChaptersSidebar: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if model.chaptersOpen {
                expanded
            } else {
                collapsed
            }
        }
        .frame(width: model.chaptersOpen ? 222 : 40)
        .background(palette.sidebar)
        .overlay(alignment: .trailing) { Hairline(axis: .vertical) }
    }

    // MARK: - Collapsed

    private var collapsed: some View {
        VStack(spacing: 10) {
            disclosureButton(symbol: "chevron.right")
            Text("CHAPTERS")
                .font(Typography.ui(10, .semibold))
                .tracking(0.8)
                .foregroundColor(palette.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 20, height: 90)
            Spacer()
        }
        .padding(.top, 13)
    }

    // MARK: - Expanded

    private var expanded: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                disclosureButton(symbol: "chevron.down")
                Text("CHAPTERS")
                    .font(Typography.ui(10, .semibold))
                    .tracking(0.6)
                    .foregroundColor(palette.tertiary)
                Text("\(model.chapters.count)")
                    .font(Typography.mono(10))
                    .foregroundColor(palette.quaternary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)

            if model.chapters.isEmpty {
                Text("Drag across the grid to mark a chapter.")
                    .font(Typography.ui(11))
                    .foregroundColor(palette.placeholder)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        // Chronological, whatever order blocks.yaml holds them
                        // in: the list reads top to bottom like the grid does.
                        ForEach(chronological) { chapter in
                            row(chapter)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    /// Oldest start first, and among chapters that start together the one that
    /// ends first — so a short chapter nested in a long one reads as inside it.
    /// An ongoing chapter sorts last of its start, since it runs to now.
    private var chronological: [Chapter] {
        model.chapters.sorted { lhs, rhs in
            if lhs.startMonday != rhs.startMonday { return lhs.startMonday < rhs.startMonday }
            switch (lhs.endMonday, rhs.endMonday) {
            case let (left?, right?): return left < right
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.title < rhs.title
            }
        }
    }

    private func row(_ chapter: Chapter) -> some View {
        let isHighlighted = model.highlightedChapterID == chapter.id
        return HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: chapter.color))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(palette.swatchHairline, lineWidth: 1))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(chapter.title)
                    .font(Typography.ui(12, .medium))
                    .foregroundColor(palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(chapter.rangeDisplay)
                    .font(Typography.mono(10))
                    .foregroundColor(palette.quaternary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(isHighlighted ? palette.sidebarHover : .clear))
        .contentShape(Rectangle())
        // Hovering a row highlights that chapter across the grid (README §5).
        .onHover { inside in
            model.highlightedChapterID = inside ? chapter.id : nil
        }
        .contextMenu {
            Button("Edit chapter…") { model.beginEditingChapter(id: chapter.id) }
            Button("Delete chapter", role: .destructive) { model.deleteChapter(id: chapter.id) }
        }
    }

    private func disclosureButton(symbol: String) -> some View {
        Button {
            model.chaptersOpen.toggle()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.secondary)
                .frame(width: 18, height: 18)
                .background(RoundedRectangle(cornerRadius: 4).fill(palette.controlFill))
        }
        .buttonStyle(.plain)
    }
}
