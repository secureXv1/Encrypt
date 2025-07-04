import SwiftUI
import CryptoKit

struct RSAKey: Identifiable, Codable {
    let id: UUID
    let alias: String
    let createdAt: Date
    let esImportada: Bool

    init(alias: String, createdAt: Date, esImportada: Bool) {
        self.id = UUID()
        self.alias = alias
        self.createdAt = createdAt
        self.esImportada = esImportada
    }
}

struct CrearLlavesView: View {
    @State private var llaves: [RSAKey] = []
    @State private var mensaje = ""
    @State private var mostrarFormulario = false
    @State private var nuevoAlias = ""
    @State private var mostrarImportador = false
    @State private var urlImportar: URL? = nil
    @State private var mostrarSelectorArchivo = false


    let storageKey = "rsa_keys"

    var body: some View {
        VStack {
            HStack {
                Text("Llaves generadas")
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

            List {
                if !llaves.filter({ !$0.esImportada }).isEmpty {
                    Section(header: Text("Llaves creadas")) {
                        ForEach(llaves.filter { !$0.esImportada }.sorted(by: { $0.createdAt > $1.createdAt })) { key in

                            celdaLlave(key)
                        }
                    }
                }

                if !llaves.filter({ $0.esImportada }).isEmpty {
                    Section(header: Text("Llaves importadas")) {
                        ForEach(llaves.filter { $0.esImportada }
                            .sorted(by: { $0.createdAt > $1.createdAt })) { key in
                            celdaLlave(key)
                        }
                    }
                }
            }
            Text(mensaje)
                .foregroundColor(.green)
                .padding(.top, 10)
        }
        .sheet(isPresented: $mostrarFormulario) {
            NavigationView {
                Form {
                    // 🔹 Sección: Crear nueva llave
                    Section(header: Text("Crear nueva llave")) {
                        TextField("Alias", text: $nuevoAlias)

                        Button(action: {
                            generarLlaves()
                        }) {
                            Label("Generar llave", systemImage: "key.fill")
                        }
                        .disabled(nuevoAlias.isEmpty)
                    }

                    // 🔹 Sección: Importar llave
                    Section(header: Text("Importar llave pública")) {
                        if let url = urlImportar {
                            HStack {
                                Image(systemName: "doc.text")
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: {
                            mostrarSelectorArchivo = true
                        }) {
                            Label("Seleccionar archivo", systemImage: "folder")
                        }

                        Button(action: {
                            if let url = urlImportar {
                                importarLlaveDesdeArchivo(url)
                                mostrarFormulario = false
                            }
                        }) {
                            Label("Importar llave", systemImage: "square.and.arrow.down")
                        }
                        .disabled(urlImportar == nil)
                    }
                }
                .navigationTitle("Administrar Llaves")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancelar") {
                    mostrarFormulario = false
                })
                .fileImporter(
                    isPresented: $mostrarSelectorArchivo,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let originalURL = urls.first {
                            let accessGranted = originalURL.startAccessingSecurityScopedResource()
                            defer {
                                if accessGranted {
                                    originalURL.stopAccessingSecurityScopedResource()
                                }
                            }

                            do {
                                let fileName = originalURL.lastPathComponent
                                let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)

                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    try FileManager.default.removeItem(at: destinationURL)
                                }

                                try FileManager.default.copyItem(at: originalURL, to: destinationURL)
                                urlImportar = destinationURL
                            } catch {
                                print("❌ Error copiando archivo al sandbox: \(error)")
                            }
                        }
                    case .failure(let error):
                        print("❌ Error seleccionando archivo: \(error)")
                    }
                }
            }
        }
        .onAppear(perform: cargarLlaves)
    }
    @ViewBuilder
    func celdaLlave(_ key: RSAKey) -> some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text(key.alias)
                    .bold()
                    .lineLimit(2)

                Text("Creada el \(formatDate(key.createdAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                eliminarLlave(key)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }

            Button {
                compartirClavePublica(alias: key.alias)
            } label: {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
    }

    func generarLlaves() {
        let tag = "com.endcrypt.\(nuevoAlias)".data(using: .utf8)!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            mensaje = "❌ Error generando llave"
            return
        }

        if SecKeyCopyPublicKey(privateKey) != nil {
            let nueva = RSAKey(alias: nuevoAlias, createdAt: Date(), esImportada: false)
            llaves.append(nueva)
            guardarLlaves()
            mensaje = "✅ Llave '\(nuevoAlias)' generada correctamente"
            nuevoAlias = ""
            mostrarFormulario = false
        }
    }

    func guardarLlaves() {
        if let data = try? JSONEncoder().encode(llaves) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func cargarLlaves() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let guardadas = try? JSONDecoder().decode([RSAKey].self, from: data) {
            self.llaves = guardadas
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    func eliminarLlave(_ llave: RSAKey) {
        // Elimina de memoria
        llaves.removeAll { $0.id == llave.id }
        guardarLlaves()

        // Elimina del llavero
        let tag = "com.endcrypt.\(llave.alias)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]
        SecItemDelete(query as CFDictionary)

        mensaje = "🗑️ Llave '\(llave.alias)' eliminada"
    }
    func compartirClavePublica(alias: String) {
        let tag = "com.endcrypt.\(alias)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let privateKey = item as! SecKey?,
           let publicKey = SecKeyCopyPublicKey(privateKey) {

            if let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {
                // Exportar como archivo .pem
                let wrappedKey = wrapRSAPublicKeyToX509(publicKeyData)
                let pemString = convertToPEM(wrappedKey, type: "PUBLIC KEY")

                let filename = "\(alias)_public.pem"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

                do {
                    try pemString.write(to: url, atomically: true, encoding: .utf8)
                    compartirArchivo(url)
                } catch {
                    mensaje = "❌ Error al exportar clave pública"
                }
            } else {
                mensaje = "❌ No se pudo obtener representación externa"
            }
        } else {
            mensaje = "❌ No se encontró la llave"
        }
    }
    func wrapRSAPublicKeyToX509(_ rawKey: Data) -> Data {
        // ASN.1 DER encabezado para una clave pública RSA de 2048 bits
        // secuencia de SubjectPublicKeyInfo = SEQUENCE { SEQUENCE { OID rsaEncryption, NULL }, BIT STRING (clave) }
        let rsaOIDHeader: [UInt8] = [
            0x30, 0x82, 0x01, 0x22, // SEQUENCE (longitud total) ← puede variar según tamaño clave
            0x30, 0x0d,
            0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, // rsaEncryption OID
            0x05, 0x00, // NULL
            0x03, 0x82, 0x01, 0x0f, // BIT STRING ← longitud = rawKey + 1 (padding bit 0)
            0x00 // padding bits = 0
        ]

        var data = Data(rsaOIDHeader)
        data.append(rawKey)
        return data
    }
    func convertToPEM(_ data: Data, type: String) -> String {
        let base64 = data.base64EncodedString(options: [.lineLength64Characters])
        return """
        -----BEGIN \(type)-----
        \(base64)
        -----END \(type)-----
        """
    }
    func compartirArchivo(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(activityVC, animated: true)
    }
    func importarLlaveDesdeArchivo(_ url: URL) {
        do {
            let string = try String(contentsOf: url, encoding: .utf8)
            let lines = string.components(separatedBy: .newlines)
                .filter { !$0.contains("BEGIN PUBLIC KEY") && !$0.contains("END PUBLIC KEY") && !$0.isEmpty }
            let base64 = lines.joined()
            guard let data = Data(base64Encoded: base64) else {
                print("❌ Error: contenido PEM inválido (base64)")
                return
            }

            let tag = "com.endcrypt.imported.\(UUID().uuidString)"
            
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrKeySizeInBits as String: 2048,
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!
            ]
            
            var error: Unmanaged<CFError>?
            guard let publicKey = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
                print("❌ Error al importar llave: \(error?.takeRetainedValue().localizedDescription ?? "desconocido")")
                return
            }

            // Guarda el alias local
            let nombreArchivo = url.deletingPathExtension().lastPathComponent
            let nueva = RSAKey(alias: nombreArchivo, createdAt: Date(), esImportada: true)
            llaves.append(nueva)
            guardarLlaves()
            print("✅ Llave pública importada correctamente")

        } catch {
            print("❌ Error leyendo archivo: \(error)")
        }
    }
}

struct LlavePublica: Identifiable, Hashable {
    let id = UUID()
    let alias: String
    let clave: SecKey
}
