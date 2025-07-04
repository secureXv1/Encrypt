import SwiftUI
import CryptoKit
import UniformTypeIdentifiers
import Security
import UIKit
import QuickLook

struct ArchivoCifrado: Identifiable, Codable {
    let id = UUID()
    let nombre: String
    let fecha: Date
}

struct CifrarArchivoView: View {
    @State private var archivos: [ArchivoCifrado] = []
    @State private var selectedFileURL: URL?
    @State private var usarContraseña = true
    @State private var contraseña = ""
    @State private var mensaje = ""
    @State private var mostrarPicker = false
    @State private var llavesDisponibles: [LlavePublica] = []
    @State private var llaveSeleccionada: LlavePublica?
    @State private var mostrarImportador = false
    @State private var archivoParaCompartir: ArchivoCompartible?
    @State private var urlArchivoCifrado: URL? = nil
    @State private var mostrarCompartir = false
    @State private var archivoParaVistaPrevia: URL?

    let storageKey = "archivos_cifrados"
    let masterPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmwF4EDZIm66+kJZlTTiV
    TtxAxr60j2CmxLfLBfdvuJdKadmV4i6yatfRSeS+ZGCAFBKwb+jHNNWv2VyWDyGO
    3vWqBA4OI69jCFF1R9cOJY4bzDmxB1pB9KgfVX3HtvyMe3Zu8q7+6s6IcthHmaoK
    xcXLKTjcsQlVb7hcWMVYaaSwyiPxtRnF/Tk42ys0eps66rM9EKi+K6/mnSzjhquS
    XlGY+O2HxGq+H3K8kP8R6iLU09mm5Q11PBoir12wiHQ8m8NiTKzCLAOAt2CCBpyu
    UIu1Bie1A04MPaKuvKXpnML5Ib9LGiXcjI6kvjOXhrj1dT8ES8JALGJWnohYZjkJ
    0wIDAQAB
    -----END PUBLIC KEY-----
    """

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

            List {
                ForEach(archivos) { archivo in
                    Button {
                        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
                        let url = directorio.appendingPathComponent(archivo.nombre)
                        if FileManager.default.fileExists(atPath: url.path) {
                            archivoParaVistaPrevia = url
                        } else {
                            mensaje = "❌ No se encontró el archivo para vista previa."
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                                .padding(.trailing, 4)

                            VStack(alignment: .leading) {
                                Text(archivo.nombre)
                                    .bold()
                                    .lineLimit(2)
                                    .truncationMode(.tail) // corta al final con "..."
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
                    }
                    .buttonStyle(PlainButtonStyle()) // para que no se vea como botón azul

                    .onTapGesture {
                        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
                        let url = directorio.appendingPathComponent(archivo.nombre)
                        
                        if FileManager.default.fileExists(atPath: url.path) {
                            archivoParaVistaPrevia = url
                        } else {
                            mensaje = "❌ No se encontró el archivo."
                        }
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") {
                                archivoParaVistaPrevia = nil
                            }
                        }
                    }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cargarArchivos()
            }
        }

    }
    
    func eliminarArchivo(_ archivo: ArchivoCifrado) {
        archivos.removeAll { $0.id == archivo.id }
        guardarArchivos()
    }

    func compartirArchivoDesdeListado(_ archivo: ArchivoCifrado) {
        let directorio = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
        let url = directorio.appendingPathComponent(archivo.nombre)

        if FileManager.default.fileExists(atPath: url.path) {
            compartirArchivo(url)

        } else {
            mensaje = "❌ No se encontró el archivo."
        }
    }

    func nombreParaLlave(_ key: SecKey) -> String {
        if let attrs = SecKeyCopyAttributes(key) as? [String: Any],
           let labelData = attrs[kSecAttrApplicationLabel as String] as? Data,
           let label = String(data: labelData, encoding: .utf8) {
            return label
        }
        return "Llave pública"
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

struct ArchivoCompartible: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
