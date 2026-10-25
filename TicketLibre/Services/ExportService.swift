import Foundation
import UIKit

// Every export uses a separate directory: sharing two receipts never races on a fixed filename.
enum ExportService {
    static func write(_ data: Data, name: String, ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TicketLibre-exports/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name).appendingPathExtension(ext)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    static func cleanup() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TicketLibre-exports")
        for file in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
            if let date = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate, Date().timeIntervalSince(date) > 86400 { try? FileManager.default.removeItem(at: file) }
        }
    }
    static func csvField(_ value: String) -> String {
        // Avoid spreadsheet formula execution when opening exported merchant/product names.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = ["=", "+", "-", "@"].contains(where: { trimmed.hasPrefix($0) }) ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    static func csv(_ receipts: [Receipt]) throws -> URL {
        var rows = ["Fecha;Tienda;Ámbito;Categoría;Etiquetas;Número;Producto;Cantidad;Importe línea;Total ticket;Moneda;IVA ticket;Tratamiento IVA"]
        for r in receipts {
            let products = r.items.isEmpty ? [ReceiptItem(name: "(sin desglose)", cents: r.totalCents)] : r.items
            for item in products {
                let treatment = r.vatCents == nil ? "" : (r.vatIncluded.map { $0 ? "Incluido" : "Añadido" } ?? "Pendiente de revisar")
                let fields = [r.date.formatted(.iso8601.year().month().day()), r.store, r.scope, item.category, r.tags.joined(separator: ", "), r.number, item.name, item.quantity, Money.edit(item.cents), Money.edit(r.totalCents), r.currency, r.vatCents.map(Money.edit) ?? "", treatment]
                rows.append(fields.map(csvField).joined(separator: ";"))
            }
        }
        return try write(Data(("\u{FEFF}" + rows.joined(separator: "\r\n")).utf8), name: "TicketLibre-productos", ext: "csv")
    }
    static func pdf(_ receipts: [Receipt], title: String = "Informe de gastos") throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            var y: CGFloat = 0
            func page() {
                context.beginPage()
                y = 42
                ("TicketLibre · " + title as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.systemTeal])
                y += 36
            }
            func line(_ value: String, bold: Bool = false) {
                let attributes: [NSAttributedString.Key: Any] = [.font: bold ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]
                let bounds = (value as NSString).boundingRect(with: CGSize(width: 523, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                if y + bounds.height + 12 > 795 { page() }
                (value as NSString).draw(in: CGRect(x: 36, y: y, width: 523, height: bounds.height + 2), withAttributes: attributes)
                y += bounds.height + 9
            }
            page()
            line("Generado: \(Date().formatted(date: .numeric, time: .shortened)). Importes en moneda original.")
            for r in receipts {
                line("\(r.store) · \(r.date.formatted(date: .numeric, time: .omitted)) · \(r.scope) · \(r.category)", bold: true)
                if !r.number.isEmpty { line("Ticket: \(r.number)") }
                for item in r.items { line("\(item.quantity) × \(item.name) — \(Money.display(item.cents, currency: r.currency))") }
                if let vat = r.vatCents {
                    let treatment = r.vatIncluded.map { $0 ? "incluido en los precios" : "añadido a los productos" } ?? "tratamiento pendiente de revisar"
                    line("IVA: \(Money.display(vat, currency: r.currency)) (\(treatment))")
                }
                line("TOTAL: \(Money.display(r.totalCents, currency: r.currency))", bold: true)
                if r.difference != 0 { line("Ajuste respecto al desglose: \(Money.display(r.difference, currency: r.currency))") }
                if !r.tags.isEmpty { line("Etiquetas: " + r.tags.joined(separator: ", ")) }
                y += 10
            }
            for currency in Catalog.currencies {
                let group = receipts.filter { $0.currency == currency }
                if !group.isEmpty { line("Total \(currency): \(Money.display(group.reduce(0) { $0 + $1.totalCents }, currency: currency))", bold: true) }
            }
            line("Documento informativo. Conserva los originales de tus compras.")
        }
        return try write(data, name: "TicketLibre-informe", ext: "pdf")
    }
}
