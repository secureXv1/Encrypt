import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

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
            let inputData = try Data(contentsOf: archivoURL)
            let aesKey = SymmetricKey(size: .bits256)
            
            // IV de 16 bytes (128 bits)
            let ivData = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
            let nonce = try AES.GCM.Nonce(data: ivData)
            
            // Cifrar el archivo
            let sealedBox = try AES.GCM.seal(inputData, using: aesKey, nonce: nonce)
            let cipherData = sealedBox.ciphertext + sealedBox.tag
            
            // Construir el JSON base
            var json: [String: Any] = [
                "filename": archivoURL.lastPathComponent,
                "ext": ".\(archivoURL.pathExtension)",
                "type": usarContraseña ? "password" : "rsa",
                "data": cipherData.toHexString(),
                "iv": ivData.toHexString()
            ]
            
            if usarContraseña {
                // IVs y sales de 16 bytes
                let saltUser = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let saltAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let ivUser = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                let ivAdmin = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
                
                let keyUser = CryptoUtils.deriveKey(from: contraseña, salt: saltUser)
                let keyAdmin = CryptoUtils.deriveKey(from: "SeguraAdmin123", salt: saltAdmin)
                
                let encryptedPassword = CryptoUtils.encrypt(
                    data: contraseña.data(using: .utf8)!,
                    key: keyAdmin,
                    iv: ivAdmin
                )
                
                json["salt_user"] = saltUser.base64EncodedString()
                json["salt_admin"] = saltAdmin.base64EncodedString()
                json["iv_user"] = ivUser.toHexString()
                json["iv_admin"] = ivAdmin.toHexString()
                json["encrypted_user_password"] = encryptedPassword.toHexString()
                
            } else {
                guard let llave = llaveSeleccionada else {
                    mensaje = "❌ Llave no seleccionada"
                    return
                }
                
                let aesKeyData = aesKey.withUnsafeBytes { Data($0) }
                
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
            
            // Guardar archivo en Documents/Encrypt_iOS
            let outDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            let name = archivoURL.deletingPathExtension().lastPathComponent + "_Cif.json"
            let path = outDir.appendingPathComponent(name)
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: path)
            
            urlArchivoCifrado = path
            
            // Guardar en lista local
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
                if let contenido = try? String(contentsOf: archivo),
                   let secKey = CryptoUtils.importarLlavePublicaDesdePEM(contenido) {
                    let nombre = archivo.deletingPathExtension().lastPathComponent
                    print("✅ Llave importada encontrada: \(nombre)")
                    llavesDisponibles.append(LlavePublica(alias: nombre, clave: secKey))
                } else {
                    print("❌ Error importando PEM desde archivo: \(archivo.lastPathComponent)")
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
    
    static func encrypt(data: Data, key: SymmetricKey, iv: Data) -> Data {
        let nonce = try! AES.GCM.Nonce(data: iv)
        let sealed = try! AES.GCM.seal(data, using: key, nonce: nonce)
        return sealed.ciphertext + sealed.tag
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
        let keyString = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        
        guard let derData = Data(base64Encoded: keyString) else { return Data() }
        
        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        guard let secKey = SecKeyCreateWithData(derData as CFData, options as CFDictionary, nil) else { return Data() }
        
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(secKey, .rsaEncryptionOAEPSHA256, data as CFData, &error) else {
            if let err = error?.takeRetainedValue() {
                print("❌ Error cifrando con RSA (PEM): \(err.localizedDescription)")
            }
            return Data()
        }
        
        return encrypted as Data
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
