import Foundation

/// Reads a delimited (CSV) bank-account export — e.g. a Kutxabank
/// "Movimientos de cuenta" sheet saved as CSV — into `StatementEntry`s.
///
/// The export has a header row (`fecha;concepto;fecha valor;importe;saldo`) and
/// one movement per row. Unlike the PDF path, the `importe` column carries an
/// explicit sign, so income vs. expense is taken directly from that sign;
/// `StatementClassifier` then flags settlements, own-account transfers, pension
/// contributions and zero-amount lines as `.ignored`. The running `saldo`
/// balance column is ignored.
///
/// Spanish locale exports use `;` as the delimiter (because the comma is the
/// decimal separator); tab- and comma-delimited files are also handled, and
/// double-quoted fields are honoured.
public enum StatementCSVParser {

    public static func parse(_ csv: String) -> [StatementEntry] {
        let rows = csv
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !rows.isEmpty else { return [] }

        let delimiter = detectDelimiter(in: rows)
        guard let headerIndex = rows.firstIndex(where: { isHeader($0) }) else { return [] }

        // Lower-cased, diacritic-folded header cells for column matching.
        let header = splitRow(rows[headerIndex], delimiter: delimiter).map { normalize($0).lowercased() }
        guard let dateCol = columnIndex(in: header, matching: { $0.contains("fecha") && !$0.contains("valor") })
                ?? columnIndex(in: header, matching: { $0.contains("fecha") }),
              let conceptCol = columnIndex(in: header, matching: { $0.contains("concepto") || $0.contains("descripcion") }),
              let amountCol = columnIndex(in: header, matching: { $0.contains("importe") || $0.contains("amount") })
        else { return [] }

        return rows[(headerIndex + 1)...].compactMap { row in
            parseRow(row, delimiter: delimiter, dateCol: dateCol, conceptCol: conceptCol, amountCol: amountCol)
        }
    }

    // MARK: - Row parsing

    private static func parseRow(
        _ row: String,
        delimiter: Character,
        dateCol: Int,
        conceptCol: Int,
        amountCol: Int
    ) -> StatementEntry? {
        let fields = splitRow(row, delimiter: delimiter)
        guard fields.count > max(dateCol, conceptCol, amountCol) else { return nil }

        guard let signed = MoneyParser.parse(fields[amountCol]) else { return nil }
        let description = fields[conceptCol].trimmingCharacters(in: .whitespaces)
        let date = DocumentDateParser.parse(fields[dateCol])

        let kind: StatementEntryKind
        if StatementClassifier.isIgnored(description: description, amount: signed) {
            kind = .ignored
        } else {
            kind = signed < 0 ? .expense : .income
        }

        return StatementEntry(date: date, amount: signed.absoluteValue, kind: kind, description: description)
    }

    // MARK: - Header / delimiter detection

    private static func isHeader(_ row: String) -> Bool {
        let l = normalize(row)
        return l.contains("IMPORTE") && (l.contains("CONCEPTO") || l.contains("DESCRIPCION"))
    }

    private static func detectDelimiter(in rows: [String]) -> Character {
        let sample = rows.first(where: isHeader) ?? rows[0]
        if sample.contains(";") { return ";" }
        if sample.contains("\t") { return "\t" }
        return ","
    }

    private static func columnIndex(in header: [String], matching predicate: (String) -> Bool) -> Int? {
        header.firstIndex(where: predicate)
    }

    // MARK: - CSV field splitting

    /// Splits one CSV row on `delimiter`, honouring double-quoted fields so an
    /// embedded delimiter inside quotes is preserved.
    private static func splitRow(_ row: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for ch in row {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == delimiter && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
    }
}
