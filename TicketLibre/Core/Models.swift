import Foundation

struct ReceiptItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name = ""
    var quantity = "1"
    var cents: Int64 = 0 // Line total, including quantity; may be a discount.
    var category = "Otros"
}

struct Participant: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

struct Allocation: Codable, Hashable {
    var itemID: UUID
    var participantIDs: [UUID]
}

struct Receipt: Identifiable, Codable, Hashable {
    var id = UUID()
    var store = ""
    var date = Date()
    var currency = "EUR"
    var scope = "Personal"
    var category = "Otros"
    var tags: [String] = []
    var number = ""
    var notes = ""
    var items: [ReceiptItem] = []
    var totalCents: Int64 = 0
    // Optional so archives written before VAT support remain decodable.
    var vatCents: Int64? = nil
    var vatIncluded: Bool? = nil
    var rawText = ""
    var images: [Data] = []
    var participants: [Participant] = []
    var allocations: [Allocation] = []
    var deletedAt: Date?
    var createdAt = Date()
    var itemSum: Int64 { items.reduce(0) { $0 + $1.cents } }
    var vatAddition: Int64 { vatIncluded == false ? (vatCents ?? 0) : 0 }
    var calculatedTotal: Int64 { itemSum + vatAddition }
    var difference: Int64 { totalCents - calculatedTotal }
}

struct ShoppingItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var quantity: Int = 1
    var estimatedUnitCents: Int64 = 0
    var currency = "EUR"
    var checked = false
}

struct Archive: Codable {
    var schemaVersion = 1
    var receipts: [Receipt] = []
    var shopping: [ShoppingItem] = []
    static let empty = Archive()

    func validated() throws -> Archive {
        guard schemaVersion == 1 else { throw AppIssue.message("La copia pertenece a una versión incompatible. Actualiza la app.") }
        guard receipts.count <= 20_000, shopping.count <= 10_000,
              Set(receipts.map(\.id)).count == receipts.count,
              Set(shopping.map(\.id)).count == shopping.count else {
            throw AppIssue.message("La copia contiene demasiados registros o identificadores duplicados.")
        }
        for r in receipts {
            guard ["EUR", "USD", "GBP"].contains(r.currency),
                  ["Personal", "Trabajo"].contains(r.scope),
                  r.store.count <= 500, r.rawText.count <= 200_000,
                  (-Money.limit...Money.limit).contains(r.totalCents), r.items.count <= 2_000,
                  r.vatCents.map({ (-Money.limit...Money.limit).contains($0) }) ?? true,
                  Set(r.items.map(\.id)).count == r.items.count,
                  Set(r.participants.map(\.id)).count == r.participants.count,
                  r.participants.count <= 50, r.images.count <= 20,
                  r.images.allSatisfy({ $0.count <= 5_000_000 }),
                  r.items.allSatisfy({ (-Money.limit...Money.limit).contains($0.cents) && $0.name.count <= 2_000 }),
                  r.allocations.allSatisfy({ a in
                      r.items.contains(where: { $0.id == a.itemID }) &&
                      Set(a.participantIDs).count == a.participantIDs.count &&
                      a.participantIDs.allSatisfy { id in r.participants.contains { $0.id == id } }
                  }), Set(r.allocations.map(\.itemID)).count == r.allocations.count else {
                throw AppIssue.message("La copia contiene datos de ticket no válidos.")
            }
        }
        guard shopping.allSatisfy({ $0.quantity > 0 && $0.quantity <= 999 &&
            (-Money.limit...Money.limit).contains($0.estimatedUnitCents) && ["EUR", "USD", "GBP"].contains($0.currency) }) else {
            throw AppIssue.message("La lista de compra de la copia no es válida.")
        }
        return self
    }
}

enum AppIssue: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum Catalog {
    static let categories = ["Alimentación", "Restauración", "Hogar", "Transporte", "Salud", "Tecnología", "Ropa", "Ocio", "Otros"]
    static let currencies = ["EUR", "USD", "GBP"]
    static func category(for text: String) -> String {
        let s = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        let rules: [(String, [String])] = [
            ("Alimentación", ["mercadona", "lidl", "aldi", "carrefour", "leche", "pan", "arroz", "yogur", "huevos", "fruta"]),
            ("Restauración", ["restaurante", "cafeteria", "bar ", "pizza", "menu", "cafe"]),
            ("Transporte", ["gasolina", "repsol", "cepsa", "parking", "renfe", "taxi", "metro"]),
            ("Salud", ["farmacia", "optica", "paracetamol"]), ("Tecnología", ["mediamarkt", "apple", "usb", "teclado"]),
            ("Ropa", ["zara", "primark", "camiseta", "pantalon"]), ("Ocio", ["cine", "juego", "entrada"])
        ]
        return rules.first { _, keys in keys.contains { s.contains($0) } }?.0 ?? "Otros"
    }
}
