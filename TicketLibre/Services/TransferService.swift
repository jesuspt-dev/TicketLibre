import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

// QR is an explicitly versioned TicketLibre format, never a third-party compatibility claim.
enum TransferService {
    static let prefix = "ticketlibre:1:"
    static func qrPayload(_ receipt: Receipt) throws -> String {
        var compact = receipt
        compact.images = []; compact.rawText = ""; compact.notes = ""
        let bytes = try JSONEncoder().encode(Archive(receipts: [compact]))
        let value = prefix + bytes.base64EncodedString()
        guard value.utf8.count <= 2_000 else { throw AppIssue.message("Este ticket es demasiado grande para un QR. Comparte el JSON o el ZIP para conservarlo completo.") }
        return value
    }
    static func receipt(from payload: String) throws -> Receipt? {
        guard payload.hasPrefix(prefix) else { return nil }
        guard payload.utf8.count <= 3_000,
              let bytes = Data(base64Encoded: String(payload.dropFirst(prefix.count))) else { throw AppIssue.message("El QR de TicketLibre no es válido.") }
        let archive = try JSONDecoder().decode(Archive.self, from: bytes).validated()
        guard archive.receipts.count == 1, archive.shopping.isEmpty else { throw AppIssue.message("El QR debe contener un único ticket.") }
        var receipt = archive.receipts[0]
        receipt.id = UUID() // Import as a draft; duplicate detection remains an explicit user decision.
        receipt.deletedAt = nil
        return receipt
    }
    static func qr(_ receipt: Receipt) throws -> URL {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(try qrPayload(receipt).utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { throw AppIssue.message("No se ha podido generar el QR.") }
        let scale = floor(1000 / output.extent.width)
        let context = CIContext()
        guard let cg = context.createCGImage(output.transformed(by: CGAffineTransform(scaleX: scale, y: scale)), from: output.extent.applying(CGAffineTransform(scaleX: scale, y: scale))) else { throw AppIssue.message("No se ha podido generar el QR.") }
        let image = UIImage(cgImage: cg)
        let canvas = UIGraphicsImageRenderer(size: CGSize(width: image.size.width + 80, height: image.size.height + 80)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: image.size.width + 80, height: image.size.height + 80)); image.draw(at: CGPoint(x: 40, y: 40))
        }
        guard let bytes = canvas.pngData() else { throw AppIssue.message("No se ha podido exportar el QR.") }
        return try ExportService.write(bytes, name: "TicketLibre-QR", ext: "png")
    }
    static func bundle(_ receipt: Receipt) throws -> URL {
        var files: [(String, Data)] = [("ticket.json", try JSONEncoder().encode(Archive(receipts: [receipt]))), ("texto.txt", Data(receipt.rawText.utf8))]
        let pdf = try ExportService.pdf([receipt])
        files.append(("informe.pdf", try Data(contentsOf: pdf)))
        for (n, bytes) in receipt.images.enumerated() { files.append(("original-\(n + 1).jpg", bytes)) }
        return try ExportService.write(ZipStore.archive(files), name: "TicketLibre-ticket", ext: "zip")
    }
}

// Minimal standards-compliant ZIP STORE writer. Names are fixed by our code; no ZIP import.
enum ZipStore {
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data { crc ^= UInt32(byte); for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xEDB88320 : 0) } }
        return ~crc
    }
    static func archive(_ files: [(String, Data)]) -> Data {
        var output = Data(), directory = Data()
        func number<T: FixedWidthInteger>(_ value: T) -> Data { var little = value.littleEndian; return withUnsafeBytes(of: &little) { Data($0) } }
        for (name, data) in files {
            let bytes = Data(name.utf8), crc = crc32(data), offset = UInt32(output.count), count = UInt32(data.count)
            output += number(UInt32(0x04034b50)); output += number(UInt16(20)); output += number(UInt16(0x0800)); output += number(UInt16(0))
            output += number(UInt16(0)); output += number(UInt16(33)); output += number(crc); output += number(count); output += number(count)
            output += number(UInt16(bytes.count)); output += number(UInt16(0)); output += bytes; output += data
            directory += number(UInt32(0x02014b50)); directory += number(UInt16(20)); directory += number(UInt16(20)); directory += number(UInt16(0x0800)); directory += number(UInt16(0))
            directory += number(UInt16(0)); directory += number(UInt16(33)); directory += number(crc); directory += number(count); directory += number(count)
            directory += number(UInt16(bytes.count)); directory += number(UInt16(0)); directory += number(UInt16(0)); directory += number(UInt16(0)); directory += number(UInt16(0)); directory += number(UInt32(0)); directory += number(offset); directory += bytes
        }
        let offset = UInt32(output.count)
        output += directory
        output += number(UInt32(0x06054b50)); output += number(UInt16(0)); output += number(UInt16(0)); output += number(UInt16(files.count)); output += number(UInt16(files.count))
        output += number(UInt32(directory.count)); output += number(offset); output += number(UInt16(0))
        return output
    }
}
