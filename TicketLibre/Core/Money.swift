import Foundation

enum Money {
    static let limit: Int64 = 10_000_000_000
    static func parse(_ input: String) -> Int64? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        for symbol in ["€", "$", "£", "EUR", "USD", "GBP", " ", "\u{00A0}"] { s = s.replacingOccurrences(of: symbol, with: "") }
        if s.contains(",") && s.contains(".") {
            if s.lastIndex(of: ",")! > s.lastIndex(of: ".")! {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else { s = s.replacingOccurrences(of: ",", with: "") }
        } else { s = s.replacingOccurrences(of: ",", with: ".") }
        guard s.range(of: #"^-?\d+(?:\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let d = Decimal(string: s, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        let n = NSDecimalNumber(decimal: d * 100)
        guard n.compare(NSDecimalNumber(value: -limit)) != .orderedAscending,
              n.compare(NSDecimalNumber(value: limit)) != .orderedDescending else { return nil }
        return n.int64Value
    }
    static func edit(_ cents: Int64) -> String {
        let d = Decimal(cents) / 100
        return NSDecimalNumber(decimal: d).stringValue.replacingOccurrences(of: ".", with: ",")
    }
    static func display(_ cents: Int64, currency: String = "EUR") -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.string(from: NSDecimalNumber(decimal: Decimal(cents) / 100)) ?? "\(edit(cents)) \(currency)"
    }
    // Signed integer arithmetic preserves every cent, including discount remainders.
    static func distribute(_ cents: Int64, among ids: [UUID]) -> [UUID: Int64] {
        guard !ids.isEmpty else { return [:] }
        let base = cents / Int64(ids.count)
        let remainder = cents % Int64(ids.count)
        var result: [UUID: Int64] = [:]
        for (index, id) in ids.enumerated() {
            result[id] = base + (Int64(index) < abs(remainder) ? (remainder < 0 ? -1 : 1) : 0)
        }
        return result
    }
    static func split(_ receipt: Receipt) -> [UUID: Int64] {
        let all = receipt.participants.map(\.id)
        var result = Dictionary(uniqueKeysWithValues: all.map { ($0, Int64(0)) })
        for item in receipt.items {
            let assigned = receipt.allocations.first { $0.itemID == item.id }?.participantIDs ?? []
            let ids = all.filter { assigned.contains($0) }
            for (id, amount) in distribute(item.cents, among: ids.isEmpty ? all : ids) { result[id, default: 0] += amount }
        }
        // Receipt-level VAT and other adjustments are shared by all participants.
        for (id, amount) in distribute(receipt.totalCents - receipt.itemSum, among: all) { result[id, default: 0] += amount }
        return result
    }
}
