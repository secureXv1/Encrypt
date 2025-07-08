import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct CifradoUtils {
    static func convertirImagenAPDF(_ imagenURL: URL) -> URL? {
        // Crear una copia local primero para evitar errores de acceso
        let tempImageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(imagenURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: tempImageURL.path) {
                try FileManager.default.removeItem(at: tempImageURL)
            }
            try FileManager.default.copyItem(at: imagenURL, to: tempImageURL)
        } catch {
            print("❌ Error copiando imagen a temporal: \(error)")
            return nil
        }

        // Ahora intenta cargar desde la copia segura
        guard let imageData = try? Data(contentsOf: tempImageURL),
              let image = UIImage(data: imageData) else {
            print("❌ No se pudo cargar la imagen desde datos.")
            return nil
        }

        // Crear PDF
        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        UIGraphicsBeginPDFPage()
        image.draw(in: pageRect)
        UIGraphicsEndPDFContext()

        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent(tempImageURL.deletingPathExtension().lastPathComponent + ".pdf")

        do {
            try pdfData.write(to: destino)
            return destino
        } catch {
            print("❌ Error escribiendo PDF: \(error)")
            return nil
        }
    }

    static func ocultarArchivo(cifrado: URL, contenedor: URL) -> URL? {
        let delimitador = "--BETTY-DELIM--"
        let acceso = contenedor.startAccessingSecurityScopedResource()
        defer {
            if acceso {
                contenedor.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let datosContenedor = try Data(contentsOf: contenedor)
            let datosCifrado = try Data(contentsOf: cifrado)
            let delimitadorData = delimitador.data(using: .utf8)!

            var combinado = Data()
            combinado.append(datosContenedor)
            combinado.append(delimitadorData)
            combinado.append(datosCifrado)

            let destino = FileManager.default.temporaryDirectory.appendingPathComponent(contenedor.lastPathComponent)
            try combinado.write(to: destino)
            return destino

        } catch {
            print("❌ Error ocultando archivo: \(error.localizedDescription)")
            return nil
        }
    }

    static func prepararArchivoParaCompartir(_ url: URL) -> URL {
        let compartirDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS/Compartir")
        try? FileManager.default.createDirectory(at: compartirDir, withIntermediateDirectories: true)

        let nombreSeguro = url.lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let destino = compartirDir.appendingPathComponent(nombreSeguro)

        do {
            if FileManager.default.fileExists(atPath: destino.path) {
                try FileManager.default.removeItem(at: destino)
            }
            try FileManager.default.copyItem(at: url, to: destino)
            return destino
        } catch {
            print("❌ Error preparando archivo para compartir: \(error.localizedDescription)")
            return url
        }
    }
    static func compartirArchivo(_ url: URL) {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
}
