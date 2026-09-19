import AppKit
import Combine
import Foundation
import LifeInWeeksCore

/// The app's single source of truth: what's on disk, what's derived from it,
/// and the view state the main window drives.
///
/// `ObservableObject` rather than `@Observable`, because Observation needs
/// macOS 14 and PRD §8 pins the deployment target at 13.
@MainActor
final class AppModel: ObservableObject {

    // MARK: - Loaded state

    @Published private(set) var archive: Archive?
    @Published private(set) var config: LifeConfig?
    @Published private(set) var timeline: Timeline?
    @Published private(set) var chapters: [Chapter] = []
    @Published private(set) var loadError: String?

    /// Notes indexed by week so the grid can look one up per cell without
    /// hashing a date 4,700 times a frame.
    private(set) var notesByWeek: [WeekNote?] = []
    private(set) var noteCount = 0

    // MARK: - Derived

    @Published private(set) var layout: RowLayout?
    @Published private(set) var resolution: ChapterResolution?
    @Published private(set) var today: CalendarDate = .today()
    @Published private(set) var currentWeek: Int = 0

    // MARK: - View state

    @Published var rowMode: RowMode = Preferences.rowMode {
        didSet {
            guard rowMode != oldValue else { return }
            Preferences.rowMode = rowMode
            rebuildLayout()
        }
    }

    @Published var zoom: ZoomLevel = Preferences.zoom {
        didSet {
            guard zoom != oldValue else { return }
            Preferences.zoom = zoom
        }
    }

    @Published var chaptersOpen = false
    @Published var hoveredWeek: Int?
    @Published var tooltipPoint: CGPoint?
    @Published var highlightedChapterID: String?
    @Published var dragAnchor: Int?
    @Published var selection: ClosedRange<Int>?
    @Published var isDragging = false
    @Published var selectedWeek: Int?

    // Search
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            runSearch()
        }
    }
    @Published private(set) var searchResults: [NoteSearchResult] = []
    /// True while the inspector is showing the result list rather than a week.
    /// Editing the query always comes back to the list; opening a result, or
    /// clicking a cell in the grid, leaves it for the week itself.
    @Published private(set) var showingSearchResults = false

    // Week editing
    @Published var isEditing = false
    @Published var draftNote = ""
    @Published var draftEmoji = ""

    // New-chapter popover
    @Published var popoverOpen = false
    @Published var draftTitle = ""
    @Published var draftColor = ChapterPalette.defaultColor
    /// Set when the popover is editing an existing chapter rather than making one.
    @Published var editingChapterID: String?
    /// Set when the draft would stack chapters deeper than the grid can split a
    /// cell; the sheet shows it and refuses to commit.
    @Published var chapterDraftError: String?

    private var watcher: FileWatcher?

    // MARK: - Lifecycle

    var hasStorageRoot: Bool { archive != nil }

    init() {
        if let root = Preferences.storageRoot {
            open(root: root)
        }
    }

    /// Points the app at a storage root, creating the layout if it's new.
    func adopt(root: URL, seeding config: LifeConfig?) {
        do {
            let archive = Archive(paths: ArchivePaths(root: root))
            if let config {
                try archive.createIfNeeded(config: config)
            }
            Preferences.storageRoot = root
            open(root: root)
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Rewrites `config.yaml` from the settings window, then reloads so the
    /// timeline, layout and chapter spans are all rebuilt off the new facts.
    func updateConfig(name: String, birthDate: CalendarDate, endAge: Int) {
        guard let archive else { return }
        do {
            try archive.save(config: LifeConfig(name: name, birthDate: birthDate, endAge: endAge))
            reload()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Points the app at a different storage folder. The current config seeds
    /// it only if it has no `config.yaml` yet — an existing archive is adopted
    /// as it stands, never overwritten.
    func changeStorageRoot(to root: URL) {
        guard root != archive?.paths.root else { return }
        cancelEditing()
        cancelChapterDraft()
        selectedWeek = nil
        adopt(root: root, seeding: config)
    }

    private func open(root: URL) {
        let archive = Archive(paths: ArchivePaths(root: root))
        self.archive = archive
        reload()
        startWatching()
    }

    /// Re-reads everything from disk. Cheap at this scale (PRD §5.3), and safe
    /// to call from the file watcher.
    func reload() {
        guard let archive else { return }
        do {
            let snapshot = try archive.load()
            loadError = nil
            config = snapshot.config
            chapters = snapshot.chapters

            let timeline = Timeline(config: snapshot.config)
            self.timeline = timeline
            today = .today()
            currentWeek = timeline.clampedWeekIndex(containing: today)

            indexNotes(snapshot.notes, timeline: timeline)
            refreshSearchResults()
            rebuildLayout()
            rebuildResolution()

            // `end_age` can shrink under an existing selection.
            if let week = selectedWeek, week > timeline.lastWeekIndex { selectedWeek = nil }
            if selectedWeek == nil { selectedWeek = currentWeek }
            // An edit in flight owns the draft; a reload must not stomp on it.
            if !isEditing { syncDraftToSelection() }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func startWatching() {
        guard let archive else { return }
        let watcher = FileWatcher { [weak self] in
            Task { @MainActor in self?.reloadNotesOnly() }
        }
        watcher.start(watching: archive.paths.weeksURL)
        self.watcher = watcher
    }

    /// The watcher only covers `weeks/`, so a change there can't have altered
    /// config or chapters — re-scanning notes alone keeps the grid steady.
    private func reloadNotesOnly() {
        guard let archive, let timeline else { return }
        indexNotes(archive.loadNotes(), timeline: timeline)
        refreshSearchResults()
        if !isEditing { syncDraftToSelection() }
        objectWillChange.send()
    }

    private func indexNotes(_ notes: [CalendarDate: WeekNote], timeline: Timeline) {
        var indexed = [WeekNote?](repeating: nil, count: timeline.weekCount)
        for (monday, note) in notes {
            guard let index = timeline.weekIndex(containing: monday) else { continue }
            indexed[index] = note
        }
        notesByWeek = indexed
        noteCount = notes.count
    }

    private func rebuildLayout() {
        guard let timeline else { return }
        layout = timeline.layout(mode: rowMode)
    }

    private func rebuildResolution() {
        guard let timeline else { return }
        resolution = ChapterResolution(chapters: chapters, timeline: timeline,
                                       openEnd: timeline.monday(of: currentWeek))
    }

    // MARK: - Search

    /// Whether a query is live — what puts the back bar above a week's note.
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Re-runs the query over changed notes without pulling the user back to
    /// the list — an edit to the open week shouldn't close it.
    private func refreshSearchResults() {
        guard isSearching else { return }
        searchResults = NoteSearch.run(query: searchText, notes: notesByWeek)
    }

    private func runSearch() {
        guard isSearching else {
            searchResults = []
            showingSearchResults = false
            return
        }
        searchResults = NoteSearch.run(query: searchText, notes: notesByWeek)
        showingSearchResults = true
    }

    /// Opens a match without disturbing the query, so Back returns to the same
    /// list the result came from.
    func openSearchResult(week: Int) {
        select(week: week)
    }

    /// Goes back to the list. An edit in flight is left as it is rather than
    /// cancelled — returning to that same week finds the draft still there.
    func returnToSearchResults() {
        guard isSearching else { return }
        showingSearchResults = true
    }

    func clearSearch() {
        searchText = ""
    }

    // MARK: - Week lookups

    func note(at week: Int) -> WeekNote? {
        guard week >= 0, week < notesByWeek.count else { return nil }
        return notesByWeek[week]
    }

    func monday(of week: Int) -> CalendarDate? {
        timeline.map { $0.monday(of: week) }
    }

    func isFuture(week: Int) -> Bool { week > currentWeek }

    /// `weeks/2011-06-13.md`
    func relativePath(of week: Int) -> String? {
        guard let archive, let monday = monday(of: week) else { return nil }
        return archive.paths.relativeWeekPath(monday: monday)
    }

    // MARK: - Selection

    func select(week: Int) {
        // Picking a week — from the grid or from a result — is what leaves the
        // result list, even when it's the week already selected.
        showingSearchResults = false
        guard week != selectedWeek else { return }
        cancelEditing()
        selectedWeek = week
        syncDraftToSelection()
    }

    func selectCurrentWeek() {
        select(week: currentWeek)
    }

    private func syncDraftToSelection() {
        guard let week = selectedWeek, let note = note(at: week) else {
            draftNote = ""
            draftEmoji = ""
            return
        }
        draftNote = note.body.trimmingCharacters(in: .newlines)
        draftEmoji = note.emoji ?? ""
    }

    // MARK: - Editing a week

    func beginEditing() {
        syncDraftToSelection()
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        syncDraftToSelection()
    }

    /// Writes the week's file — or deletes it when both fields end up empty,
    /// since a week only has a file while it has content (PRD §5.1).
    func saveEdit() {
        guard let week = selectedWeek, let monday = monday(of: week) else { return }
        let emoji = draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)

        var note = note(at: week) ?? WeekNote()
        note.emoji = emoji.isEmpty ? nil : emoji
        note.body = body.isEmpty ? "" : "\n" + body + "\n"
        if note.tags.isEmpty { note.tags = [WeekNote.tag] }

        if persist(note: note, week: week, monday: monday) { isEditing = false }
    }

    /// Writes just the emoji, leaving the body on disk untouched — the
    /// inspector header's emoji field edits a week in place, without the
    /// editor (PRD §5.1).
    func saveEmoji(_ emoji: String) {
        guard let week = selectedWeek, let monday = monday(of: week) else { return }
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

        var note = note(at: week) ?? WeekNote()
        guard (note.emoji ?? "") != trimmed else { return }
        note.emoji = trimmed.isEmpty ? nil : trimmed
        if note.tags.isEmpty { note.tags = [WeekNote.tag] }

        _ = persist(note: note, week: week, monday: monday)
    }

    /// Saves a note to disk and folds the result back into the loaded weeks.
    /// Returns false when the write failed, so the caller can stay put.
    @discardableResult
    private func persist(note: WeekNote, week: Int, monday: CalendarDate) -> Bool {
        guard let archive else { return false }
        do {
            let saved = try archive.save(note: note, monday: monday)
            if week < notesByWeek.count { notesByWeek[week] = saved }
            noteCount = notesByWeek.reduce(into: 0) { count, note in
                if note != nil { count += 1 }
            }
            refreshSearchResults()
            syncDraftToSelection()
            objectWillChange.send()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    /// The menu bar's quick note: a timestamped line appended to this week.
    func appendQuickNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let archive, let monday = monday(of: currentWeek) else { return }
        do {
            let note = try archive.appendQuickNote(trimmed, monday: monday, stamp: quickNoteStamp())
            if currentWeek < notesByWeek.count {
                let wasEmpty = notesByWeek[currentWeek] == nil
                notesByWeek[currentWeek] = note
                if wasEmpty { noteCount += 1 }
            }
            refreshSearchResults()
            if !isEditing { syncDraftToSelection() }
            objectWillChange.send()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// `Sun 21:04` — enough to place the line within the week without repeating
    /// the date already carried by the filename.
    private func quickNoteStamp(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE HH:mm")
        return formatter.string(from: now)
    }

    func revealInFinder(week: Int) {
        guard let archive, let monday = monday(of: week) else { return }
        let url = archive.paths.weekURL(monday: monday)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([archive.paths.weeksURL])
        }
    }

    // MARK: - Chapters

    /// Opens the popover for a new chapter over the dragged range.
    func beginNewChapter(over range: ClosedRange<Int>) {
        selection = range
        editingChapterID = nil
        draftTitle = ""
        draftColor = ChapterPalette.defaultColor
        // Checked on opening, not just on commit: the range is fixed by the
        // drag, so a doomed draft says so before anything is typed into it.
        chapterDraftError = overlapRejection(for: chapters + [draftChapter(over: range, id: "draft")])
        popoverOpen = true
    }

    /// Opens the same popover to edit an existing chapter (sidebar context menu).
    func beginEditingChapter(id: String) {
        guard let chapter = chapters.first(where: { $0.id == id }),
              let resolution, let span = resolution.span(of: id) else { return }
        selection = span
        editingChapterID = id
        draftTitle = chapter.title
        draftColor = chapter.color
        chapterDraftError = nil
        popoverOpen = true
    }

    func cancelChapterDraft() {
        popoverOpen = false
        editingChapterID = nil
        chapterDraftError = nil
        selection = nil
        dragAnchor = nil
    }

    func commitChapterDraft() {
        guard let range = selection, let timeline else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = timeline.monday(of: range.lowerBound)
        let end = timeline.monday(of: range.upperBound)

        var proposed = chapters
        if let id = editingChapterID, let index = proposed.firstIndex(where: { $0.id == id }) {
            proposed[index].title = title.isEmpty ? Chapter.untitled : title
            proposed[index].color = draftColor
            proposed[index].start = start
            proposed[index].end = end
        } else {
            proposed.append(draftChapter(over: range,
                                         id: Chapter.makeID(avoiding: Set(chapters.map(\.id)))))
        }

        if let rejection = overlapRejection(for: proposed) {
            chapterDraftError = rejection
            return
        }
        chapters = proposed
        persistChapters()
        cancelChapterDraft()
    }

    /// The chapter the current draft would write, over `range`.
    private func draftChapter(over range: ClosedRange<Int>, id: String) -> Chapter {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return Chapter(
            id: id,
            start: timeline?.monday(of: range.lowerBound) ?? .today(),
            end: timeline?.monday(of: range.upperBound),
            color: draftColor,
            title: title.isEmpty ? Chapter.untitled : title
        )
    }

    /// Why a proposed set of chapters can't be saved, or `nil` if it can. Only
    /// depth is checked: past `maxOverlap` a cell has no legible way to show
    /// every chapter covering it (README §4).
    private func overlapRejection(for proposed: [Chapter]) -> String? {
        guard let timeline else { return nil }
        let trial = ChapterResolution(chapters: proposed, timeline: timeline,
                                      openEnd: timeline.monday(of: currentWeek))
        guard trial.deepestOverlap > ChapterResolution.maxOverlap else { return nil }
        return "A week can be in at most \(ChapterResolution.maxOverlap) chapters. "
            + "This range already has that many."
    }

    func deleteChapter(id: String) {
        chapters.removeAll { $0.id == id }
        if highlightedChapterID == id { highlightedChapterID = nil }
        persistChapters()
    }

    private func persistChapters() {
        chapters.sort { ($0.startMonday, $0.id) < ($1.startMonday, $1.id) }
        rebuildResolution()
        guard let archive else { return }
        do {
            try archive.save(chapters: chapters)
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Toolbar

    /// Whole weeks left in the grid after the one being lived. `nil` until an
    /// archive is loaded, and zero once the end age is behind you — the grid
    /// stops at `end_age`, so this counts to that edge, not to a real forecast.
    var weeksRemaining: Int? {
        guard let timeline else { return nil }
        return max(0, timeline.lastWeekIndex - currentWeek)
    }

    /// `2,847 weeks remaining, more or less. What will you do with the time?`
    var weeksRemainingLine: String? {
        guard let remaining = weeksRemaining else { return nil }
        let count = NumberFormatter.localizedString(
            from: NSNumber(value: remaining), number: .decimal)
        let noun = remaining == 1 ? "week" : "weeks"
        return "\(count) \(noun) remaining, more or less. What will you do with the time?"
    }

    // MARK: - Status bar

    var statusLeft: String {
        guard let archive else { return "" }
        let notes = noteCount == 1 ? "1 note" : "\(noteCount) notes"
        let chapterCount = chapters.count == 1 ? "1 chapter" : "\(chapters.count) chapters"
        return "\(archive.paths.displayWeeksPath) · \(notes) · \(chapterCount)"
    }

    var statusRight: String {
        guard let timeline else { return "" }
        let count = NumberFormatter.localizedString(
            from: NSNumber(value: timeline.weekCount), number: .decimal)
        return "\(count) weeks · \(timeline.birthWeekMonday.iso) → \(timeline.endWeekMonday.iso)"
    }
}
