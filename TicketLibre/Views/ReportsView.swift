import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var scope = "Todos"
    @State private var currency = "EUR"
    @State private var period = "Mes"
    @State private var start = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var end = Date()
    @State private var share: ShareFile?
    private var bounds: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        if period == "Personalizado" { return (cal.startOfDay(for: start), cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: end)) ?? end) }
        let component: Calendar.Component = period == "Semana" ? .weekOfYear : period == "Año" ? .year : period == "Trimestre" ? .quarter : .month
        let interval = cal.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 1)
        return (interval.start, interval.end)
    }
    private var selection: [Receipt] { store.active.filter { $0.currency == currency && (scope == "Todos" || $0.scope == scope) && $0.date >= bounds.0 && $0.date < bounds.1 } }
    private var categories: [(String, Int64)] { Dictionary(grouping: selection, by: \.category).map { ($0.key, $0.value.reduce(0) { $0 + $1.totalCents }) }.sorted { $0.1 > $1.1 } }
    private var days: [(Date, Int64)] { Dictionary(grouping: selection, by: { Calendar.current.startOfDay(for: $0.date) }).map { ($0.key, $0.value.reduce(0) { $0 + $1.totalCents }) }.sorted { $0.0 < $1.0 } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Periodo", selection: $period) { ForEach(["Semana", "Mes", "Trimestre", "Año", "Personalizado"], id: \.self) { Text($0) } }
                    if period == "Personalizado" {
                        DatePicker("Desde", selection: $start, in: ...end, displayedComponents: .date)
                        DatePicker("Hasta", selection: $end, in: start..., displayedComponents: .date)
                    }
                    Picker("Ámbito", selection: $scope) { ForEach(["Todos", "Personal", "Trabajo"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Picker("Moneda", selection: $currency) { ForEach(Catalog.currencies, id: \.self) { Text($0) } }
                    Text(Money.display(selection.reduce(0) { $0 + $1.totalCents }, currency: currency)).font(.system(.largeTitle, design: .rounded).bold())
                    Text("\(selection.count) tickets · \(bounds.0.formatted(date: .abbreviated, time: .omitted)) – \(Calendar.current.date(byAdding: .day, value: -1, to: bounds.1)!.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                }
                if selection.isEmpty { ContentUnavailableView("Sin gastos en este periodo", systemImage: "chart.bar", description: Text("Prueba otro periodo, moneda o ámbito.")).listRowBackground(Color.clear) }
                else {
                    Section("Gastos por día") {
                        Chart(days, id: \.0) { day in BarMark(x: .value("Día", day.0, unit: .day), y: .value("Gasto", Double(day.1) / 100)).foregroundStyle(.teal) }
                            .frame(height: 180).accessibilityLabel("Gráfico de gastos diarios")
                    }
                    Section("Categorías") {
                        Chart(categories, id: \.0) { category in BarMark(x: .value("Importe", Double(category.1) / 100), y: .value("Categoría", category.0)).foregroundStyle(.teal.gradient) }.frame(height: CGFloat(max(100, categories.count * 35)))
                        ForEach(categories, id: \.0) { c in LabeledContent(c.0, value: Money.display(c.1, currency: currency)) }
                    }
                }
                Section("Explorar esta selección") {
                    NavigationLink { CatalogView(receipts: selection, mode: .products) } label: { Label("Productos y precios", systemImage: "shippingbox") }
                    NavigationLink { CatalogView(receipts: selection, mode: .stores) } label: { Label("Tiendas", systemImage: "storefront") }
                    NavigationLink { CatalogView(receipts: selection, mode: .tags) } label: { Label("Etiquetas", systemImage: "tag") }
                }
                Section("Exportar selección") {
                    Button("Informe PDF") { export { try ExportService.pdf(selection) } }.disabled(selection.isEmpty)
                    Button("Productos CSV") { export { try ExportService.csv(selection) } }.disabled(selection.isEmpty)
                }
                Section { Text("Cada moneda se analiza por separado. No se aplican conversiones ni se suman euros con dólares. Las categorías del gráfico son las del ticket; cada producto conserva además su propia categoría.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Análisis").sheet(item: $share) { ShareSheet(urls: [$0.url]).securePresentation() }
        }
    }
    private func export(_ work: () throws -> URL) { do { share = ShareFile(url: try work()) } catch { store.error = error.localizedDescription } }
}

enum CatalogMode { case products, stores, tags
    var title: String { switch self { case .products: return "Productos"; case .stores: return "Tiendas"; case .tags: return "Etiquetas" } }
}
struct CatalogGroup: Identifiable { var id: String; var title: String; var cents: Int64; var receipts: [Receipt] }
struct CatalogView: View {
    let receipts: [Receipt]
    let mode: CatalogMode
    @State private var query = ""
    @EnvironmentObject private var store: ReceiptStore
    private var groups: [CatalogGroup] {
        var result: [String: CatalogGroup] = [:]
        for r in receipts {
            let values: [(String, Int64)]
            switch mode {
            case .products: values = r.items.map { ($0.name, $0.cents) }
            case .stores: values = [(r.store, r.totalCents)]
            case .tags:
                let tree = Set(r.tags.flatMap { tag in let parts = tag.split(separator: "/"); return (1...max(1, parts.count)).map { parts.prefix($0).joined(separator: "/") } }.filter { !$0.isEmpty })
                values = tree.map { ($0, r.totalCents) }
            }
            for (title, cents) in values {
                let key = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
                if result[key] == nil { result[key] = CatalogGroup(id: key, title: title, cents: 0, receipts: []) }
                result[key]!.cents += cents
                if !result[key]!.receipts.contains(where: { $0.id == r.id }) { result[key]!.receipts.append(r) }
            }
        }
        return result.values.filter { query.isEmpty || $0.title.localizedStandardContains(query) }.sorted { $0.cents > $1.cents }
    }
    var body: some View {
        List {
            if mode == .tags { Text("Las etiquetas con / forman niveles. Un ticket puede aparecer en varias etiquetas; sus importes no deben sumarse entre sí.").font(.footnote).foregroundStyle(.secondary) }
            ForEach(groups) { group in
                NavigationLink {
                    CatalogHistory(group: group, mode: mode, currency: receipts.first?.currency ?? "EUR")
                } label: {
                    VStack(alignment: .leading, spacing: 4) { Text(group.title); Text("\(group.receipts.count) compras · \(Money.display(group.cents, currency: receipts.first?.currency ?? "EUR"))").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle(mode.title).searchable(text: $query)
    }
}
struct CatalogHistory: View {
    let group: CatalogGroup
    let mode: CatalogMode
    let currency: String
    @EnvironmentObject private var store: ReceiptStore
    @State private var editing: Receipt?
    @State private var added = false
    var body: some View {
        List {
            Section { Text(Money.display(group.cents, currency: currency)).font(.largeTitle.bold()) }
            if mode == .products {
                Section {
                    Button { addToShopping() } label: { Label(added ? "Añadido a tu lista" : "Añadir a la lista de compra", systemImage: added ? "checkmark" : "basket.badge.plus") }.disabled(added)
                    Text("Precio estimado por unidad a partir de la compra más reciente de esta selección. Comprueba cantidades y formatos.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Historial") {
                ForEach(group.receipts.sorted { $0.date > $1.date }) { r in
                    Button { editing = r } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ReceiptRow(receipt: r)
                            if mode == .products { ForEach(r.items.filter { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES")) == group.id }) { item in Text("\(item.quantity) × \(item.name): \(Money.display(item.cents, currency: currency))").font(.caption).foregroundStyle(.secondary) } }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.navigationTitle(group.title).sheet(item: $editing) { ReceiptEditor(initial: $0) }
    }
    private func addToShopping() {
        let item = group.receipts.sorted { $0.date > $1.date }.flatMap(\.items).first { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES")) == group.id }
        var price: Int64 = item?.cents ?? 0
        if let item, let q = Decimal(string: item.quantity.replacingOccurrences(of: ",", with: ".")), q > 0 {
            let number = NSDecimalNumber(decimal: Decimal(item.cents) / q)
            if number.compare(NSDecimalNumber(value: Money.limit)) == .orderedDescending || number.compare(NSDecimalNumber(value: -Money.limit)) == .orderedAscending { store.error = "El precio unitario no es válido. Revisa la cantidad del producto."; return }
            price = number.rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)).int64Value
        }
        added = store.change { $0.shopping.append(ShoppingItem(name: group.title, estimatedUnitCents: price, currency: currency)) }
    }
}
