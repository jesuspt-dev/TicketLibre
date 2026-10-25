import Foundation

@main
struct CoreTests {
    // Anonymized amounts/columns from the reported receipt. No photo or personal
    // invoice identifiers are stored in the repository.
    static let netProducts = """
    TIENDA PRUEBA
    24/10/2026
    Producto A 2.3400 2.34
    Producto B 1.7200 1.72
    Producto B 1.7200 1.72
    Producto C 1.5900 1.59
    Producto D 1.4375 1.44
    Producto D 1.4375 1.44
    Producto E 0.7988 0.80
    Producto F 0.6300 0.63
    Producto G 0.7650 0.77
    Producto H 2.6808 2.68
    Producto I 2.9754 2.98
    """
    static let fiscalFooter = """
    Importe Base %Iva Iva Total
    18.11 15.91 21 3.34 21.67
    2.20 10 0.22
    """
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw AppIssue.message(message) }
    }
    static func mustThrow(_ operation: () throws -> Void, _ message: String) throws {
        do { try operation() } catch { return }
        throw AppIssue.message(message)
    }
    static func main() throws {
        var passed = 0
        func run(_ name: String, _ operation: () throws -> Void) throws {
            try operation(); passed += 1; print("PASS: \(name)")
        }
        try run("Decimal parsing and bounds") {
            try require(Money.parse("1.234,56 €") == 123456, "Spanish amount")
            try require(Money.parse("$1,234.56") == 123456, "International amount")
            try require(Money.parse("-0,01") == -1, "Negative discount")
            try require(Money.parse("1,005") == nil, "Reject sub-cent amount")
            try require(Money.parse("NaN") == nil, "Reject NaN")
            try require(Money.parse("999999999999999999999999999999999") == nil, "Reject overflow")
        }
        try run("14,007 signed remainder distributions") {
            let ids = (0..<7).map { _ in UUID() }
            for cents in -1000...1000 {
                for count in 1...7 {
                    let amounts = Money.distribute(Int64(cents), among: Array(ids.prefix(count)))
                    try require(amounts.values.reduce(0,+) == Int64(cents), "Cent conservation")
                    try require((amounts.values.max() ?? 0) - (amounts.values.min() ?? 0) <= 1, "Fair remainder")
                }
            }
        }
        try run("Stable allocation after renaming") {
            var r = Receipt()
            r.participants = [Participant(name: "Ana"),Participant(name: "Jesús")]
            r.items = [ReceiptItem(name: "Pan", cents: 301),ReceiptItem(name: "Descuento", cents: -1)]
            r.totalCents = 301
            r.allocations = [Allocation(itemID:r.items[0].id,participantIDs:[r.participants[0].id])]
            let before = Money.split(r)
            r.participants[0].name = "Ana María";r.items[0].name = "Pan integral"
            try require(before == Money.split(r), "Names must not identify assignments")
            try require(Money.split(r).values.reduce(0,+) == 301, "Adjustment conservation")
        }
        try run("Subtotal, tax, payment and discount parsing") {
            let p = ReceiptParser.parse("MERCADONA\n24/10/2026\n2 x Leche 2,40\nPan 1,20\nDescuento -0,10\nSUBTOTAL 3,60\nIVA 0,30\nTOTAL A PAGAR 3,50\nTARJETA 3,50\nCAMBIO 0,00")
            try require(p.receipt.totalCents == 350, "Final total")
            try require(p.receipt.items.count == 3, "Only product lines")
            try require(p.receipt.itemSum == 350, "Product sum")
            try require(p.receipt.items[0].quantity == "2", "Quantity")
        }
        try run("Reported multi-rate VAT footer includes all 356 cents") {
            let r = ReceiptParser.parse(netProducts + "\n" + fiscalFooter).receipt
            try require(r.items.count == 11, "VAT rows must not become products")
            try require(r.itemSum == 1811, "Net product amounts")
            try require(r.vatCents == 356 && r.vatIncluded == false, "Both printed VAT quotas must be added")
            try require(r.totalCents == 2167 && r.calculatedTotal == 2167, "Payable and recalculated totals")
            try require(r.difference == 0, "VAT must reconcile the receipt")
        }
        try run("VAT table without its final total derives bases plus quotas") {
            let footer = fiscalFooter.replacingOccurrences(of: "3.34 21.67", with: "3.34")
            let r = ReceiptParser.parse(netProducts + "\n" + footer).receipt
            try require(r.totalCents == 2167 && r.vatCents == 356, "Missing final cell must not drop VAT")
        }
        try run("VAT already included is never added a second time") {
            let text = "TIENDA\nProducto 21,67\nBase %IVA Cuota Total\n15,91 21 3,34 21,67\n2,20 10 0,22"
            let r = ReceiptParser.parse(text).receipt
            try require(r.vatCents == 356 && r.vatIncluded == true, "Included VAT classification")
            try require(r.totalCents == 2167 && r.calculatedTotal == 2167, "No double VAT")
            try require(r.difference == 0 && r.items.count == 1, "Fiscal table stays separate")
        }
        try run("Explicit net base and standalone VAT") {
            let r = ReceiptParser.parse("TIENDA\nProducto 100,00\nBASE IMPONIBLE 100,00\nIVA 21% 21,00").receipt
            try require(r.vatCents == 2100 && r.vatIncluded == false, "Explicit net base")
            try require(r.totalCents == 12100 && r.calculatedTotal == 12100, "Add printed quota once")
        }
        try run("Ambiguous subtotal and VAT require review rather than guessing") {
            let p = ReceiptParser.parse("TIENDA\nProducto 100,00\nSUBTOTAL 100,00\nIVA 21,00")
            try require(p.receipt.vatCents == 2100 && p.receipt.vatIncluded == nil, "Subtotal alone does not prove prices exclude VAT")
            try require(p.receipt.totalCents == 10000, "Do not assume every receipt needs VAT added")
            try require(p.warnings.contains { $0.contains("no se puede confirmar") }, "Explain the ambiguity")
        }
        try run("Included label, dotted acronym and grand total label") {
            let r = ReceiptParser.parse("TIENDA\nProducto 121,00\nI.V.A. incluido 21,00\nTOTAL (IVA INCLUIDO) 121,00").receipt
            try require(r.vatCents == 2100 && r.vatIncluded == true, "Included label")
            try require(r.totalCents == 12100 && r.items.count == 1, "Read decorated final label")
        }
        try run("Printed total wins when other lines do not reconcile") {
            let r = ReceiptParser.parse("TIENDA\nProducto 100,00\nIVA no incluido 21,00\nTOTAL 120,00").receipt
            try require(r.totalCents == 12000 && r.difference == -100, "Do not replace a printed total with a guessed adjustment")
        }
        try run("Tax summary does not duplicate individual tax lines") {
            let r = ReceiptParser.parse("TIENDA\nProducto 100,00\nIVA 21% 10,00\nIVA 10% 2,00\nTOTAL IVA 12,00\nTOTAL 112,00").receipt
            try require(r.vatCents == 1200 && r.totalCents == 11200, "Prefer explicit IVA summary")
        }
        try run("Rates before the base and decimal rate notation") {
            let a = ReceiptParser.parse("TIENDA\nProducto 100,00\nTipo Base Cuota\n21 100,00 21,00").receipt
            let b = ReceiptParser.parse("TIENDA\nProducto 100,00\nBase %IVA Cuota\n100,00 21,00 21,00").receipt
            try require(a.totalCents == 12100 && b.totalCents == 12100, "Respect header order and printed rates")
        }
        try run("Incomplete VAT table preserves printed total and asks for review") {
            let r = ReceiptParser.parse(netProducts + "\nImporte Base %IVA IVA Total\n18.11 15.91 21 3.34 21.67").receipt
            try require(r.totalCents == 2167 && r.vatCents == 334 && r.vatIncluded == nil, "Do not treat partial VAT as a complete adjustment")
        }
        try run("VAT table keeps thousands separators in each monetary cell") {
            let r = ReceiptParser.parse("TIENDA\nProducto 1.234,56\nBase %IVA Cuota Total\n1.234,56 21 259,26 1.493,82").receipt
            try require(r.vatCents == 25926 && r.vatIncluded == false, "Spanish thousands separator")
            try require(r.totalCents == 149382 && r.calculatedTotal == 149382, "Do not split a monetary cell into multiple numbers")
        }
        try run("VAT matching uses words and preserves product names such as olivas") {
            let r = ReceiptParser.parse("TIENDA\nOlivas 2,00\nTOTAL 2,00").receipt
            try require(r.items.count == 1 && r.itemSum == 200 && r.vatCents == nil, "iva inside a product is not a tax label")
        }
        try run("VAT survives backup and old backups remain readable") {
            let r = ReceiptParser.parse(netProducts + "\n" + fiscalFooter).receipt
            let data = try JSONEncoder().encode(Archive(receipts: [r]))
            let restored = try JSONDecoder().decode(Archive.self, from: data).validated()
            try require(restored.receipts == [r], "New VAT metadata round trip")
            var legacy = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            var receipts = legacy["receipts"] as! [[String: Any]]
            receipts[0].removeValue(forKey: "vatCents"); receipts[0].removeValue(forKey: "vatIncluded")
            legacy["receipts"] = receipts
            let old = try JSONDecoder().decode(Archive.self, from: JSONSerialization.data(withJSONObject: legacy)).validated().receipts[0]
            try require(old.vatCents == nil && old.totalCents == r.totalCents && old.items == r.items, "No migration may change old amounts or products")
            var bad = r; bad.vatCents = .min
            try mustThrow({ _ = try Archive(receipts: [bad]).validated() }, "Invalid VAT must be rejected")
        }
        try run("Splitting VAT preserves every cent, including other adjustments") {
            var r = ReceiptParser.parse(netProducts + "\n" + fiscalFooter).receipt
            r.participants = [Participant(name: "A"), Participant(name: "B")]
            r.allocations = r.items.map { Allocation(itemID: $0.id, participantIDs: [r.participants[0].id]) }
            let amounts = Money.split(r)
            try require(amounts[r.participants[0].id] == 1989 && amounts[r.participants[1].id] == 178, "Share receipt-level VAT once")
            r.totalCents -= 1
            try require(Money.split(r).values.reduce(0, +) == 2166, "Conserve VAT plus a receipt-level discount")
        }
        try run("Invalid dates and leap years") {
            try require(ReceiptParser.date(in:"31/02/2026") == nil, "Invalid February")
            try require(ReceiptParser.date(in:"29/02/2025") == nil, "Non leap year")
            try require(ReceiptParser.date(in:"29/02/2024") != nil, "Leap year")
            try require(ReceiptParser.date(in:"2026-10-24") != nil, "ISO date")
            try require(ReceiptParser.date(in:"24.10.26") != nil, "Short year")
        }
        try run("Archive round trip retains attachments and stable IDs") {
            var r = Receipt();r.store = "Prueba";r.totalCents = 199
            r.images = [Data([1,2,3])]
            r.items = [ReceiptItem(name:"Arroz",cents:199)]
            let data = try JSONEncoder().encode(Archive(receipts:[r]))
            let decoded = try JSONDecoder().decode(Archive.self,from:data).validated()
            try require(decoded.receipts == [r], "Lossless archive round trip")
        }
        try run("Malformed archives rejected without arithmetic overflow") {
            var r = Receipt();r.totalCents = .min
            try mustThrow({ _ = try Archive(receipts:[r]).validated() },"Must reject Int64.min")
            try mustThrow({ _ = try Archive(schemaVersion:99).validated() },"Reject future schema")
            let a = Receipt()
            try mustThrow({ _ = try Archive(receipts:[a,a]).validated() },"Reject duplicate IDs")
        }
        try run("Cross-record assignments rejected") {
            var r = Receipt();r.allocations = [Allocation(itemID:UUID(),participantIDs:[])]
            try mustThrow({ _ = try Archive(receipts:[r]).validated() },"Unknown item ID")
            r.items = [ReceiptItem(name:"Pan",cents:100)]
            r.allocations = [Allocation(itemID:r.items[0].id,participantIDs:[UUID()])]
            try mustThrow({ _ = try Archive(receipts:[r]).validated() },"Unknown participant ID")
        }
        print("RESULT: \(passed) portable test groups passed. iOS frameworks, OCR and UI are not covered.")
    }
}
