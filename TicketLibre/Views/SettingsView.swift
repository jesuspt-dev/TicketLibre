import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @AppStorage("appearance") private var appearance = "Sistema"
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("spotlightEnabled") private var spotlight = false
    @State private var share: ShareFile?
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var recovery = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("TicketLibre", systemImage: "receipt.fill").font(.title2.bold()).foregroundStyle(.teal)
                    Text("Versión 1.0.2 · Gratis y de código abierto (MIT)").font(.subheadline)
                    Text("Sin anuncios, cuentas, créditos ni suscripciones. El escaneo no envía tus tickets a ningún servidor.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Tu app") {
                    Picker("Apariencia", selection: $appearance) { ForEach(["Sistema", "Claro", "Oscuro"], id: \.self) { Text($0) } }
                    Toggle("Face ID o código del dispositivo", isOn: Binding(get: { lockEnabled }, set: { value in
                        if value {
                            let context = LAContext(); var issue: NSError?
                            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &issue) else { store.error = issue?.localizedDescription ?? "Configura un código en el iPhone para activar el bloqueo."; return }
                            spotlight = false
                        }
                        lockEnabled = value
                    }))
                    Toggle("Buscar tickets en Spotlight", isOn: $spotlight).disabled(lockEnabled)
                        .onChange(of: spotlight) { _, _ in store.refreshSearchIndex() }
                    Text("Spotlight es opcional y muestra tiendas y etiquetas fuera de la app. Se desactiva al activar el bloqueo. Las exportaciones que compartas no quedan protegidas por el bloqueo de la app.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Copias y recuperación") {
                    Button("Exportar copia completa") { do { share = ShareFile(url: try store.backupURL()) } catch { store.error = error.localizedDescription } }.disabled(store.recoveryRequired)
                    Button("Importar copia o ticket JSON") { importing = true }
                    Button("Recuperar la copia local anterior") { recovery = true }
                    Text("Exporta periódicamente. Las copias JSON incluyen los originales y la papelera, y no están cifradas. Guárdalas en un lugar privado. Importar añade registros nuevos por ID y conserva los existentes.").font(.footnote).foregroundStyle(.secondary)
                    if store.recoveryRequired { Label("Es necesaria una recuperación. No se sobrescribirá la colección dañada.", systemImage: "exclamationmark.shield").foregroundStyle(.orange) }
                }
                Section {
                    NavigationLink { TrashView() } label: { Label("Papelera (\(store.trash.count))", systemImage: "trash") }
                    NavigationLink { PrivacyView() } label: { Label("Privacidad y licencia", systemImage: "hand.raised") }
                }
                Section("Atajos de Siri") {
                    Text("En Atajos, añade la acción «Abrir URL» con una de estas direcciones:").font(.footnote).foregroundStyle(.secondary)
                    Text("ticketlibre://scan\nticketlibre://shopping\nticketlibre://receipts").font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                }
            }.navigationTitle("Más")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do { pendingImport = try result.get() } catch { store.error = error.localizedDescription }
                }
                .confirmationDialog("¿Importar esta copia?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                    Button("Añadir datos de la copia") { if let url = pendingImport { store.importBackup(url); pendingImport = nil } }
                } message: { Text("Los registros con el mismo ID no se modificarán. Comprueba que el archivo procede de una fuente de confianza.") }
                .confirmationDialog("¿Recuperar la copia anterior?", isPresented: $recovery, titleVisibility: .visible) {
                    Button("Recuperar versión anterior", role: .destructive) { store.recoverPrevious() }
                } message: { Text("Se sustituirá la colección por la última versión local guardada antes de tu último cambio. Exporta primero una copia si puedes.") }
                .sheet(item: $share) { ShareSheet(urls: [$0.url]).securePresentation() }
        }
    }
}

struct TrashView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var deleting: Receipt?
    var body: some View {
        List {
            Section { Text("Los tickets se eliminan definitivamente al abrir la app después de 30 días en la papelera.").font(.footnote).foregroundStyle(.secondary) }
            if store.trash.isEmpty { ContentUnavailableView("Papelera vacía", systemImage: "trash") }
            ForEach(store.trash.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }) { r in
                VStack(alignment: .leading, spacing: 10) {
                    ReceiptRow(receipt: r)
                    HStack {
                        Button("Recuperar") { store.restore(r.id) }.buttonStyle(.borderless)
                        Spacer()
                        Button("Eliminar", role: .destructive) { deleting = r }.buttonStyle(.borderless)
                    }
                }
            }
        }.navigationTitle("Papelera")
            .confirmationDialog("¿Eliminar definitivamente?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Eliminar definitivamente", role: .destructive) { if let r = deleting { store.removePermanently(r.id); deleting = nil } }
            } message: { Text("No podrás recuperar el ticket desde la app. Una copia de seguridad anterior puede conservarlo.") }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Tus datos") {
                Text("Los tickets, productos, fotografías y lista de compra se guardan en el almacenamiento privado de esta app, con protección de archivos de iOS. El sistema puede incluirlos en las copias del dispositivo según tus ajustes de iCloud.")
                Text("El reconocimiento usa Apple Vision en el dispositivo. TicketLibre no incorpora red, publicidad, analítica ni servicios de IA externos. No exige una cuenta.")
                Text("Se solicita acceso a la cámara solo al escanear. El selector de Fotos comparte únicamente las imágenes que elijas. Face ID o el código se usan solo si activas el bloqueo.")
                Text("Puedes exportar tus datos, mover tickets a la papelera y eliminarlos. Desinstalar la app elimina su almacenamiento local; exporta antes una copia si quieres conservarlo.")
            }
            Section("Código libre · MIT") {
                Text("Copyright © 2026 TicketLibre contributors. Se permite usar, copiar, modificar y distribuir el código, incluso comercialmente, conservando el aviso de copyright y la licencia MIT. Se entrega sin garantía. La licencia completa acompaña al proyecto.")
                Text("TicketLibre es un proyecto independiente. No está afiliado a Ticketeca ni utiliza su código, marca, iconos o recursos.")
            }
            Section("Precisión y límites") {
                Text("El reconocimiento local propone datos que debes revisar. Puede fallar con tickets arrugados, fotos borrosas, columnas o pesos. No equivale al análisis de un modelo remoto. Guarda los originales.")
                Text("Esta versión no incluye widgets, sincronización entre dispositivos, compatibilidad con QR de otras apps ni todas las traducciones de Ticketeca. Incluye atajos de Siri y admite también Abrir URL.")
            }
        }.navigationTitle("Privacidad").navigationBarTitleDisplayMode(.inline)
    }
}
