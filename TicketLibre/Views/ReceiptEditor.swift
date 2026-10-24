import SwiftUI

struct ReceiptEditor: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var receipt: Receipt
    @State private var total: String
    @State private var tags: String
    @State private var reviewed = false
    @State private var item: ReceiptItem?
    @State private var duplicateAlert = false
    @State private var deleteAlert = false
    @State private var share: ShareFile?
    private let warnings: [String]
    init(initial: Receipt, scanWarnings: [String] = []) {
        _receipt = State(initialValue: initial)
        _total = State(initialValue: Money.edit(initial.totalCents))
        _tags = State(initialValue: initial.tags.joined(separator: ", "))
        _reviewed = State(initialValue: scanWarnings.isEmpty)
        warnings = scanWarnings
    }
    private var valid: Bool { !receipt.store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Money.parse(total) != nil && reviewed }
    private var existing: Bool { store.archive.receipts.contains { $0.id == receipt.id } }
    var body: some View {
        Group {
        NavigationStack {
            Form {
                if !warnings.isEmpty {
                    Section("Revisión del escaneo") {
                        ForEach(warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                        Toggle("He revisado fecha, productos y total", isOn: $reviewed)
                    }
                }
                Section("Compra") {
                    TextField("Tienda", text: $receipt.store)
                    DatePicker("Fecha", selection: $receipt.date, displayedComponents: .date)
                    TextField("Número de ticket (opcional)", text: $receipt.number)
                    Picker("Ámbito", selection: $receipt.scope) { Text("Personal").tag("Personal"); Text("Trabajo").tag("Trabajo") }
                    Picker("Categoría", selection: $receipt.category) { ForEach(Catalog.categories, id: \.self) { Text($0) } }
                    Picker("Moneda", selection: $receipt.currency) { ForEach(Catalog.currencies, id: \.self) { Text($0) } }
                    TextField("Etiquetas: hogar/cocina, viaje…", text: $tags)
                }
                Section {
                    ForEach(receipt.items) { value in
                        Button { item = value } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(value.name); Text("\(value.quantity) · \(value.category)").font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Text(Money.display(value.cents, currency: receipt.currency)).monospacedDigit()
                            }.foregroundStyle(.primary)
                        }
                    }.onDelete { indices in
                        let removed = indices.map { receipt.items[$0].id }
                        receipt.items.remove(atOffsets: indices)
                        receipt.allocations.removeAll { removed.contains($0.itemID) }
                    }
                    Button { item = ReceiptItem() } label: { Label("Añadir producto o descuento", systemImage: "plus.circle") }
                } header: { Text("Productos · \(receipt.items.count)") } footer: { Text("El importe de cada línea incluye su cantidad. Usa un importe negativo para descuentos.") }
                Section("Total") {
                    HStack { Text("Total del ticket"); TextField("0,00", text: $total).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                    LabeledContent("Suma de productos", value: Money.display(receipt.itemSum, currency: receipt.currency))
                    if let parsed = Money.parse(total), parsed != receipt.itemSum {
                        Label("Diferencia: \(Money.display(parsed - receipt.itemSum, currency: receipt.currency))", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    Button("Usar suma de productos") { total = Money.edit(receipt.itemSum) }
                }
                Section {
                    NavigationLink { SplitView(receipt: $receipt, total: Money.parse(total) ?? receipt.totalCents) } label: { Label("Dividir entre personas", systemImage: "person.2") }
                    NavigationLink { OriginalView(receipt: receipt) } label: { Label("Ver original y texto", systemImage: "doc.text.magnifyingglass") }
                    TextField("Notas", text: $receipt.notes, axis: .vertical).lineLimit(2...5)
                }
                if existing {
                    Section("Compartir") {
                        Button("Exportar PDF") { export { try ExportService.pdf([current()]) } }
                        Button("Exportar ZIP con originales") { export { try TransferService.bundle(current()) } }
                        Button("Compartir QR de TicketLibre") { export { try TransferService.qr(current()) } }
                        Button("Exportar productos CSV") { export { try ExportService.csv([current()]) } }
                        Button("Exportar ticket completo JSON") { export { try ExportService.write(try JSONEncoder().encode(Archive(receipts: [current()])), name: "TicketLibre-ticket", ext: "json") } }
                    }
                    Section { Button("Mover a la papelera", role: .destructive) { deleteAlert = true } }
                }
            }
            .navigationTitle(existing ? "Editar ticket" : "Revisar ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { if store.duplicates(of: current()).isEmpty { save() } else { duplicateAlert = true } }.disabled(!valid) }
            }
            .sheet(item: $item) { value in ItemEditor(initial: value, currency: receipt.currency) { edited in
                if let index = receipt.items.firstIndex(where: { $0.id == edited.id }) { receipt.items[index] = edited }
                else { receipt.items.append(edited) }
            } }
            .sheet(item: $share) { ShareSheet(urls: [$0.url]).securePresentation() }
            .alert("Posible ticket duplicado", isPresented: $duplicateAlert) {
                Button("Revisar", role: .cancel) {}
                Button("Guardar igualmente") { save() }
            } message: { Text("Ya hay un ticket de la misma tienda, fecha, moneda e importe. No se fusionará ni borrará automáticamente.") }
            .confirmationDialog("¿Mover este ticket a la papelera?", isPresented: $deleteAlert, titleVisibility: .visible) {
                Button("Mover a la papelera", role: .destructive) { var r = current(); r.deletedAt = Date(); if store.save(r) { dismiss() } }
            } message: { Text("Puedes recuperarlo durante 30 días.") }
        }
    
        }.securePresentation()
    }
    private func current() -> Receipt {
        var result = receipt
        result.totalCents = Money.parse(total) ?? receipt.totalCents
        result.tags = Array(Set(tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        result.store = result.store.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
    private func save() { if store.save(current()) { dismiss() } }
    private func export(_ work: () throws -> URL) { do { share = ShareFile(url: try work()) } catch { store.error = error.localizedDescription } }
}

struct ItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ReceiptItem
    @State private var amount: String
    let currency: String
    let completion: (ReceiptItem) -> Void
    init(initial: ReceiptItem, currency: String, completion: @escaping (ReceiptItem) -> Void) {
        _item = State(initialValue: initial); _amount = State(initialValue: Money.edit(initial.cents)); self.currency = currency; self.completion = completion
    }
    var body: some View {
        Group {
        NavigationStack {
            Form {
                TextField("Producto", text: $item.name)
                TextField("Cantidad o peso", text: $item.quantity).keyboardType(.numbersAndPunctuation)
                TextField("Importe de la línea (\(currency))", text: $amount).keyboardType(.numbersAndPunctuation)
                Picker("Categoría", selection: $item.category) { ForEach(Catalog.categories, id: \.self) { Text($0) } }
                Text("Ejemplo: 3 yogures por 2,40 € → cantidad 3 e importe 2,40. Para un descuento introduce -0,50.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Producto").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Listo") { if let cents = Money.parse(amount) { item.cents = cents; completion(item); dismiss() } }.disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Money.parse(amount) == nil) }
                }
        }
    
        }.securePresentation()
    }
}

struct OriginalView: View {
    let receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore
    @State private var share: ShareFile?
    var body: some View {
        Group {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(receipt.images.enumerated()), id: \.offset) { n, bytes in
                    if let image = UIImage(data: bytes) {
                        Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Compartir página \(n + 1)") {
                            do { share = ShareFile(url: try ExportService.write(bytes, name: "TicketLibre-pagina-\(n + 1)", ext: "jpg")) } catch { store.error = error.localizedDescription }
                        }
                    }
                }
                Text(receipt.rawText.isEmpty ? "Este ticket no tiene texto original." : receipt.rawText).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                if !receipt.rawText.isEmpty { Button("Compartir texto") { do { share = ShareFile(url: try ExportService.write(Data(receipt.rawText.utf8), name: "TicketLibre-texto", ext: "txt")) } catch { store.error = error.localizedDescription } } }
            }.padding()
        }.navigationTitle("Original").navigationBarTitleDisplayMode(.inline).sheet(item: $share) { ShareSheet(urls: [$0.url]).securePresentation() }
    
        }.securePresentation()
    }
}

struct SplitView: View {
    @Binding var receipt: Receipt
    let total: Int64
    @State private var name = ""
    private var amounts: [UUID: Int64] { var r = receipt; r.totalCents = total; return Money.split(r) }
    var body: some View {
        Form {
            Section("Participantes") {
                ForEach($receipt.participants) { $person in TextField("Nombre", text: $person.name) }
                    .onDelete { offsets in
                        let ids = offsets.map { receipt.participants[$0].id }
                        receipt.participants.remove(atOffsets: offsets)
                        for i in receipt.allocations.indices { receipt.allocations[i].participantIDs.removeAll { ids.contains($0) } }
                    }
                HStack {
                    TextField("Nombre de la persona", text: $name)
                    Button { receipt.participants.append(Participant(name: name.trimmingCharacters(in: .whitespacesAndNewlines))); name = "" } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.participants.count >= 50)
                }
            }
            if !receipt.participants.isEmpty {
                Section {
                    ForEach(receipt.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(item.name) · \(Money.display(item.cents, currency: receipt.currency))").font(.headline)
                            ForEach(receipt.participants) { person in
                                Toggle(person.name, isOn: Binding(get: { ids(for: item.id).contains(person.id) }, set: { selected in assign(item.id, person.id, selected) }))
                            }
                            if ids(for: item.id).isEmpty { Text("Sin selección: se reparte entre todas las personas.").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }
                } header: { Text("Asignar productos") } footer: { Text("Los productos sin selección y la diferencia con el total se reparten entre todos. Los céntimos sobrantes se asignan por orden de participantes, también en los descuentos.") }
                Section("Cada persona paga") {
                    ForEach(receipt.participants) { p in LabeledContent(p.name, value: Money.display(amounts[p.id] ?? 0, currency: receipt.currency)) }
                    LabeledContent("Total", value: Money.display(total, currency: receipt.currency)).font(.headline)
                }
            }
            Section { Text("Los cambios del reparto se conservarán cuando pulses Guardar en el ticket.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Dividir ticket").navigationBarTitleDisplayMode(.inline)
    }
    private func ids(for item: UUID) -> [UUID] { receipt.allocations.first { $0.itemID == item }?.participantIDs ?? [] }
    private func assign(_ item: UUID, _ person: UUID, _ selected: Bool) {
        if let i = receipt.allocations.firstIndex(where: { $0.itemID == item }) {
            if selected && !receipt.allocations[i].participantIDs.contains(person) { receipt.allocations[i].participantIDs.append(person) }
            else if !selected { receipt.allocations[i].participantIDs.removeAll { $0 == person } }
        } else if selected { receipt.allocations.append(Allocation(itemID: item, participantIDs: [person])) }
    }
}
