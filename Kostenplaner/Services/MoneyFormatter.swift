import Foundation

enum MoneyFormatter {
    static let currency: FloatingPointFormatStyle<Double>.Currency = .currency(code: "EUR")
        .locale(Locale(identifier: "de_DE"))

    static func format(cents: Int) -> String {
        (Double(cents) / 100).formatted(currency)
    }

    static func parseToCents(_ input: String) -> Int {
        let normalized = input
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Double(normalized) ?? 0
        return Int((value * 100).rounded())
    }
}

extension Date {
    var monthKey: String {
        formatted(.dateTime.year().month(.twoDigits).locale(Locale(identifier: "de_DE")))
    }
}
