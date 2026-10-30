import Foundation

/// A calendar day in the user's current time zone, identified by its "yyyy-MM-dd" string.
/// The id doubles as the note's file name, and sorts chronologically as a plain string.
struct Day: Hashable, Comparable, Identifiable {
    let id: String

    init(_ date: Date) {
        id = Day.formatter.string(from: date)
    }

    init?(id: String) {
        guard Day.formatter.date(from: id) != nil else { return nil }
        self.id = id
    }

    static var today: Day { Day(Date()) }

    var date: Date { Day.formatter.date(from: id) ?? Date() }

    func adding(days: Int) -> Day {
        Day(Calendar.current.date(byAdding: .day, value: days, to: date) ?? date)
    }

    /// "yyyy-MM", used to group the sidebar by month.
    var monthID: String { String(id.prefix(7)) }

    static func < (lhs: Day, rhs: Day) -> Bool { lhs.id < rhs.id }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
