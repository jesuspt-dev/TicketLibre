import AppIntents
import Foundation
import Combine

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var route: String?
}

struct ScanReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Escanear un ticket"
    static var description = IntentDescription("Abre el escáner local de TicketLibre.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        AppRouter.shared.route = "scan"
        return .result()
    }
}
struct OpenShoppingIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir lista de compra"
    static var description = IntentDescription("Abre tu lista de compra de TicketLibre.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        AppRouter.shared.route = "shopping"
        return .result()
    }
}
struct TicketLibreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScanReceiptIntent(), phrases: ["Escanear un ticket con \(.applicationName)"], shortTitle: "Escanear ticket", systemImageName: "doc.viewfinder")
        AppShortcut(intent: OpenShoppingIntent(), phrases: ["Abrir mi lista de compra en \(.applicationName)"], shortTitle: "Lista de compra", systemImageName: "basket")
    }
}
