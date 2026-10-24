import SwiftUI

struct ReceiptsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var query = ""
    @State private var scope = "Todos"
    @State private var category = "Todas"
    @State private var currency = "EUR"
    @State private var scan = false
    @State private var editing: Receipt?
    var filtered: [Receipt] {
        store.active.filter { r in
            (scope == "Todos" || r.scope == scope) && (category == "Todas" || r.category == category) && r.currency == currency &&
            (query.isEmpty || ([r.store, r.number, r.notes] + r.tags + r.items.map(\.name)).joined(separator: " ").localizedStandardContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Todo bajo control").font(.title2.bold())
                        Text(Money.display(filtered.reduce(0) { $0 + $1.totalCents }, currency: currency)).font(.system(.largeTitle, design: .rounded).bold()).contentTransition(.numericText())
                        Text("\(filtered.count) tickets en esta selección").font(.subheadline).foregroundStyle(.secondary)
                        Label("Escaneos gratuitos · Datos en tu iPhone", systemImage: "checkmark.shield").font(.caption).foregroundStyle(.teal)
                    }.padding(.vertical, 8)
                    Picker("Ámbito", selection: $scope) { ForEach(["Todos", "Personal", "Trabajo"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    HStack {
                        Picker("Categoría", selection: $category) { Text("Todas").tag("Todas"); ForEach(Catalog.categories, id: \.self) { Text($0).tag($0) } }
                        Picker("Moneda", selection: $currency) { ForEach(Catalog.currencies, id: \.self) { Text($0).tag($0) } }
                    }
                }
                if store.recoveryRequired {
                    Section { Label("Datos protegidos: recupera la colección en Más.", systemImage: "exclamationmark.shield").foregroundStyle(.orange) }
                } else if filtered.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "Tu archivo empieza aquí" : "Sin resultados", systemImage: "receipt", description: Text("Escanea un ticket, importa un PDF o añádelo a mano."))
                        .listRowBackground(Color.clear)
                }
                Section("Tickets") {
                    ForEach(filtered) { r in
                        Button { editing = r } label: { ReceiptRow(receipt: r) }.buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("TicketLibre")
            .searchable(text: $query, prompt: "Tienda, producto o etiqueta")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { scan = true } label: { Image(systemName: "plus.viewfinder") }.accessibilityLabel("Añadir o escanear un ticket")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { scan = true } label: { Label("Añadir ticket", systemImage: "camera.viewfinder").font(.headline).frame(maxWidth: .infinity) }
                    .modifier(GlassAction()).padding(.horizontal, 32).padding(.bottom, 8).disabled(store.recoveryRequired)
            }
            .sheet(isPresented: $scan) { ScanView() }
            .sheet(item: $editing) { ReceiptEditor(initial: $0) }
        }
    }
}

struct ReceiptRow: View {
    let receipt: Receipt
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.scope == "Trabajo" ? "briefcase.fill" : "receipt.fill").font(.title3).foregroundStyle(.teal).frame(width: 42, height: 46).background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.store).font(.headline).lineLimit(2)
                Text("\(receipt.date.formatted(date: .abbreviated, time: .omitted)) · \(receipt.category)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(Money.display(receipt.totalCents, currency: receipt.currency)).font(.subheadline.weight(.semibold)).monospacedDigit()
        }.padding(.vertical, 4)
    }
}
