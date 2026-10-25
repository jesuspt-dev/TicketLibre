import Foundation

struct ParsedReceipt {
    var receipt: Receipt
    var warnings: [String]
}

enum ReceiptParser {
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
            .replacingOccurrences(of: "i.v.a.", with: "iva")
            .replacingOccurrences(of: "i.v.a", with: "iva")
    }

    private struct VATRow {
        var base: Int64
        var vat: Int64
        var prefix: Int64?
        var total: Int64?
    }
    private struct VATTable {
        var rows: [VATRow] = []
        var consumed: Set<Int> = []
        var base: Int64 { rows.reduce(0) { $0 + $1.base } }
        var vat: Int64 { rows.reduce(0) { $0 + $1.vat } }
        var subtotal: Int64? { rows.compactMap(\.prefix).first }
        var printedTotal: Int64? {
            // A merged summary cell can appear on the first VAT row, as in the
            // Importe / Base / %IVA / IVA / Total layout. It is not a product.
            if subtotal != nil { return rows.compactMap(\.total).first }
            let totals = rows.compactMap(\.total)
            if totals.count == 1 { return totals[0] }
            if let global = totals.first(where: { $0 == base + vat }) { return global }
            if totals.count == rows.count && rows.allSatisfy({ $0.total == $0.base + $0.vat }) {
                return totals.reduce(0, +)
            }
            return nil
        }
        var balanced: Bool {
            (subtotal == nil || subtotal == base) && (printedTotal == nil || printedTotal == base + vat)
        }
    }

    private static func vatTable(in lines: [String]) -> VATTable? {
        let decimal = #"-?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}"#
        for headerIndex in lines.indices {
            let header = normalized(lines[headerIndex])
            guard let baseRange = header.range(of: "base"),
                  let vatRange = header.range(of: "iva") ?? header.range(of: "cuota"),
                  matches(decimal, header).isEmpty else { continue }
            let rateRange = header.range(of: "tipo") ?? header.range(of: "%") ?? vatRange
            let rateFirst = rateRange.lowerBound < baseRange.lowerBound
            let summaryPrefix = header.contains("importe") && header.contains("total")
            var table = VATTable(consumed: [headerIndex])
            for index in lines.indices.dropFirst(headerIndex + 1).prefix(12) {
                let rowText = normalized(lines[index]).replacingOccurrences(of: "eur", with: "")
                guard rowText.range(of: #"^[\s\d.,%€+\-]+$"#, options: .regularExpression) != nil else { break }
                let tokens = matches(#"-?(?:\d{1,3}(?:\.\d{3})+,\d{2}|\d{1,3}(?:,\d{3})+\.\d{2}|\d+(?:[.,]\d+)?)%?"#, rowText).map { substring(rowText, $0) }
                guard (3...5).contains(tokens.count) else { break }
                var candidates: [VATRow] = []
                let positions = rateFirst ? [0] : [1, 2]
                for rateIndex in positions where rateIndex + 1 < tokens.count {
                    let baseIndex = rateFirst ? 1 : rateIndex - 1
                    let taxIndex = rateFirst ? 2 : rateIndex + 1
                    guard taxIndex < tokens.count,
                          let base = Money.parse(tokens[baseIndex]),
                          let rate = Money.parse(tokens[rateIndex].replacingOccurrences(of: "%", with: "")),
                          (0...10_000).contains(rate), let vat = Money.parse(tokens[taxIndex]) else { continue }
                    let product = base * rate
                    let expected = (product + (product >= 0 ? 5_000 : -5_000)) / 10_000
                    guard abs(vat - expected) <= 1 else { continue }
                    let afterTax = tokens.count - taxIndex - 1
                    guard afterTax <= 1 else { continue }
                    let prefix = summaryPrefix && !rateFirst && rateIndex == 2 ? Money.parse(tokens[0]) : nil
                    let total = afterTax == 1 ? Money.parse(tokens[taxIndex + 1]) : nil
                    candidates.append(VATRow(base: base, vat: vat, prefix: prefix, total: total))
                }
                guard candidates.count == 1, let row = candidates.first else { break }
                table.rows.append(row)
                table.consumed.insert(index)
            }
            if !table.rows.isEmpty { return table }
        }
        return nil
    }
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
        let table = vatTable(in: lines)
        var explicitBase: Int64?
        var taxLines: [Int64] = []
        var taxTotal: Int64?
        var includedHint = false
        var excludedHint = false
        let amountPattern = #"(-?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2})\s*(?:€|EUR|USD|GBP|\$|£)?\s*[A-Z]?\s*$"#
        let ignored = ["base imponible", "subtotal", "sub total", "tarjeta", "efectivo", "cambio", "entregado", "ahorro", "saldo", "a pagar con", "precio/kg", "precio /", "nif", "cif", "telefono", "tel:"]
        for (index, line) in lines.enumerated() {
            let lower = normalized(line)
            let excludes = lower.range(of: #"(?:iva\s+(?:no\s+incluid|excluid)|sin\s+iva|\+\s*iva)"#, options: .regularExpression) != nil
            excludedHint = excludedHint || excludes
            includedHint = includedHint || (!excludes && lower.range(of: #"iva\s+incluid|precios?\s+con\s+iva"#, options: .regularExpression) != nil)
            if table?.consumed.contains(index) == true { continue }
            guard let hit = matches(amountPattern, line).last,
                  let amount = Money.parse(substring(line, hit, group: 1)),
                  let range = Range(hit.range, in: line) else { continue }
            let name = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let label = normalized(name)
            let taxLabel = label.range(of: #"^(?:(?:total|importe|cuota)\s+(?:(?:de|del)\s+)?)?iva\b"#, options: .regularExpression) != nil
            if taxLabel && !(label.hasPrefix("total") && label.contains("incluid")) {
                if label.hasPrefix("total") { taxTotal = amount } else { taxLines.append(amount) }
                continue
            }
            if label.range(of: #"^(?:base\s+imponible|total\s+sin\s+iva)\s*[:=]?\s*$"#, options: .regularExpression) != nil {
                explicitBase = amount
                continue
            }
            let isTotal = lower.range(of: #"^\s*(?:importe\s+total|total(?:\s+(?:a\s+pagar|compra|eur|€))?|a\s+pagar)\s*[:=]?\s*-?\d"#, options: .regularExpression) != nil
            let totalWithVAT = label.range(of: #"^total\s*\(?\s*(?:con\s+iva|iva\s+incluid[oa]s?)\s*\)?\s*[:=]?\s*$"#, options: .regularExpression) != nil
            if isTotal || totalWithVAT { r.totalCents = amount; foundTotal = true; continue }
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
        r.vatCents = table?.vat ?? taxTotal ?? (taxLines.isEmpty ? nil : taxLines.reduce(0, +))
        if !foundTotal, let table {
            if let printed = table.printedTotal {
                r.totalCents = printed
                foundTotal = true
            } else if table.balanced {
                r.totalCents = table.base + table.vat
                foundTotal = true
                warnings.append("El total se ha calculado con las bases y cuotas de IVA del cuadro fiscal. Compruébalo con el original.")
            }
        }
        if let vat = r.vatCents {
            if foundTotal && r.totalCents == r.itemSum { r.vatIncluded = true }
            else if foundTotal && r.totalCents == r.itemSum + vat { r.vatIncluded = false }
            else if includedHint && !excludedHint { r.vatIncluded = true }
            else if excludedHint && !includedHint { r.vatIncluded = false }
            else if !foundTotal, let base = explicitBase, base == r.itemSum || r.items.isEmpty { r.vatIncluded = false }
            if table?.balanced == false {
                r.vatIncluded = nil
                warnings.append("El cuadro de IVA no cuadra por completo: conserva el total impreso y revisa las cuotas reconocidas.")
            } else if r.vatIncluded == nil {
                warnings.append("Se ha reconocido IVA, pero no se puede confirmar si los productos ya lo incluyen. Revísalo antes de añadirlo.")
            }
        }
        if !foundTotal {
            if let base = explicitBase, let vat = r.vatCents, r.vatIncluded == false { r.totalCents = base + vat }
            else { r.totalCents = r.calculatedTotal }
            warnings.append("No se ha encontrado un total final: se propone la suma reconocida, con el IVA añadido solo cuando está identificado. Compruébala con el original.")
        }
        if r.items.isEmpty { warnings.append("No se han detectado productos. Puedes añadirlos manualmente sin perder el original.") }
        if r.difference != 0 { warnings.append("El desglose de productos e IVA no coincide con el total. Revisa descuentos, impuestos o líneas no detectadas.") }
        return ParsedReceipt(receipt: r, warnings: warnings)
    }
}
