import Foundation

/// Locale-aware parser for dates found in statements, receipts and invoices.
///
/// Defaults to day-first European notation and understands ISO dates and
/// month names in Spanish, Italian, Basque (Euskera) and English. Returns a
/// `Date` anchored at noon UTC so the calendar day is stable regardless of the
/// reader's time zone.
public enum DocumentDateParser {

    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Parses the first date found in `raw`, or `nil` if none is recognised.
    public static func parse(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // ISO first so that yyyy-mm-dd is not misread as a day-first date.
        return parseISO(text)
            ?? parseNumeric(text)
            ?? parseDayMonthNameYear(text)
            ?? parseMonthNameDayYear(text)
    }

    // MARK: - Strategies

    /// yyyy-mm-dd
    private static func parseISO(_ text: String) -> Date? {
        guard let g = firstMatch(text, "(\\d{4})-(\\d{2})-(\\d{2})") else { return nil }
        return makeDate(year: Int(g[1])!, month: Int(g[2])!, day: Int(g[3])!)
    }

    /// dd[/.-]mm[/.-]yy(yy) — day-first, with a fallback swap when the second
    /// field is the only one that can be a month (US mm/dd input).
    private static func parseNumeric(_ text: String) -> Date? {
        guard let g = firstMatch(text, "(\\d{1,2})[/.\\-](\\d{1,2})[/.\\-](\\d{2,4})") else { return nil }
        var day = Int(g[1])!
        var month = Int(g[2])!
        if month > 12 && day <= 12 { swap(&day, &month) }
        return makeDate(year: normalizeYear(Int(g[3])!), month: month, day: day)
    }

    /// dd <month name> yyyy  (e.g. "14 de marzo de 2026", "14 mar 2026")
    private static func parseDayMonthNameYear(_ text: String) -> Date? {
        guard let g = firstMatch(text, "(\\d{1,2})\\s+(?:de\\s+)?(\\p{L}+)\\.?\\s+(?:de\\s+)?(\\d{4})"),
              let month = monthNumber(g[2]) else { return nil }
        return makeDate(year: Int(g[3])!, month: month, day: Int(g[1])!)
    }

    /// <month name> dd, yyyy  (e.g. "March 14, 2026", "Mar 14 2026")
    private static func parseMonthNameDayYear(_ text: String) -> Date? {
        guard let g = firstMatch(text, "(\\p{L}+)\\.?\\s+(\\d{1,2}),?\\s+(\\d{4})"),
              let month = monthNumber(g[1]) else { return nil }
        return makeDate(year: Int(g[3])!, month: month, day: Int(g[2])!)
    }

    // MARK: - Helpers

    private static func normalizeYear(_ y: Int) -> Int { y < 100 ? 2000 + y : y }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        guard let date = utcCalendar.date(from: c) else { return nil }
        // Reject normalised impossible dates (e.g. 30 February).
        let r = utcCalendar.dateComponents([.year, .month, .day], from: date)
        guard r.year == year, r.month == month, r.day == day else { return nil }
        return date
    }

    private static func firstMatch(_ text: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    private static func monthNumber(_ word: String) -> Int? {
        let key = word.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return monthMap[key]
    }

    /// Month names and common abbreviations across Spanish, Italian, Basque
    /// and English. Overlapping forms (e.g. "mar", "ago") map to the same
    /// month in every language, so the merge is unambiguous.
    private static let monthMap: [String: Int] = {
        var map: [String: Int] = [:]
        func add(_ n: Int, _ names: [String]) { names.forEach { map[$0] = n } }
        add(1, ["enero", "ene", "gennaio", "gen", "january", "jan", "urtarrila"])
        add(2, ["febrero", "feb", "febbraio", "february", "otsaila"])
        add(3, ["marzo", "mar", "march", "martxoa"])
        add(4, ["abril", "abr", "aprile", "apr", "april", "apirila"])
        add(5, ["mayo", "may", "maggio", "mag", "maiatza"])
        add(6, ["junio", "jun", "giugno", "giu", "june", "ekaina"])
        add(7, ["julio", "jul", "luglio", "lug", "july", "uztaila"])
        add(8, ["agosto", "ago", "august", "aug", "abuztua"])
        add(9, ["septiembre", "setiembre", "sep", "set", "settembre", "september", "sept", "iraila"])
        add(10, ["octubre", "oct", "ottobre", "ott", "october", "urria"])
        add(11, ["noviembre", "nov", "novembre", "november", "azaroa"])
        add(12, ["diciembre", "dic", "dicembre", "december", "dec", "abendua"])
        return map
    }()
}
