import SwiftUI
import CryptoKit
import UniformTypeIdentifiers
import Security
import UIKit
import QuickLook

struct ArchivoCifrado: Identifiable, Codable {
    let id: UUID
    let nombre: String
    let fecha: Date
    let esRecibido: Bool

    init(nombre: String, fecha: Date, esRecibido: Bool = false) {
        self.id = UUID()
        self.nombre = nombre
        self.fecha = fecha
        self.esRecibido = esRecibido
    }
}

struct CifrarArchivoView: View {
    @State private var archivos: [ArchivoCifrado] = []
    @State private var selectedFileURL: URL?
    @State private var mensaje = ""
    @State private var mostrarImportador = false
    @State private var archivoParaVistaPrevia: URL?
    @State private var mostrarAlertaOcultar = false
    @State private var mostrarSelectorPlantilla = false
    @State private var archivoSeleccionado: ArchivoCifrado? = nil
    @State private var archivoOculto: URL?
    @State private var mostrarCompartir = false
    @State private var archivoSeleccionadoParaDetalle: ArchivoDetalle? = nil
    @State private var archivoParaDescifrar: URL? = nil
    @State private var mostrarFormulario = false
    @State private var modo = 0
    
    let storageKey = "archivos_cifrados"
    
    var body: some View {
        VStack {
            HStack {
                Text("Archivos cifrados")
                    .font(.title2).bold()
                Spacer()
                Button(action: {
                    mostrarImportador = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            Picker("Modo", selection: $modo) {
                Text("Mis archivos").tag(0)
                Text("Recibidos").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            List {
                ForEach(archivos.filter { $0.esRecibido == (modo == 1) }) { archivo in
                    HStack {
                        Image(systemName: "lock.doc.fill")
                            .foregroundColor(archivo.esRecibido ? .gray : .orange)
                            .padding(.trailing, 4)

                        VStack(alignment: .leading) {
                            Text(archivo.nombre)
                                .bold()
                                .lineLimit(2)
                            Text("Cifrado el \(formatDate(archivo.fecha))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                        Image(systemName: "chevron.left")
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(180))
                            .padding(.trailing, 6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
                        let url = directorio.appendingPathComponent(archivo.nombre)
                        archivoSeleccionadoParaDetalle = ArchivoDetalle(url: url)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            eliminarArchivo(archivo)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }

                        Button {
                            compartirArchivoDesdeListado(archivo)
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

            Text(mensaje)
                .foregroundColor(.green)
                .padding(.top, 10)
        }
        .sheet(item: $selectedFileURL) { url in
            SheetFormularioCifrado(
                archivoURL: url,
                onFinish: { _ in
                    selectedFileURL = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        cargarArchivos()
                    }
                },
                isPresented: .constant(true)
            )
        }
        .sheet(item: $archivoSeleccionadoParaDetalle) { detalle in
            DetalleArchivoCifradoView(url: detalle.url) {
                archivoParaDescifrar = detalle.url
                archivoSeleccionadoParaDetalle = nil
            }
            .presentationDetents([.medium]) // o [.height(300)] en iOS 16.4+
            .presentationDragIndicator(.visible) // opcional, muestra línea superior
        }
        .sheet(item: $archivoParaDescifrar) { url in
            SheetDescifrarArchivoView(
                archivo: url,  // ✅ este URL se usará directamente
                onDescifrado: { nuevoArchivo in
                    // Puedes agregar lógica para notificar
                    print("✅ Archivo descifrado: \(nuevoArchivo.nombre)")
                }
            )
        }

        .fileImporter(
            isPresented: $mostrarImportador,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            let fileName = url.lastPathComponent
                            let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                            
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            
                            try FileManager.default.copyItem(at: url, to: destinationURL)
                            selectedFileURL = destinationURL
                        } catch {
                            print("❌ Error al copiar archivo: \(error)")
                        }
                    } else {
                        print("❌ No se pudo acceder al recurso del archivo seleccionado")
                    }
                }
            case .failure(let error):
                print("❌ Error al seleccionar archivo: \(error)")
            }
        }
        .fullScreenCover(item: $archivoParaVistaPrevia) { url in
            NavigationView {
                FilePreview(url: url)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(leading: Button("Cerrar") {
                        archivoParaVistaPrevia = nil
                    })
            }
        }

        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cargarArchivos()
            }
        }
        .alert(isPresented: $mostrarAlertaOcultar) {
            Alert(
                title: Text("¿Deseas ocultar el archivo antes de compartir?"),
                message: Text("Puedes ocultarlo dentro de una imagen u otro archivo contenedor."),
                primaryButton: .default(Text("Sí")) {
                    mostrarSelectorPlantilla = true
                },
                secondaryButton: .cancel(Text("No")) {
                    if let archivo = archivoSeleccionado {
                        compartirSinOcultar(archivo)
                    }
                }
            )
        }
        .sheet(isPresented: $mostrarSelectorPlantilla) {
            DocumentPicker { contenedor in
                mostrarSelectorPlantilla = false
                guard let archivo = archivoSeleccionado else { return }

                let ext = contenedor.pathExtension.lowercased()
                let contenedorFinal = ["jpg", "jpeg", "png", "heic"].contains(ext)
                    ? CifradoUtils.convertirImagenAPDF(contenedor)
                    : contenedor

                guard let definitivo = contenedorFinal else {
                    mensaje = "❌ No se pudo preparar el contenedor."
                    return
                }

                let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
                let urlArchivo = directorio.appendingPathComponent(archivo.nombre)

                archivoOculto = CifradoUtils.ocultarArchivo(cifrado: urlArchivo, contenedor: definitivo)
                if let listo = archivoOculto {
                    CifradoUtils.compartirArchivo(listo)
                    archivoSeleccionado = nil
                }
            }
        }
    }
    
    func filaArchivo(_ archivo: ArchivoCifrado) -> some View {
        HStack {
            Image(systemName: "lock.doc.fill")
                .foregroundColor(archivo.esRecibido ? .gray : .orange)
                .padding(.trailing, 4)

            VStack(alignment: .leading) {
                Text(archivo.nombre)
                    .bold()
                    .lineLimit(2)
                Text("Cifrado el \(formatDate(archivo.fecha))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
            Image(systemName: "chevron.left")
                .foregroundColor(.gray)
                .rotationEffect(.degrees(180))
                .padding(.trailing, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
            let url = directorio.appendingPathComponent(archivo.nombre)
            archivoSeleccionadoParaDetalle = ArchivoDetalle(url: url)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                eliminarArchivo(archivo)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }

            Button {
                compartirArchivoDesdeListado(archivo)
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

    
    func compartirSinOcultar(_ archivo: ArchivoCifrado) {
        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
        let url = directorio.appendingPathComponent(archivo.nombre)

        if FileManager.default.fileExists(atPath: url.path) {
            CifradoUtils.compartirArchivo(url)
            archivoSeleccionado = nil
        } else {
            mensaje = "❌ No se encontró el archivo."
        }
    }

    func eliminarArchivo(_ archivo: ArchivoCifrado) {
        archivos.removeAll { $0.id == archivo.id }
        guardarArchivos()
    }
    
    func compartirArchivoDesdeListado(_ archivo: ArchivoCifrado) {
        archivoSeleccionado = archivo
        mostrarAlertaOcultar = true
    }
    
    func guardarArchivos() {
        if let data = try? JSONEncoder().encode(archivos) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func cargarArchivos() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let guardados = try? JSONDecoder().decode([ArchivoCifrado].self, from: data) {
            self.archivos = guardados
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    func compartirArchivo(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Para mostrarlo en la ventana actual
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    func descargarArchivo(_ archivo: ArchivoCifrado) {
        let origen = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Encrypt_iOS")
            .appendingPathComponent(archivo.nombre)

        guard FileManager.default.fileExists(atPath: origen.path) else {
            mensaje = "❌ No se encontró el archivo."
            return
        }

        // Exportar sin mover (permite al usuario elegir dónde guardar)
        let picker = UIDocumentPickerViewController(forExporting: [origen], asCopy: true)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(picker, animated: true, completion: nil)
            mensaje = "📤 Selecciona dónde guardar"
        }
    }
}


struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct FilePreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: FilePreview
        
        init(_ parent: FilePreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

extension URL: Identifiable {
    public var id: String { self.path }
}

struct DetalleArchivoCifradoView: View {
    let url: URL
    let onDescifrar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📄 Nombre: \(url.lastPathComponent)")
            Text("📅 Fecha: \(formatDate(getFileDate()))")
            Text("🔐 Tipo: \(tipoDeCifrado())")
            Text("📦 Tamaño: \(formatSize(getFileSize()))")

            Spacer()

            Button("Descifrar archivo") {
                onDescifrar()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }

    func getFileDate() -> Date {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date()
    }

    func getFileSize() -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    func formatSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func tipoDeCifrado() -> String {
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tipo = json["type"] as? String {
            return tipo == "password" ? "Contraseña" : "Llave pública"
        }
        return "Desconocido"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ArchivoDetalle: Identifiable {
    let id = UUID()
    let url: URL
}
