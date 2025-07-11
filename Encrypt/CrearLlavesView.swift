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

// 🔐 Tipo de clave detectada
enum TipoPEMKey {
    case `public`, `private`, desconocido
}

func detectarTipoClave(pem: String) -> TipoPEMKey {
    if pem.contains("BEGIN RSA PRIVATE KEY") {
        return .private
    } else if pem.contains("BEGIN PUBLIC KEY") || pem.contains("BEGIN RSA PUBLIC KEY") {
        return .public
    }
    return .desconocido
}

struct CrearLlavesView: View {
    @State private var llaves: [RSAKey] = []
    @State private var mensaje = ""
    @State private var mostrarFormulario = false
    @State private var nuevoAlias = ""
    @State private var mostrarImportador = false
    @State private var urlsImportar: [URL] = []
    @State private var mostrarSelectorArchivo = false
    @State private var modo = 0 // 0 = creadas, 1 = importadas

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

            Picker("Tipo", selection: $modo) {
                Text("Generadas").tag(0)
                Text("Importadas").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            List {
                ForEach(llaves.filter { $0.esImportada == (modo == 1) }.sorted(by: { $0.createdAt > $1.createdAt })) { key in
                    celdaLlave(key)
                }
            }
            Text(mensaje)
                .foregroundColor(.green)
                .padding(.top, 10)
        }
        .sheet(isPresented: $mostrarFormulario) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 28) {

                        // 🔐 Crear nueva llave
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Crear nueva llave")
                                .font(.headline)

                            TextField("Alias", text: $nuevoAlias)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Spacer()
                                Button {
                                    generarLlaves()
                                } label: {
                                    Label("Generar llave", systemImage: "key.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(nuevoAlias.isEmpty)
                                Spacer()
                            }
                        }

                        Divider()

                        // 📂 Importar llaves
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Importar llave(s)")
                                .font(.headline)

                            if !urlsImportar.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(urlsImportar, id: \.self) { url in
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .foregroundColor(.blue)
                                            Text(url.lastPathComponent)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }
                            }

                            HStack {
                                Spacer()
                                Button {
                                    mostrarSelectorArchivo = true
                                } label: {
                                    Label("Seleccionar archivo(s)", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }

                            HStack {
                                Spacer()
                                Button {
                                    for url in urlsImportar {
                                        importarLlaveDesdeArchivo(url)
                                    }
                                    urlsImportar.removeAll()
                                    mostrarFormulario = false
                                } label: {
                                    Label("Importar \(urlsImportar.count) archivo(s)", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(urlsImportar.isEmpty)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Administrar Llaves")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancelar") {
                    mostrarFormulario = false
                })
                .fileImporter(
                    isPresented: $mostrarSelectorArchivo,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        var nuevos: [URL] = []
                        for originalURL in urls {
                            let accessGranted = originalURL.startAccessingSecurityScopedResource()
                            defer {
                                if accessGranted {
                                    originalURL.stopAccessingSecurityScopedResource()
                                }
                            }

                            do {
                                let fileName = originalURL.lastPathComponent
                                let destinationURL = FileManager.default
                                    .urls(for: .documentDirectory, in: .userDomainMask).first!
                                    .appendingPathComponent(fileName)

                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    try FileManager.default.removeItem(at: destinationURL)
                                }

                                try FileManager.default.copyItem(at: originalURL, to: destinationURL)
                                nuevos.append(destinationURL)
                            } catch {
                                print("❌ Error copiando archivo al sandbox: \(error)")
                            }
                        }
                        urlsImportar = nuevos

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
        let disponibles = clavesDisponibles(alias: key.alias)

        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(key.alias)
                    .bold()
                    .lineLimit(2)

                Text("\(key.esImportada ? "Import:" : "Creada:") \(formatDate(key.createdAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 6) {
                if disponibles.pub {
                    Image(systemName: "arrow.up.right.square.fill")
                        .foregroundColor(.green)
                }
                if disponibles.priv {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)

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
                compartirClave(alias: key.alias)
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
        
        // 🔐 Guarda también la clave pública en el llavero
        let pubKey = SecKeyCopyPublicKey(privateKey)!
        var pubAttrs: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag
        ]
        pubAttrs[kSecValueRef as String] = pubKey
        SecItemAdd(pubAttrs as CFDictionary, nil)
        
        // ✅ Registro exitoso
        let nueva = RSAKey(alias: nuevoAlias, createdAt: Date(), esImportada: false)
        llaves.append(nueva)
        guardarLlaves()
        mensaje = "✅ Llave '\(nuevoAlias)' generada correctamente"
        nuevoAlias = ""
        mostrarFormulario = false
    }
    func guardarLlaves() {
        if let data = try? JSONEncoder().encode(llaves) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func cargarLlaves() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let guardadas = try? JSONDecoder().decode([RSAKey].self, from: data) {
            // Forzar refresco para actualizar íconos de claves disponibles
            DispatchQueue.main.async {
                self.llaves = guardadas
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    func eliminarLlave(_ llave: RSAKey) {
        let alert = UIAlertController(title: "Eliminar clave", message: "¿Qué deseas eliminar?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Sólo pública", style: .destructive) { _ in
            eliminarDelLlavero(alias: llave.alias, tipo: .public)
        })
        
        alert.addAction(UIAlertAction(title: "Sólo privada", style: .destructive) { _ in
            eliminarDelLlavero(alias: llave.alias, tipo: .private)
        })
        
        alert.addAction(UIAlertAction(title: "Ambas", style: .destructive) { _ in
            eliminarDelLlavero(alias: llave.alias, tipo: nil)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    func eliminarDelLlavero(alias: String, tipo: TipoClave?) {
        let tagData = "com.endcrypt.\(alias)".data(using: .utf8)!
        var deleted = false

        if tipo == .public || tipo == nil {
            let pubQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic
            ]
            deleted = SecItemDelete(pubQuery as CFDictionary) == errSecSuccess || deleted
        }

        if tipo == .private || tipo == nil {
            let privQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
            ]
            deleted = SecItemDelete(privQuery as CFDictionary) == errSecSuccess || deleted
        }

        // 🧠 Verifica si ya no queda ninguna clave (ni pública ni privada)
        let disponibles = clavesDisponibles(alias: alias)
        if !disponibles.pub && !disponibles.priv {
            llaves.removeAll { $0.alias == alias }
            guardarLlaves()
        }

        mensaje = deleted ? "🗑️ Eliminado: \(alias)" : "⚠️ No se encontró la llave"
    }
    func compartirClave(alias: String) {
        let alert = UIAlertController(title: "Compartir clave", message: "¿Cuál deseas compartir?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clave pública", style: .default) { _ in
            exportarClave(alias: alias, tipo: .public)
        })
        
        alert.addAction(UIAlertAction(title: "Clave privada", style: .default) { _ in
            exportarClave(alias: alias, tipo: .private)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    enum TipoClave {
        case `public`, `private`
    }
    
    func exportarClave(alias: String, tipo: TipoClave) {
        let tag = "com.endcrypt.\(alias)".data(using: .utf8)!
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]
        
        if tipo == .public {
            query[kSecAttrKeyClass as String] = kSecAttrKeyClassPrivate
        } else {
            query[kSecAttrKeyClass as String] = kSecAttrKeyClassPrivate
        }
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
            let key = item as! SecKey  // o simplemente: let key = item as SecKey
            
            let exportable: SecKey = (tipo == .public) ? SecKeyCopyPublicKey(key)! : key
            
            if let data = SecKeyCopyExternalRepresentation(exportable, nil) as Data? {
                let tipoStr = (tipo == .public) ? "RSA PUBLIC KEY" : "RSA PRIVATE KEY"
                let pem = convertToPEM(data, type: tipoStr)
                let nombre = "\(alias)_\(tipo == .public ? "public" : "private").pem"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
                
                do {
                    try pem.write(to: url, atomically: true, encoding: .utf8)
                    compartirArchivo(url)
                } catch {
                    mensaje = "❌ Error al exportar \(tipo == .public ? "pública" : "privada")"
                }
            }
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
            let contenido = try String(contentsOf: url, encoding: .utf8)
            let tipo = detectarTipoClave(pem: contenido)

            guard tipo != .desconocido else {
                print("❌ Tipo de clave desconocido")
                return
            }

            var nombre = url.deletingPathExtension().lastPathComponent
            if nombre.hasSuffix("_public") {
                nombre = String(nombre.dropLast(7))
            } else if nombre.hasSuffix("_private") {
                nombre = String(nombre.dropLast(8))
            }

            let tag = "com.endcrypt.\(nombre)"
            let tagData = tag.data(using: .utf8)!

            let base64 = contenido.components(separatedBy: .newlines)
                .filter { !$0.contains("BEGIN") && !$0.contains("END") && !$0.isEmpty }
                .joined()

            guard var data = Data(base64Encoded: base64) else {
                print("❌ Error: contenido PEM inválido (base64)")
                return
            }

            // 🔁 Si es clave pública PKCS#1, convertir a formato X.509
            if tipo == .public && url.lastPathComponent.contains("_public") && contenido.contains("BEGIN RSA PUBLIC KEY") {
                print("ℹ️ Clave pública PKCS#1 detectada. Envolviendo a formato X.509")
                data = wrapRSAPublicKeyToX509(data)
            }

            let keyClass = (tipo == .public) ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate

            let keyDict: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: keyClass,
                kSecAttrKeySizeInBits as String: 2048,
                kSecValueData as String: data,
                kSecAttrIsPermanent as String: true
            ]

            let status = SecItemAdd(keyDict as CFDictionary, nil)

            if status == errSecSuccess || status == errSecDuplicateItem {
                if let index = llaves.firstIndex(where: { $0.alias == nombre }) {
                    llaves[index] = llaves[index] // Forzar refresh
                } else {
                    let nueva = RSAKey(alias: nombre, createdAt: Date(), esImportada: true)
                    llaves.append(nueva)
                }
                guardarLlaves()
                cargarLlaves()
                mensaje = "✅ Llave \(tipo == .public ? "pública" : "privada") importada"
                print("🔐 Clave importada con tag: \(tag)")
            } else {
                print("❌ Error al guardar en llavero: \(status)")
            }
        } catch {
            print("❌ Error leyendo archivo: \(error)")
        }
    }
    func clavesDisponibles(alias: String) -> (pub: Bool, priv: Bool) {
        let tag = "com.endcrypt.\(alias)"
        let tagData = tag.data(using: .utf8)!

        let queryPub: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecReturnRef as String: true
        ]
        let queryPriv: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]
        let pub = SecItemCopyMatching(queryPub as CFDictionary, nil) == errSecSuccess
        let priv = SecItemCopyMatching(queryPriv as CFDictionary, nil) == errSecSuccess
        
        print("🔎 Claves para \(alias): pública=\(pub), privada=\(priv)")
        return (pub, priv)
    }
}

struct LlavePublica: Identifiable, Hashable {
    let id = UUID()
    let alias: String
    let clave: SecKey
}

