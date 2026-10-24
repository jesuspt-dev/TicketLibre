import SwiftUI
import LocalAuthentication
import CoreSpotlight

@main
struct TicketLibreApp: App {
    @StateObject private var store = ReceiptStore()
    @StateObject private var gate = DeviceGate()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).environmentObject(gate).tint(.teal) }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var gate: DeviceGate
    @Environment(\.scenePhase) private var phase
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("appearance") private var appearance = "Sistema"
    @StateObject private var router = AppRouter.shared
    @State private var selected = 0
    @State private var scan = false
    @State private var focus: Receipt?
    var body: some View {
        ZStack {
            TabView(selection: $selected) {
                ReceiptsView().tabItem { Label("Tickets", systemImage: "receipt") }.tag(0)
                ReportsView().tabItem { Label("Análisis", systemImage: "chart.bar.xaxis") }.tag(1)
                ShoppingView().tabItem { Label("Compra", systemImage: "basket") }.tag(2)
                SettingsView().tabItem { Label("Más", systemImage: "ellipsis.circle") }.tag(3)
            }

        }.securePresentation()
        .preferredColorScheme(appearance == "Oscuro" ? .dark : appearance == "Claro" ? .light : nil)
        .task { ExportService.cleanup(); if lockEnabled { gate.authenticate() }; routePending() }
        .onChange(of: router.route) { _, _ in routePending() }
        .onChange(of: gate.locked) { _, locked in if !locked { routePending() } }
        .onChange(of: phase) { _, value in
            if value != .active { gate.lock() }
            if value == .active && gate.enabled && gate.locked { gate.authenticate() }
        }
        .onChange(of: lockEnabled) { _, value in gate.lock(); store.refreshSearchIndex(); if value { gate.authenticate() } }
        .onOpenURL { url in
            guard url.scheme == "ticketlibre" else { return }
            router.route = url.host
            routePending()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard !lockEnabled || !gate.locked,
                  let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
            focus = store.active.first { $0.id.uuidString == id }
        }
        .sheet(isPresented: $scan) { ScanView() }
        .sheet(item: $focus) { ReceiptEditor(initial: $0) }
        .alert("TicketLibre", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private func routePending() {
        guard !gate.enabled || !gate.locked, let route = router.route else { return }
        if route == "scan" { scan = true }
        if route == "shopping" { selected = 2 }
        if route == "receipts" { selected = 0 }
        router.route = nil
    }
}

struct GlassAction: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.padding(14).glassEffect(.regular.interactive(), in: .capsule) }
        else { content.padding(14).background(.regularMaterial, in: Capsule()) }
    }
}

struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: urls, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
