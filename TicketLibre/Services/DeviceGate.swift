import SwiftUI
import LocalAuthentication

@MainActor
final class DeviceGate: ObservableObject {
    @Published private(set) var locked = UserDefaults.standard.bool(forKey: "lockEnabled")
    @Published private(set) var authenticating = false
    @Published private(set) var issue: String?
    var enabled: Bool { UserDefaults.standard.bool(forKey: "lockEnabled") }
    func lock() { locked = enabled }
    func authenticate() {
        guard enabled else { locked = false; return }
        guard !authenticating else { return }
        authenticating = true
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Acceder a tus tickets y gastos") { success, error in
            Task { @MainActor in
                self.authenticating = false
                self.locked = !success
                self.issue = success ? nil : error?.localizedDescription
            }
        }
    }
}
struct SecurePresentation: ViewModifier {
    @EnvironmentObject private var gate: DeviceGate
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        ZStack {
            content.opacity(gate.enabled && (gate.locked || phase != .active) ? 0 : 1)
                .disabled(gate.enabled && gate.locked)
            if gate.enabled && (gate.locked || phase != .active) {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 60)).foregroundStyle(.teal)
                    Text("Tus tickets, protegidos").font(.title2.bold())
                    if let issue = gate.issue { Text(issue).font(.footnote).multilineTextAlignment(.center) }
                    Button("Desbloquear") { gate.authenticate() }.buttonStyle(.borderedProminent).disabled(gate.authenticating)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground))
            }
        }
    }
}
extension View { func securePresentation() -> some View { modifier(SecurePresentation()) } }
