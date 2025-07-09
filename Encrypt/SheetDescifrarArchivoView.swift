import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct SheetDescifrarArchivoView: View {
    var archivo: URL? = nil
    var onDescifrado: (ArchivoDescifrado) -> Void


    @Environment(\.dismiss) var dismiss
    @State private var selectedFileURL: URL?
    @State private var contraseña = ""
    @State private var mensaje = ""
    @State private var mostrarImportador = false
    @State private var llavesPrivadas: [LlavePrivada] = []
    @State private var llaveSeleccionada: LlavePrivada?
    @State private var tipoDetectado: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Seleccionar archivo cifrado")) {
                    Button("Seleccionar") {
                        mostrarImportador = true
                    }

                    if let url = selectedFileURL {
                        Text("📄 \(url.lastPathComponent)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                if tipoDetectado == "password" {
                    Section(header: Text("Método: Contraseña")) {
                        SecureField("Contraseña", text: $contraseña)
                    }
                } else if tipoDetectado == "rsa" {
                    Section(header: Text("Método: Llave privada")) {
                        Picker("Selecciona una llave", selection: $llaveSeleccionada) {
                            ForEach(llavesPrivadas) { item in
                                Text(item.alias).tag(item as LlavePrivada?)
                            }
                        }
                    }
                }

                Section {
                    Button("Descifrar") {
                        descifrarArchivo()
                    }
                    .disabled(selectedFileURL == nil ||
                             (tipoDetectado == "password" && contraseña.isEmpty) ||
                             (tipoDetectado == "rsa" && llaveSeleccionada == nil))
                }

                if !mensaje.isEmpty {
                    Section {
                        Text(mensaje).foregroundColor(mensaje.contains("✅") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Descifrar archivo")
            .navigationBarItems(trailing: Button("Cerrar") {
                dismiss()
            })
            .onAppear {
                cargarLlavesPrivadas()
                if selectedFileURL == nil, let archivo = archivo {
                        selectedFileURL = archivo
                        tipoDetectado = FileDecryptor.detectarMetodo(url: archivo)  // <-- Agrega esto
                    }
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
                                mensaje = ""
                                tipoDetectado = FileDecryptor.detectarMetodo(url: destinationURL)
                            } catch {
                                mensaje = "❌ Error al copiar archivo: \(error.localizedDescription)"
                            }
                        }
                    }
                case .failure(let error):
                    mensaje = "❌ Error seleccionando archivo: \(error.localizedDescription)"
                }
            }
        }
    }

    func descifrarArchivo() {
        guard let url = selectedFileURL else {
            mensaje = "Selecciona un archivo"
            return
        }

        do {
            let resultado: ArchivoDescifrado

            if tipoDetectado == "password" {
                guard !contraseña.isEmpty else {
                    mensaje = "Debes ingresar una contraseña"
                    return
                }
                resultado = try FileDecryptor.descifrar(url: url, password: contraseña, privateKey: nil)

            } else if tipoDetectado == "rsa" {
                guard let llave = llaveSeleccionada else {
                    mensaje = "Debes seleccionar una llave privada"
                    return
                }
                resultado = try FileDecryptor.descifrar(url: url, password: nil, privateKey: llave.clave)

            } else {
                mensaje = "❌ Método no soportado"
                return
            }

            mensaje = "✅ Descifrado exitoso: \(resultado.nombre)"
            registrarComoRecibido(cifradoNombre: url.lastPathComponent)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onDescifrado(resultado)
                dismiss()
            }

        } catch {
            mensaje = "❌ Error al descifrar: \(error.localizedDescription)"
        }
    }


    
    func cargarLlavesPrivadas() {
        llavesPrivadas.removeAll()

        // Cargar desde UserDefaults los alias
        if let data = UserDefaults.standard.data(forKey: "rsa_keys"),
           let guardadas = try? JSONDecoder().decode([RSAKey].self, from: data) {
            for key in guardadas {
                let tagData = "com.endcrypt.\(key.alias)".data(using: .utf8)!
                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                    kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,  // ✅ SOLO claves privadas
                    kSecReturnRef as String: true
                ]

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)

                if status == errSecSuccess, let item = item {
                    let clave = item as! SecKey
                    if let attrs = SecKeyCopyAttributes(clave) as? [String: Any],
                       let keyClass = attrs[kSecAttrKeyClass as String] as? String,
                       keyClass == (kSecAttrKeyClassPrivate as String) {
                        llavesPrivadas.append(LlavePrivada(alias: key.alias, clave: clave))
                    } else {
                        print("⚠️ La clave recuperada no es privada. Alias: \(key.alias)")
                    }
                }
            }
        }
    }
    func registrarComoRecibido(cifradoNombre: String) {
        var existentes = (try? UserDefaults.standard.data(forKey: "archivos_cifrados"))
            .flatMap { try? JSONDecoder().decode([ArchivoCifrado].self, from: $0) } ?? []

        let yaRegistrado = existentes.contains { $0.nombre == cifradoNombre }

        if !yaRegistrado {
            let recibido = ArchivoCifrado(nombre: cifradoNombre, fecha: Date(), esRecibido: true)
            existentes.append(recibido)

            if let data = try? JSONEncoder().encode(existentes) {
                UserDefaults.standard.set(data, forKey: "archivos_cifrados")
            }
        }
    }
}

extension StringProtocol {
    func mapPairs() -> [String] {
        stride(from: 0, to: count, by: 2).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: 2, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}

