import Foundation

@main
struct CoreTests {
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
