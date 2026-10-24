import SwiftUI

struct ShoppingView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var draft: ShoppingItem?
    @State private var clear = false
    var body: some View {
        NavigationStack {
            List {
                if store.archive.shopping.isEmpty { ContentUnavailableView("Prepara tu próxima compra", systemImage: "basket", description: Text("Añade productos manualmente o desde Análisis → Productos.")).listRowBackground(Color.clear) }
                else {
                    Section("Estimación pendiente") {
                        ForEach(Catalog.currencies, id: \.self) { currency in
                            let pending = store.archive.shopping.filter { !$0.checked && $0.currency == currency }
                            if !pending.isEmpty { LabeledContent(currency, value: Money.display(pending.reduce(0) { $0 + $1.estimatedUnitCents * Int64($1.quantity) }, currency: currency)) }
                        }
                    }
                }
                Section("Productos") {
                    ForEach(store.archive.shopping) { item in
                        HStack(spacing: 12) {
                            Button { _ = store.change { a in if let i = a.shopping.firstIndex(where: { $0.id == item.id }) { a.shopping[i].checked.toggle() } } } label: { Image(systemName: item.checked ? "checkmark.circle.fill" : "circle").font(.title2) }.buttonStyle(.borderless).accessibilityLabel(item.checked ? "Marcar pendiente" : "Marcar comprado")
                            Button { draft = item } label: {
                                VStack(alignment: .leading) { Text(item.name).strikethrough(item.checked); Text("\(item.quantity) × \(Money.display(item.estimatedUnitCents, currency: item.currency))").font(.caption).foregroundStyle(.secondary) }.foregroundStyle(item.checked ? .secondary : .primary)
                            }.buttonStyle(.plain)
                        }
                    }.onDelete { offsets in _ = store.change { $0.shopping.remove(atOffsets: offsets) } }
                    Button { draft = ShoppingItem(name: "") } label: { Label("Añadir producto", systemImage: "plus.circle") }
                }
                Section { Text("Los precios son estimaciones editables. La lista no crea gastos ni tickets automáticamente.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Lista de compra")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Limpiar") { clear = true }.disabled(!store.archive.shopping.contains { $0.checked }) } }
                .confirmationDialog("¿Eliminar los productos marcados?", isPresented: $clear, titleVisibility: .visible) { Button("Eliminar comprados", role: .destructive) { _ = store.change { $0.shopping.removeAll { $0.checked } } } }
                .sheet(item: $draft) { item in ShoppingEditor(initial: item) { value in store.change { a in if let i = a.shopping.firstIndex(where: { $0.id == value.id }) { a.shopping[i] = value } else { a.shopping.append(value) } } } }
        }
    }
}
struct ShoppingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ShoppingItem
    @State private var price: String
    let completion: (ShoppingItem) -> Bool
    init(initial: ShoppingItem, completion: @escaping (ShoppingItem) -> Bool) { _item = State(initialValue: initial); _price = State(initialValue: Money.edit(initial.estimatedUnitCents)); self.completion = completion }
    var body: some View {
        Group {
        NavigationStack {
            Form {
                TextField("Producto", text: $item.name)
                Stepper("Cantidad: \(item.quantity)", value: $item.quantity, in: 1...999)
                TextField("Precio estimado por unidad", text: $price).keyboardType(.numbersAndPunctuation)
                Picker("Moneda", selection: $item.currency) { ForEach(Catalog.currencies, id: \.self) { Text($0) } }
            }.navigationTitle("Producto de la lista").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Guardar") { if let cents = Money.parse(price) { item.estimatedUnitCents = cents; if completion(item) { dismiss() } } }.disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Money.parse(price) == nil) }
                }
        }
    
        }.securePresentation()
    }
}
