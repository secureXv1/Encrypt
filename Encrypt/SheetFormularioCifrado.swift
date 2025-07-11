import SwiftUI
import CryptoKit
import UniformTypeIdentifiers
import CommonCrypto


struct SheetFormularioCifrado: View {
    let archivoURL: URL
    let onFinish: (URL) -> Void
    
    @Binding var isPresented: Bool
    @State private var usarContraseña = true
    @State private var contraseña = ""
    @State private var llaveSeleccionada: LlavePublica?
    @State private var llavesDisponibles: [LlavePublica] = []
    @State private var mensaje = ""
    @State private var urlArchivoCifrado: URL?
    @State private var mostrarCompartir = false
    @State private var mostrarAlertaOcultar = false
    @State private var mostrarPickerContenedor = false
    @State private var archivoOculto: URL?
    @State private var mostrarSelectorPlantilla = false
    
    
    let masterPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiCfktLjm9bcCMzIyGnKw
    Z4frVoBi2nHDuaaIsYPs3t4pL5l+Udq3FO+lhKZtSCZZI54MLRqRamelnSHNpFxI
    UKiU34ZKiv6o+mPCtQegZ1EaoMEKOu26MukDC2oFL9b5R17USZntZOGFfC8s2NPl
    A5zMfRheR49Ufb/4lLNGKoTql3ACzHqHk05vcwQcR/isoHkWk3m4+r7HFDb4aMqj
    Mj1N3DkKe2upeQIExdrcrBNKYZ8g/LpFp2S13+C0Qlj/mvDiarJ3/c9+ekNhCnIn
    SjFYmLLH1ZeowWeH+fZXSOAL0WIOvi+RynjvpT5BfnNGrJW9iP0QJgsw2axxOZw6
    GwIDAQAB
    -----END PUBLIC KEY-----
    """
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Archivo a cifrar")) {
                        Text(archivoURL.lastPathComponent)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                Section(header: Text("Método de cifrado")) {
                    Picker("Método", selection: $usarContraseña) {
                        Text("Contraseña").tag(true)
                        Text("Llave pública").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if usarContraseña {
                        SecureField("Contraseña", text: $contraseña)
                    } else {
                        Picker("Selecciona una llave", selection: $llaveSeleccionada) {
                            ForEach(llavesDisponibles) { item in
                                Text(item.alias).tag(item as LlavePublica?)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Cifrar ahora") {
                        cifrarArchivo()
                    }
                    .disabled((usarContraseña && contraseña.isEmpty) || (!usarContraseña && llaveSeleccionada == nil))
                }
                
                if let url = urlArchivoCifrado {
                    Section(header: Text("Resultado")) {
                        Text("✅ \(url.lastPathComponent)")
                            .foregroundColor(.green)
                        
                        Button("Compartir") {
                            mostrarAlertaOcultar = true
                        }
                        .alert(isPresented: $mostrarAlertaOcultar) {
                            Alert(
                                title: Text("¿Deseas ocultar el archivo antes de compartir?"),
                                message: Text("Puedes ocultarlo dentro de una imagen u otro archivo contenedor."),
                                primaryButton: .default(Text("Sí")) {
                                    mostrarSelectorPlantilla = true
                                },
                                secondaryButton: .cancel(Text("No")) {
                                    mostrarCompartir = true
                                }
                            )
                        }
                    }
                }
                
                if !mensaje.isEmpty {
                    Text(mensaje).foregroundColor(.red)
                }
            }
            .navigationTitle("Cifrado de archivo")
            .navigationBarItems(trailing: Button("Cancelar") {
                isPresented = false
            })
            .onAppear {
                cargarLlaves()
            }
        }
        .sheet(isPresented: $mostrarCompartir) {
            if let originalURL = archivoOculto ?? urlArchivoCifrado {
                let seguroURL = prepararArchivoParaCompartir(originalURL)
                ShareWrapper(url: seguroURL)
            }
        }
        .sheet(isPresented: $mostrarSelectorPlantilla) {
            DocumentPickerWrapper { seleccionada in
                guard let originalContenedor = seleccionada, let cifrado = urlArchivoCifrado else { return }
                
                let ext = originalContenedor.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "heic"].contains(ext) {
                    // Convertir imagen a PDF antes de ocultar
                    if let pdfContenedor = convertirImagenAPDF(originalContenedor) {
                        ocultarArchivo(cifrado: cifrado, contenedor: pdfContenedor)
                    } else {
                        mensaje = "❌ No se pudo convertir la imagen a PDF."
                    }
                } else {
                    ocultarArchivo(cifrado: cifrado, contenedor: originalContenedor)
                }
            }
        }
    }
    
    func ocultarArchivo(cifrado: URL, contenedor: URL) {
        let delimitador = "--BETTY-DELIM--"
        
        // Activar acceso al archivo externo
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
            
            archivoOculto = destino
            mostrarCompartir = true
            
        } catch {
            mensaje = "❌ Error ocultando archivo: \(error.localizedDescription)"
        }
    }
    func convertirImagenAPDF(_ imagenURL: URL) -> URL? {
        guard imagenURL.startAccessingSecurityScopedResource() else {
            print("❌ No se pudo acceder al recurso seguro.")
            return nil
        }
        defer { imagenURL.stopAccessingSecurityScopedResource() }
        
        // Copiar a una ruta temporal
        let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent(imagenURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: tempImageURL.path) {
                try FileManager.default.removeItem(at: tempImageURL)
            }
            try FileManager.default.copyItem(at: imagenURL, to: tempImageURL)
        } catch {
            print("❌ Error copiando imagen a temporal: \(error)")
            return nil
        }
        
        // Cargar imagen
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
        
        let destino = FileManager.default.temporaryDirectory.appendingPathComponent(tempImageURL.deletingPathExtension().lastPathComponent + ".pdf")
        
        do {
            try pdfData.write(to: destino)
            return destino
        } catch {
            print("❌ Error escribiendo PDF: \(error)")
            return nil
        }
    }
    
    func prepararArchivoParaCompartir(_ url: URL) -> URL {
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
            mensaje = "❌ Error preparando archivo para compartir: \(error.localizedDescription)"
            return url
        }
    }
    
    func cifrarArchivo() {
        do {
            let fileData = try Data(contentsOf: archivoURL)
            let base64Content = fileData.base64EncodedString()

            let payload: [String: Any] = [
                "filename": archivoURL.lastPathComponent,
                "ext": ".\(archivoURL.pathExtension)",
                "content": base64Content
            ]

            let inputData = try JSONSerialization.data(withJSONObject: payload, options: [])

            let saltUser = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
            let saltAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
            let ivUser = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
            let ivAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })

            let keyUser = CryptoUtils.deriveKey(from: contraseña, salt: saltUser)
            let aesKey = keyUser
            let aesKeyData = keyUser.withUnsafeBytes { Data($0) }

            let ivData = ivUser // AES-GCM IV

            guard let (ciphertext, tag) = CryptoUtils.encrypt(data: inputData, key: aesKey, iv: ivData) else {
                mensaje = "❌ Falló el cifrado AES-GCM"
                return
            }
            let combined = ciphertext + tag
            var json: [String: Any] = [
                "filename": archivoURL.lastPathComponent,
                "ext": ".\(archivoURL.pathExtension)",
                "type": usarContraseña ? "password" : "rsa",
                "data": (ciphertext + tag).toHexString(),   // ✅ combinado
                "iv": ivData.toHexString()
            ]
            
            if usarContraseña {
                let saltUser = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let saltAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let ivUser = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let ivAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                
                let keyUser = CryptoUtils.deriveKey(from: contraseña, salt: saltUser)
                let keyAdmin = CryptoUtils.deriveKey(from: "SeguraAdmin123", salt: saltAdmin)
                guard let encryptedPassword = CryptoUtils.encryptCBC(
                    data: contraseña.data(using: .utf8)!,
                    key: keyAdmin.withUnsafeBytes { Data($0) },
                    iv: ivAdmin
                ) else {
                    mensaje = "❌ Falló el cifrado de contraseña"
                    return
                }
                json["encrypted_user_password"] = encryptedPassword.toHexString()

                
                json["salt_user"] = saltUser.toHexString()
                json["salt_admin"] = saltAdmin.toHexString()
                json["iv_user"] = ivUser.toHexString()
                json["iv_admin"] = ivAdmin.toHexString()
                json["encrypted_user_password"] = encryptedPassword.toHexString()
                
            } else {
                guard let llave = llaveSeleccionada else {
                    mensaje = "❌ Llave no seleccionada"
                    return
                }
                
                guard let encryptedKeyUser = CryptoUtils.encryptRSA(secKey: llave.clave, data: aesKeyData) else {
                    mensaje = "❌ Error con la llave del usuario"
                    return
                }
                
                let encryptedKeyMaster = CryptoUtils.encryptRSA(data: aesKeyData, pem: masterPublicKeyPEM)
                if encryptedKeyMaster.isEmpty {
                    mensaje = "❌ Error con la llave maestra"
                    return
                }
                
                json["key_user"] = encryptedKeyUser.toHexString()
                json["key_master"] = encryptedKeyMaster.toHexString()
            }

            let outDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            let name = archivoURL.deletingPathExtension().lastPathComponent + ".json"
            let path = outDir.appendingPathComponent(name)
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: path)
            
            urlArchivoCifrado = path
            
            let nuevo = ArchivoCifrado(nombre: name, fecha: Date())
            if var existentes = try? UserDefaults.standard.data(forKey: "archivos_cifrados").flatMap({ try? JSONDecoder().decode([ArchivoCifrado].self, from: $0) }) {
                existentes.append(nuevo)
                if let data = try? JSONEncoder().encode(existentes) {
                    UserDefaults.standard.set(data, forKey: "archivos_cifrados")
                }
            } else {
                if let data = try? JSONEncoder().encode([nuevo]) {
                    UserDefaults.standard.set(data, forKey: "archivos_cifrados")
                }
            }
            
        } catch {
            mensaje = "❌ Error al cifrar: \(error.localizedDescription)"
        }
    }
    
    func cargarLlaves() {
        llavesDisponibles = []
        
        // 1. Llaves generadas (llavero)
        if let data = UserDefaults.standard.data(forKey: "rsa_keys"),
           let guardadas = try? JSONDecoder().decode([RSAKey].self, from: data) {
            for rsa in guardadas {
                let tag = "com.endcrypt.\(rsa.alias)"
                if let clave = recuperarClavePublica(tag: tag) {
                    llavesDisponibles.append(LlavePublica(alias: rsa.alias, clave: clave))
                }
            }
        }
        
        // 2. Llaves importadas (archivos PEM)
        let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // NUEVO: buscar en todo Documents, no solo /LlavesPublicas
        if let archivos = try? FileManager.default.contentsOfDirectory(at: documentos, includingPropertiesForKeys: nil) {
            for archivo in archivos where archivo.pathExtension == "pem" {
                if let contenido = try? String(contentsOf: archivo) {
                    let nombre = archivo.deletingPathExtension().lastPathComponent
                    var secKey: SecKey?

                    if contenido.contains("-----BEGIN RSA PUBLIC KEY-----") {
                        secKey = CryptoUtils.importarLlavePublicaPKCS1DesdePEM(contenido)
                    } else {
                        secKey = CryptoUtils.importarLlavePublicaDesdePEM(contenido)
                    }

                    if let clave = secKey {
                        print("✅ Llave importada correctamente: \(nombre)")
                        llavesDisponibles.append(LlavePublica(alias: nombre, clave: clave))
                    } else {
                        print("❌ Error importando PEM desde archivo: \(archivo.lastPathComponent)")
                    }
                }
            }
        }
    }
    
    func recuperarClavePublica(tag: String) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let privateKey = item {
            return SecKeyCopyPublicKey(privateKey as! SecKey)
        } else {
            return nil
        }
    }
}

struct CryptoUtils {
    static func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: password.data(using: .utf8)!),
                                         salt: salt,
                                         info: Data(),
                                         outputByteCount: 32)
        return key
    }
    
    static func encrypt(data: Data, key: SymmetricKey, iv: Data) -> (ciphertext: Data, tag: Data)? {
        do {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
            return (sealed.ciphertext, sealed.tag)
        } catch {
            print("❌ Error cifrando GCM: \(error)")
            return nil
        }
    }
    
    static func encryptRSA(secKey: SecKey, data: Data) -> Data? {
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(secKey, .rsaEncryptionOAEPSHA256, data as CFData, &error) else {
            if let err = error?.takeRetainedValue() {
                print("❌ Error cifrando con RSA: \(err.localizedDescription)")
            }
            return nil
        }
        return encrypted as Data
    }
    static func encryptRSA(data: Data, pem: String) -> Data {
        let trimmedPem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        var derData: Data?

        if trimmedPem.contains("RSA PUBLIC KEY") {
            // PKCS#1 → convertir a PKCS#8
            let keyString = trimmedPem
                .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
                .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
                .replacingOccurrences(of: "\n", with: "")
            guard let rawKey = Data(base64Encoded: keyString) else { return Data() }
            derData = CryptoUtils.pkcs1ToPkcs8(rawKey)
        } else if trimmedPem.contains("BEGIN PUBLIC KEY") {
            let keyString = trimmedPem
                .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
                .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
                .replacingOccurrences(of: "\n", with: "")
            derData = Data(base64Encoded: keyString)
        }

        guard let keyData = derData else {
            print("❌ Error convirtiendo PEM a DER")
            return Data()
        }

        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        guard let secKey = SecKeyCreateWithData(keyData as CFData, options as CFDictionary, nil) else {
            print("❌ No se pudo crear SecKey desde clave maestra")
            return Data()
        }

        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(secKey, .rsaEncryptionOAEPSHA256, data as CFData, &error) else {
            print("❌ Error cifrando con RSA (clave maestra): \(error?.takeRetainedValue().localizedDescription ?? "desconocido")")
            return Data()
        }

        return encrypted as Data
    }
    static func pkcs1ToPkcs8(_ pkcs1: Data) -> Data {
        let rsaOID: [UInt8] = [
            0x30, 0x0D,
            0x06, 0x09,
            0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
            0x05, 0x00
        ]
        let bitString = [0x00] + [UInt8](pkcs1)
        let bitStringLen = encodeASN1Length(bitString.count)
        let bitStringASN1: [UInt8] = [0x03] + bitStringLen + bitString

        let algIdLen = encodeASN1Length(rsaOID.count)
        let algIdSequence: [UInt8] = [0x30] + algIdLen + rsaOID

        let fullBody = algIdSequence + bitStringASN1
        let fullLen = encodeASN1Length(fullBody.count)

        return Data([0x30] + fullLen + fullBody)
    }
    private static func encodeASN1Length(_ length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        }
        var len = length
        var bytes: [UInt8] = []
        while len > 0 {
            bytes.insert(UInt8(len & 0xFF), at: 0)
            len = len >> 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }
    static func importarLlavePublicaDesdePEM(_ pem: String) -> SecKey? {
        let keyString = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard let derData = Data(base64Encoded: keyString) else { return nil }
        
        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        return SecKeyCreateWithData(derData as CFData, options as CFDictionary, nil)
    }
    static func encryptCBC(data: Data, key: Data, iv: Data) -> Data? {
        let keyLength = key.count
        let dataLength = data.count
        let bufferSize = dataLength + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0

        let cryptStatus = buffer.withUnsafeMutableBytes { bufferBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keyLength,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            dataLength,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        guard cryptStatus == kCCSuccess else {
            print("❌ Error en cifrado AES-CBC")
            return nil
        }

        return buffer.prefix(numBytesEncrypted)
    }
    static func importarLlavePublicaPKCS1DesdePEM(_ pem: String) -> SecKey? {
        let keyString = pem
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard let pkcs1Data = Data(base64Encoded: keyString) else { return nil }

        // Construir el encabezado ASN.1 para PKCS#8
        let pkcs8Data = pkcs1ToPkcs8(pkcs1Data)

        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        return SecKeyCreateWithData(pkcs8Data as CFData, options as CFDictionary, nil)
    }
}

struct ShareWrapper: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct DocumentPickerWrapper: UIViewControllerRepresentable {
    let onPick: (URL?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tipos: [UTType] = [.data] // Puedes restringir si lo deseas a [.pdf, .image, etc.]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: tipos)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        
        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}
