import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct ArchivoDescifrado: Identifiable {
    let id = UUID()
    let nombre: String
    let url: URL
    let fecha: Date
}

struct DescifrarArchivoView: View {
    @State private var mostrarFormulario = false
    @State private var archivos: [ArchivoDescifrado] = []
    @State private var archivoSeleccionado: URL?
    @State private var mensaje = ""
    @State private var mostrarPicker = false
    @State private var mostrarCompartir = false
    @State private var archivoParaCompartir: URL?
    @State private var archivoParaVistaPrevia: URL?

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
                                    if let temp = copiarAArchivoTemporal(archivo.url) {
                                        compartirArchivo(temp)
                                    }
                                } label: {
                                    Label("Compartir", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
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
            if url.lastPathComponent.contains("_descifrado") {
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
}

struct LlavePrivada: Identifiable, Hashable {
    let id = UUID()
    let alias: String
    let clave: SecKey
}

struct SheetDescifrarArchivoView: View {
    var onDescifrado: (ArchivoDescifrado) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedFileURL: URL?
    @State private var usarContraseña = true
    @State private var contraseña = ""
    @State private var mensaje = ""
    @State private var mostrarImportador = false
    @State private var llavesPrivadas: [LlavePrivada] = []
    @State private var llaveSeleccionada: LlavePrivada?

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

                Section(header: Text("Método de descifrado")) {
                    Picker("Método", selection: $usarContraseña) {
                        Text("Contraseña").tag(true)
                        Text("Llave privada").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if usarContraseña {
                        SecureField("Contraseña", text: $contraseña)
                    } else {
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
                    .disabled(selectedFileURL == nil || (usarContraseña && contraseña.isEmpty))
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
        guard var url = selectedFileURL else {
            mensaje = "Selecciona un archivo"
            return
        }

        do {
            // Paso 1: Leer el archivo seleccionado
            var fileData = try Data(contentsOf: url)

            // Paso 2: Detectar y extraer si contiene contenido oculto
            let delimitador = "--BETTY-DELIM--"
            if let delimitadorData = delimitador.data(using: .utf8),
               let rango = fileData.range(of: delimitadorData) {
                let cifradoInicio = rango.upperBound
                let datosCifrados = fileData[cifradoInicio...]

                // Guardar el archivo extraído como .json temporal
                let extraidoURL = FileManager.default.temporaryDirectory.appendingPathComponent("extraido.json")
                try datosCifrados.write(to: extraidoURL)
                fileData = datosCifrados
                url = extraidoURL
            }

            // Paso 3: Interpretar JSON cifrado
            let jsonData = fileData
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                mensaje = "❌ Formato de archivo inválido"
                return
            }

            guard let dataHex = json["data"] as? String,
                  let ivHex = json["iv"] as? String,
                  let type = json["type"] as? String,
                  let sealedData = Data(hex: dataHex),
                  let iv = Data(hex: ivHex) else {
                mensaje = "❌ Faltan o están mal formateados los campos 'data' o 'iv'"
                return
            }

            let aesKey: SymmetricKey

            if type == "password" {
                guard usarContraseña else {
                    mensaje = "❌ Este archivo requiere contraseña"
                    return
                }

                guard let saltBase64 = json["salt_user"] as? String,
                      let salt = Data(base64Encoded: saltBase64) else {
                    mensaje = "❌ Faltan datos de contraseña"
                    return
                }

                aesKey = CryptoUtils.deriveKey(from: contraseña, salt: salt)
            }

            else if type == "rsa" {
                guard !usarContraseña, let llave = llaveSeleccionada else {
                    mensaje = "❌ Este archivo requiere llave privada"
                    return
                }

                guard let keyHex = json["key_user"] as? String,
                      let encryptedKey = Data(hex: keyHex) else {
                    mensaje = "❌ Clave cifrada RSA inválida (Hex)"
                    return
                }

                var error: Unmanaged<CFError>?
                guard let decrypted = SecKeyCreateDecryptedData(
                    llave.clave,
                    .rsaEncryptionOAEPSHA256,
                    encryptedKey as CFData,
                    &error
                ) else {
                    if let err = error?.takeRetainedValue() {
                        print("🔐 Error RSA: \(err.localizedDescription)")
                    }
                    mensaje = "❌ Error descifrando la clave AES con RSA"
                    return
                }

                aesKey = SymmetricKey(data: decrypted as Data)
            }

            else {
                mensaje = "❌ Método de cifrado no soportado"
                return
            }

            // Reconstruir SealedBox: ciphertext + tag
            guard sealedData.count >= 16 else {
                mensaje = "❌ Datos cifrados inválidos"
                return
            }

            let tagRange = sealedData.index(sealedData.endIndex, offsetBy: -16)..<sealedData.endIndex
            let ciphertext = sealedData[..<tagRange.lowerBound]
            let tag = sealedData[tagRange]

            let nonce = try AES.GCM.Nonce(data: iv)
            let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plaintext = try AES.GCM.open(sealed, using: aesKey)

            let nombreOriginal = (json["filename"] as? String) ?? "archivo"
            let nombreBase = nombreOriginal.replacingOccurrences(of: ".json", with: "").replacingOccurrences(of: "_Cif", with: "")
            let ext = (json["ext"] as? String) ?? (nombreOriginal as NSString).pathExtension
            let destinoDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
            try FileManager.default.createDirectory(at: destinoDir, withIntermediateDirectories: true)
            let destino = destinoDir.appendingPathComponent("\(nombreBase)_descifrado\(ext)")

            try plaintext.write(to: destino)

            let nuevo = ArchivoDescifrado(nombre: destino.lastPathComponent, url: destino, fecha: Date())
            mensaje = "✅ Descifrado exitoso: \(nuevo.nombre)"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onDescifrado(nuevo)
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
