import Foundation

/// How a statement movement should be counted.
public enum StatementEntryKind: String, Equatable {
    /// Money out — counts towards spending.
    case expense
    /// Money in — counts towards income.
    case income
    /// A real line on the statement that should be excluded from both income
    /// and expense totals (see `StatementClassifier`).
    case ignored
}

/// Shared rules deciding whether a statement movement is expense, income or
/// `ignored`, used by both the PDF (`StatementParser`) and CSV
/// (`StatementCSVParser`) readers so the two formats agree.
///
/// "Ignored" movements are genuine statement lines that are neither spending
/// nor income:
/// - the monthly **credit-card bill settlement** (`PAGO RECIBO …` on the card,
///   `TARJ.CRDTO …` on the account) — counting it would double-count the
///   individual card purchases;
/// - **transfers between the holder's own accounts** (`TRASPASO A …`,
///   `TRANSF. …`, English `… Transfer …`);
/// - **pension contributions** (`… BASKEPENSIONES`, `EPSV`, `PENSION`);
/// - **zero-amount** bookkeeping lines (e.g. interest liquidation at `0,00`).
public enum StatementClassifier {

    /// `true` when the movement should be excluded from income and expense
    /// totals, given its `description` and *signed* `amount`.
    public static func isIgnored(description: String, amount: Decimal) -> Bool {
        if amount == 0 { return true }
        let s = normalize(description)
        return isCardSettlement(s) || isOwnAccountTransfer(s) || isPensionContribution(s)
    }

    // MARK: - Rules

    /// A full 15–16 digit card number alongside a card-bill keyword marks the
    /// monthly settlement. The masked PAN printed on every card-statement row
    /// (`******4014350600`, only 10 digits) deliberately does not match.
    private static let cardNumberRegex = try! NSRegularExpression(pattern: "\\d{15,16}")

    private static func isCardSettlement(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        guard cardNumberRegex.firstMatch(in: s, range: range) != nil else { return false }
        return s.contains("PAGO RECIBO") || s.contains("TARJ")
    }

    private static func isOwnAccountTransfer(_ s: String) -> Bool {
        s.contains("TRASPASO")          // TRASPASO A …
            || s.contains("TRANSF")     // TRANSF. / TRANSFERENCIA …
            || s.contains("TRANSFER")   // English "… Transfer …"
    }

    private static func isPensionContribution(_ s: String) -> Bool {
        s.contains("BASKEPENSIONES") || s.contains("PENSION") || s.contains("EPSV")
    }

    // MARK: - Helpers

    /// Upper-cased and diacritic-folded, so the keyword checks are accent- and
    /// case-insensitive (`Pensión` → `PENSION`).
    private static func normalize(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil).uppercased()
    }
}
