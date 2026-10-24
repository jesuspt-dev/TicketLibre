import Foundation
import Combine
import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
final class ReceiptStore: ObservableObject {
    @Published private(set) var archive = Archive.empty
    @Published var error: String?
    @Published private(set) var recoveryRequired = false
    private var indexGeneration = UUID()
    private let folder: URL
    private var database: URL { folder.appendingPathComponent("receipts-v1.json") }
    private var previous: URL { folder.appendingPathComponent("receipts-v1.previous.json") }
    static let maxBytes = 250_000_000
    var active: [Receipt] { archive.receipts.filter { $0.deletedAt == nil }.sorted { $0.date > $1.date } }
    var trash: [Receipt] { archive.receipts.filter { $0.deletedAt != nil } }

    init(folderOverride: URL? = nil) {
        folder = folderOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TicketLibre", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: database.path) {
                archive = try decode(database)
                // Expiration happens only after a successfully decoded database.
                let expired = archive.receipts.contains { r in r.deletedAt.map { Date().timeIntervalSince($0) > 30 * 86400 } ?? false }
                if expired { _ = change { $0.receipts.removeAll { r in r.deletedAt.map { Date().timeIntervalSince($0) > 30 * 86400 } ?? false } } }
            }
        } catch {
            recoveryRequired = true
            self.error = "No se han podido cargar tus datos. No se sobrescribirán. En Ajustes puedes recuperar la copia local anterior o importar una copia externa. \(error.localizedDescription)"
        }
    }
    private func decode(_ url: URL) throws -> Archive {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Self.maxBytes else { throw AppIssue.message("El archivo supera 250 MB.") }
        return try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url)).validated()
    }
    @discardableResult func change(_ action: (inout Archive) -> Void) -> Bool {
        guard !recoveryRequired else { error = "Recupera tus datos en Ajustes antes de modificar la colección."; return false }
        var candidate = archive
        action(&candidate)
        do { try persist(candidate, preservePrevious: true); return true }
        catch { self.error = "No se ha guardado el cambio: \(error.localizedDescription)"; return false }
    }
    private func persist(_ value: Archive, preservePrevious: Bool) throws {
        let checked = try value.validated()
        let bytes = try JSONEncoder().encode(checked)
        guard bytes.count <= Self.maxBytes else { throw AppIssue.message("La colección supera el límite de 250 MB. Exporta una copia y libera adjuntos.") }
        if preservePrevious && FileManager.default.fileExists(atPath: database.path) {
            // Never replace a known-good backup with undecodable bytes.
            _ = try decode(database)
            let old = try Data(contentsOf: database)
            try old.write(to: previous, options: [.atomic, .completeFileProtection])
        }
        try bytes.write(to: database, options: [.atomic, .completeFileProtection])
        archive = checked
        recoveryRequired = false
        index()
    }
    @discardableResult func save(_ receipt: Receipt) -> Bool {
        change { a in
            if let i = a.receipts.firstIndex(where: { $0.id == receipt.id }) { a.receipts[i] = receipt }
            else { a.receipts.append(receipt) }
        }
    }
    func duplicates(of r: Receipt) -> [Receipt] {
        active.filter { existing in
            existing.id != r.id && existing.currency == r.currency && existing.totalCents == r.totalCents &&
            existing.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == r.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
            Calendar.current.isDate(existing.date, inSameDayAs: r.date)
        }
    }
    func moveToTrash(_ id: UUID) { _ = change { a in if let i = a.receipts.firstIndex(where: { $0.id == id }) { a.receipts[i].deletedAt = Date() } } }
    func restore(_ id: UUID) { _ = change { a in if let i = a.receipts.firstIndex(where: { $0.id == id }) { a.receipts[i].deletedAt = nil } } }
    func removePermanently(_ id: UUID) { _ = change { $0.receipts.removeAll { $0.id == id } } }
    func recoverPrevious() {
        do { let recovered = try decode(previous); try persist(recovered, preservePrevious: false) }
        catch { self.error = "No se ha podido recuperar la copia anterior: \(error.localizedDescription)" }
    }
    func importBackup(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let other = try decode(url)
            var merged = recoveryRequired ? Archive.empty : archive
            let currentIDs = Set(merged.receipts.map(\.id))
            let shoppingIDs = Set(merged.shopping.map(\.id))
            merged.receipts += other.receipts.filter { !currentIDs.contains($0.id) }
            merged.shopping += other.shopping.filter { !shoppingIDs.contains($0.id) }
            try persist(merged, preservePrevious: !recoveryRequired)
        } catch { self.error = "No se ha importado nada: \(error.localizedDescription)" }
    }
    func backupURL() throws -> URL {
        guard !recoveryRequired else { throw AppIssue.message("Primero recupera la colección. Exportar ahora produciría una copia vacía.") }
        return try ExportService.write(try JSONEncoder().encode(archive), name: "TicketLibre-copia-\(Date().formatted(.iso8601.year().month().day()))", ext: "json")
    }
    private func index() {
        let generation = UUID(); indexGeneration = generation
        // Financial metadata in Spotlight is optional; no image or raw OCR is indexed.
        guard UserDefaults.standard.bool(forKey: "spotlightEnabled"), !UserDefaults.standard.bool(forKey: "lockEnabled") else {
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["TicketLibre"]) { _ in }
            return
        }
        let entries = active.map { r -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = r.store
            attributes.contentDescription = "\(r.scope) · \(r.category) · \(r.date.formatted(date: .abbreviated, time: .omitted))"
            attributes.keywords = r.tags
            return CSSearchableItem(uniqueIdentifier: r.id.uuidString, domainIdentifier: "TicketLibre", attributeSet: attributes)
        }
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["TicketLibre"]) { _ in
            Task { @MainActor [weak self] in
                guard let self, self.indexGeneration == generation, UserDefaults.standard.bool(forKey: "spotlightEnabled"), !UserDefaults.standard.bool(forKey: "lockEnabled") else { return }
                CSSearchableIndex.default().indexSearchableItems(entries) { _ in }
            }
        }
    }
    func refreshSearchIndex() { index() }
}
