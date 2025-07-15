import Foundation
import CryptoKit

struct ArchivoDescifrado: Identifiable {
    let id = UUID()
    let nombre: String
    let url: URL
    let fecha: Date
}

class FileDecryptor {
    static func descifrar(url: URL, password: String?, privateKey: SecKey?) throws -> ArchivoDescifrado {
        var fileData = try Data(contentsOf: url)

        let delimitador = "--BETTY-DELIM--"
        if let delimitadorData = delimitador.data(using: .utf8),
           let rango = fileData.range(of: delimitadorData) {
            let cifradoInicio = rango.upperBound
            fileData = fileData[cifradoInicio...]
        }

        guard let json = try JSONSerialization.jsonObject(with: fileData) as? [String: Any],
              let dataHex = json["data"] as? String,
              let ivHex = json["iv"] as? String,
              let type = json["type"] as? String,
              let sealedData = Data(hex: dataHex),
              let iv = Data(hex: ivHex) else {
            throw NSError(domain: "Formato inválido", code: 1)
        }

        let aesKey: SymmetricKey

        if type == "password" {
            guard let saltHex = json["salt_user"] as? String,
                  let salt = Data(hex: saltHex),
                  let password = password else {
                throw NSError(domain: "Faltan datos de contraseña", code: 2)
            }
            aesKey = CryptoUtils.deriveKey(from: password, salt: salt)
        } else if type == "rsa" {
            guard let privateKey = privateKey,
                  let keyHex = json["key_user"] as? String,
                  let encryptedKey = Data(hex: keyHex) else {
                throw NSError(domain: "Faltan datos de clave RSA", code: 3)
            }

            var error: Unmanaged<CFError>?
            guard let decrypted = SecKeyCreateDecryptedData(
                privateKey,
                .rsaEncryptionOAEPSHA256,
                encryptedKey as CFData,
                &error
            ) else {
                throw error?.takeRetainedValue() ?? NSError(domain: "RSA Error", code: 4)
            }

            aesKey = SymmetricKey(data: decrypted as Data)
        } else {
            throw NSError(domain: "Método no soportado", code: 5)
        }

        let tagRange = sealedData.index(sealedData.endIndex, offsetBy: -16)..<sealedData.endIndex
        let ciphertext = sealedData[..<tagRange.lowerBound]
        let tag = sealedData[tagRange]

        let nonce = try AES.GCM.Nonce(data: iv)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(sealed, using: aesKey)

        let nombreOriginal = (json["filename"] as? String) ?? "archivo"
        let nombreBase = nombreOriginal.replacingOccurrences(of: ".json", with: "")
        let ext = (json["ext"] as? String) ?? (nombreOriginal as NSString).pathExtension

        let destinoDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Encrypt_iOS")
        try FileManager.default.createDirectory(at: destinoDir, withIntermediateDirectories: true)
        let destino = destinoDir.appendingPathComponent(nombreBase + ext)

        try plaintext.write(to: destino)

        return ArchivoDescifrado(nombre: destino.lastPathComponent, url: destino, fecha: Date())
    }
}
