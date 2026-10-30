import Foundation
import Security
import SwiftADB

enum BridgeError: LocalizedError {
    case notConnected
    case invalidHost
    case invalidPort
    case invalidPackage
    case unsupportedFile
    case refusedProtectedPackage(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect to the TV first."
        case .invalidHost: "Enter a TV IP address or local hostname."
        case .invalidPort: "Enter a port between 1 and 65535."
        case .invalidPackage: "Enter a valid installed Android package name."
        case .unsupportedFile: "Select an Android APK file."
        case .refusedProtectedPackage(let package):
            "BridgeDeck will not disable the protected TV component \(package)."
        }
    }
}

enum AdbIdentity {
    private static let tag = Data("com.soum91.bridgedeck.adb.identity.v1".utf8)

    static func loadOrCreate() throws -> KeyPair {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let result else { throw NSError(domain: "BridgeDeck.Keychain", code: 3) }
            let privateKey = result as! SecKey
            guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
                throw NSError(domain: "BridgeDeck.Keychain", code: 1)
            }
            return KeyPair(privateKey: privateKey, publicKey: publicKey)
        }
        guard status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            if let error { throw error.takeRetainedValue() }
            throw NSError(domain: "BridgeDeck.Keychain", code: 2)
        }
        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

actor ADBClient {
    private var connection: AdbConnection?

    func connect(host: String, port: Int) async throws {
        guard !host.isEmpty, !host.contains(" "), !host.contains("/") else {
            throw BridgeError.invalidHost
        }
        guard (1...65535).contains(port) else { throw BridgeError.invalidPort }
        await disconnect()
        let keyPair = try AdbIdentity.loadOrCreate()
        let next = AdbConnection(
            host: host,
            port: UInt16(port),
            keyPair: keyPair,
            deviceName: "BridgeDeck iPhone"
        )
        guard try await next.connect(timeout: 45, throwOnUnauthorised: false) else {
            await next.close()
            throw NSError(domain: "BridgeDeck.ADB", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Timed out. Check network debugging and approve the TV prompt."])
        }
        connection = next
    }

    func disconnect() async {
        if let connection { await connection.close() }
        connection = nil
    }

    func shell(_ command: String) async throws -> String {
        guard let connection else { throw BridgeError.notConnected }
        let stream = try await connection.open(destination: "shell:\(command)")
        var output = Data()
        while true {
            do {
                let chunk = try await stream.read()
                if chunk.isEmpty { break }
                // Bound log output so a noisy command cannot exhaust iPhone memory.
                if output.count + chunk.count > 2_000_000 {
                    output.append(Data("\n[Output truncated]\n".utf8))
                    break
                }
                output.append(chunk)
            } catch { break }
        }
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func installAPK(from url: URL) async throws -> String {
        guard url.pathExtension.lowercased() == "apk" else {
            throw BridgeError.unsupportedFile
        }
        guard let connection else { throw BridgeError.notConnected }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        guard let size, size.int64Value > 0 else { throw BridgeError.unsupportedFile }
        let stream = try await connection.open(destination: "exec:cmd package install -S \(size.int64Value)")
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        while let data = try file.read(upToCount: 32 * 1024), !data.isEmpty {
            try await stream.write(data)
        }
        var response = Data()
        while true {
            do {
                let chunk = try await stream.read()
                if chunk.isEmpty { break }
                response.append(chunk)
            } catch { break }
        }
        return String(decoding: response, as: UTF8.self)
    }
}
