import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct DescifrarArchivoView: View {
    @State private var mostrarFormulario = false
    @State private var archivos: [ArchivoDescifrado] = []
    @State private var archivoSeleccionado: URL?
    @State private var mensaje = ""
    @State private var mostrarPicker = false
    @State private var mostrarCompartir = false
    @State private var archivoParaCompartir: URL?
    @State private var archivoParaVistaPrevia: URL?
    @State private var archivoPendiente: ArchivoDescifrado? = nil
    @State private var mostrarAlertaCompartir = false
    @State private var archivoSeleccionadoParaCifrar: ArchivoDescifrado? = nil
    @State private var mostrarSheetCifrado = false

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("Archivos descifrados")
                        .font(.title2).bold()
                    Spacer()
                    Button(action: { mostrarFormulario = true }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                if archivos.isEmpty {
                    Spacer()
                    Text("Aún no hay archivos descifrados")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(archivos) { archivo in
                            Button {
                                archivoParaVistaPrevia = archivo.url
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)

                                    VStack(alignment: .leading) {
                                        Text(archivo.nombre)
                                            .bold()
                                            .lineLimit(2)
                                        Text("Descifrado el \(formatDate(archivo.fecha))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    eliminarArchivo(archivo)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }

                                Button {
                                    archivoPendiente = archivo
                                    mostrarAlertaCompartir = true
                                } label: {
                                    Label("Compartir", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)

                                Button {
                                    descargarArchivo(archivo)
                                } label: {
                                    Label("Descargar", systemImage: "arrow.down.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $mostrarFormulario) {
                SheetDescifrarArchivoView(onDescifrado: { nuevoArchivo in
                    archivos.append(nuevoArchivo)
                })
            }
            .onAppear {
                cargarArchivosDescifrados()
            }
            .fullScreenCover(item: $archivoParaVistaPrevia) { url in
                NavigationView {
                    VStack {
                        FilePreview(url: url)
                            .frame(maxHeight: .infinity)

                        Button(action: {
                            archivoParaVistaPrevia = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                archivoSeleccionadoParaCifrar = ArchivoDescifrado(nombre: url.lastPathComponent, url: url, fecha: Date())
                                mostrarSheetCifrado = true
                            }
                        }) {
                            Label("Cifrar archivo", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .padding()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") {
                                archivoParaVistaPrevia = nil
                            }
                        }
                    }
                }
            }
            .sheet(item: $archivoSeleccionadoParaCifrar) { archivo in
                SheetFormularioCifrado(
                    archivoURL: archivo.url,
                    onFinish: { _ in
                        archivoSeleccionadoParaCifrar = nil
                    },
                    isPresented: Binding(
                        get: { archivoSeleccionadoParaCifrar != nil },
                        set: { newValue in
                            if !newValue { archivoSeleccionadoParaCifrar = nil }
                        }
                    )
                )
            }

            .alert("Este archivo no está cifrado", isPresented: $mostrarAlertaCompartir) {
                Button("Cancelar", role: .cancel) {}
                Button("Continuar") {
                    if let archivo = archivoPendiente,
                       let temp = copiarAArchivoTemporal(archivo.url) {
                        compartirArchivo(temp)
                    }
                    archivoPendiente = nil
                }
            } message: {
                Text("¿Deseas compartirlo de todos modos?")
            }
        }
    }
    func compartirArchivo(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    func eliminarArchivo(_ archivo: ArchivoDescifrado) {
        do {
            try FileManager.default.removeItem(at: archivo.url)
            archivos.removeAll { $0.id == archivo.id }
        } catch {
            print("❌ Error eliminando archivo: \(error)")
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    func cargarArchivosDescifrados() {
        archivos.removeAll()
        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")

        guard let items = try? FileManager.default.contentsOfDirectory(at: directorio, includingPropertiesForKeys: nil) else { return }

        for url in items {
            if !url.lastPathComponent.hasSuffix(".json") {
                let atributos = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fecha = atributos?[.creationDate] as? Date ?? Date()
                let archivo = ArchivoDescifrado(nombre: url.lastPathComponent, url: url, fecha: fecha)
                archivos.append(archivo)
            }
        }

        archivos.sort { $0.fecha > $1.fecha } // Más reciente primero
    }
    func copiarAArchivoTemporal(_ url: URL) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            print("❌ Error copiando archivo a temporal: \(error)")
            return nil
        }
    }
    func descargarArchivo(_ archivo: ArchivoDescifrado) {
        guard FileManager.default.fileExists(atPath: archivo.url.path) else {
            mensaje = "❌ No se encontró el archivo."
            return
        }

        let picker = UIDocumentPickerViewController(forExporting: [archivo.url], asCopy: true)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(picker, animated: true, completion: nil)
            mensaje = "📤 Selecciona dónde guardar"
        }
    }

}

struct LlavePrivada: Identifiable, Hashable {
    let id = UUID()
    let alias: String
    let clave: SecKey
}

