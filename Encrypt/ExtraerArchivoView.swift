import SwiftUI

struct ExtraerArchivoView: View {
    @State private var archivoOculto: URL?
    @State private var mostrarPicker = false
    @State private var mensaje = ""

    var body: some View {
        VStack(spacing: 20) {
            Button("Seleccionar archivo contenedor") {
                mostrarPicker = true
            }

            if let archivoOculto = archivoOculto {
                Text("📂 Seleccionado: \(archivoOculto.lastPathComponent)")
            }

            Button("🧪 Extraer oculto") {
                extraer()
            }
            .disabled(archivoOculto == nil)

            Text(mensaje).foregroundColor(.green)
        }
        .padding()
        .navigationTitle("Extraer Archivo")
        
    }

    func extraer() {
        guard let url = archivoOculto else { return }
        let delimitador = "--BETTY-DELIM--"

        do {
            let datos = try Data(contentsOf: url)
            guard let rangoDelim = datos.range(of: delimitador.data(using: .utf8)!) else {
                mensaje = "❌ Delimitador no encontrado"
                return
            }

            let datosCifrados = datos.suffix(from: rangoDelim.upperBound)
            let destino = FileManager.default.temporaryDirectory.appendingPathComponent("extraido_oculto.json")
            try datosCifrados.write(to: destino)

            mensaje = "✅ Extraído: \(destino.lastPathComponent)"

        } catch {
            mensaje = "❌ Error: \(error.localizedDescription)"
        }
    }
}
