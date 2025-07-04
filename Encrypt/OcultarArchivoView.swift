import SwiftUI

struct OcultarArchivoView: View {
    @State private var archivoCifrado: URL?
    @State private var archivoContenedor: URL?
    @State private var mostrarPickerCifrado = false
    @State private var mostrarPickerContenedor = false
    @State private var mensaje = ""

    var body: some View {
        VStack(spacing: 20) {
            Button("Seleccionar archivo cifrado") {
                mostrarPickerCifrado = true
            }
            if let archivoCifrado = archivoCifrado {
                Text("📦 Cifrado: \(archivoCifrado.lastPathComponent)")
            }

            Button("Seleccionar archivo contenedor") {
                mostrarPickerContenedor = true
            }
            if let archivoContenedor = archivoContenedor {
                Text("🖼️ Contenedor: \(archivoContenedor.lastPathComponent)")
            }

            Button("🔐 Ocultar archivo") {
                ocultar()
            }
            .disabled(archivoCifrado == nil || archivoContenedor == nil)

            Text(mensaje).foregroundColor(.green)
        }
        .padding()
        .navigationTitle("Ocultar Archivo")
        
    }

    func ocultar() {
        guard let cifrado = archivoCifrado, let contenedor = archivoContenedor else { return }
        let delimitador = "--BETTY-DELIM--"

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
            mensaje = "✅ Oculto en: \(destino.lastPathComponent)"

        } catch {
            mensaje = "❌ Error: \(error.localizedDescription)"
        }
    }
}
