import Foundation

struct ParsedReceipt {
    var receipt: Receipt
    var warnings: [String]
}

enum ReceiptParser {
    static func matches(_ pattern: String, _ text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }
    static func substring(_ text: String, _ result: NSTextCheckingResult, group: Int = 0) -> String {
        guard group < result.numberOfRanges, let range = Range(result.range(at: group), in: text) else { return "" }
        return String(text[range])
    }
    static func date(in text: String) -> Date? {
        let patterns = [#"\b(\d{1,2}[/.-]\d{1,2}[/.-](?:20\d{2}|\d{2}))\b"#, #"\b(20\d{2}[/.-]\d{1,2}[/.-]\d{1,2})\b"#]
        for pattern in patterns {
            for hit in matches(pattern, text) {
                let raw = substring(text, hit, group: 1).replacingOccurrences(of: ".", with: "/").replacingOccurrences(of: "-", with: "/")
                let parts = raw.split(separator: "/").compactMap { Int($0) }
                guard parts.count == 3 else { continue }
                let yearFirst = parts[0] >= 2000
                let year = yearFirst ? parts[0] : (parts[2] < 100 ? 2000 + parts[2] : parts[2])
                let month = parts[1], day = yearFirst ? parts[2] : parts[0]
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(secondsFromGMT: 0)!
                let c = DateComponents(year: year, month: month, day: day, hour: 12)
                if let d = cal.date(from: c), cal.component(.year, from: d) == year,
                   cal.component(.month, from: d) == month, cal.component(.day, from: d) == day { return d }
            }
        }
        return nil
    }
    static func parse(_ text: String) -> ParsedReceipt {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var r = Receipt()
        r.rawText = text
        r.store = lines.prefix(5).first { $0.rangeOfCharacter(from: .letters) != nil && !$0.lowercased().contains("factura") } ?? ""
        r.category = Catalog.category(for: r.store)
        var warnings = ["Revisa los productos, la fecha y el total antes de guardar. El OCR local puede equivocarse."]
        if let d = date(in: text) { r.date = d } else { warnings.append("No se ha reconocido una fecha válida: selecciona la fecha de compra.") }
        if text.contains("USD") || text.contains("$") { r.currency = "USD" }
        if text.contains("GBP") || text.contains("£") { r.currency = "GBP" }
        var foundTotal = false
        let amountPattern = #"(-?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2})\s*(?:€|EUR|USD|GBP|\$|£)?\s*[A-Z]?\s*$"#
        let ignored = ["iva", "base imponible", "subtotal", "sub total", "tarjeta", "efectivo", "cambio", "entregado", "ahorro", "saldo", "a pagar con", "precio/kg", "precio /", "nif", "cif", "telefono", "tel:"]
        for line in lines {
            let lower = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
            guard let hit = matches(amountPattern, line).last,
                  let amount = Money.parse(substring(line, hit, group: 1)),
                  let range = Range(hit.range, in: line) else { continue }
            let name = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let isTotal = lower.range(of: #"^\s*(?:importe\s+total|total(?:\s+(?:a\s+pagar|compra|eur|€))?|a\s+pagar)\s*[:=]?\s*-?\d"#, options: .regularExpression) != nil
            if isTotal { r.totalCents = amount; foundTotal = true; continue }
            if ignored.contains(where: { lower.contains($0) }) || lower.hasPrefix("total") { continue }
            if !name.isEmpty && name.rangeOfCharacter(from: .letters) != nil {
                var item = ReceiptItem(name: name, cents: amount, category: Catalog.category(for: name))
                if let q = matches(#"^(\d+(?:[.,]\d+)?)\s*[x×]\s+"#, name).first {
                    item.quantity = substring(name, q, group: 1)
                    if let qr = Range(q.range, in: name) { item.name = String(name[qr.upperBound...]) }
                }
                r.items.append(item)
            }
        }
        if !foundTotal { r.totalCents = r.itemSum; warnings.append("No se ha encontrado un total: se propone la suma de líneas. Compruébala con el original.") }
        if r.items.isEmpty { warnings.append("No se han detectado productos. Puedes añadirlos manualmente sin perder el original.") }
        if r.difference != 0 { warnings.append("La suma de productos no coincide con el total. Revisa descuentos, impuestos o líneas no detectadas.") }
        return ParsedReceipt(receipt: r, warnings: warnings)
    }
}
