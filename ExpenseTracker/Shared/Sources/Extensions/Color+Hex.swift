import SwiftUI

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexString = sanitized.hasPrefix("#") ? String(sanitized.dropFirst()) : sanitized

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let length = hexString.count
        let r: Double
        let g: Double
        let b: Double
        let a: Double

        switch length {
        case 6:
            r = Double((rgbValue >> 16) & 0xFF) / 255.0
            g = Double((rgbValue >> 8) & 0xFF) / 255.0
            b = Double(rgbValue & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgbValue >> 24) & 0xFF) / 255.0
            g = Double((rgbValue >> 16) & 0xFF) / 255.0
            b = Double((rgbValue >> 8) & 0xFF) / 255.0
            a = Double(rgbValue & 0xFF) / 255.0
        default:
            r = 0.5
            g = 0.5
            b = 0.5
            a = 1.0
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
