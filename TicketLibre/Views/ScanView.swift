import SwiftUI
import PhotosUI
import VisionKit
import PDFKit
import UniformTypeIdentifiers

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var camera = false
    @State private var file = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @State private var draft: Receipt?
    @State private var warnings: [String] = []
    @State private var pdfURL: URL?
    var body: some View {
        Group {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "viewfinder").font(.system(size: 44)).foregroundStyle(.teal)
                        Text("Del papel a tu bolsillo").font(.title2.bold())
                        Text("Sin créditos ni suscripciones. El reconocimiento se hace en este iPhone.").foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                    Button { camera = true } label: { Label("Escanear con la cámara", systemImage: "doc.viewfinder") }.disabled(!VNDocumentCameraViewController.isSupported)
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) { Label("Importar fotos o QR de TicketLibre", systemImage: "photo.on.rectangle") }
                    Button { file = true } label: { Label("Importar PDF, imagen o texto", systemImage: "doc.badge.plus") }
                    Button { draft = Receipt(); warnings = [] } label: { Label("Añadir manualmente", systemImage: "square.and.pencil") }
                }
                Section("Desde texto") {
                    TextEditor(text: $text).frame(minHeight: 140).accessibilityLabel("Texto del ticket")
                    PasteButton(payloadType: String.self) { values in text = values.joined(separator: "\n") }
                    Button("Analizar texto") { accept(ScanOutput(text: text, images: [])) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section { Text("Para un ticket de varias páginas, selecciona todas juntas. Cada importación crea un ticket; revisa el resultado antes de guardarlo.").font(.footnote).foregroundStyle(.secondary) }
            }
            .disabled(busy)
            .navigationTitle("Añadir ticket")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() }.disabled(busy) } }
            .overlay { if busy { ProgressView("Reconociendo en tu iPhone…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
            .sheet(isPresented: $camera) {
                Group {
                DocumentScanner(onCancel: { camera = false }) { result in
                    camera = false
                    switch result { case .success(let images): process { try OCRService.recognize(images) }; case .failure(let e): error = e.localizedDescription }
                }
                }.securePresentation()
            }
            .sheet(item: $draft, onDismiss: { dismiss() }) { ReceiptEditor(initial: $0, scanWarnings: warnings) }
            .sheet(isPresented: Binding(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
                if let pdfURL { PDFPagePicker(url: pdfURL) { pages in
                    self.pdfURL = nil
                    process { try OCRService.pdf(pdfURL, pages: pages) }
                } }
            }
            .fileImporter(isPresented: $file, allowedContentTypes: [.image, .pdf, .plainText]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 40_000_000 else { throw AppIssue.message("El archivo supera 40 MB.") }
                    if url.pathExtension.lowercased() == "pdf" {
                        let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                        try FileManager.default.copyItem(at: url, to: local)
                        pdfURL = local
                    } else {
                        let data = try Data(contentsOf: url)
                        if let image = UIImage(data: data) { process { try OCRService.recognize([image]) } }
                        else { guard let value = String(data: data, encoding: .utf8) else { throw AppIssue.message("El texto debe estar en UTF-8.") }; accept(ScanOutput(text: value, images: [])) }
                    }
                } catch { self.error = error.localizedDescription }
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                busy = true
                Task {
                    do {
                        var images: [UIImage] = []
                        for item in items {
                            guard let bytes = try await item.loadTransferable(type: Data.self), bytes.count <= 40_000_000, let image = UIImage(data: bytes) else { throw AppIssue.message("No se pudo abrir alguna foto, o supera 40 MB. No se ha importado el ticket.") }
                            images.append(image)
                        }
                        busy = false
                        process { try OCRService.recognize(images) }
                    } catch { busy = false; self.error = error.localizedDescription }
                    photoItems = []
                }
            }
            .alert("No se ha podido importar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Entendido") {} } message: { Text(error ?? "") }
        }
    
        }.securePresentation()
    }
    private func accept(_ output: ScanOutput) {
        if let receipt = output.receipt { warnings = ["Ticket importado desde un QR de TicketLibre. Revisa los datos antes de guardarlo."]; draft = receipt; return }
        let parsed = ReceiptParser.parse(output.text)
        var receipt = parsed.receipt; receipt.images = output.images
        warnings = parsed.warnings
        draft = receipt
    }
    private func process(_ work: @escaping () throws -> ScanOutput) {
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work() }
            DispatchQueue.main.async {
                busy = false
                switch result { case .success(let output): accept(output); case .failure(let e): error = e.localizedDescription }
            }
        }
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let completion: (Result<[UIImage], Error>) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion, onCancel) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController(); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<[UIImage], Error>) -> Void
        let onCancel: () -> Void
        init(_ completion: @escaping (Result<[UIImage], Error>) -> Void, _ onCancel: @escaping () -> Void) { self.completion = completion; self.onCancel = onCancel }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 20 else { completion(.failure(AppIssue.message("Máximo 20 páginas por ticket."))); return }
            completion(.success((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { completion(.failure(error)) }
    }
}

struct PDFPagePicker: View {
    let url: URL
    let completion: ([Int]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<Int> = []
    private var count: Int { PDFDocument(url: url)?.pageCount ?? 0 }
    var body: some View {
        Group {
        NavigationStack {
            List {
                Text("Selecciona hasta 20 páginas de un mismo ticket.").font(.footnote)
                ForEach(0..<count, id: \.self) { n in
                    Button { if chosen.contains(n) { chosen.remove(n) } else if chosen.count < 20 { chosen.insert(n) } } label: {
                        HStack {
                            if let page = PDFDocument(url: url)?.page(at: n) { Image(uiImage: page.thumbnail(of: CGSize(width: 65, height: 90), for: .mediaBox)).resizable().scaledToFit().frame(width: 45, height: 64) }
                            Text("Página \(n + 1)"); Spacer(); Image(systemName: chosen.contains(n) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                if count == 0 { Text("No se puede abrir este PDF. Puede estar protegido con contraseña.").foregroundStyle(.orange) }
            }.navigationTitle("Páginas del PDF")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Analizar") { completion(chosen.sorted()) }.disabled(chosen.isEmpty) }
                }.onAppear { chosen = Set(0..<min(count, 20)) }
        }
    
        }.securePresentation()
    }
}
