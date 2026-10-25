import XCTest
@testable import TicketLibre

final class TicketLibreTests: XCTestCase {
    private var vatReceipt: Receipt {
        ReceiptParser.parse("TIENDA PRUEBA\nProducto 18,11\nImporte Base %IVA IVA Total\n18,11 15,91 21 3,34 21,67\n2,20 10 0,22").receipt
    }
    func testReportedVATTableAndRecalculation() {
        let r = vatReceipt
        XCTAssertEqual(r.itemSum, 1811)
        XCTAssertEqual(r.vatCents, 356)
        XCTAssertEqual(r.vatIncluded, false)
        XCTAssertEqual(r.totalCents, 2167)
        XCTAssertEqual(r.calculatedTotal, 2167)
        XCTAssertEqual(r.difference, 0)
        XCTAssertEqual(r.items.count, 1)
    }
    func testIncludedVATIsNotAddedAgain() {
        let r = ReceiptParser.parse("TIENDA\nProducto 21,67\nBase %IVA Cuota Total\n15,91 21 3,34 21,67\n2,20 10 0,22").receipt
        XCTAssertEqual(r.vatCents, 356)
        XCTAssertEqual(r.vatIncluded, true)
        XCTAssertEqual(r.calculatedTotal, 2167)
        XCTAssertEqual(r.totalCents, 2167)
    }
    func testVATBackupAndSplitting() throws {
        var r = vatReceipt
        r.participants = [Participant(name: "A"), Participant(name: "B")]
        XCTAssertEqual(Money.split(r).values.reduce(0, +), 2167)
        let archive = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(Archive(receipts: [r]))).validated()
        XCTAssertEqual(archive.receipts[0], r)
        r.vatCents = .min
        XCTAssertThrowsError(try Archive(receipts: [r]).validated())
    }
    func testSpanishAndInternationalMoney() {
        XCTAssertEqual(Money.parse("1.234,56 €"), 123456)
        XCTAssertEqual(Money.parse("$1,234.56"), 123456)
        XCTAssertEqual(Money.parse("-0,01"), -1)
        XCTAssertEqual(Money.parse("12"), 1200)
        XCTAssertNil(Money.parse("1,005"))
        XCTAssertNil(Money.parse("NaN"))
        XCTAssertNil(Money.parse("1e9"))
        XCTAssertNil(Money.parse("999999999999999999999999999999999"))
    }
    func testEveryRemainderIsConserved() {
        let ids = (0..<7).map { _ in UUID() }
        for total in -1001...1001 {
            for count in 1...7 {
                let split = Money.distribute(Int64(total), among: Array(ids.prefix(count)))
                XCTAssertEqual(split.values.reduce(0, +), Int64(total))
                XCTAssertLessThanOrEqual((split.values.max() ?? 0) - (split.values.min() ?? 0), 1)
            }
        }
    }
    func testRenamesDoNotChangeAllocations() {
        var r = Receipt()
        let a = Participant(name: "Ana"), b = Participant(name: "Jesús")
        r.participants = [a, b]
        r.items = [ReceiptItem(name: "Pan", cents: 301), ReceiptItem(name: "Descuento", cents: -1)]
        r.totalCents = 301 // One extra cent from a receipt-level adjustment.
        r.allocations = [Allocation(itemID: r.items[0].id, participantIDs: [a.id])]
        let original = Money.split(r)
        r.participants[0].name = "Ana María"; r.items[0].name = "Pan integral"
        XCTAssertEqual(Money.split(r), original)
        XCTAssertEqual(Money.split(r).values.reduce(0, +), r.totalCents)
    }
    func testSubtotalTaxAndPaymentsAreNotProductsOrTotal() {
        let parsed = ReceiptParser.parse("MERCADONA\n24/10/2026\n2 x Leche 2,40\nPan 1,20\nDescuento -0,10\nSUBTOTAL 3,60\nIVA 0,30\nTOTAL A PAGAR 3,50\nTARJETA 3,50\nCAMBIO 0,00")
        XCTAssertEqual(parsed.receipt.totalCents, 350)
        XCTAssertEqual(parsed.receipt.items.count, 3)
        XCTAssertEqual(parsed.receipt.items[0].quantity, "2")
        XCTAssertEqual(parsed.receipt.itemSum, 350)
        XCTAssertEqual(parsed.receipt.category, "Alimentación")
    }
    func testInvalidCalendarDatesAreRejected() {
        XCTAssertNil(ReceiptParser.date(in: "Fecha: 31/02/2026"))
        XCTAssertNil(ReceiptParser.date(in: "29/02/2025"))
        XCTAssertNotNil(ReceiptParser.date(in: "29/02/2024"))
        XCTAssertNotNil(ReceiptParser.date(in: "2026-10-24"))
        XCTAssertNotNil(ReceiptParser.date(in: "24.10.26"))
    }
    func testArchiveKeepsImagesAndAssignments() throws {
        var r = Receipt(store: "Prueba", items: [ReceiptItem(name: "Arroz", cents: 201)], totalCents: 201)
        r.images = [Data([0, 1, 2, 3])]
        r.participants = [Participant(name: "Ana")]
        r.allocations = [Allocation(itemID: r.items[0].id, participantIDs: [r.participants[0].id])]
        let data = try JSONEncoder().encode(Archive(receipts: [r]))
        let decoded = try JSONDecoder().decode(Archive.self, from: data).validated()
        XCTAssertEqual(decoded.receipts[0], r)
    }
    func testBadArchiveAndMinimumIntegerCannotCrashValidation() throws {
        var invalid = Receipt(); invalid.totalCents = .min
        XCTAssertThrowsError(try Archive(receipts: [invalid]).validated())
        var r = Receipt(); r.allocations = [Allocation(itemID: UUID(), participantIDs: [])]
        XCTAssertThrowsError(try Archive(receipts: [r]).validated())
        let duplicate = Receipt()
        XCTAssertThrowsError(try Archive(receipts: [duplicate, duplicate]).validated())
        XCTAssertThrowsError(try Archive(schemaVersion: 99).validated())
    }
    func testCSVFormulaAndEscapes() {
        XCTAssertEqual(ExportService.csvField("=1+1"), "\"'=1+1\"")
        XCTAssertEqual(ExportService.csvField("  @SUM(A1)"), "\"'  @SUM(A1)\"")
        XCTAssertEqual(ExportService.csvField("a\"b;c"), "\"a\"\"b;c\"")
    }
    func testOwnQRCodeRoundTrip() throws {
        var r = Receipt(); r.store = "Prueba"; r.totalCents = 123
        let payload = try TransferService.qrPayload(r)
        XCTAssertEqual(try TransferService.receipt(from: payload)?.totalCents, 123)
        XCTAssertNil(try TransferService.receipt(from: "https://example.org"))
        XCTAssertThrowsError(try TransferService.receipt(from: "ticketlibre:1:invalid"))
    }
    func testZipSignaturesAndSize() {
        let data = ZipStore.archive([("hello.txt", Data("hello".utf8))])
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4b, 0x03, 0x04])
        XCTAssertEqual(Array(data.suffix(22).prefix(4)), [0x50, 0x4b, 0x05, 0x06])
        XCTAssertEqual(data.count, 30 + 9 + 5 + 46 + 9 + 22)
    }
    @MainActor func testPersistenceAndPreviousRecovery() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = ReceiptStore(folderOverride: dir)
        var r = Receipt(); r.store = "Prueba"; r.totalCents = 100
        XCTAssertTrue(first.save(r))
        r.totalCents = 200
        XCTAssertTrue(first.save(r))
        let reopened = ReceiptStore(folderOverride: dir)
        XCTAssertEqual(reopened.active.first?.totalCents, 200)
        reopened.recoverPrevious()
        XCTAssertEqual(reopened.active.first?.totalCents, 100)
    }
    @MainActor func testCorruptDatabaseIsNeverSilentlyReplaced() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("receipts-v1.json")
        let broken = Data("broken".utf8)
        try broken.write(to: url)
        let store = ReceiptStore(folderOverride: dir)
        XCTAssertTrue(store.recoveryRequired)
        XCTAssertFalse(store.save(Receipt()))
        XCTAssertEqual(try Data(contentsOf: url), broken)
        XCTAssertThrowsError(try store.backupURL())
    }
    @MainActor func testInvalidImportLeavesCurrentCollectionUntouched() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReceiptStore(folderOverride: dir)
        var r = Receipt(); r.store = "Prueba"
        XCTAssertTrue(store.save(r))
        let bad = dir.appendingPathComponent("bad.json")
        try Data("{}".utf8).write(to: bad)
        store.importBackup(bad)
        XCTAssertEqual(store.active, [r])
        XCTAssertNotNil(store.error)
    }
    @MainActor func testDuplicateWarningDoesNotMergeOrDelete() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReceiptStore(folderOverride: dir)
        var a = Receipt(); a.store = "Lidl"; a.totalCents = 100
        XCTAssertTrue(store.save(a))
        var b = a; b.id = UUID()
        XCTAssertEqual(store.duplicates(of: b).count, 1)
        XCTAssertTrue(store.save(b))
        XCTAssertEqual(store.active.count, 2)
    }

}
