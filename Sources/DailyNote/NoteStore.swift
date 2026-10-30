import AppKit
import Foundation

/// Owns the notes folder: which day is open, its text, and the list of days that have notes.
/// Each day is a plain Markdown file named `yyyy-MM-dd.md`. Edits autosave shortly after typing stops.
@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var day: Day
    @Published private(set) var today: Day
    @Published private(set) var folder: URL
    @Published var errorMessage: String?
    @Published var text = "" {
        didSet {
            if !isLoading && text != oldValue { markEdited() }
        }
    }

    /// Days that have a file on disk, mapped to a one-line preview of their contents.
    @Published private var notes: [Day: String] = [:]

    private var isLoading = false
    private var isDirty = false
    private var lastEdit = Date.distantPast
    private var saveTask: Task<Void, Never>?
    private var clock: Timer?

    private static let folderKey = "notesFolder"

    static var defaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Daily Notes", isDirectory: true)
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.folderKey)
        folder = saved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
        today = .today
        day = .today

        ensureFolder()
        refreshIndex()
        load(day)

        // Roll over to the new day's blank page after midnight.
        clock = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForNewDay(force: false) }
        }
    }

    // MARK: - Days

    /// Days with notes, plus today and the open day, newest first.
    var days: [Day] {
        Set(notes.keys).union([today, day]).sorted(by: >)
    }

    var previousDay: Day? { days.first { $0 < day } }
    var nextDay: Day? { days.last { $0 > day } }

    func preview(for day: Day) -> String? { notes[day] }
    func hasNote(_ day: Day) -> Bool { notes[day] != nil }

    struct MonthSection: Identifiable {
        let id: String
        let title: String
        var days: [Day]
    }

    var sections: [MonthSection] {
        var result: [MonthSection] = []
        for d in days {
            if result.last?.id == d.monthID {
                result[result.count - 1].days.append(d)
            } else {
                let title = d.date.formatted(.dateTime.month(.wide).year())
                result.append(MonthSection(id: d.monthID, title: title, days: [d]))
            }
        }
        return result
    }

    // MARK: - Navigation

    func open(_ target: Day) {
        guard target != day else { return }
        flush()
        load(target)
    }

    func goToToday() { open(today) }
    func goToPrevious() { if let d = previousDay { open(d) } }
    func goToNext() { if let d = nextDay { open(d) } }

    // MARK: - Saving

    private func markEdited() {
        isDirty = true
        lastEdit = Date()
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes pending edits to disk immediately.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty else { return }
        isDirty = false
        write(text, for: day)
    }

    private func write(_ contents: String, for day: Day) {
        let url = fileURL(for: day)
        let isBlank = contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        do {
            if isBlank {
                // Don't leave empty files behind for days with nothing written.
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                notes[day] = nil
            } else {
                ensureFolder()
                try contents.write(to: url, atomically: true, encoding: .utf8)
                notes[day] = Self.preview(of: contents)
            }
        } catch {
            isDirty = true
            errorMessage = "\(url.lastPathComponent) could not be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Loading

    private func load(_ target: Day) {
        isLoading = true
        day = target
        text = read(target)
        isLoading = false
        isDirty = false
    }

    private func read(_ day: Day) -> String {
        var encoding = String.Encoding.utf8
        return (try? String(contentsOf: fileURL(for: day), usedEncoding: &encoding)) ?? ""
    }

    private func refreshIndex() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var found: [Day: String] = [:]
        for name in names where name.hasSuffix(".md") {
            guard let d = Day(id: String(name.dropLast(3))) else { continue }
            found[d] = Self.preview(of: read(d))
        }
        notes = found
    }

    /// Called when the app comes to the front: pick up the new day and any edits made outside the app.
    func refresh() {
        checkForNewDay(force: true)
        refreshIndex()
        guard !isDirty else { return }
        let onDisk = read(day)
        if onDisk != text {
            isLoading = true
            text = onDisk
            isLoading = false
        }
    }

    /// If the date has changed and today's page is open, move to the new day's blank page.
    /// Unless forced, waits until the user hasn't typed for a couple of minutes, so a note
    /// being written across midnight isn't yanked away mid-sentence.
    private func checkForNewDay(force: Bool) {
        let now = Day.today
        guard now != today else { return }
        let wasOnToday = day == today
        if wasOnToday && !force && Date().timeIntervalSince(lastEdit) < 120 { return }
        today = now
        if wasOnToday { open(now) }
    }

    // MARK: - Files

    func fileURL(for day: Day) -> URL {
        folder.appendingPathComponent("\(day.id).md")
    }

    func setFolder(_ url: URL) {
        flush()
        folder = url
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        ensureFolder()
        refreshIndex()
        load(day)
    }

    func reveal(_ day: Day) {
        let url = fileURL(for: day)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    func moveToTrash(_ target: Day) {
        if target == day {
            saveTask?.cancel()
            isDirty = false
        }
        do {
            try FileManager.default.trashItem(at: fileURL(for: target), resultingItemURL: nil)
            notes[target] = nil
        } catch {
            errorMessage = "\(target.id).md could not be moved to the Trash: \(error.localizedDescription)"
        }
        if target == day { load(today) }
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// First non-empty line, without leading Markdown markers.
    private static func preview(of contents: String) -> String {
        let line = contents.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#-*>[] \t")) }
            .first { !$0.isEmpty } ?? ""
        return String(line.prefix(80))
    }
}
