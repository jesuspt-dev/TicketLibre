import UIKit
import Vision
import PDFKit

struct ScanOutput {
    var text: String
    var images: [Data]
    var receipt: Receipt? = nil
}

enum OCRService {
    static func normalize(_ image: UIImage) throws -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { throw AppIssue.message("La imagen no es válida.") }
        let scale = min(1, 1800 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    static func recognize(_ images: [UIImage]) throws -> ScanOutput {
        guard !images.isEmpty, images.count <= 20 else { throw AppIssue.message("Selecciona entre 1 y 20 páginas.") }
        var text: [String] = [], saved: [Data] = []
        for image in images {
            let upright = try normalize(image)
            guard let cg = upright.cgImage, let jpeg = upright.jpegData(compressionQuality: 0.78) else { throw AppIssue.message("No se pudo preparar la imagen.") }
            if images.count == 1 {
                let barcode = VNDetectBarcodesRequest()
                barcode.symbologies = [.qr]
                try VNImageRequestHandler(cgImage: cg).perform([barcode])
                for result in barcode.results ?? [] {
                    if let payload = result.payloadStringValue, let receipt = try TransferService.receipt(from: payload) {
                        return ScanOutput(text: "", images: [], receipt: receipt)
                    }
                }
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES", "en-US", "fr-FR"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: cg).perform([request])
            // Group bounding boxes by baseline so name/price columns stay on one line.
            let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []
            for o in observations {
                if let i = rows.lastIndex(where: { row in
                    guard let first = row.first else { return false }
                    return abs(first.boundingBox.midY - o.boundingBox.midY) < min(first.boundingBox.height, o.boundingBox.height) * 0.45
                }) { rows[i].append(o) } else { rows.append([o]) }
            }
            text.append(rows.map { row in row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ") }.joined(separator: "\n"))
            saved.append(jpeg)
        }
        return ScanOutput(text: text.joined(separator: "\n"), images: saved)
    }
    static func pdf(_ url: URL, pages selection: [Int]? = nil) throws -> ScanOutput {
        guard let doc = PDFDocument(url: url), !doc.isLocked else { throw AppIssue.message("El PDF no se puede abrir o está protegido con contraseña.") }
        let pages = selection ?? Array(0..<doc.pageCount)
        guard !pages.isEmpty, pages.count <= 20 else { throw AppIssue.message("Elige como máximo 20 páginas. Divide el PDF si es más grande.") }
        var images: [UIImage] = [], texts: [String] = []
        var allHaveText = true
        for n in pages {
            guard let page = doc.page(at: n) else { throw AppIssue.message("La página seleccionada no existe.") }
            images.append(page.thumbnail(of: CGSize(width: 1500, height: 2100), for: .mediaBox))
            let value = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.count < 10 { allHaveText = false }
            texts.append(value)
        }
        if allHaveText {
            return ScanOutput(text: texts.joined(separator: "\n"), images: try images.map { try normalize($0).jpegData(compressionQuality: 0.78) ?? Data() })
        }
        return try recognize(images)
    }
}
