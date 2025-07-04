import Foundation
import UIKit

struct ClientService {
    static let shared = ClientService()
    private let registrarURL = URL(string: "http://symbolsaps.ddns.net:8000/api/registrar_cliente")!

    private let userDefaultsKey = "deviceUUID"

    /// Devuelve un UUID persistente para este dispositivo
    func getOrCreateUUID() -> String {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: userDefaultsKey) {
            return saved
        }
        let newUUID = UUID().uuidString
        defaults.set(newUUID, forKey: userDefaultsKey)
        return newUUID
    }

    /// Obtiene información del dispositivo
    func getDeviceInfo() -> (hostname: String, sistema: String) {
        let device = UIDevice.current
        let hostname = device.name
        let sistema = "\(device.systemName) \(device.systemVersion)"
        return (hostname, sistema)
    }

    /// Llama al backend para registrar el cliente (si no existe ya)
    func registrarCliente(completion: @escaping (Bool) -> Void) {
        let uuid = getOrCreateUUID()
        let (hostname, sistema) = getDeviceInfo()

        var request = URLRequest(url: registrarURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let json: [String: Any] = [
            "uuid": uuid,
            "hostname": hostname,
            "sistema": sistema // debe coincidir con el backend
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: json)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error al registrar cliente:", error.localizedDescription)
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Respuesta inválida del servidor")
                completion(false)
                return
            }

            if httpResponse.statusCode == 200 {
                print("✅ Cliente registrado correctamente")
                completion(true)
            } else {
                print("⚠️ Falló el registro del cliente. Código:", httpResponse.statusCode)
                completion(false)
            }
        }.resume()
    }
}
